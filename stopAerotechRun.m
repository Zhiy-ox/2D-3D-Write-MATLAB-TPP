function stopAerotechRun(controller, task, psoAxis)
%STOPAEROTECHRUN Turn off PSO output and stop the active Aerotech program.

if nargin < 3 || isempty(psoAxis)
    psoAxis = 'X';
end

errors = {};

[psoCommandOk, psoCommand, errMsg] = makePsoOffCommand(psoAxis);
if psoCommandOk
    [psoOffOk, errMsg] = tryExecutePsoOff(controller, psoCommand);
else
    psoOffOk = false;
end
if ~psoOffOk
    errors{end + 1} = errMsg;
end

[stopOk, errMsg] = tryStopTask(task);
if ~stopOk
    errors{end + 1} = errMsg;
end

if psoCommandOk && ~psoOffOk
    [retryOk, errMsg] = tryExecutePsoOff(controller, psoCommand);
    if ~retryOk
        errors{end + 1} = ['Retry failed: ' errMsg];
    end
end

if ~isempty(errors)
    warning('stopAerotechRun:PartialStop', ...
        'Stop requested, but one or more stop actions reported errors:%s%s', ...
        newline, strjoin(errors, newline));
end
end

function [ok, psoCommand, errMsg] = makePsoOffCommand(psoAxis)
ok = false;
psoCommand = '';
errMsg = '';
psoAxis = strtrim(char(psoAxis));
if isempty(regexp(psoAxis, '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
    errMsg = sprintf('Invalid PSO axis "%s". Could not build PSOCONTROL OFF command.', psoAxis);
    return;
end
psoCommand = sprintf('PSOCONTROL %s OFF', psoAxis);
ok = true;
end

function [ok, errMsg] = tryExecutePsoOff(controller, psoCommand)
ok = false;
errMsg = '';
if isempty(controller)
    errMsg = 'No Aerotech controller object is available for PSOCONTROL OFF.';
    return;
end

try
    controller.Commands.Execute(psoCommand);
    ok = true;
catch err
    errMsg = sprintf('%s failed: %s', psoCommand, err.message);
end
end

function [ok, errMsg] = tryStopTask(task)
ok = false;
errMsg = '';
if isempty(task)
    errMsg = 'No Aerotech task object is available for Program.Stop.';
    return;
end

try
    task.Program.Stop();
    ok = true;
catch err
    errMsg = sprintf('Program.Stop failed: %s', err.message);
end
end
