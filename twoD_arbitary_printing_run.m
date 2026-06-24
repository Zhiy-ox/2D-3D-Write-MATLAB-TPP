function twoD_arbitary_printing_run(manifestPath, options)
%TWOD_ARBITARY_PRINTING_RUN Run generated AeroBasic chunks one at a time.
%
% Usage:
%   twoD_arbitary_printing_run(fullfile(pwd, 'Generated_Scripts', ...
%       'twoD_arbitary_printing_manifest.mat'));
%
% This runner assumes you have already checked the preview and that the
% current stage position is the intended pattern origin for relative scripts.

if nargin < 1 || isempty(manifestPath)
    manifestPath = fullfile(pwd, 'Generated_Scripts', 'twoD_arbitary_printing_manifest.mat');
end
if nargin < 2 || isempty(options)
    options = struct();
end

loaded = load(manifestPath, 'manifest');
manifest = loaded.manifest;
options = fillRunOptions(options, manifest);

if options.endChunk < 0 || options.endChunk > manifest.scriptCount
    options.endChunk = manifest.scriptCount;
end
if options.startChunk < 1 || options.startChunk > manifest.scriptCount
    error('startChunk must be between 1 and %d.', manifest.scriptCount);
end
if options.startChunk > options.endChunk
    error('startChunk must be <= endChunk.');
end

fprintf('Manifest: %s\n', manifestPath);
fprintf('Source BMP: %s\n', manifest.sourceBmp);
fprintf('Coordinate mode: %s\n', manifest.coordinateMode);
fprintf('Running chunks %d to %d of %d.\n', ...
    options.startChunk, options.endChunk, manifest.scriptCount);

if options.requireConfirmation
    reply = input('Type RUN to start the Aerotech chunk runner: ', 's');
    if ~strcmp(reply, 'RUN')
        error('Run cancelled by user.');
    end
end

loadAerotechAssemblies(options.aerotechDotNetDir);

if isempty(options.controller)
    [Aerotech_Controller, ~, ~, ~] = Aerotech_Initialize(options.aerotechDotNetDir);
else
    Aerotech_Controller = options.controller;
end

task = Aerotech_Controller.Tasks.Item(Aerotech.Ensemble.TaskId.T01);
notifyRunState(options, Aerotech_Controller, task, true);
cleanupRunState = onCleanup(@() notifyRunState(options, [], [], false));

logFid = fopen(options.logPath, 'a');
if logFid < 0
    error('Could not open log file: %s', options.logPath);
end
cleanupLog = onCleanup(@() fclose(logFid));

fprintf(logFid, 'Run started: %s\r\n', currentTimestamp());
fprintf(logFid, 'Manifest: %s\r\n', manifestPath);
fprintf(logFid, 'Chunks: %d to %d\r\n', options.startChunk, options.endChunk);

totalToRun = options.endChunk - options.startChunk + 1;
estRange = chunkEstimatesForRange(manifest, options.startChunk, options.endChunk);
doneCount = 0;
runTic = tic;
notifyProgress(options, makeProgressInfo('init', options, totalToRun, options.startChunk, ...
    0, 0, computeEta(0, 0, estRange, totalToRun), '', NaN));

for chunkIndex = options.startChunk:options.endChunk
    processUiEvents();
    stopIfRequested(Aerotech_Controller, task, options);

    scriptPath = manifest.scriptFiles{chunkIndex};
    fprintf('Chunk %d/%d: %s\n', chunkIndex, manifest.scriptCount, scriptPath);
    fprintf(logFid, 'START\t%d\t%s\t%s\r\n', chunkIndex, currentTimestamp(), scriptPath);
    elapsedNow = toc(runTic);
    notifyProgress(options, makeProgressInfo('start', options, totalToRun, chunkIndex, ...
        doneCount, elapsedNow, computeEta(doneCount, elapsedNow, estRange, totalToRun), scriptPath, NaN));

    chunkTic = tic;
    try
        task.Program.Run(scriptPath);
        processUiEvents();
        stopIfRequested(Aerotech_Controller, task, options);
        waitForProgramComplete(Aerotech_Controller, task, options);
        processUiEvents();
        stopIfRequested(Aerotech_Controller, task, options);
    catch runErr
        if ~strcmp(runErr.identifier, 'twoD_arbitary_printing_run:Stopped')
            stopAerotechRun(Aerotech_Controller, task, options.psoAxis);
        end
        rethrow(runErr);
    end
    chunkDur = toc(chunkTic);

    fprintf(logFid, 'DONE\t%d\t%s\tdur=%.3f\telapsed=%.3f\r\n', ...
        chunkIndex, currentTimestamp(), chunkDur, toc(runTic));
    doneCount = doneCount + 1;
    elapsedNow = toc(runTic);
    notifyProgress(options, makeProgressInfo('done', options, totalToRun, chunkIndex, ...
        doneCount, elapsedNow, computeEta(doneCount, elapsedNow, estRange, totalToRun), scriptPath, chunkDur));

    if options.pauseBetweenChunks_s > 0
        pauseBetweenChunks(Aerotech_Controller, task, options);
    end
end

elapsedNow = toc(runTic);
notifyProgress(options, makeProgressInfo('complete', options, totalToRun, options.endChunk, ...
    doneCount, elapsedNow, 0, '', NaN));
fprintf(logFid, 'Run completed: %s\r\n', currentTimestamp());
fprintf('All requested chunks completed.\n');
end

function options = fillRunOptions(options, manifest)
if ~isfield(options, 'startChunk') || isempty(options.startChunk)
    options.startChunk = 1;
end
if ~isfield(options, 'endChunk') || isempty(options.endChunk)
    options.endChunk = -1;
end
if ~isfield(options, 'pauseBetweenChunks_s') || isempty(options.pauseBetweenChunks_s)
    options.pauseBetweenChunks_s = 0.1;
end
if ~isfield(options, 'pollPeriod_s') || isempty(options.pollPeriod_s)
    options.pollPeriod_s = 0.05;
end
if ~isfield(options, 'timeout_s') || isempty(options.timeout_s)
    options.timeout_s = Inf;
end
if ~isfield(options, 'controller')
    options.controller = [];
end
if ~isfield(options, 'requireConfirmation')
    options.requireConfirmation = [];
end
if ~isfield(options, 'stopRequestedFcn')
    options.stopRequestedFcn = [];
end
if ~isfield(options, 'stopToken')
    options.stopToken = [];
end
if ~isfield(options, 'runStateFcn')
    options.runStateFcn = [];
end
if ~isfield(options, 'progressFcn')
    options.progressFcn = [];
end
if ~isfield(options, 'psoAxis') || isempty(options.psoAxis)
    if isfield(manifest, 'config') && isfield(manifest.config, 'psoAxis')
        options.psoAxis = manifest.config.psoAxis;
    else
        options.psoAxis = 'X';
    end
end
if isempty(options.requireConfirmation)
    if isfield(manifest, 'config') && isfield(manifest.config, 'requireRunConfirmation')
        options.requireConfirmation = manifest.config.requireRunConfirmation;
    else
        options.requireConfirmation = true;
    end
end
if ~isfield(options, 'aerotechDotNetDir') || isempty(options.aerotechDotNetDir)
    if isfield(manifest, 'config') && isfield(manifest.config, 'aerotechDotNetDir')
        options.aerotechDotNetDir = manifest.config.aerotechDotNetDir;
    else
        options.aerotechDotNetDir = fullfile(pwd, 'Aerotech_DotNet');
    end
end
if ~isfield(options, 'logPath') || isempty(options.logPath)
    logDir = fullfile(pwd, 'Log');
    if ~exist(logDir, 'dir')
        mkdir(logDir);
    end
    options.logPath = fullfile(logDir, ['twoD_dlw_run_' fileTimestamp() '.txt']);
end
end

function waitForProgramComplete(controller, task, options)
startTime = tic;
while true
    processUiEvents();
    stopIfRequested(controller, task, options);

    stateText = getTaskStateText(task);
    if isProgramFinishedState(stateText)
        return;
    end
    if containsIgnoreCase(stateText, 'Error') || containsIgnoreCase(stateText, 'Fault')
        error('Aerotech task entered state: %s', stateText);
    end
    if isfinite(options.timeout_s) && toc(startTime) > options.timeout_s
        error('Timed out waiting for ProgramComplete. Last state: %s', stateText);
    end
    pause(options.pollPeriod_s);
end
end

function tf = isProgramFinishedState(stateText)
stateText = char(stateText);
tf = strcmpi(stateText, 'ProgramComplete') || ...
    strcmpi(stateText, 'Idle') || ...
    strcmpi(stateText, 'Inactive') || ...
    containsIgnoreCase(stateText, 'ProgramComplete');
end

function stopIfRequested(controller, task, options)
if ~isStopRequested(options)
    return;
end

stopAerotechRun(controller, task, options.psoAxis);
error('twoD_arbitary_printing_run:Stopped', ...
    'Aerotech run stopped by user. PSOCONTROL %s OFF was requested.', options.psoAxis);
end

function tf = isStopRequested(options)
tf = false;
if isfield(options, 'stopToken') && ~isempty(options.stopToken)
    try
        tf = logical(options.stopToken.IsStopRequested);
    catch
        tf = false;
    end
    if tf
        return;
    end
end

stopRequestedFcn = options.stopRequestedFcn;
if isa(stopRequestedFcn, 'function_handle')
    stopValue = stopRequestedFcn();
    tf = ~isempty(stopValue) && any(logical(stopValue(:)));
end
end

function notifyRunState(options, controller, task, isRunning)
if isa(options.runStateFcn, 'function_handle')
    try
        options.runStateFcn(controller, task, isRunning);
    catch stateErr
        warning('twoD_arbitary_printing_run:RunStateCallbackFailed', ...
            'Run state callback failed: %s', stateErr.message);
    end
end
end

function processUiEvents()
try
    drawnow;
catch
end
end

function notifyProgress(options, info)
if isfield(options, 'progressFcn') && isa(options.progressFcn, 'function_handle')
    try
        options.progressFcn(info);
    catch progErr
        warning('twoD_arbitary_printing_run:ProgressCallbackFailed', ...
            'Progress callback failed: %s', progErr.message);
    end
end
end

function info = makeProgressInfo(phase, options, totalToRun, currentChunk, doneCount, ...
    elapsed_s, eta_s, currentFile, lastDur_s)
info = struct();
info.phase = phase;                       % 'init' | 'start' | 'done' | 'complete'
info.startChunk = options.startChunk;
info.endChunk = options.endChunk;
info.totalToRun = totalToRun;
info.currentChunk = currentChunk;         % absolute chunk index
info.indexInRun = currentChunk - options.startChunk + 1;
info.doneCount = doneCount;
if totalToRun > 0
    info.fractionDone = doneCount / totalToRun;
else
    info.fractionDone = 0;
end
info.elapsed_s = elapsed_s;
info.etaRemaining_s = eta_s;
if isfinite(eta_s)
    info.finishClock = datetime('now') + seconds(eta_s);
else
    info.finishClock = NaT;
end
[~, base, ext] = fileparts(char(currentFile));
info.currentFile = [base ext];
info.lastChunkDur_s = lastDur_s;
end

function eta = computeEta(doneCount, elapsed_s, estRange, totalToRun)
% Remaining-time estimate. With per-chunk estimates, scale the remaining
% estimated motion time by the observed speed factor (actual/estimated so far).
% Otherwise fall back to a simple measured average per chunk.
if ~isempty(estRange)
    estDone = sum(estRange(1:doneCount));
    estRem = sum(estRange(doneCount + 1:end));
    if doneCount > 0 && estDone > 0
        eta = (elapsed_s / estDone) * estRem;
    else
        eta = estRem;             % no measured speed yet: use the nominal estimate
    end
elseif doneCount > 0
    eta = (elapsed_s / doneCount) * (totalToRun - doneCount);
else
    eta = NaN;
end
end

function estRange = chunkEstimatesForRange(manifest, startChunk, endChunk)
estRange = [];
if isfield(manifest, 'chunkEstimatedTime_s') && ~isempty(manifest.chunkEstimatedTime_s)
    v = manifest.chunkEstimatedTime_s(:);
    if numel(v) >= endChunk && startChunk >= 1
        estRange = v(startChunk:endChunk);
    end
end
end

function pauseBetweenChunks(controller, task, options)
remaining_s = options.pauseBetweenChunks_s;
while remaining_s > 0
    processUiEvents();
    stopIfRequested(controller, task, options);
    step_s = min(remaining_s, max(options.pollPeriod_s, 0.01));
    pause(step_s);
    remaining_s = remaining_s - step_s;
end
processUiEvents();
stopIfRequested(controller, task, options);
end

function textValue = currentTimestamp()
textValue = char(datetime('now', 'Format', 'dd-MMM-yyyy HH:mm:ss'));
end

function textValue = fileTimestamp()
textValue = char(datetime('now', 'Format', 'yyyyMMddHHmmss'));
end

function stateText = getTaskStateText(task)
try
    stateText = char(task.State.ToString());
catch
    try
        stateText = char(task.State.string);
    catch
        stateText = '';
    end
end
end

function tf = containsIgnoreCase(textValue, pattern)
tf = ~isempty(regexpi(char(textValue), pattern, 'once'));
end
