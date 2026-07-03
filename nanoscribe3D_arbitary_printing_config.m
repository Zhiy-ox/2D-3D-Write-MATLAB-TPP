function cfg = nanoscribe3D_arbitary_printing_config()
%NANOSCRIBE3D_ARBITARY_PRINTING_CONFIG Settings for layer-by-layer 3D DLW printing.
%
% Nanoscribe-style true 3D printing on the Aerotech stage: the part is sliced
% into layers, each layer is written as a hatched 2D slice at its own Z, then
% the stage steps one layer height and the next slice is written. Input is an
% STL mesh or a .mat heightmap (extruded along Z). Output is chunked AeroBasic
% .ab files per layer, run in order by nanoscribe3D_arbitary_printing_run.
%
% Edit this file, then:
%   layers = nanoscribe3D_arbitary_printing_generate(nanoscribe3D_arbitary_printing_config());
%   nanoscribe3D_arbitary_printing_run(layers.layersPath);

cfg = struct();

%% Input / output
% Input is a .stl mesh or a .mat file holding a 2D heightmap matrix.
cfg.inputPath = fullfile(pwd, 'model.stl');
% For .mat files with more than one 2D numeric matrix, name the variable.
cfg.matVariableName = '';
cfg.outputDir = fullfile(pwd, 'Generated_Scripts_N3D');
cfg.previewDir = fullfile(pwd, 'Preview');
cfg.scriptPrefix = 'nanoscribe3D_arbitary_printing';

%% STL interpretation
% Scale from STL units to micrometers (1000 for an STL authored in mm; 1 for um).
cfg.stlScale_um_per_unit = 1000;

%% Heightmap interpretation (.mat input)
% The heightmap is resampled (interp2) onto the slice grid over this footprint,
% then converted to height: height_um = heightScale_um_per_unit*value + heightOffset_um.
% Each layer's mask is (height_um >= layer mid-plane z).
cfg.targetSizeX_um = 100.0;
cfg.targetSizeY_um = 100.0;
cfg.interpMethod = 'linear';
cfg.heightScale_um_per_unit = 1.0;
cfg.heightOffset_um = 0.0;

%% Slicing
cfg.layerHeight_um = 0.5;      % Z step between layers (slice thickness)
cfg.xyResolution_um = 0.5;     % slice-grid pitch = written pixel size along a scan line
cfg.hatchSpacing_um = 0.5;     % spacing between scan lines within a layer

% Alternate the hatch direction 0/90 degrees between layers (odd layers scan
% along X, even layers along Y) for isotropic in-plane strength.
cfg.crossHatch = true;

% Layer k is written at zPosition = zLayerSign*(firstLayerZOffset + (k-1/2)*layerHeight).
% With a fixed objective the stage moves toward -Z to build upward, so keep -1.
cfg.zLayerSign = -1;
cfg.firstLayerZOffset_um = 0.0;

% Safety cap on the number of layers (guards against a wrong layerHeight).
cfg.maxLayers = 2000;

%% Geometry (per layer; origin = stage position where the print starts)
cfg.xOrigin_mm = 0.0;
cfg.yOrigin_mm = 0.0;
cfg.leadIn_um = 2.0;
cfg.leadOut_um = 2.0;

%% Writing / scan logic (same meaning as twoD_arbitary_printing_config)
cfg.writeSpeed_mm_s = 0.02;
cfg.unwrittenSpeed_mm_s = 10.0;
cfg.repositionSpeed_mm_s = 10.0;
cfg.serpentine = true;

%% Run behavior
cfg.pauseBetweenLayers_s = 0.0;    % optional settle time between layers

%% Aerotech output (same as twoD_arbitary_printing_config)
cfg.coordinateMode = 'relative';
cfg.emitCoordinateModeCommand = false;
cfg.relativeModeCommand = '';
cfg.absoluteModeCommand = '';
cfg.includePsoControl = true;
cfg.psoAxis = 'X';
cfg.psoOutput = 2;
cfg.maxMotionCommandsPerScript = 300;
cfg.buildAeroBasic = false;
cfg.aerotechDotNetDir = fullfile(pwd, 'Aerotech_DotNet');

%% Preview / safety
cfg.savePreview = true;
cfg.overwriteOutput = true;
cfg.requireRunConfirmation = true;
end
