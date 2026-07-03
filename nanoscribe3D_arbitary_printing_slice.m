function slices = nanoscribe3D_arbitary_printing_slice(cfg)
%NANOSCRIBE3D_ARBITARY_PRINTING_SLICE Slice an STL mesh or heightmap into layer masks.
%
% Shared by nanoscribe3D_arbitary_printing_generate and the GUI preview.
%
% Returns a struct:
%   .masks       Ny x Nx x nLayers logical; (row 1, col 1) at physical (y=0, x=0)
%   .x_um,.y_um  grid sample centers (pitch = cfg.xyResolution_um)
%   .z_um        1 x nLayers layer mid-plane heights (geometry frame, z up)
%   .nLayers, .sourceType ('stl'|'heightmap'), .extent_um [X Y Z]
%   .mesh        (STL) struct with .Points (um) and .ConnectivityList, for preview
%   .height_um   (heightmap) resampled height field on the grid, for preview
%   .oddCrossingRows  count of rows with odd crossing parity (non-watertight STL)

[~, ~, ext] = fileparts(cfg.inputPath);
switch lower(ext)
    case '.stl'
        slices = sliceStl(cfg);
    case '.mat'
        slices = sliceHeightmap(cfg);
    otherwise
        error('Input must be a .stl mesh or a .mat heightmap (got %s).', ext);
end
end

function slices = sliceStl(cfg)
TR = stlread(cfg.inputPath);
P = double(TR.Points) * cfg.stlScale_um_per_unit;   % -> micrometers
P = P - min(P, [], 1);                               % min corner at the origin
F = double(TR.ConnectivityList);

extent = max(P, [], 1);
if any(extent <= 0)
    error('STL mesh is degenerate (zero extent along an axis).');
end

res = cfg.xyResolution_um;
x = 0:res:extent(1);
y = 0:res:extent(2);
nLayers = ceil(extent(3) / cfg.layerHeight_um);
checkLayerCount(nLayers, cfg);

z1 = P(F(:, 1), 3); z2 = P(F(:, 2), 3); z3 = P(F(:, 3), 3);
triZmin = min(min(z1, z2), z3);
triZmax = max(max(z1, z2), z3);

masks = false(numel(y), numel(x), nLayers);
oddRows = 0;
for k = 1:nLayers
    zk = cfg.firstLayerZOffset_um + (k - 0.5) * cfg.layerHeight_um;
    tri = find(triZmin <= zk & triZmax > zk);   % half-open: vertex-on-plane safe
    if isempty(tri)
        continue;
    end
    segs = planeSegments(P, F(tri, :), zk);
    [masks(:, :, k), odd] = fillRows(segs, x, y);
    oddRows = oddRows + odd;
end

if oddRows > 0
    warning('nanoscribe3D:OpenMesh', ...
        ['%d scan row(s) had an odd number of surface crossings. The STL is ', ...
        'probably not watertight; check the sliced layers in the preview.'], oddRows);
end

slices = struct();
slices.masks = masks;
slices.x_um = x;
slices.y_um = y;
slices.z_um = cfg.firstLayerZOffset_um + ((1:nLayers) - 0.5) * cfg.layerHeight_um;
slices.nLayers = nLayers;
slices.sourceType = 'stl';
slices.extent_um = extent;
slices.mesh = struct('Points', P, 'ConnectivityList', F);
slices.oddCrossingRows = oddRows;
end

function segs = planeSegments(P, F, zk)
% Intersect triangles with the plane z = zk. Half-open vertex classification
% (z < zk vs z >= zk) gives exactly 0 or 2 edge crossings per triangle, so
% vertices exactly on the plane cannot double-count.
nTri = size(F, 1);
segs = zeros(2 * nTri, 4);   % [x1 y1 x2 y2], generous preallocation
nSeg = 0;
edges = [1 2; 2 3; 3 1];
for t = 1:nTri
    v = P(F(t, :), :);
    below = v(:, 3) < zk;
    pts = zeros(2, 2);
    nPts = 0;
    for e = 1:3
        a = edges(e, 1); b = edges(e, 2);
        if below(a) ~= below(b)
            f = (zk - v(a, 3)) / (v(b, 3) - v(a, 3));
            nPts = nPts + 1;
            pts(nPts, :) = v(a, 1:2) + f * (v(b, 1:2) - v(a, 1:2));
        end
    end
    if nPts == 2
        nSeg = nSeg + 1;
        segs(nSeg, :) = [pts(1, :), pts(2, :)];
    end
end
segs = segs(1:nSeg, :);
end

function [mask, oddRows] = fillRows(segs, x, y)
% Even-odd scanline fill: for each grid row, collect the X positions where the
% slice outline crosses that row, sort them, and fill alternate spans.
mask = false(numel(y), numel(x));
oddRows = 0;
if isempty(segs)
    return;
end

rowXs = cell(numel(y), 1);
for s = 1:size(segs, 1)
    y1 = segs(s, 2); y2 = segs(s, 4);
    yLo = min(y1, y2); yHi = max(y1, y2);
    if yLo == yHi
        continue;   % horizontal segment: no half-open row can cross it
    end
    for iy = 1:numel(y)
        if y(iy) >= yLo && y(iy) < yHi   % half-open: shared endpoints count once
            xc = segs(s, 1) + (y(iy) - y1) / (y2 - y1) * (segs(s, 3) - segs(s, 1));
            rowXs{iy}(end + 1) = xc;
        end
    end
end

for iy = 1:numel(y)
    xs = sort(rowXs{iy});
    if isempty(xs)
        continue;
    end
    if mod(numel(xs), 2) ~= 0
        oddRows = oddRows + 1;
        xs = xs(1:end - 1);
    end
    for m = 1:2:numel(xs) - 1
        mask(iy, x >= xs(m) & x <= xs(m + 1)) = true;
    end
end
end

function slices = sliceHeightmap(cfg)
S = load(cfg.inputPath);
M = pickMatrixVariable(S, cfg.matVariableName, cfg.inputPath);
M = double(M);
if ~ismatrix(M) || size(M, 1) < 2 || size(M, 2) < 2
    error('Heightmap must be a 2D matrix of at least 2 x 2 (got size [%s]).', num2str(size(M)));
end

res = cfg.xyResolution_um;
x = 0:res:cfg.targetSizeX_um;
y = 0:res:cfg.targetSizeY_um;

% Resample onto the slice grid (matrix row 1 = y = 0 end after this mapping).
[nRows, nCols] = size(M);
colQ = 1 + (x / cfg.targetSizeX_um) * (nCols - 1);
rowQ = 1 + (y / cfg.targetSizeY_um) * (nRows - 1);
[CQ, RQ] = meshgrid(colQ, rowQ);
sampled = interp2(M, CQ, RQ, cfg.interpMethod);

H = cfg.heightScale_um_per_unit * sampled + cfg.heightOffset_um;
H(~isfinite(H)) = 0;                                  % NaN cells: nothing printed
maxZ = max(H(:));
if maxZ <= 0
    error('Heightmap has no positive height; nothing to print.');
end
nLayers = ceil(maxZ / cfg.layerHeight_um);
checkLayerCount(nLayers, cfg);

masks = false(numel(y), numel(x), nLayers);
z_um = cfg.firstLayerZOffset_um + ((1:nLayers) - 0.5) * cfg.layerHeight_um;
for k = 1:nLayers
    masks(:, :, k) = H >= z_um(k);
end

slices = struct();
slices.masks = masks;
slices.x_um = x;
slices.y_um = y;
slices.z_um = z_um;
slices.nLayers = nLayers;
slices.sourceType = 'heightmap';
slices.extent_um = [cfg.targetSizeX_um, cfg.targetSizeY_um, maxZ];
slices.height_um = H;
slices.oddCrossingRows = 0;
end

function checkLayerCount(nLayers, cfg)
if nLayers < 1
    error('Model height is smaller than one layer (layerHeight_um = %g).', cfg.layerHeight_um);
end
if nLayers > cfg.maxLayers
    error(['Slicing needs %d layers, above the maxLayers cap (%d). ', ...
        'Increase layerHeight_um or cfg.maxLayers.'], nLayers, cfg.maxLayers);
end
end

function M = pickMatrixVariable(S, requestedName, matPath)
requestedName = strtrim(char(requestedName));
if ~isempty(requestedName)
    if ~isfield(S, requestedName)
        error('Variable "%s" not found in %s.', requestedName, matPath);
    end
    M = S.(requestedName);
    return;
end
names = fieldnames(S);
candidates = {};
for k = 1:numel(names)
    v = S.(names{k});
    if isnumeric(v) && ismatrix(v) && size(v, 1) >= 2 && size(v, 2) >= 2
        candidates{end + 1} = names{k}; %#ok<AGROW>
    end
end
if numel(candidates) == 1
    M = S.(candidates{1});
elseif isempty(candidates)
    error('No 2D numeric matrix (>= 2 x 2) found in %s.', matPath);
else
    error('Multiple matrices found in %s: %s. Set cfg.matVariableName.', ...
        matPath, strjoin(candidates, ', '));
end
end
