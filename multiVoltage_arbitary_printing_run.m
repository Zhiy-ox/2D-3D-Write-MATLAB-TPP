function multiVoltage_arbitary_printing_run(sessionsPath, options)
%MULTIVOLTAGE_ARBITARY_PRINTING_RUN Run multi-voltage sessions in order.
%
% For each session: optionally auto-set the phase voltage via the AFG, pause for
% the operator to set/confirm (and optionally adjust) it, then run that session's
% chunks by reusing twoD_arbitary_printing_run. The Aerotech controller is shared
% across sessions so the stage stays put; each session returns to the physical
% start, keeping the patterns registered.
%
% Usage:
%   multiVoltage_arbitary_printing_run(fullfile(pwd, 'Generated_Scripts_MV', ...
%       'multiVoltage_arbitary_printing_sessions.mat'));

if nargin < 1 || isempty(sessionsPath)
    sessionsPath = fullfile(pwd, 'Generated_Scripts_MV', ...
        'multiVoltage_arbitary_printing_sessions.mat');
end
if nargin < 2 || isempty(options)
    options = struct();
end

loaded = load(sessionsPath, 'sessions');
sessions = loaded.sessions;
cfg = sessions.config;
options = fillRunOptions(options, sessions, cfg);

if options.endSession < 0 || options.endSession > sessions.nSessions
    options.endSession = sessions.nSessions;
end
if options.startSession < 1 || options.startSession > sessions.nSessions
    error('startSession must be between 1 and %d.', sessions.nSessions);
end
if options.startSession > options.endSession
    error('startSession must be <= endSession.');
end

fprintf('Multi-voltage run: sessions %d to %d of %d.\n', ...
    options.startSession, options.endSession, sessions.nSessions);

if options.requireConfirmation
    reply = input('Type RUN to start the multi-voltage run: ', 's');
    if ~strcmp(reply, 'RUN')
        error('Run cancelled by user.');
    end
end

% Connect once and share the controller across sessions (stage stays put).
loadAerotechAssemblies(options.aerotechDotNetDir);
if isempty(options.controller)
    [controller, ~, ~, ~] = Aerotech_Initialize(options.aerotechDotNetDir);
else
    controller = options.controller;
end

cleanupAFG = onCleanup(@() afgOffIfNeeded(cfg)); %#ok<NASGU>

for i = options.startSession:options.endSession
    s = sessions.sessionList(i);

    % 1. Auto-set voltage via the AFG (if enabled).
    if cfg.useAFG
        setAFG(cfg, s.voltage, (i == options.startSession) && cfg.afgResetFirst);
    end

    % 2. Operator confirm / adjust before writing this session.
    if cfg.requireSessionConfirmation
        info = struct('index', i, 'total', sessions.nSessions, 'value', s.value, ...
            'voltage', s.voltage, 'useAFG', cfg.useAFG, 'unit', cfg.afgUnit, ...
            'scriptCount', s.scriptCount, 'estTime_s', s.estTime_s);
        [proceed, newVoltage] = confirmSession(options, info);
        if ~proceed
            fprintf('Multi-voltage run stopped by operator before session %d.\n', i);
            return;
        end
        if ~isempty(newVoltage) && isfinite(newVoltage) && newVoltage ~= s.voltage
            s.voltage = newVoltage;
            if cfg.useAFG
                setAFG(cfg, s.voltage, false);
            end
        end
    end

    % 3. Write this session's chunks (full reuse of the per-session runner).
    fprintf('Session %d/%d: value %d at %.4g %s (%d chunks).\n', ...
        i, sessions.nSessions, s.value, s.voltage, cfg.afgUnit, s.scriptCount);
    runOpts = makeSessionRunOptions(options, cfg, controller, sessions, i);
    twoD_arbitary_printing_run(s.manifestPath, runOpts);
end

fprintf('All requested sessions complete.\n');
end

function options = fillRunOptions(options, sessions, cfg)
if ~isfield(options, 'startSession') || isempty(options.startSession)
    options.startSession = 1;
end
if ~isfield(options, 'endSession') || isempty(options.endSession)
    options.endSession = sessions.nSessions;
end
if ~isfield(options, 'controller')
    options.controller = [];
end
if ~isfield(options, 'requireConfirmation') || isempty(options.requireConfirmation)
    options.requireConfirmation = cfg.requireRunConfirmation;
end
if ~isfield(options, 'confirmFcn')
    options.confirmFcn = [];
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

function setAFG(cfg, voltage, doReset)
try
    AFG_Standalone(doReset, cfg.afgImpedance, cfg.afgFunction, cfg.afgFrequency_Hz, ...
        cfg.afgUnit, voltage, 'ON');
    fprintf('AFG set to %.4g %s (%s, %g Hz).\n', voltage, cfg.afgUnit, ...
        cfg.afgFunction, cfg.afgFrequency_Hz);
catch err
    warning('multiVoltage:AFGFailed', ...
        'AFG set failed (%s). Set the voltage manually before continuing.', err.message);
end
end

function afgOffIfNeeded(cfg)
if cfg.useAFG && cfg.afgOffAtEnd
    try
        AFG_Standalone(false, cfg.afgImpedance, cfg.afgFunction, cfg.afgFrequency_Hz, ...
            cfg.afgUnit, 0, 'OFF');
        fprintf('AFG output set OFF.\n');
    catch err
        warning('multiVoltage:AFGOffFailed', 'AFG OFF failed: %s', err.message);
    end
end
end

function [proceed, newVoltage] = confirmSession(options, info)
if isa(options.confirmFcn, 'function_handle')
    [proceed, newVoltage] = options.confirmFcn(info);
    return;
end
% Default console confirmation.
fprintf('--- Session %d/%d: value %d, target voltage %.4g %s ---\n', ...
    info.index, info.total, info.value, info.voltage, info.unit);
if info.useAFG
    fprintf('AFG was set automatically. Adjust on the instrument if needed.\n');
else
    fprintf('Set the phase voltage manually now.\n');
end
resp = strtrim(input('Type RUN to write this session, or Q to stop: ', 's'));
proceed = strcmpi(resp, 'RUN');
newVoltage = [];
end

function runOpts = makeSessionRunOptions(options, cfg, controller, sessions, i)
runOpts = struct();
runOpts.controller = controller;
runOpts.requireConfirmation = false;   % handled at the session level
runOpts.aerotechDotNetDir = cfg.aerotechDotNetDir;
runOpts.psoAxis = cfg.psoAxis;
runOpts.stopToken = options.stopToken;
runOpts.stopRequestedFcn = options.stopRequestedFcn;
runOpts.runStateFcn = options.runStateFcn;
runOpts.startChunk = 1;
runOpts.endChunk = -1;
if isa(options.progressFcn, 'function_handle')
    s = sessions.sessionList(i);
    n = sessions.nSessions;
    runOpts.progressFcn = @(progInfo) options.progressFcn( ...
        addSessionFields(progInfo, i, n, s.value, s.voltage));
end
end

function info = addSessionFields(info, sessionIndex, sessionTotal, value, voltage)
info.sessionIndex = sessionIndex;
info.sessionTotal = sessionTotal;
info.sessionValue = value;
info.sessionVoltage = voltage;
end
