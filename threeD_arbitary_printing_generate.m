function summary = threeD_arbitary_printing_generate(cfg)
%THREED_ARBITARY_PRINTING_GENERATE Convert a 2D phase/height matrix into chunked AeroBasic files.
%
% Usage:
%   cfg = threeD_arbitary_printing_config();
%   cfg.matrixPath = fullfile(pwd, 'my_phase.csv');  % .csv or .mat 2D matrix
%   cfg.targetSizeX_um = 1800;  cfg.targetSizeY_um = 1800;
%   cfg.pixelSize_um = 7.03125; cfg.lineSpacing_um = 7.03125;
%   cfg.phaseHeightSlope = 0.5;     % um height per matrix unit
%   cfg.xTilt_um_per_mm = 0.2;      % tilt plane slope
%   cfg.writeSpeed_mm_s = 0.02;
%   summary = threeD_arbitary_printing_generate(cfg);
%
% The matrix is resampled onto a physical grid (Target Size footprint), each
% sample is converted to a height via a linear multiplier, an X/Y tilt plane is
% added, and the surface is written line by line as relative "linear X Y Z F"
% moves with Z tracking the surface. Output is chunked into .ab files that the
% existing twoD_arbitary_printing_run runner executes unchanged.
%
% Output:
%   <outputDir>/<prefix>_NNNNNN.ab
%   <outputDir>/<prefix>_manifest.mat
%   <outputDir>/<prefix>_manifest.txt
%   <previewDir>/<prefix>_height_map.png

if nargin < 1 || isempty(cfg)
    cfg = threeD_arbitary_printing_config();
end

cfg = fillDefaultConfig(cfg);
validateConfig(cfg);
prepareOutputFolders(cfg);

[sourceMatrix, sourceInfo] = loadSourceMatrix(cfg);

% Resample the source matrix onto the physical toolpath grid and build the
% full surface (Z in mm) including the phase->height conversion and tilt plane.
[surface, grid] = buildSurface(sourceMatrix, cfg);

scriptFiles = {};
chunkCommandCounts = [];
chunkStartPositions_mm = zeros(0, 3);
chunkEndPositions_mm = zeros(0, 3);
buildWarnings = {};

chunkIndex = 0;
fid = -1;
commandsInChunk = 0;

currentPos = [0, 0, 0];
totalMotionCommands = 0;
writeSegmentCount = 0;
traverseSegmentCount = 0;
estimatedMotionTime_s = 0;

rowCommandCounts = zeros(grid.ny, 1);
rowWriteSegments = zeros(grid.ny, 1);
rowTraverseSegments = zeros(grid.ny, 1);

for scanLineIndex = 1:grid.ny
    [cmds, rowEndPos, rowStats] = buildRowCommands(surface, scanLineIndex, currentPos, cfg, grid);
    writeCommandBlock(cmds);

    currentPos = rowEndPos;
    rowCommandCounts(scanLineIndex) = numel(cmds);
    rowWriteSegments(scanLineIndex) = rowStats.writeSegments;
    rowTraverseSegments(scanLineIndex) = rowStats.traverseSegments;
    writeSegmentCount = writeSegmentCount + rowStats.writeSegments;
    traverseSegmentCount = traverseSegmentCount + rowStats.traverseSegments;
end

if fid >= 0
    closeChunk(currentPos);
end

previewPath = '';
if cfg.savePreview
    previewPath = saveHeightPreview(surface, cfg);
end

manifestPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_manifest.mat']);
manifestTextPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_manifest.txt']);

summary = struct();
summary.sourceMatrix = cfg.matrixPath;
summary.sourceBmp = cfg.matrixPath;   % alias kept for runner compatibility
summary.sourceInfo = sourceInfo;
summary.coordinateMode = cfg.coordinateMode;
summary.outputDir = cfg.outputDir;
summary.previewMaskPath = previewPath;
summary.previewHeightMapPath = previewPath;
summary.manifestPath = manifestPath;
summary.manifestTextPath = manifestTextPath;
summary.scriptFiles = scriptFiles;
summary.scriptCount = numel(scriptFiles);
summary.chunkCommandCounts = chunkCommandCounts;
summary.chunkStartPositions_mm = chunkStartPositions_mm;
summary.chunkEndPositions_mm = chunkEndPositions_mm;
summary.matrixRows = sourceInfo.rows;
summary.matrixCols = sourceInfo.cols;
summary.nx = grid.nx;
summary.ny = grid.ny;
summary.pixelSize_um = cfg.pixelSize_um;
summary.lineSpacing_um = cfg.lineSpacing_um;
summary.effectivePixelSize_um = grid.effPixel_um;
summary.effectiveLineSpacing_um = grid.effLine_um;
summary.targetSizeX_um = cfg.targetSizeX_um;
summary.targetSizeY_um = cfg.targetSizeY_um;
summary.heightMin_um = grid.heightMin_um;
summary.heightMax_um = grid.heightMax_um;
summary.zMin_mm = grid.zMin_mm;
summary.zMax_mm = grid.zMax_mm;
summary.writtenPoints = grid.writtenPoints;
summary.skippedPoints = grid.skippedPoints;
summary.writeSegments = writeSegmentCount;
summary.traverseSegments = traverseSegmentCount;
summary.motionCommands = totalMotionCommands;
summary.rowCommandCounts = rowCommandCounts;
summary.rowWriteSegments = rowWriteSegments;
summary.rowTraverseSegments = rowTraverseSegments;
summary.estimatedMotionTime_s = estimatedMotionTime_s;
summary.xTilt_um_per_mm = cfg.xTilt_um_per_mm;
summary.yTilt_um_per_mm = cfg.yTilt_um_per_mm;
summary.xTiltIntrinsic_um = cfg.xTiltIntrinsic_um;
summary.yTiltIntrinsic_um = cfg.yTiltIntrinsic_um;
summary.xAxisSign = cfg.xAxisSign;
summary.yAxisSign = cfg.yAxisSign;
summary.heightZSign = cfg.heightZSign;
summary.phaseHeightSlope = cfg.phaseHeightSlope;
summary.phaseHeightOffset_um = cfg.phaseHeightOffset_um;
summary.config = cfg;
summary.buildWarnings = buildWarnings;

manifest = summary; %#ok<NASGU>
save(manifestPath, 'manifest');
writeManifestText(summary, cfg);

fprintf('Generated %d script chunk(s).\n', summary.scriptCount);
fprintf('Written points: %d (skipped %d)\n', summary.writtenPoints, summary.skippedPoints);
fprintf('Height range: %.4g to %.4g um\n', summary.heightMin_um, summary.heightMax_um);
fprintf('Motion commands: %d\n', summary.motionCommands);
fprintf('Estimated motion time: %.2f s\n', summary.estimatedMotionTime_s);
fprintf('Manifest: %s\n', manifestPath);

    function writeCommandBlock(cmds)
        if isempty(cmds)
            return;
        end

        if fid >= 0 && commandsInChunk > 0 && ...
                commandsInChunk + numel(cmds) > cfg.maxMotionCommandsPerScript && ...
                numel(cmds) <= cfg.maxMotionCommandsPerScript
            closeChunk(cmds(1).startPos);
        end

        for cmdIndex = 1:numel(cmds)
            cmd = cmds(cmdIndex);
            if fid < 0
                openChunk(cmd.startPos);
            end
            if commandsInChunk >= cfg.maxMotionCommandsPerScript
                closeChunk(cmd.startPos);
                openChunk(cmd.startPos);
            end

            fprintf(fid, '%s\r\n', cmd.text);
            commandsInChunk = commandsInChunk + 1;
            totalMotionCommands = totalMotionCommands + 1;
            estimatedMotionTime_s = estimatedMotionTime_s + cmd.time_s;
        end
    end

    function openChunk(startPos)
        chunkIndex = chunkIndex + 1;
        chunkPath = fullfile(cfg.outputDir, sprintf('%s_%06d.ab', cfg.scriptPrefix, chunkIndex));
        fid = fopen(chunkPath, 'w');
        if fid < 0
            error('Could not open output script: %s', chunkPath);
        end

        if cfg.emitCoordinateModeCommand
            if strcmpi(cfg.coordinateMode, 'relative')
                emitOptionalCommand(fid, cfg.relativeModeCommand);
            else
                emitOptionalCommand(fid, cfg.absoluteModeCommand);
            end
        end
        if cfg.includePsoControl
            fprintf(fid, 'PSOOUTPUT %s CONTROL %d\r\n', cfg.psoAxis, cfg.psoOutput);
            fprintf(fid, 'PSOCONTROL %s ON\r\n', cfg.psoAxis);
        end

        scriptFiles{chunkIndex, 1} = chunkPath;
        chunkCommandCounts(chunkIndex, 1) = 0;
        chunkStartPositions_mm(chunkIndex, :) = startPos;
        commandsInChunk = 0;
    end

    function closeChunk(endPos)
        if fid < 0
            return;
        end

        if cfg.includePsoControl
            fprintf(fid, 'PSOCONTROL %s OFF\r\n', cfg.psoAxis);
        end
        fclose(fid);
        fid = -1;

        chunkCommandCounts(chunkIndex, 1) = commandsInChunk;
        chunkEndPositions_mm(chunkIndex, :) = endPos;

        if cfg.buildAeroBasic
            try
                ensureAerotechBuilderLoaded(cfg);
                Aerotech.AeroBasic.Builder.Build(scriptFiles{chunkIndex});
            catch buildErr
                buildWarnings{end + 1, 1} = sprintf('Build failed for %s: %s', ...
                    scriptFiles{chunkIndex}, buildErr.message);
            end
        end
        commandsInChunk = 0;
    end
end

function emitOptionalCommand(fid, commandText)
commandText = strtrim(char(commandText));
if ~isempty(commandText)
    fprintf(fid, '%s\r\n', commandText);
end
end

function cfg = fillDefaultConfig(cfg)
defaults = threeD_arbitary_printing_config();
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(cfg, names{k}) || (isempty(cfg.(names{k})) && ~islogical(cfg.(names{k})))
        cfg.(names{k}) = defaults.(names{k});
    end
end
end

function validateConfig(cfg)
if ~exist(cfg.matrixPath, 'file')
    error('Matrix file not found: %s', cfg.matrixPath);
end
mustBePositiveScalar(cfg.targetSizeX_um, 'targetSizeX_um');
mustBePositiveScalar(cfg.targetSizeY_um, 'targetSizeY_um');
mustBePositiveScalar(cfg.pixelSize_um, 'pixelSize_um');
mustBePositiveScalar(cfg.lineSpacing_um, 'lineSpacing_um');
mustBePositiveScalar(cfg.writeSpeed_mm_s, 'writeSpeed_mm_s');
mustBePositiveScalar(cfg.repositionSpeed_mm_s, 'repositionSpeed_mm_s');
mustBePositiveScalar(cfg.maxMotionCommandsPerScript, 'maxMotionCommandsPerScript');
mustBeFiniteScalar(cfg.phaseHeightSlope, 'phaseHeightSlope');
mustBeFiniteScalar(cfg.phaseHeightOffset_um, 'phaseHeightOffset_um');
mustBeFiniteScalar(cfg.xTilt_um_per_mm, 'xTilt_um_per_mm');
mustBeFiniteScalar(cfg.yTilt_um_per_mm, 'yTilt_um_per_mm');
mustBeFiniteScalar(cfg.xTiltIntrinsic_um, 'xTiltIntrinsic_um');
mustBeFiniteScalar(cfg.yTiltIntrinsic_um, 'yTiltIntrinsic_um');
mustBeSign(cfg.xAxisSign, 'xAxisSign');
mustBeSign(cfg.yAxisSign, 'yAxisSign');
mustBeSign(cfg.heightZSign, 'heightZSign');
mustBeNonnegativeScalar(cfg.leadIn_um, 'leadIn_um');
mustBeNonnegativeScalar(cfg.leadOut_um, 'leadOut_um');
mustBeNonnegativeScalar(cfg.liftHeight_um, 'liftHeight_um');
mustBeNonnegativeScalar(cfg.mergeColinearTolerance_um, 'mergeColinearTolerance_um');
if cfg.includePsoControl
    validatePsoAxis(cfg.psoAxis);
    mustBeNonnegativeInteger(cfg.psoOutput, 'psoOutput');
end
if cfg.maxMotionCommandsPerScript < 10
    error('maxMotionCommandsPerScript should be at least 10.');
end
if ~any(strcmpi(cfg.coordinateMode, {'relative', 'absolute'}))
    error('coordinateMode must be ''relative'' or ''absolute''.');
end
if ~any(strcmpi(cfg.interpMethod, {'nearest', 'linear', 'cubic', 'spline', 'makima'}))
    error('interpMethod must be one of nearest, linear, cubic, spline, makima.');
end
end

function mustBePositiveScalar(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || value <= 0
    error('%s must be a positive finite scalar.', name);
end
end

function mustBeNonnegativeScalar(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || value < 0
    error('%s must be a nonnegative finite scalar.', name);
end
end

function mustBeFiniteScalar(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value)
    error('%s must be a finite scalar.', name);
end
end

function mustBeSign(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~(value == 1 || value == -1)
    error('%s must be +1 or -1.', name);
end
end

function mustBeNonnegativeInteger(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || value < 0 || value ~= round(value)
    error('%s must be a nonnegative integer scalar.', name);
end
end

function validatePsoAxis(psoAxis)
psoAxis = strtrim(char(psoAxis));
if isempty(regexp(psoAxis, '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
    error('psoAxis must be a single Aerotech axis name such as X.');
end
end

function prepareOutputFolders(cfg)
if exist(cfg.outputDir, 'dir')
    if ~cfg.overwriteOutput
        error('Output directory exists and overwriteOutput=false: %s', cfg.outputDir);
    end
else
    mkdir(cfg.outputDir);
end

if cfg.savePreview && ~exist(cfg.previewDir, 'dir')
    mkdir(cfg.previewDir);
end
end

function [M, sourceInfo] = loadSourceMatrix(cfg)
[~, ~, ext] = fileparts(cfg.matrixPath);
ext = lower(ext);

switch ext
    case '.mat'
        S = load(cfg.matrixPath);
        M = pickMatrixVariable(S, cfg.matVariableName, cfg.matrixPath);
    otherwise
        % .csv, .txt, .dat and similar numeric text files.
        M = readmatrix(cfg.matrixPath);
end

M = double(M);
if ~ismatrix(M) || ndims(M) ~= 2 %#ok<ISMAT>
    error('Source must be a 2D matrix. Got size [%s].', num2str(size(M)));
end
if size(M, 1) < 2 || size(M, 2) < 2
    error('Source matrix must be at least 2 x 2 (got %d x %d).', size(M, 1), size(M, 2));
end

sourceInfo = struct();
sourceInfo.path = cfg.matrixPath;
sourceInfo.fileType = ext;
sourceInfo.rows = size(M, 1);
sourceInfo.cols = size(M, 2);
finiteVals = M(isfinite(M));
if isempty(finiteVals)
    error('Source matrix has no finite values.');
end
sourceInfo.valueMin = min(finiteVals);
sourceInfo.valueMax = max(finiteVals);
sourceInfo.nanCount = nnz(~isfinite(M));
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
    error(['Multiple matrices found in %s: %s. ', ...
        'Set cfg.matVariableName to choose one.'], matPath, strjoin(candidates, ', '));
end
end

function [surface, grid] = buildSurface(M, cfg)
if cfg.flipY
    M = flipud(M);
end
[nRows, nCols] = size(M);

% Toolpath sample counts and exact (footprint-preserving) sample positions.
grid = struct();
grid.nx = max(2, round(cfg.targetSizeX_um / cfg.pixelSize_um) + 1);
grid.ny = max(2, round(cfg.targetSizeY_um / cfg.lineSpacing_um) + 1);
grid.x_um = linspace(0, cfg.targetSizeX_um, grid.nx);
grid.y_um = linspace(0, cfg.targetSizeY_um, grid.ny);
grid.effPixel_um = cfg.targetSizeX_um / (grid.nx - 1);
grid.effLine_um = cfg.targetSizeY_um / (grid.ny - 1);

% Map physical sample positions to matrix index coordinates and resample.
colQ = 1 + (grid.x_um / cfg.targetSizeX_um) * (nCols - 1);   % 1..nCols
rowQ = 1 + (grid.y_um / cfg.targetSizeY_um) * (nRows - 1);   % 1..nRows
[CQ, RQ] = meshgrid(colQ, rowQ);
sampled = interp2(M, CQ, RQ, cfg.interpMethod);

if cfg.wrapPhase
    sampled = mod(sampled, cfg.wrapModulus);
end

height_um = cfg.phaseHeightSlope * sampled + cfg.phaseHeightOffset_um;

% XX_um / YY_um run 0..targetSize_um, so the intrinsic term ramps 0..value.
[XX_um, YY_um] = meshgrid(grid.x_um, grid.y_um);
tilt_um = cfg.xTilt_um_per_mm * (XX_um / 1000) + cfg.yTilt_um_per_mm * (YY_um / 1000) ...
    + cfg.xTiltIntrinsic_um * (XX_um / cfg.targetSizeX_um) ...
    + cfg.yTiltIntrinsic_um * (YY_um / cfg.targetSizeY_um);

% Stage frame. The stage moves the SAMPLE, so axis directions can be reversed
% (xAxisSign / yAxisSign), and because the objective is fixed, writing a taller
% feature moves the stage toward -Z (heightZSign = -1 for that setup).
surfaceHeight_um = height_um + tilt_um;
Z_mm = cfg.zBase_mm + cfg.heightZSign * surfaceHeight_um / 1000;

% Cells with no usable value are not written.
invalid = ~isfinite(sampled);
if ~cfg.skipNaN && any(invalid(:))
    error(['Source produced %d non-finite samples but skipNaN=false. ', ...
        'Enable skipNaN or clean the matrix.'], nnz(invalid));
end
Z_mm(invalid) = NaN;
displayHeight_um = surfaceHeight_um;   % pattern-frame physical height, for preview
displayHeight_um(invalid) = NaN;

surface = struct();
surface.X_mm = cfg.xOrigin_mm + cfg.xAxisSign * (XX_um / 1000);
surface.Y_mm = cfg.yOrigin_mm + cfg.yAxisSign * (YY_um / 1000);
surface.Z_mm = Z_mm;
surface.height_um = height_um;
surface.displayHeight_um = displayHeight_um;
surface.xLocal_um = grid.x_um;
surface.yLocal_um = grid.y_um;

finiteH = height_um(isfinite(sampled));
grid.heightMin_um = min(finiteH);
grid.heightMax_um = max(finiteH);
finiteZ = Z_mm(isfinite(Z_mm));
grid.zMin_mm = min(finiteZ);
grid.zMax_mm = max(finiteZ);
grid.writtenPoints = nnz(isfinite(Z_mm));
grid.skippedPoints = nnz(~isfinite(Z_mm));
end

function [cmds, endPos, stats] = buildRowCommands(surface, scanLineIndex, startPos, cfg, grid)
cmds = emptyCommandStruct();
currentPos = startPos;

direction = 1;
if cfg.serpentine && mod(scanLineIndex, 2) == 0
    direction = -1;
end

xRow_mm = surface.X_mm(scanLineIndex, :);
zRow_mm = surface.Z_mm(scanLineIndex, :);
y_mm = surface.Y_mm(scanLineIndex, 1);
if direction < 0
    xRow_mm = fliplr(xRow_mm);
    zRow_mm = fliplr(zRow_mm);
end

valid = isfinite(zRow_mm);
stats = struct('writeSegments', 0, 'traverseSegments', 0);
if ~any(valid)
    endPos = currentPos;
    return;
end

leadIn_mm = cfg.leadIn_um / 1000;
leadOut_mm = cfg.leadOut_um / 1000;
scanSign = sign(xRow_mm(end) - xRow_mm(1));
if scanSign == 0
    scanSign = 1;
end

firstValid = find(valid, 1, 'first');
lastValid = find(valid, 1, 'last');

% Reposition (fast) to the lead-in point at the first written height.
lineStart = [xRow_mm(firstValid) - scanSign * leadIn_mm, y_mm, zRow_mm(firstValid)];
[cmds, currentPos] = appendMove(cmds, currentPos, lineStart, cfg.repositionSpeed_mm_s, cfg, false);
if leadIn_mm > 0
    patternStart = [xRow_mm(firstValid), y_mm, zRow_mm(firstValid)];
    [cmds, currentPos] = appendMove(cmds, currentPos, patternStart, cfg.repositionSpeed_mm_s, cfg, false);
end

% Walk contiguous runs of written samples; write within a run, traverse across
% gaps between runs.
runs = contiguousRuns(valid);
for r = 1:size(runs, 1)
    runStart = runs(r, 1);
    runEnd = runs(r, 2);

    % Points (in mm) for this written run.
    P = [xRow_mm(runStart:runEnd).', repmat(y_mm, runEnd - runStart + 1, 1), zRow_mm(runStart:runEnd).'];
    keepIdx = simplifyColinear(P, cfg.mergeColinearTolerance_um / 1000);
    Pk = P(keepIdx, :);

    if r > 1
        % Pen-up traverse from the previous run end to this run start.
        target = Pk(1, :);
        [cmds, currentPos] = appendTraverse(cmds, currentPos, target, cfg);
        stats.traverseSegments = stats.traverseSegments + 1;
    else
        % Already positioned at the first run start by the lead-in moves; make
        % sure we are exactly there (no-op if coincident).
        [cmds, currentPos] = appendMove(cmds, currentPos, Pk(1, :), cfg.repositionSpeed_mm_s, cfg, false);
    end

    % Written moves along the surface.
    for p = 2:size(Pk, 1)
        [cmds, currentPos, moved] = appendMove(cmds, currentPos, Pk(p, :), cfg.writeSpeed_mm_s, cfg, true);
        if moved
            stats.writeSegments = stats.writeSegments + 1;
        end
    end
end

% Lead-out past the last written sample.
if leadOut_mm > 0
    lineEnd = [xRow_mm(lastValid) + scanSign * leadOut_mm, y_mm, zRow_mm(lastValid)];
    [cmds, currentPos] = appendMove(cmds, currentPos, lineEnd, cfg.repositionSpeed_mm_s, cfg, false);
end

endPos = currentPos;
end

function [cmds, newPos, moved] = appendMove(cmds, currentPos, targetPos, speed, cfg, isWriteMove)
[cmd, newPos] = makeMoveCommand(currentPos, targetPos, speed, cfg, isWriteMove);
moved = ~isempty(cmd);
cmds = appendCommand(cmds, cmd);
end

function [cmds, newPos] = appendTraverse(cmds, currentPos, targetPos, cfg)
% Pen-up traverse across a no-write gap, with optional Z lift.
lift_mm = cfg.liftHeight_um / 1000;
newPos = currentPos;
if lift_mm > 0
    up = [currentPos(1), currentPos(2), currentPos(3) + lift_mm];
    [cmds, newPos] = appendMove(cmds, newPos, up, cfg.repositionSpeed_mm_s, cfg, false);
    over = [targetPos(1), targetPos(2), targetPos(3) + lift_mm];
    [cmds, newPos] = appendMove(cmds, newPos, over, cfg.repositionSpeed_mm_s, cfg, false);
    [cmds, newPos] = appendMove(cmds, newPos, targetPos, cfg.repositionSpeed_mm_s, cfg, false);
else
    [cmds, newPos] = appendMove(cmds, newPos, targetPos, cfg.repositionSpeed_mm_s, cfg, false);
end
end

function runs = contiguousRuns(valid)
% Rows of [startIndex endIndex] for each contiguous run of true values.
runs = zeros(0, 2);
n = numel(valid);
k = 1;
while k <= n
    if valid(k)
        j = k;
        while j < n && valid(j + 1)
            j = j + 1;
        end
        runs(end + 1, :) = [k, j]; %#ok<AGROW>
        k = j + 1;
    else
        k = k + 1;
    end
end
end

function keepIdx = simplifyColinear(P, tol_mm)
% Greedy collinear simplification: keep endpoints of straight 3D segments.
n = size(P, 1);
if n <= 2 || tol_mm <= 0
    keepIdx = 1:n;
    return;
end

keep = false(1, n);
keep(1) = true;
anchor = 1;
for k = 3:n
    if maxPerpDistance(P(anchor:k, :)) > tol_mm
        keep(k - 1) = true;
        anchor = k - 1;
    end
end
keep(n) = true;
keepIdx = find(keep);
end

function d = maxPerpDistance(P)
% Max perpendicular distance of intermediate points from the line P(1)->P(end).
a = P(1, :);
b = P(end, :);
ab = b - a;
abLen = sqrt(sum(ab .^ 2));
if abLen < 1e-15
    diffs = P - a;
    d = max(sqrt(sum(diffs .^ 2, 2)));
    return;
end
abUnit = ab / abLen;
d = 0;
for k = 2:size(P, 1) - 1
    ap = P(k, :) - a;
    proj = dot(ap, abUnit);
    perp = ap - proj * abUnit;
    d = max(d, sqrt(sum(perp .^ 2)));
end
end

function [cmd, newPos] = makeMoveCommand(currentPos, targetPos, speed, cfg, isWriteMove)
delta = targetPos - currentPos;
distance = sqrt(sum(delta .^ 2));
if distance < 1e-12
    cmd = [];
    newPos = currentPos;
    return;
end

if strcmpi(cfg.coordinateMode, 'relative')
    outputPos = delta;
else
    outputPos = targetPos;
end

cmd = struct();
cmd.startPos = currentPos;
cmd.endPos = targetPos;
cmd.speed = speed;
cmd.distance_mm = distance;
cmd.time_s = distance / speed;
cmd.isWriteMove = isWriteMove;
cmd.text = sprintf('linear X %.9f Y %.9f Z %.9f F %.6f', ...
    outputPos(1), outputPos(2), outputPos(3), speed);
newPos = targetPos;
end

function cmds = appendCommand(cmds, cmd)
if isempty(cmd)
    return;
end
if isempty(cmds)
    cmds = cmd;
else
    cmds(end + 1) = cmd;
end
end

function cmds = emptyCommandStruct()
cmds = struct('startPos', {}, 'endPos', {}, 'speed', {}, 'distance_mm', {}, ...
    'time_s', {}, 'isWriteMove', {}, 'text', {});
end

function previewPath = saveHeightPreview(surface, cfg)
previewPath = fullfile(cfg.previewDir, [cfg.scriptPrefix '_height_map.png']);
H = surface.displayHeight_um;
finiteH = H(isfinite(H));
if isempty(finiteH)
    lo = 0; hi = 1;
else
    lo = min(finiteH);
    hi = max(finiteH);
end
if hi <= lo
    hi = lo + 1;
end

norm = (H - lo) / (hi - lo);
norm(~isfinite(norm)) = 0;
idx = uint8(round(min(max(norm, 0), 1) * 255));

try
    cmap = parula(256);
catch
    cmap = gray(256);
end
rgb = ind2rgb(idx, cmap);

% Row 1 of Z is the physical bottom; flip so the saved image has bottom at the
% bottom (matches a normal XY view).
imwrite(flipud(rgb), previewPath);
end

function writeManifestText(summary, cfg)
fid = fopen(summary.manifestTextPath, 'w');
if fid < 0
    error('Could not write manifest text file: %s', summary.manifestTextPath);
end

fprintf(fid, 'threeD surface Aerotech toolpath manifest\r\n');
fprintf(fid, 'Source matrix: %s\r\n', summary.sourceMatrix);
fprintf(fid, 'Coordinate mode: %s\r\n', summary.coordinateMode);
fprintf(fid, 'Matrix: %d rows x %d cols\r\n', summary.matrixRows, summary.matrixCols);
fprintf(fid, 'Target size: %.9g um x %.9g um\r\n', summary.targetSizeX_um, summary.targetSizeY_um);
fprintf(fid, 'Toolpath grid: %d x %d samples\r\n', summary.nx, summary.ny);
fprintf(fid, 'Effective sample step: %.9g um (X) x %.9g um (Y)\r\n', ...
    summary.effectivePixelSize_um, summary.effectiveLineSpacing_um);
fprintf(fid, 'Phase->height slope: %.9g um/unit  offset: %.9g um\r\n', ...
    summary.phaseHeightSlope, summary.phaseHeightOffset_um);
fprintf(fid, 'Tilt: %.9g um/mm (X) %.9g um/mm (Y)\r\n', ...
    summary.xTilt_um_per_mm, summary.yTilt_um_per_mm);
fprintf(fid, 'Intrinsic tilt: %.9g um (X) %.9g um (Y) across footprint\r\n', ...
    summary.xTiltIntrinsic_um, summary.yTiltIntrinsic_um);
fprintf(fid, 'Axis signs: X %+d  Y %+d  height->Z %+d\r\n', ...
    summary.xAxisSign, summary.yAxisSign, summary.heightZSign);
fprintf(fid, 'Height range: %.9g to %.9g um\r\n', summary.heightMin_um, summary.heightMax_um);
fprintf(fid, 'Z range: %.9g to %.9g mm\r\n', summary.zMin_mm, summary.zMax_mm);
fprintf(fid, 'Written points: %d\r\n', summary.writtenPoints);
fprintf(fid, 'Skipped points: %d\r\n', summary.skippedPoints);
fprintf(fid, 'Write segments: %d\r\n', summary.writeSegments);
fprintf(fid, 'Traverse segments: %d\r\n', summary.traverseSegments);
fprintf(fid, 'Motion commands: %d\r\n', summary.motionCommands);
fprintf(fid, 'Script chunks: %d\r\n', summary.scriptCount);
fprintf(fid, 'Max motion commands per script: %d\r\n', cfg.maxMotionCommandsPerScript);
fprintf(fid, 'Estimated motion time: %.3f s\r\n', summary.estimatedMotionTime_s);
fprintf(fid, '\r\nChunks:\r\n');
for k = 1:summary.scriptCount
    startPos = summary.chunkStartPositions_mm(k, :);
    endPos = summary.chunkEndPositions_mm(k, :);
    fprintf(fid, '%06d\tcommands=%d\tstart=[%.9f %.9f %.9f]\tend=[%.9f %.9f %.9f]\t%s\r\n', ...
        k, summary.chunkCommandCounts(k), ...
        startPos(1), startPos(2), startPos(3), ...
        endPos(1), endPos(2), endPos(3), ...
        summary.scriptFiles{k});
end

if ~isempty(summary.buildWarnings)
    fprintf(fid, '\r\nBuild warnings:\r\n');
    for k = 1:numel(summary.buildWarnings)
        fprintf(fid, '%s\r\n', summary.buildWarnings{k});
    end
end

fclose(fid);
end

function ensureAerotechBuilderLoaded(cfg)
persistent loaded
if ~isempty(loaded) && loaded
    return;
end
loadAerotechAssemblies(cfg.aerotechDotNetDir);
loaded = true;
end
