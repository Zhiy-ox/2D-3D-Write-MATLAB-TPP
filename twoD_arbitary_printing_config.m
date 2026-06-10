function cfg = twoD_arbitary_printing_config()
%TWOD_ARBITARY_PRINTING_CONFIG Editable settings for twoD BMP DLW pattern generation.
%
% Edit this file first, then run:
%   summary = twoD_arbitary_printing_generate(twoD_arbitary_printing_config());
%
% White BMP pixels are written at cfg.writeSpeed_mm_s.
% Black BMP pixels are traversed at cfg.unwrittenSpeed_mm_s.

cfg = struct();

%% Input / output
cfg.bmpPath = fullfile(pwd, 'pattern.bmp');
cfg.outputDir = fullfile(pwd, 'Generated_Scripts');
cfg.previewDir = fullfile(pwd, 'Preview');
cfg.scriptPrefix = 'twoD_arbitary_printing';

%% Geometry
% One BMP pixel maps to this physical feature size in both X and Y.
cfg.pixelSize_um = 1.0;

% Physical distance between adjacent written scan lines in Y.
% Set this to your writing resolution. For example, use pixelSize_um=7.03125
% and lineSpacing_um=1.0 for a 256 x 256 BMP printed at 1.8 mm square with
% roughly 1 um scan-line spacing.
cfg.lineSpacing_um = 1.0;

% Program coordinates relative to the stage position where the pattern starts.
% In the default relative mode, the first generated move is relative to the
% current stage position.
cfg.xOrigin_mm = 0.0;
cfg.yOrigin_mm = 0.0;
cfg.zPosition_mm = 0.0;

% Extra distance before and after each scan line for velocity settling. These
% moves are outside the intended pattern area; verify laser blanking if PSO
% remains active during non-writing moves.
cfg.leadIn_um = 2.0;
cfg.leadOut_um = 2.0;

%% Writing / scan logic
cfg.writeSpeed_mm_s = 0.02;
cfg.unwrittenSpeed_mm_s = 10.0;
cfg.repositionSpeed_mm_s = 10.0;

% Serpentine scanning avoids long flyback moves across the image.
cfg.serpentine = true;

% MATLAB image row 1 is at the top. With flipY=true, the physical bottom row
% is written first so the fabricated pattern matches the BMP orientation in
% a normal bottom-left XY coordinate system.
cfg.flipY = true;

% Usually false: white = written, black = unwritten.
cfg.invertImage = false;

% Threshold after converting the BMP to grayscale in [0, 1].
cfg.whiteThreshold = 0.5;

%% Aerotech output
% The existing splitter in this folder treats each linear X/Y/Z/F line as a
% relative displacement. Keep 'relative' unless your controller program is
% explicitly set up for absolute LINEAR targets.
cfg.coordinateMode = 'relative';  % 'relative' or 'absolute'

% Optional command emitted at the top of each chunk. Leave false unless you
% confirm the exact mode command syntax for your controller. On this Ensemble
% builder, adding INCREMENTAL before these LINEAR commands prevents the script
% from compiling.
cfg.emitCoordinateModeCommand = false;
cfg.relativeModeCommand = '';
cfg.absoluteModeCommand = '';

% Match the style of the existing split_script.m.
cfg.includePsoControl = true;
cfg.psoAxis = 'X';
cfg.psoOutput = 2;

% Keep this conservative at first. The generator tries to split at line
% boundaries, but will split inside a line if a single scan line is too long.
cfg.maxMotionCommandsPerScript = 300;

% Build .ab files with the Aerotech .NET builder. This usually only works on
% the controller computer with the Aerotech DLLs available.
cfg.buildAeroBasic = false;
cfg.aerotechDotNetDir = fullfile(pwd, 'Aerotech_DotNet');

%% Preview / safety
cfg.savePreview = true;
cfg.overwriteOutput = true;

% The runner asks for confirmation by default before running hardware.
cfg.requireRunConfirmation = true;
end
