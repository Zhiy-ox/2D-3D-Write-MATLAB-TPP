function cfg = threeD_arbitary_printing_config()
%THREED_ARBITARY_PRINTING_CONFIG Editable settings for 3D surface DLW generation.
%
% Edit this file first, then run:
%   summary = threeD_arbitary_printing_generate(threeD_arbitary_printing_config());
%
% A 2D matrix (loaded from .csv or .mat) is treated as a phase / height field.
% Each matrix cell is converted to a physical height with a linear multiplier,
% an optional X/Y tilt plane is added, and the surface is written line by line
% as relative "linear X Y Z F" moves with Z tracking the surface. Output .ab
% chunks share the format used by twoD_arbitary_printing, so the existing
% twoD_arbitary_printing_run runner executes them unchanged.

cfg = struct();

%% Input / output
% Source is a 2D matrix in a .csv (numeric) or .mat file.
cfg.matrixPath = fullfile(pwd, 'phase_matrix.csv');
% For .mat files that hold more than one 2D numeric matrix, name the variable.
% Leave empty to auto-pick when exactly one suitable matrix is present.
cfg.matVariableName = '';
cfg.outputDir = fullfile(pwd, 'Generated_Scripts_3D');
cfg.previewDir = fullfile(pwd, 'Preview');
cfg.scriptPrefix = 'threeD_arbitary_printing';

%% Footprint / resampling
% Target Size sets the physical extent of the written surface. The matrix is
% resampled (interp2) onto a grid whose X step is pixelSize_um and whose Y step
% (scan-line spacing) is lineSpacing_um. The matrix data resolution and the
% write resolution are therefore decoupled.
cfg.targetSizeX_um = 1800.0;
cfg.targetSizeY_um = 1800.0;

% Toolpath sampling steps. One written point is produced per X sample; rows are
% spaced by lineSpacing_um in Y. Effective steps are adjusted slightly so the
% footprint equals the target size exactly (reported in the summary).
cfg.pixelSize_um = 7.03125;     % X sampling step
cfg.lineSpacing_um = 7.03125;   % Y scan-line spacing

% interp2 method used to resample the matrix onto the toolpath grid.
cfg.interpMethod = 'linear';    % 'nearest' | 'linear' | 'cubic' | 'spline'

% Matrix row 1 is treated as the top of the field. With flipY=true the physical
% bottom row is written first so the fabricated surface matches the matrix when
% viewed in a normal bottom-left XY coordinate system.
cfg.flipY = true;

%% Origin / base position
% Program coordinates are relative to the stage position where the surface
% starts (default relative mode). The first generated move is relative to the
% current stage position.
cfg.xOrigin_mm = 0.0;
cfg.yOrigin_mm = 0.0;

% Z height of the zero-phase, zero-tilt reference plane.
cfg.zBase_mm = 0.0;

% Extra travel before/after each written scan line for velocity settling. These
% moves are outside the intended pattern; verify laser blanking if PSO stays on.
cfg.leadIn_um = 2.0;
cfg.leadOut_um = 2.0;

%% Phase -> height conversion (linear multiplier)
% height_um = phaseHeightSlope * matrixValue + phaseHeightOffset_um
cfg.phaseHeightSlope = 1.0;       % um of height per matrix unit
cfg.phaseHeightOffset_um = 0.0;

% Optional phase wrapping before the linear conversion (off by default for a
% pure linear map). Useful for blazed / Fresnel phase profiles.
cfg.wrapPhase = false;
cfg.wrapModulus = 2 * pi;

%% Tilt plane (slope, um of height per mm of lateral travel)
% z_tilt_um = xTilt_um_per_mm*(x_mm - xOrigin) + yTilt_um_per_mm*(y_mm - yOrigin)
cfg.xTilt_um_per_mm = 0.0;
cfg.yTilt_um_per_mm = 0.0;

% Intrinsic tilt, entered directly in micrometers as the TOTAL Z change across
% the whole footprint in each axis. It ramps linearly from 0 at the origin edge
% to the full value at the far edge and adds to the per-mm slope tilt above.
% Convenient for dialing in a measured substrate tilt as a height drop across
% the field. Set to 0 to disable.
cfg.xTiltIntrinsic_um = 0.0;
cfg.yTiltIntrinsic_um = 0.0;

%% Stage axis conventions
% The stage moves the SAMPLE (the objective is fixed), so the commanded stage
% coordinates can be reversed relative to the pattern. Each sign is +1 (keep) or
% -1 (negate) and applies only to the motion away from the origin/base; the
% xOrigin/yOrigin/zBase references stay as true stage positions.
%   X_stage = xOrigin_mm + xAxisSign*Dx
%   Y_stage = yOrigin_mm + yAxisSign*Dy
% Because the objective is fixed, writing a TALLER feature moves the stage
% toward -Z, so heightZSign = -1 maps positive height to negative Z motion:
%   Z_stage = zBase_mm + heightZSign*(height_um + tilt_um)/1000
% Defaults match a reversed stage where height builds toward -Z.
cfg.xAxisSign = -1;
cfg.yAxisSign = -1;
cfg.heightZSign = -1;

%% Writing / scan logic
cfg.writeSpeed_mm_s = 0.02;       % speed along the written surface
cfg.repositionSpeed_mm_s = 10.0;  % flyback / lead-in / pen-up traverse speed

% Serpentine scanning avoids long flyback moves across the surface.
cfg.serpentine = true;

% Cells that are NaN (e.g. outside the data, or NaN in the source matrix) are
% not written. The toolpath lifts (optional) and traverses across them.
cfg.skipNaN = true;
cfg.liftHeight_um = 0.0;          % Z lift used during pen-up traverses over gaps

% Optional collinear simplification: consecutive written samples that lie on a
% straight 3D line within this tolerance are merged into one move to shrink the
% output. 0 disables merging (one move per sample).
cfg.mergeColinearTolerance_um = 0.0;

%% Aerotech output
% The existing splitter/runner treat each "linear X Y Z F" line as a relative
% displacement. Keep 'relative' unless your controller program uses absolute
% LINEAR targets.
cfg.coordinateMode = 'relative';  % 'relative' or 'absolute'

% Optional mode command at the top of each chunk. Leave false unless you have
% confirmed the exact syntax for your controller (INCREMENTAL before LINEAR
% breaks the local Ensemble builder).
cfg.emitCoordinateModeCommand = false;
cfg.relativeModeCommand = '';
cfg.absoluteModeCommand = '';

% Match the style of the existing 2D scripts.
cfg.includePsoControl = true;
cfg.psoAxis = 'X';
cfg.psoOutput = 2;

% Chunk size. The generator splits at scan-line boundaries when it can, and
% inside a line if a single line is longer than this.
cfg.maxMotionCommandsPerScript = 300;

% Build .ab files with the Aerotech .NET builder (usually only works on the
% controller computer with the Aerotech DLLs available).
cfg.buildAeroBasic = false;
cfg.aerotechDotNetDir = fullfile(pwd, 'Aerotech_DotNet');

%% Preview / safety
cfg.savePreview = true;
cfg.overwriteOutput = true;

% The runner asks for confirmation by default before running hardware.
cfg.requireRunConfirmation = true;
end
