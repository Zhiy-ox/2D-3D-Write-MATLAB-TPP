function multiVoltage_arbitary_printing(parentContainer)
%MULTIVOLTAGE_ARBITARY_PRINTING GUI for multi-value BMP -> per-voltage sessions.
%
% Run from MATLAB:
%   multiVoltage_arbitary_printing                 % standalone window
%   multiVoltage_arbitary_printing(parentContainer)% embed in a container/tab (see arbitary_printing)
%
% Wraps multiVoltage_arbitary_printing_config / _generate / _run. Each gray value
% in the Values table becomes one written pattern (session) at its own phase
% voltage; between sessions the voltage is set (optionally via the AFG) and the
% operator confirms. Sessions return to the start so patterns stay registered.

cfg0 = multiVoltage_arbitary_printing_config();

app = struct();
app.lastSessions = [];
app.runStopToken = AerotechRunStopToken();
app.activeController = [];
app.activeTask = [];

if nargin < 1 || isempty(parentContainer)
    app.fig = uifigure('Name', 'multiVoltage Arbitrary Printing', 'Position', [50 40 1380 880]);
    uiParent = app.fig;
else
    uiParent = parentContainer;
    app.fig = ancestor(parentContainer, 'figure');
end

root = uigridlayout(uiParent, [2 1]);
root.RowHeight = {62, '1x'};
root.ColumnWidth = {'1x'};
root.Padding = [14 12 14 14];
root.RowSpacing = 10;

buildHeader(root);

main = uigridlayout(root, [1 2]);
main.ColumnWidth = {400, '1x'};
main.RowHeight = {'1x'};
main.Padding = [0 0 0 0];
main.ColumnSpacing = 12;

left = uigridlayout(main, [3 1]);
left.RowHeight = {174, '1x', 110};
left.Padding = [0 0 0 0];
left.RowSpacing = 10;

right = uigridlayout(main, [2 1]);
right.RowHeight = {'1x', 330};
right.Padding = [0 0 0 0];
right.RowSpacing = 10;

buildFilesPanel(left, cfg0);
buildActionPanel(left);
buildStatusPanel(left);
buildPreviewPanel(right);
buildSettingsTabs(right, cfg0);

logStatus('Ready. Pick a multi-value BMP, set values/voltages, preview, generate.');
updateSummaryText('No sessions generated yet.');

    function buildHeader(parent)
        panel = uipanel(parent, 'BorderType', 'none');
        grid = uigridlayout(panel, [2 3]);
        grid.ColumnWidth = {'1x', 150, 150};
        grid.RowHeight = {30, 22};
        grid.Padding = [4 0 4 0];
        grid.RowSpacing = 0;
        titleLabel = uilabel(grid, 'Text', 'multiVoltage Arbitrary Printing', ...
            'FontSize', 22, 'FontWeight', 'bold');
        setGridPosition(titleLabel, 1, 1);
        subtitle = uilabel(grid, 'Text', ...
            'Multi-value BMP to per-voltage registered DLW patterns (one session per value)');
        subtitle.FontColor = [0.28 0.32 0.38];
        setGridPosition(subtitle, 2, 1);
        b = uibutton(grid, 'Text', 'Preview', 'ButtonPushedFcn', @previewClasses);
        setGridPosition(b, 1, 2);
        b = uibutton(grid, 'Text', 'Generate', 'ButtonPushedFcn', @generateSessions);
        setGridPosition(b, 1, 3);
    end

    function buildFilesPanel(parent, cfg)
        panel = uipanel(parent, 'Title', 'Pattern Files');
        grid = uigridlayout(panel, [5 3]);
        grid.ColumnWidth = {60, '1x', 74};
        grid.RowHeight = {28, 28, 28, 28, 24};
        grid.Padding = [12 8 12 8];
        grid.RowSpacing = 6;
        grid.ColumnSpacing = 8;
        uilabel(grid, 'Text', 'BMP');
        app.bmpPath = uieditfield(grid, 'text', 'Value', cfg.bmpPath);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browseBmp);
        uilabel(grid, 'Text', 'Output');
        app.outputDir = uieditfield(grid, 'text', 'Value', cfg.outputDir);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browseOutputDir);
        uilabel(grid, 'Text', 'Preview');
        app.previewDir = uieditfield(grid, 'text', 'Value', cfg.previewDir);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browsePreviewDir);
        uilabel(grid, 'Text', 'Prefix');
        app.scriptPrefix = uieditfield(grid, 'text', 'Value', cfg.scriptPrefix);
        uilabel(grid, 'Text', '');
        note = uilabel(grid, 'Text', 'Each value in the Values tab = one pattern at its voltage.');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 5, [1 3]);
    end

    function buildSettingsTabs(parent, cfg)
        tg = uitabgroup(parent);
        buildValuesTab(uitab(tg, 'Title', 'Values'), cfg);
        buildAfgTab(uitab(tg, 'Title', 'AFG'), cfg);
        buildGeometryTab(uitab(tg, 'Title', 'Geometry'), cfg);
        buildMotionTab(uitab(tg, 'Title', 'Motion'), cfg);
        buildAerotechTab(uitab(tg, 'Title', 'Aerotech'), cfg);
        buildSummaryTab(uitab(tg, 'Title', 'Summary'));
        buildSessionsTab(uitab(tg, 'Title', 'Sessions'));
    end

    function buildValuesTab(tab, cfg)
        grid = uigridlayout(tab, [4 4]);
        grid.ColumnWidth = {'1x', '1x', '1x', '1x'};
        grid.RowHeight = {'1x', 30, 30, 26};
        grid.Padding = [12 10 12 10];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 10;

        data = [cfg.writtenValues(:), cfg.voltages(:)];
        app.valuesTable = uitable(grid, 'Data', data, ...
            'ColumnName', {'Value (0-255)', 'Voltage'}, ...
            'ColumnEditable', [true true], 'RowName', {});
        setGridPosition(app.valuesTable, 1, [1 4]);

        b = uibutton(grid, 'Text', 'Add row', 'ButtonPushedFcn', @addValueRow);
        setGridPosition(b, 2, 1);
        b = uibutton(grid, 'Text', 'Remove row', 'ButtonPushedFcn', @removeValueRow);
        setGridPosition(b, 2, 2);
        app.valueTolerance = addNumericAt(grid, 'Tolerance (+/-)', cfg.valueTolerance, 2, 3, 4);

        app.returnToStartEachSession = uicheckbox(grid, 'Text', 'Return to start each session', ...
            'Value', cfg.returnToStartEachSession);
        setGridPosition(app.returnToStartEachSession, 3, [1 2]);
        app.requireSessionConfirmation = uicheckbox(grid, 'Text', 'Confirm before each session', ...
            'Value', cfg.requireSessionConfirmation);
        setGridPosition(app.requireSessionConfirmation, 3, [3 4]);

        note = uilabel(grid, 'Text', ['Rows are written in order. Values not listed (within tolerance) ', ...
            'are background and never written.']);
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 4, [1 4]);
    end

    function buildAfgTab(tab, cfg)
        grid = uigridlayout(tab, [5 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;

        app.useAFG = uicheckbox(grid, 'Text', 'Auto-set voltage via AFG', 'Value', cfg.useAFG);
        setGridPosition(app.useAFG, 1, [1 2]);
        b = uibutton(grid, 'Text', 'Set now (test)', 'ButtonPushedFcn', @afgSetNow);
        setGridPosition(b, 1, [3 4]);

        lbl = uilabel(grid, 'Text', 'Function');
        setGridPosition(lbl, 2, 1);
        app.afgFunction = uidropdown(grid, 'Items', {'SQUare', 'SINusoid', 'RAMP', 'PULSe', 'DC'}, ...
            'Value', cfg.afgFunction);
        setGridPosition(app.afgFunction, 2, 2);
        app.afgFrequency_Hz = addNumericAt(grid, 'Frequency (Hz)', cfg.afgFrequency_Hz, 2, 3, 4);

        lbl = uilabel(grid, 'Text', 'Unit');
        setGridPosition(lbl, 3, 1);
        app.afgUnit = uidropdown(grid, 'Items', {'VPP', 'VRMS', 'DBM'}, 'Value', cfg.afgUnit);
        setGridPosition(app.afgUnit, 3, 2);
        lbl = uilabel(grid, 'Text', 'Impedance');
        setGridPosition(lbl, 3, 3);
        app.afgImpedance = uieditfield(grid, 'text', 'Value', cfg.afgImpedance);
        setGridPosition(app.afgImpedance, 3, 4);

        app.afgResetFirst = uicheckbox(grid, 'Text', 'Send *RST first', 'Value', cfg.afgResetFirst);
        setGridPosition(app.afgResetFirst, 4, [1 2]);
        app.afgOffAtEnd = uicheckbox(grid, 'Text', 'AFG output OFF at end', 'Value', cfg.afgOffAtEnd);
        setGridPosition(app.afgOffAtEnd, 4, [3 4]);

        note = uilabel(grid, 'Text', 'AFG is optional; you can also set the voltage manually at each confirm step.');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 5, [1 4]);
    end

    function buildGeometryTab(tab, cfg)
        grid = uigridlayout(tab, [4 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;
        app.pixelSize_um = addNumericAt(grid, 'BMP pixel size (um)', cfg.pixelSize_um, 1, 1, 2);
        app.lineSpacing_um = addNumericAt(grid, 'Scan spacing Y (um)', cfg.lineSpacing_um, 1, 3, 4);
        app.xOrigin_mm = addNumericAt(grid, 'X origin (mm)', cfg.xOrigin_mm, 2, 1, 2);
        app.yOrigin_mm = addNumericAt(grid, 'Y origin (mm)', cfg.yOrigin_mm, 2, 3, 4);
        app.zPosition_mm = addNumericAt(grid, 'Z position (mm)', cfg.zPosition_mm, 3, 1, 2);
        app.leadIn_um = addNumericAt(grid, 'Lead-in (um)', cfg.leadIn_um, 3, 3, 4);
        app.leadOut_um = addNumericAt(grid, 'Lead-out (um)', cfg.leadOut_um, 4, 1, 2);
        app.flipY = uicheckbox(grid, 'Text', 'Write physical bottom row first', 'Value', cfg.flipY);
        setGridPosition(app.flipY, 4, [3 4]);
    end

    function buildMotionTab(tab, cfg)
        grid = uigridlayout(tab, [3 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;
        app.writeSpeed_mm_s = addNumericAt(grid, 'Write speed (mm/s)', cfg.writeSpeed_mm_s, 1, 1, 2);
        app.unwrittenSpeed_mm_s = addNumericAt(grid, 'Traverse speed (mm/s)', cfg.unwrittenSpeed_mm_s, 1, 3, 4);
        app.repositionSpeed_mm_s = addNumericAt(grid, 'Reposition speed', cfg.repositionSpeed_mm_s, 2, 1, 2);
        app.maxMotionCommandsPerScript = addNumericAt(grid, 'Max commands/chunk', cfg.maxMotionCommandsPerScript, 2, 3, 4);
        app.serpentine = uicheckbox(grid, 'Text', 'Serpentine scan', 'Value', cfg.serpentine);
        setGridPosition(app.serpentine, 3, [1 2]);
        app.savePreview = uicheckbox(grid, 'Text', 'Save preview PNG', 'Value', cfg.savePreview);
        setGridPosition(app.savePreview, 3, [3 4]);
    end

    function buildAerotechTab(tab, cfg)
        grid = uigridlayout(tab, [6 4]);
        grid.ColumnWidth = {'1x', 120, '1x', '2x'};
        grid.RowHeight = {28, 28, 28, 28, 28, 28};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;
        lbl = uilabel(grid, 'Text', 'Coordinate mode');
        setGridPosition(lbl, 1, 1);
        app.coordinateMode = uidropdown(grid, 'Items', {'relative', 'absolute'}, 'Value', cfg.coordinateMode);
        setGridPosition(app.coordinateMode, 1, 2);
        app.psoOutput = addNumericAt(grid, 'PSO output', cfg.psoOutput, 1, 3, 4);
        lbl = uilabel(grid, 'Text', 'PSO axis');
        setGridPosition(lbl, 2, 1);
        app.psoAxis = uieditfield(grid, 'text', 'Value', cfg.psoAxis);
        setGridPosition(app.psoAxis, 2, 2);
        lbl = uilabel(grid, 'Text', 'Aero DLL dir');
        setGridPosition(lbl, 3, 1);
        app.aerotechDotNetDir = uieditfield(grid, 'text', 'Value', cfg.aerotechDotNetDir);
        setGridPosition(app.aerotechDotNetDir, 3, [2 4]);
        lbl = uilabel(grid, 'Text', 'Relative cmd');
        setGridPosition(lbl, 4, 1);
        app.relativeModeCommand = uieditfield(grid, 'text', 'Value', cfg.relativeModeCommand);
        setGridPosition(app.relativeModeCommand, 4, 2);
        lbl = uilabel(grid, 'Text', 'Absolute cmd');
        setGridPosition(lbl, 4, 3);
        app.absoluteModeCommand = uieditfield(grid, 'text', 'Value', cfg.absoluteModeCommand);
        setGridPosition(app.absoluteModeCommand, 4, 4);
        app.includePsoControl = uicheckbox(grid, 'Text', 'Emit PSO on/off', 'Value', cfg.includePsoControl);
        setGridPosition(app.includePsoControl, 5, [1 2]);
        app.emitCoordinateModeCommand = uicheckbox(grid, 'Text', 'Emit mode command', 'Value', cfg.emitCoordinateModeCommand);
        setGridPosition(app.emitCoordinateModeCommand, 5, [3 4]);
        app.buildAeroBasic = uicheckbox(grid, 'Text', 'Build with AeroBasic .NET', 'Value', cfg.buildAeroBasic);
        setGridPosition(app.buildAeroBasic, 6, [1 2]);
        app.overwriteOutput = uicheckbox(grid, 'Text', 'Overwrite output folder', 'Value', cfg.overwriteOutput);
        setGridPosition(app.overwriteOutput, 6, 3);
        app.requireRunConfirmation = uicheckbox(grid, 'Text', 'Confirm hardware run', 'Value', cfg.requireRunConfirmation);
        setGridPosition(app.requireRunConfirmation, 6, 4);
    end

    function buildActionPanel(parent)
        panel = uipanel(parent, 'Title', 'Workflow');
        makeScrollable(panel);
        grid = uigridlayout(panel, [6 5]);
        grid.ColumnWidth = {42, '1x', 42, '1x', 52};
        grid.RowHeight = {34, 34, 28, 20, 16, 18};
        grid.Padding = [12 8 12 8];
        grid.RowSpacing = 7;
        grid.ColumnSpacing = 8;
        b = uibutton(grid, 'Text', 'Preview', 'ButtonPushedFcn', @previewClasses);
        setGridPosition(b, 1, [1 2]);
        b = uibutton(grid, 'Text', 'Generate Sessions', 'ButtonPushedFcn', @generateSessions);
        setGridPosition(b, 1, [3 5]);
        app.runButton = uibutton(grid, 'Text', 'Run Sessions', 'ButtonPushedFcn', @runSessions);
        setGridPosition(app.runButton, 2, [1 3]);
        app.stopButton = uibutton(grid, 'Text', 'Stop / Laser Off', 'ButtonPushedFcn', @stopRun, ...
            'BackgroundColor', [0.82 0.20 0.18], 'FontColor', [1 1 1]);
        setGridPosition(app.stopButton, 2, [4 5]);
        lbl = uilabel(grid, 'Text', 'From');
        setGridPosition(lbl, 3, 1);
        app.startSession = uieditfield(grid, 'numeric', 'Value', 1, 'Limits', [1 Inf]);
        setGridPosition(app.startSession, 3, 2);
        lbl = uilabel(grid, 'Text', 'To');
        setGridPosition(lbl, 3, 3);
        app.endSession = uieditfield(grid, 'numeric', 'Value', 0, 'Limits', [0 Inf]);
        setGridPosition(app.endSession, 3, 4);
        note = uilabel(grid, 'Text', '0=all');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 3, 5);
        app.progressLabel = uilabel(grid, 'Text', 'No run yet.');
        setGridPosition(app.progressLabel, 4, [1 5]);
        app.progressAxes = uiaxes(grid);
        setGridPosition(app.progressAxes, 5, [1 5]);
        configureProgressBar(app.progressAxes);
        app.progressPatch = patch(app.progressAxes, 'XData', [0 0 0 0], 'YData', [0 0 1 1], ...
            'FaceColor', [0.20 0.55 0.90], 'EdgeColor', 'none');
        app.etaLabel = uilabel(grid, 'Text', '');
        app.etaLabel.FontColor = [0.36 0.40 0.46];
        setGridPosition(app.etaLabel, 6, [1 5]);
    end

    function buildStatusPanel(parent)
        panel = uipanel(parent, 'Title', 'Status');
        grid = uigridlayout(panel, [1 1]);
        grid.Padding = [12 8 12 10];
        app.statusText = uitextarea(grid, 'Editable', 'off');
        app.statusText.Value = {'Ready.'};
    end

    function buildPreviewPanel(parent)
        panel = uipanel(parent, 'Title', 'Class Map Preview (value -> session)');
        grid = uigridlayout(panel, [1 1]);
        grid.Padding = [12 8 12 10];
        app.previewAxes = uiaxes(grid);
        title(app.previewAxes, 'Class map');
        xlabel(app.previewAxes, 'X pixel');
        ylabel(app.previewAxes, 'Y pixel');
        axis(app.previewAxes, 'image');
        app.previewAxes.YDir = 'normal';
    end

    function buildSummaryTab(tab)
        grid = uigridlayout(tab, [1 1]);
        grid.Padding = [12 10 12 12];
        app.summaryText = uitextarea(grid, 'Editable', 'off');
    end

    function buildSessionsTab(tab)
        grid = uigridlayout(tab, [1 1]);
        grid.Padding = [12 10 12 12];
        app.sessionsText = uitextarea(grid, 'Editable', 'off');
        app.sessionsText.Value = {'Generate to list sessions.'};
    end

    function field = addNumericAt(parent, labelText, value, row, labelColumn, fieldColumn)
        lbl = uilabel(parent, 'Text', labelText);
        setGridPosition(lbl, row, labelColumn);
        field = uieditfield(parent, 'numeric', 'Value', value);
        setGridPosition(field, row, fieldColumn);
    end

    function setGridPosition(control, row, column)
        control.Layout.Row = row;
        control.Layout.Column = column;
    end

    function makeScrollable(container)
        if isprop(container, 'Scrollable')
            container.Scrollable = 'on';
        end
    end

    function addValueRow(~, ~)
        d = app.valuesTable.Data;
        app.valuesTable.Data = [d; 0 0];
    end

    function removeValueRow(~, ~)
        d = app.valuesTable.Data;
        if size(d, 1) > 1
            app.valuesTable.Data = d(1:end - 1, :);
        end
    end

    function browseBmp(~, ~)
        startDir = fileparts(app.bmpPath.Value);
        if isempty(startDir) || ~exist(startDir, 'dir'), startDir = pwd; end
        [f, p] = uigetfile({'*.bmp;*.dib;*.png;*.tif', 'Image files'; '*.*', 'All files'}, ...
            'Select multi-value BMP', startDir);
        if isequal(f, 0), return; end
        app.bmpPath.Value = fullfile(p, f);
        previewClasses();
    end

    function browseOutputDir(~, ~)
        d = chooseFolder(app.outputDir.Value, 'Select output folder');
        if ~isequal(d, 0), app.outputDir.Value = d; end
    end

    function browsePreviewDir(~, ~)
        d = chooseFolder(app.previewDir.Value, 'Select preview folder');
        if ~isequal(d, 0), app.previewDir.Value = d; end
    end

    function folder = chooseFolder(currentValue, prompt)
        if isempty(currentValue) || ~exist(currentValue, 'dir'), currentValue = pwd; end
        folder = uigetdir(currentValue, prompt);
    end

    function previewClasses(varargin)
        try
            cfg = readConfigFromGui();
            [classMap, gray255, counts] = computeClassMapForGui(cfg);
            imagesc(app.previewAxes, classMap);
            n = numel(cfg.writtenValues);
            colormap(app.previewAxes, [0.85 0.85 0.85; classPaletteGui(n)]);
            app.previewAxes.CLim = [0 max(n, 1)];
            axis(app.previewAxes, 'image');
            app.previewAxes.YDir = 'normal';
            title(app.previewAxes, 'Class map (gray = background)');
            lines = {sprintf('Image: %d x %d px', size(gray255, 2), size(gray255, 1))};
            for i = 1:n
                lines{end + 1} = sprintf('Value %d -> %.4g %s : %d px', ...
                    cfg.writtenValues(i), cfg.voltages(i), cfg.afgUnit, counts(i)); %#ok<AGROW>
            end
            lines{end + 1} = sprintf('Background px: %d', nnz(classMap == 0));
            updateSummaryText(strjoin(lines, newline));
            logStatus('Preview updated.');
        catch err
            logStatus(['Preview failed: ' err.message]);
            showErrorDialog('Preview failed', err.message);
        end
    end

    function generateSessions(varargin)
        try
            cfg = readConfigFromGui();
            logStatus('Generating sessions...');
            drawnow;
            sessions = multiVoltage_arbitary_printing_generate(cfg);
            app.lastSessions = sessions;
            app.endSession.Value = sessions.nSessions;
            updateSessionsText(sessions);
            showReadyProgress(sessions);
            previewClasses();
            logStatus(sprintf('Generated %d sessions (%d chunks).', ...
                sessions.nSessions, sessions.totalScriptCount));
        catch err
            logStatus(['Generation failed: ' err.message]);
            showErrorDialog('Generation failed', err.message);
        end
    end

    function runSessions(varargin)
        runButton = app.runButton;
        cleanupButton = onCleanup(@() setControlEnabled(runButton, 'on'));
        try
            cfg = readConfigFromGui();
            sessionsPath = getSessionsPath(cfg);
            if ~exist(sessionsPath, 'file')
                error('Sessions index not found. Generate first: %s', sessionsPath);
            end
            options = struct();
            options.startSession = round(app.startSession.Value);
            options.endSession = round(app.endSession.Value);
            if options.endSession == 0, options.endSession = -1; end
            options.aerotechDotNetDir = cfg.aerotechDotNetDir;
            options.requireConfirmation = false;
            options.stopToken = app.runStopToken;
            options.stopRequestedFcn = @() app.runStopToken.IsStopRequested;
            options.runStateFcn = @setActiveRunObjects;
            options.progressFcn = @onRunProgress;
            options.confirmFcn = @guiConfirmSession;

            if cfg.requireRunConfirmation
                answer = confirmHardwareRun('Run the multi-voltage sessions on the Aerotech controller?');
                if ~strcmp(answer, 'RUN')
                    logStatus('Run cancelled.');
                    return;
                end
            end
            app.runStopToken.reset();
            setControlEnabled(app.runButton, 'off');
            logStatus('Starting multi-voltage run...');
            drawnow;
            multiVoltage_arbitary_printing_run(sessionsPath, options);
            logStatus('Multi-voltage run finished.');
        catch err
            if app.runStopToken.IsStopRequested
                logStatus(['Run stopped: ' err.message]);
            else
                logStatus(['Run failed: ' err.message]);
                showErrorDialog('Run failed', err.message);
            end
        end
        resetRunControls();
    end

    function [proceed, newVoltage] = guiConfirmSession(info)
        msg = sprintf(['Session %d of %d  -  value %d\n\n', ...
            'Set the phase voltage for this pattern, then OK to write (Cancel to stop).\n', ...
            'Voltage (%s):'], info.index, info.total, info.value, info.unit);
        answer = inputdlg({msg}, sprintf('Session %d voltage', info.index), 1, {num2str(info.voltage)});
        if isempty(answer)
            proceed = false; newVoltage = [];
            return;
        end
        newVoltage = str2double(answer{1});
        proceed = true;
        if ~isfinite(newVoltage), newVoltage = []; end
    end

    function afgSetNow(~, ~)
        try
            cfg = readConfigFromGui();
            if isempty(cfg.voltages)
                error('Add at least one value/voltage row.');
            end
            AFG_Standalone(cfg.afgResetFirst, cfg.afgImpedance, cfg.afgFunction, ...
                cfg.afgFrequency_Hz, cfg.afgUnit, cfg.voltages(1), 'ON');
            logStatus(sprintf('AFG set to %.4g %s (test).', cfg.voltages(1), cfg.afgUnit));
        catch err
            logStatus(['AFG set failed: ' err.message]);
            showErrorDialog('AFG set failed', err.message);
        end
    end

    function stopRun(varargin)
        app.runStopToken.requestStop();
        logStatus('Stop requested: sending PSOCONTROL OFF...');
        drawnow;
        try
            cfg = readConfigFromGui();
            controller = app.activeController;
            task = app.activeTask;
            if isempty(controller)
                loadAerotechAssemblies(cfg.aerotechDotNetDir);
                Aerotech.Ensemble.Controller.Connect();
                controller = Aerotech.Ensemble.Controller.ConnectedControllers.Item(0);
                task = controller.Tasks.Item(Aerotech.Ensemble.TaskId.T01);
            elseif isempty(task)
                task = controller.Tasks.Item(Aerotech.Ensemble.TaskId.T01);
            end
            stopAerotechRun(controller, task, cfg.psoAxis);
            logStatus(sprintf('PSOCONTROL %s OFF requested.', cfg.psoAxis));
        catch err
            logStatus(['Stop failed: ' err.message]);
            showErrorDialog('Stop failed', err.message);
        end
    end

    function setActiveRunObjects(controller, task, isRunning)
        if isRunning
            app.activeController = controller;
            app.activeTask = task;
        else
            app.activeController = [];
            app.activeTask = [];
        end
    end

    function resetRunControls()
        setControlEnabled(app.runButton, 'on');
        app.runStopToken.reset();
        app.activeController = [];
        app.activeTask = [];
    end

    function onRunProgress(info)
        try
            frac = max(0, min(1, info.fractionDone));
            if isfield(app, 'progressPatch') && isvalid(app.progressPatch)
                app.progressPatch.XData = [0 frac frac 0];
            end
            sessTxt = '';
            if isfield(info, 'sessionIndex')
                sessTxt = sprintf('S%d/%d v=%d (%.4g V)  ', info.sessionIndex, ...
                    info.sessionTotal, info.sessionValue, info.sessionVoltage);
            end
            if strcmp(info.phase, 'complete')
                app.progressLabel.Text = sprintf('%sDone: %d / %d chunks', sessTxt, ...
                    info.doneCount, info.totalToRun);
            else
                app.progressLabel.Text = sprintf('%sChunk %d / %d  (%.1f%%)', sessTxt, ...
                    info.indexInRun, info.totalToRun, 100 * frac);
            end
            app.etaLabel.Text = sprintf('Elapsed %s   Remaining ~ %s   Finish ~ %s', ...
                fmtDuration(info.elapsed_s), fmtDuration(info.etaRemaining_s), fmtClock(info.finishClock));
            drawnow limitrate;
        catch
        end
    end

    function showReadyProgress(sessions)
        if isfield(app, 'progressPatch') && isvalid(app.progressPatch)
            app.progressPatch.XData = [0 0 0 0];
        end
        app.progressLabel.Text = sprintf('Ready: %d sessions, %d chunks', ...
            sessions.nSessions, sessions.totalScriptCount);
        app.etaLabel.Text = sprintf('Est. total write time ~ %s', fmtDuration(sessions.totalEstTime_s));
    end

    function cfg = readConfigFromGui()
        cfg = multiVoltage_arbitary_printing_config();
        cfg.bmpPath = char(app.bmpPath.Value);
        cfg.outputDir = char(app.outputDir.Value);
        cfg.previewDir = char(app.previewDir.Value);
        cfg.scriptPrefix = char(app.scriptPrefix.Value);

        d = app.valuesTable.Data;
        if isempty(d)
            error('Add at least one value/voltage row in the Values tab.');
        end
        cfg.writtenValues = d(:, 1).';
        cfg.voltages = d(:, 2).';
        cfg.valueTolerance = app.valueTolerance.Value;
        cfg.returnToStartEachSession = app.returnToStartEachSession.Value;
        cfg.requireSessionConfirmation = app.requireSessionConfirmation.Value;

        cfg.useAFG = app.useAFG.Value;
        cfg.afgFunction = char(app.afgFunction.Value);
        cfg.afgFrequency_Hz = app.afgFrequency_Hz.Value;
        cfg.afgUnit = char(app.afgUnit.Value);
        cfg.afgImpedance = char(app.afgImpedance.Value);
        cfg.afgResetFirst = app.afgResetFirst.Value;
        cfg.afgOffAtEnd = app.afgOffAtEnd.Value;

        cfg.pixelSize_um = app.pixelSize_um.Value;
        cfg.lineSpacing_um = app.lineSpacing_um.Value;
        cfg.xOrigin_mm = app.xOrigin_mm.Value;
        cfg.yOrigin_mm = app.yOrigin_mm.Value;
        cfg.zPosition_mm = app.zPosition_mm.Value;
        cfg.leadIn_um = app.leadIn_um.Value;
        cfg.leadOut_um = app.leadOut_um.Value;
        cfg.flipY = app.flipY.Value;

        cfg.writeSpeed_mm_s = app.writeSpeed_mm_s.Value;
        cfg.unwrittenSpeed_mm_s = app.unwrittenSpeed_mm_s.Value;
        cfg.repositionSpeed_mm_s = app.repositionSpeed_mm_s.Value;
        cfg.maxMotionCommandsPerScript = round(app.maxMotionCommandsPerScript.Value);
        cfg.serpentine = app.serpentine.Value;
        cfg.savePreview = app.savePreview.Value;

        cfg.coordinateMode = char(app.coordinateMode.Value);
        cfg.emitCoordinateModeCommand = app.emitCoordinateModeCommand.Value;
        cfg.relativeModeCommand = char(app.relativeModeCommand.Value);
        cfg.absoluteModeCommand = char(app.absoluteModeCommand.Value);
        cfg.includePsoControl = app.includePsoControl.Value;
        cfg.psoAxis = char(app.psoAxis.Value);
        cfg.psoOutput = round(app.psoOutput.Value);
        cfg.buildAeroBasic = app.buildAeroBasic.Value;
        cfg.aerotechDotNetDir = char(app.aerotechDotNetDir.Value);
        cfg.overwriteOutput = app.overwriteOutput.Value;
        cfg.requireRunConfirmation = app.requireRunConfirmation.Value;
    end

    function p = getSessionsPath(cfg)
        p = fullfile(cfg.outputDir, [cfg.scriptPrefix '_sessions.mat']);
    end

    function updateSessionsText(sessions)
        lines = {sprintf('Sessions: %d   Total chunks: %d   Est total: %s', ...
            sessions.nSessions, sessions.totalScriptCount, fmtDuration(sessions.totalEstTime_s))};
        for i = 1:sessions.nSessions
            s = sessions.sessionList(i);
            lines{end + 1} = sprintf('  %d) value %d -> %.4g V  |  %d px  |  %d chunks  |  est %s', ...
                i, s.value, s.voltage, s.pixelCount, s.scriptCount, fmtDuration(s.estTime_s)); %#ok<AGROW>
        end
        lines{end + 1} = ['Index: ' sessions.sessionsPath];
        app.sessionsText.Value = lines;
    end

    function updateSummaryText(text)
        if ischar(text)
            app.summaryText.Value = regexp(text, '\n', 'split');
        else
            app.summaryText.Value = text;
        end
    end

    function logStatus(message)
        if ~isfield(app, 'statusText') || ~isvalid(app.statusText), return; end
        stamp = char(datetime('now', 'Format', 'HH:mm:ss'));
        old = app.statusText.Value;
        if ischar(old), old = cellstr(old); end
        app.statusText.Value = [{[stamp '  ' message]}; old(:)];
        drawnow;
    end

    function answer = confirmHardwareRun(message)
        if exist('uiconfirm', 'file') == 2 || exist('uiconfirm', 'builtin') == 5
            answer = uiconfirm(app.fig, message, 'Confirm Hardware Motion', ...
                'Options', {'RUN', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
        else
            answer = questdlg(message, 'Confirm Hardware Motion', 'RUN', 'Cancel', 'Cancel');
            if isempty(answer), answer = 'Cancel'; end
        end
    end

    function showErrorDialog(titleText, message)
        if exist('uialert', 'file') == 2 || exist('uialert', 'builtin') == 5
            uialert(app.fig, message, titleText);
        else
            errordlg(message, titleText);
        end
    end
end

function [classMap, gray255, counts] = computeClassMapForGui(cfg)
[raw, map] = imread(cfg.bmpPath);
if ~isempty(map)
    if isfloat(raw), idx = raw; else, idx = double(raw) + 1; end
    idx(idx < 1) = 1; idx(idx > size(map, 1)) = size(map, 1);
    rgb = map(idx(:), :);
    gray = reshape(0.2989 * rgb(:, 1) + 0.5870 * rgb(:, 2) + 0.1140 * rgb(:, 3), size(raw));
elseif ndims(raw) == 3
    rd = double(raw);
    gray = (0.2989 * rd(:, :, 1) + 0.5870 * rd(:, :, 2) + 0.1140 * rd(:, :, 3)) ./ guiClassMax(raw);
else
    gray = double(raw) ./ guiClassMax(raw);
end
gray255 = min(max(gray, 0), 1) * 255;
classMap = zeros(size(gray255));
counts = zeros(1, numel(cfg.writtenValues));
for i = 1:numel(cfg.writtenValues)
    m = abs(gray255 - cfg.writtenValues(i)) <= cfg.valueTolerance;
    classMap(m & classMap == 0) = i;
    counts(i) = nnz(m);
end
if cfg.flipY
    classMap = flipud(classMap);   % match physical write orientation / preview
end
end

function mx = guiClassMax(raw)
if islogical(raw), mx = 1;
elseif isa(raw, 'uint8'), mx = 255;
elseif isa(raw, 'uint16'), mx = 65535;
else, mx = max(double(raw(:))); if mx <= 1, mx = 1; end
end
end

function pal = classPaletteGui(n)
base = [0.20 0.45 0.90; 0.90 0.30 0.20; 0.20 0.70 0.35; 0.85 0.65 0.10; ...
    0.55 0.30 0.75; 0.20 0.75 0.80];
if n < 1, pal = base(1, :); return; end
if n <= size(base, 1), pal = base(1:n, :); else, pal = base(mod(0:n - 1, size(base, 1)) + 1, :); end
end
