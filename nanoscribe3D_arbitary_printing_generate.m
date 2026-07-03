function layers = nanoscribe3D_arbitary_printing_generate(cfg)
%NANOSCRIBE3D_ARBITARY_PRINTING_GENERATE Slice a model into per-layer .ab sessions.
%
% The input (.stl mesh or .mat heightmap) is sliced into layer masks by
% nanoscribe3D_arbitary_printing_slice, and each layer is generated as a full set
% of chunked .ab files by reusing the 2D engine (maskOverride + returnToStart, so
% every layer nets to zero displacement and relative chaining cannot drift).
% With crossHatch on, odd layers hatch along X and even layers along Y
% (scanAxis='y' with the transposed mask). Layer k is written at
% zPosition = zLayerSign*(firstLayerZOffset + (k-1/2)*layerHeight).
%
% Usage:
%   cfg = nanoscribe3D_arbitary_printing_config();
%   cfg.inputPath = fullfile(pwd, 'model.stl');
%   cfg.layerHeight_um = 0.5;
%   layers = nanoscribe3D_arbitary_printing_generate(cfg);
%   nanoscribe3D_arbitary_printing_run(layers.layersPath);

if nargin < 1 || isempty(cfg)
    cfg = nanoscribe3D_arbitary_printing_config();
end

cfg = fillDefaultConfig(cfg);
validateConfig(cfg);
prepareOutputFolders(cfg);

slices = nanoscribe3D_arbitary_printing_slice(cfg);

layerList = struct('index', {}, 'z_um', {}, 'scanAxis', {}, 'manifestPath', {}, ...
    'outputDir', {}, 'scriptCount', {}, 'estTime_s', {}, 'pixelCount', {});

for k = 1:slices.nLayers
    mask = slices.masks(:, :, k);
    pixelCount = nnz(mask);

    if cfg.crossHatch && mod(k, 2) == 0
        axisK = 'y';
    else
        axisK = 'x';
    end

    layerList(k).index = k;
    layerList(k).z_um = slices.z_um(k);
    layerList(k).scanAxis = axisK;
    layerList(k).pixelCount = pixelCount;

    if pixelCount == 0
        warning('nanoscribe3D:EmptyLayer', 'Layer %d is empty; skipping.', k);
        layerList(k).manifestPath = '';
        layerList(k).outputDir = '';
        layerList(k).scriptCount = 0;
        layerList(k).estTime_s = 0;
        continue;
    end

    sessCfg = makeLayerCfg(cfg, k, slices.z_um(k), axisK, mask);
    sSummary = twoD_arbitary_printing_generate(sessCfg);

    layerList(k).manifestPath = sSummary.manifestPath;
    layerList(k).outputDir = sessCfg.outputDir;
    layerList(k).scriptCount = sSummary.scriptCount;
    layerList(k).estTime_s = sSummary.estimatedMotionTime_s;
end

previewPath = '';
if cfg.savePreview
    previewPath = saveLayerPreview(slices, cfg);
end

layers = struct();
layers.config = cfg;
layers.inputPath = cfg.inputPath;
layers.sourceType = slices.sourceType;
layers.extent_um = slices.extent_um;
layers.layerHeight_um = cfg.layerHeight_um;
layers.nLayers = slices.nLayers;
layers.layerList = layerList;
layers.writtenLayerCount = nnz([layerList.scriptCount] > 0);
layers.totalScriptCount = sum([layerList.scriptCount]);
layers.totalEstTime_s = sum([layerList.estTime_s]);
layers.oddCrossingRows = slices.oddCrossingRows;
layers.previewPath = previewPath;
layers.layersPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_layers.mat']);
layers.layersTextPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_layers.txt']);
save(layers.layersPath, 'layers');
writeLayersText(layers);

fprintf('Sliced %s: %d layer(s) (%d written), %d chunk(s), est %.1f s total.\n', ...
    slices.sourceType, layers.nLayers, layers.writtenLayerCount, ...
    layers.totalScriptCount, layers.totalEstTime_s);
fprintf('Extent: %.4g x %.4g x %.4g um at %.4g um layers.\n', ...
    layers.extent_um(1), layers.extent_um(2), layers.extent_um(3), cfg.layerHeight_um);
fprintf('Layers index: %s\n', layers.layersPath);
end

function cfg = fillDefaultConfig(cfg)
defaults = nanoscribe3D_arbitary_printing_config();
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(cfg, names{k}) || isempty(cfg.(names{k}))
        cfg.(names{k}) = defaults.(names{k});
    end
end
end

function validateConfig(cfg)
if ~exist(cfg.inputPath, 'file')
    error('Input file not found: %s', cfg.inputPath);
end
mustBePositiveScalar(cfg.layerHeight_um, 'layerHeight_um');
mustBePositiveScalar(cfg.xyResolution_um, 'xyResolution_um');
mustBePositiveScalar(cfg.hatchSpacing_um, 'hatchSpacing_um');
mustBePositiveScalar(cfg.stlScale_um_per_unit, 'stlScale_um_per_unit');
mustBePositiveScalar(cfg.targetSizeX_um, 'targetSizeX_um');
mustBePositiveScalar(cfg.targetSizeY_um, 'targetSizeY_um');
mustBePositiveScalar(cfg.maxLayers, 'maxLayers');
if ~isscalar(cfg.zLayerSign) || ~any(cfg.zLayerSign == [-1 1])
    error('zLayerSign must be +1 or -1.');
end
if ~isscalar(cfg.firstLayerZOffset_um) || ~isfinite(cfg.firstLayerZOffset_um)
    error('firstLayerZOffset_um must be a finite scalar.');
end
end

function mustBePositiveScalar(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || value <= 0
    error('%s must be a positive finite scalar.', name);
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

function sc = makeLayerCfg(cfg, k, z_um, axisK, mask)
% Build a twoD_arbitary_printing config for one layer. Masks are in physical
% orientation (row 1 at y = 0), so flipY is off; for Y-scan layers the engine
% receives the transposed mask (its rows = physical Y-lines stepped along X).
sc = twoD_arbitary_printing_config();
sc.bmpPath = cfg.inputPath;   % not read (maskOverride present); kept for the record
sc.outputDir = fullfile(cfg.outputDir, sprintf('layer%04d', k));
sc.previewDir = cfg.previewDir;
sc.scriptPrefix = sprintf('%s_L%04d', cfg.scriptPrefix, k);
sc.pixelSize_um = cfg.xyResolution_um;
sc.lineSpacing_um = cfg.hatchSpacing_um;
sc.xOrigin_mm = cfg.xOrigin_mm;
sc.yOrigin_mm = cfg.yOrigin_mm;
sc.zPosition_mm = cfg.zLayerSign * z_um / 1000;
sc.leadIn_um = cfg.leadIn_um;
sc.leadOut_um = cfg.leadOut_um;
sc.writeSpeed_mm_s = cfg.writeSpeed_mm_s;
sc.unwrittenSpeed_mm_s = cfg.unwrittenSpeed_mm_s;
sc.repositionSpeed_mm_s = cfg.repositionSpeed_mm_s;
sc.serpentine = cfg.serpentine;
sc.flipY = false;
sc.invertImage = false;
sc.coordinateMode = cfg.coordinateMode;
sc.emitCoordinateModeCommand = cfg.emitCoordinateModeCommand;
sc.relativeModeCommand = cfg.relativeModeCommand;
sc.absoluteModeCommand = cfg.absoluteModeCommand;
sc.includePsoControl = cfg.includePsoControl;
sc.psoAxis = cfg.psoAxis;
sc.psoOutput = cfg.psoOutput;
sc.maxMotionCommandsPerScript = cfg.maxMotionCommandsPerScript;
sc.buildAeroBasic = cfg.buildAeroBasic;
sc.aerotechDotNetDir = cfg.aerotechDotNetDir;
sc.savePreview = false;
sc.overwriteOutput = cfg.overwriteOutput;
sc.requireRunConfirmation = cfg.requireRunConfirmation;
sc.returnToStart = true;
sc.scanAxis = axisK;
if strcmp(axisK, 'y')
    sc.maskOverride = mask.';
else
    sc.maskOverride = mask;
end
end

function previewPath = saveLayerPreview(slices, cfg)
% Height-coded max projection of the layer stack (top layer wins).
previewPath = fullfile(cfg.previewDir, [cfg.scriptPrefix '_layer_stack.png']);
[ny, nx, n] = size(slices.masks);
topLayer = zeros(ny, nx);
for k = 1:n
    m = slices.masks(:, :, k);
    topLayer(m) = k;
end
idx = uint8(round(topLayer / max(n, 1) * 255));
try
    cmap = parula(256);
catch
    cmap = gray(256);
end
rgb = ind2rgb(idx, cmap);
bg = repmat(topLayer == 0, 1, 1, 3);
rgb(bg) = 0.85;
imwrite(flipud(rgb), previewPath);   % row 1 is physical bottom; image bottom-up
end

function writeLayersText(layers)
fid = fopen(layers.layersTextPath, 'w');
if fid < 0
    error('Could not write layers text file: %s', layers.layersTextPath);
end
cfg = layers.config;
fprintf(fid, 'Nanoscribe-style layer-by-layer DLW index\r\n');
fprintf(fid, 'Input: %s (%s)\r\n', layers.inputPath, layers.sourceType);
fprintf(fid, 'Extent: %.6g x %.6g x %.6g um\r\n', ...
    layers.extent_um(1), layers.extent_um(2), layers.extent_um(3));
fprintf(fid, 'Layer height: %.6g um   XY resolution: %.6g um   Hatch: %.6g um\r\n', ...
    cfg.layerHeight_um, cfg.xyResolution_um, cfg.hatchSpacing_um);
fprintf(fid, 'Cross-hatch: %d   zLayerSign: %+d   First layer offset: %.6g um\r\n', ...
    cfg.crossHatch, cfg.zLayerSign, cfg.firstLayerZOffset_um);
fprintf(fid, 'Layers: %d (%d written)   Total chunks: %d   Total est time: %.3f s\r\n', ...
    layers.nLayers, layers.writtenLayerCount, layers.totalScriptCount, layers.totalEstTime_s);
if layers.oddCrossingRows > 0
    fprintf(fid, 'WARNING: %d odd-crossing rows (mesh may not be watertight)\r\n', ...
        layers.oddCrossingRows);
end
fprintf(fid, '\r\nLayers (write order, z in geometry frame):\r\n');
for k = 1:layers.nLayers
    L = layers.layerList(k);
    fprintf(fid, '%04d\tz=%.6gum\tscan=%s\tpixels=%d\tchunks=%d\test=%.3fs\t%s\r\n', ...
        L.index, L.z_um, L.scanAxis, L.pixelCount, L.scriptCount, L.estTime_s, L.manifestPath);
end
fclose(fid);
end
