function nanoscribe3D_arbitary_printing_run(layersPath, options)
%NANOSCRIBE3D_ARBITARY_PRINTING_RUN Run layer-by-layer sessions in order.
%
% Loads the layers index written by nanoscribe3D_arbitary_printing_generate and
% runs each layer's chunks with twoD_arbitary_printing_run, sharing one Aerotech
% controller connection. Each layer returns to the physical start, so the only
% net motion between layers is the Z step encoded in each layer's first moves.
%
% Usage:
%   nanoscribe3D_arbitary_printing_run(fullfile(pwd, 'Generated_Scripts_N3D', ...
%       'nanoscribe3D_arbitary_printing_layers.mat'));
%
% Options: startLayer, endLayer (resume support), pauseBetweenLayers_s,
% controller, requireConfirmation, stopToken, stopRequestedFcn, runStateFcn,
% progressFcn (receives the per-chunk info plus layerIndex/layerTotal/layerZ_um).

if nargin < 1 || isempty(layersPath)
    layersPath = fullfile(pwd, 'Generated_Scripts_N3D', ...
        'nanoscribe3D_arbitary_printing_layers.mat');
end
if nargin < 2 || isempty(options)
    options = struct();
end

loaded = load(layersPath, 'layers');
layers = loaded.layers;
cfg = layers.config;
options = fillRunOptions(options, layers, cfg);

if options.endLayer < 0 || options.endLayer > layers.nLayers
    options.endLayer = layers.nLayers;
end
if options.startLayer < 1 || options.startLayer > layers.nLayers
    error('startLayer must be between 1 and %d.', layers.nLayers);
end
if options.startLayer > options.endLayer
    error('startLayer must be <= endLayer.');
end

fprintf('Layer run: layers %d to %d of %d (%d chunks total).\n', ...
    options.startLayer, options.endLayer, layers.nLayers, layers.totalScriptCount);

if options.requireConfirmation
    reply = input('Type RUN to start the layer-by-layer print: ', 's');
    if ~strcmp(reply, 'RUN')
        error('Run cancelled by user.');
    end
end

% Connect once and share the controller across layers.
loadAerotechAssemblies(options.aerotechDotNetDir);
if isempty(options.controller)
    [controller, ~, ~, ~] = Aerotech_Initialize(options.aerotechDotNetDir);
else
    controller = options.controller;
end

for k = options.startLayer:options.endLayer
    L = layers.layerList(k);
    if L.scriptCount == 0
        fprintf('Layer %d/%d: empty, skipped.\n', k, layers.nLayers);
        continue;
    end

    fprintf('Layer %d/%d: z=%.4g um, scan %s (%d chunks).\n', ...
        k, layers.nLayers, L.z_um, L.scanAxis, L.scriptCount);
    runOpts = makeLayerRunOptions(options, cfg, controller, layers, k);
    twoD_arbitary_printing_run(L.manifestPath, runOpts);

    if options.pauseBetweenLayers_s > 0 && k < options.endLayer
        pause(options.pauseBetweenLayers_s);
    end
end

fprintf('All requested layers complete.\n');
end

function options = fillRunOptions(options, layers, cfg)
if ~isfield(options, 'startLayer') || isempty(options.startLayer)
    options.startLayer = 1;
end
if ~isfield(options, 'endLayer') || isempty(options.endLayer)
    options.endLayer = layers.nLayers;
end
if ~isfield(options, 'pauseBetweenLayers_s') || isempty(options.pauseBetweenLayers_s)
    options.pauseBetweenLayers_s = cfg.pauseBetweenLayers_s;
end
if ~isfield(options, 'controller')
    options.controller = [];
end
if ~isfield(options, 'requireConfirmation') || isempty(options.requireConfirmation)
    options.requireConfirmation = cfg.requireRunConfirmation;
end
if ~isfield(options, 'stopToken')
    options.stopToken = [];
end
if ~isfield(options, 'stopRequestedFcn')
    options.stopRequestedFcn = [];
end
if ~isfield(options, 'runStateFcn')
    options.runStateFcn = [];
end
if ~isfield(options, 'progressFcn')
    options.progressFcn = [];
end
if ~isfield(options, 'aerotechDotNetDir') || isempty(options.aerotechDotNetDir)
    options.aerotechDotNetDir = cfg.aerotechDotNetDir;
end
end

function runOpts = makeLayerRunOptions(options, cfg, controller, layers, k)
runOpts = struct();
runOpts.controller = controller;
runOpts.requireConfirmation = false;   % confirmed once at the print level
runOpts.aerotechDotNetDir = cfg.aerotechDotNetDir;
runOpts.psoAxis = cfg.psoAxis;
runOpts.stopToken = options.stopToken;
runOpts.stopRequestedFcn = options.stopRequestedFcn;
runOpts.runStateFcn = options.runStateFcn;
runOpts.startChunk = 1;
runOpts.endChunk = -1;
if isa(options.progressFcn, 'function_handle')
    L = layers.layerList(k);
    n = layers.nLayers;
    runOpts.progressFcn = @(progInfo) options.progressFcn( ...
        addLayerFields(progInfo, k, n, L.z_um));
end
end

function info = addLayerFields(info, layerIndex, layerTotal, z_um)
info.layerIndex = layerIndex;
info.layerTotal = layerTotal;
info.layerZ_um = z_um;
end
