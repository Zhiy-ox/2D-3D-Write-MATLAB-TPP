function cfg = multiVoltage_arbitary_printing_config()
%MULTIVOLTAGE_ARBITARY_PRINTING_CONFIG Settings for multi-voltage 2D DLW writing.
%
% A multi-value BMP (e.g. gray levels 0 / 128 / 255) is split into one written
% pattern per value. Each value is written in its own "session" at its own phase
% voltage; between sessions the voltage is changed (optionally via the AFG) and
% the operator confirms. Every session returns to the physical start so the
% patterns stay registered in a single coordinate frame.
%
% Edit this file, then:
%   sessions = multiVoltage_arbitary_printing_generate(multiVoltage_arbitary_printing_config());
%   multiVoltage_arbitary_printing_run(sessions.sessionsPath);

cfg = struct();

%% Input / output
cfg.bmpPath = fullfile(pwd, 'pattern_3value.bmp');
cfg.outputDir = fullfile(pwd, 'Generated_Scripts_MV');
cfg.previewDir = fullfile(pwd, 'Preview');
cfg.scriptPrefix = 'multiVoltage_arbitary_printing';

%% Value -> session mapping
% Each value in writtenValues becomes one session, written in this order at the
% matching voltage. Pixels within valueTolerance (on a 0-255 gray scale) of a
% written value are written for that session; every other pixel (including the
% background value, e.g. 0) is traversed fast and never written.
cfg.writtenValues = [128 255];   % gray levels to write, in write order
cfg.voltages = [2.0 4.0];        % phase voltage for each written value (same length)
cfg.valueTolerance = 24;         % +/- gray levels for class membership (0-255 scale)

%% Geometry (same meaning as twoD_arbitary_printing_config)
cfg.pixelSize_um = 1.0;
cfg.lineSpacing_um = 1.0;
cfg.xOrigin_mm = 0.0;
cfg.yOrigin_mm = 0.0;
cfg.zPosition_mm = 0.0;
cfg.leadIn_um = 2.0;
cfg.leadOut_um = 2.0;

%% Writing / scan logic
cfg.writeSpeed_mm_s = 0.02;
cfg.unwrittenSpeed_mm_s = 10.0;
cfg.repositionSpeed_mm_s = 10.0;
cfg.serpentine = true;
cfg.flipY = true;
cfg.whiteThreshold = 0.5;        % kept for engine compatibility (unused for classes)

% Return to the physical start after each session so the separate patterns stay
% registered (the stage is not moved between sessions, only the voltage changes).
cfg.returnToStartEachSession = true;

%% AFG voltage control (Tektronix via AFG_Standalone.m)
cfg.useAFG = false;              % auto-set the session voltage through the AFG
cfg.afgImpedance = 'INFinity';
cfg.afgFunction = 'SQUare';
cfg.afgFrequency_Hz = 1000;
cfg.afgUnit = 'VRMS';
cfg.afgResetFirst = false;       % send *RST before the first set
cfg.afgOffAtEnd = false;         % set AFG output OFF after the last session

% Pause for the operator to set/confirm the voltage before each session.
cfg.requireSessionConfirmation = true;

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
