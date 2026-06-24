function twoD_arbitary_printing()
%TWOD_ARBITARY_PRINTING User interface for BMP-based twoD DLW toolpath generation.
%
% Run from MATLAB:
%   twoD_arbitary_printing
%
% The GUI wraps twoD_arbitary_printing_config, twoD_arbitary_printing_generate, and
% twoD_arbitary_printing_run.

cfg0 = twoD_arbitary_printing_config();

app = struct();
app.lastSummary = [];
app.lastPreviewMask = [];
app.runStopToken = AerotechRunStopToken();
app.activeController = [];
app.activeTask = [];

app.fig = uifigure('Name', 'twoD Arbitrary Printing', ...
    'Position', [50 40 1360 860]);

root = uigridlayout(app.fig, [2 1]);
root.RowHeight = {62, '1x'};
root.ColumnWidth = {'1x'};
root.Padding = [14 12 14 14];
root.RowSpacing = 10;

buildHeader(root);

main = uigridlayout(root, [1 2]);
main.ColumnWidth = {390, '1x'};
main.RowHeight = {'1x'};
main.Padding = [0 0 0 0];
main.ColumnSpacing = 12;

left = uigridlayout(main, [3 1]);
left.RowHeight = {174, '1x', 118};
left.Padding = [0 0 0 0];
left.RowSpacing = 10;

right = uigridlayout(main, [2 1]);
right.RowHeight = {'1x', 286};
right.Padding = [0 0 0 0];
right.RowSpacing = 10;

buildFilesPanel(left, cfg0);
buildActionPanel(left);
buildStatusPanel(left);
buildPreviewPanel(right);
buildSettingsTabs(right, cfg0);

logStatus('GUI ready. Select a BMP, preview it, then generate scripts.');
updateSummaryText('No script generated yet.');

    function buildHeader(parent)
        panel = uipanel(parent, 'BorderType', 'none');
        grid = uigridlayout(panel, [2 3]);
        grid.ColumnWidth = {'1x', 150, 150};
        grid.RowHeight = {30, 22};
        grid.Padding = [4 0 4 0];
        grid.RowSpacing = 0;

        titleLabel = uilabel(grid, 'Text', 'twoD Arbitrary Printing', ...
            'FontSize', 22, 'FontWeight', 'bold');
        setGridPosition(titleLabel, 1, 1);
        subtitle = uilabel(grid, 'Text', ...
            'BMP mask to chunked AeroBasic scan scripts for DLW writing');
        subtitle.FontColor = [0.28 0.32 0.38];
        setGridPosition(subtitle, 2, 1);

        button = uibutton(grid, 'Text', 'Preview', 'ButtonPushedFcn', @previewBmp);
        setGridPosition(button, 1, 2);
        button = uibutton(grid, 'Text', 'Generate', 'ButtonPushedFcn', @generateScripts);
        setGridPosition(button, 1, 3);
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

        note = uilabel(grid, 'Text', 'White pixels write slowly; black pixels traverse fast.');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 5, [1 3]);
    end

    function buildSettingsTabs(parent, cfg)
        tabGroup = uitabgroup(parent);
        buildPatternTab(uitab(tabGroup, 'Title', 'Pattern'), cfg);
        buildMotionTab(uitab(tabGroup, 'Title', 'Motion'), cfg);
        buildAerotechTab(uitab(tabGroup, 'Title', 'Aerotech'), cfg);
        buildSummaryTab(uitab(tabGroup, 'Title', 'Summary'));
        buildManifestTab(uitab(tabGroup, 'Title', 'Manifest'));
    end

    function buildPatternTab(tab, cfg)
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
        app.whiteThreshold = addNumericAt(grid, 'White threshold', cfg.whiteThreshold, 3, 3, 4);

        app.flipY = uicheckbox(grid, 'Text', 'Write physical bottom row first', 'Value', cfg.flipY);
        setGridPosition(app.flipY, 4, [1 2]);
        app.invertImage = uicheckbox(grid, 'Text', 'Invert image', 'Value', cfg.invertImage);
        setGridPosition(app.invertImage, 4, 3);
        app.savePreview = uicheckbox(grid, 'Text', 'Save preview PNG', 'Value', cfg.savePreview);
        setGridPosition(app.savePreview, 4, 4);
    end

    function buildMotionTab(tab, cfg)
        grid = uigridlayout(tab, [4 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;

        app.writeSpeed_mm_s = addNumericAt(grid, 'Write speed (mm/s)', cfg.writeSpeed_mm_s, 1, 1, 2);
        app.unwrittenSpeed_mm_s = addNumericAt(grid, 'Black speed (mm/s)', cfg.unwrittenSpeed_mm_s, 1, 3, 4);
        app.repositionSpeed_mm_s = addNumericAt(grid, 'Reposition speed', cfg.repositionSpeed_mm_s, 2, 1, 2);
        app.maxMotionCommandsPerScript = addNumericAt(grid, 'Max commands/chunk', ...
            cfg.maxMotionCommandsPerScript, 2, 3, 4);
        app.leadIn_um = addNumericAt(grid, 'Lead-in (um)', cfg.leadIn_um, 3, 1, 2);
        app.leadOut_um = addNumericAt(grid, 'Lead-out (um)', cfg.leadOut_um, 3, 3, 4);

        app.serpentine = uicheckbox(grid, 'Text', 'Serpentine scan', 'Value', cfg.serpentine);
        setGridPosition(app.serpentine, 4, [1 2]);
    end

    function buildAerotechTab(tab, cfg)
        grid = uigridlayout(tab, [6 4]);
        grid.ColumnWidth = {'1x', 120, '1x', '2x'};
        grid.RowHeight = {28, 28, 28, 28, 28, 28};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;

        label = uilabel(grid, 'Text', 'Coordinate mode');
        setGridPosition(label, 1, 1);
        app.coordinateMode = uidropdown(grid, 'Items', {'relative', 'absolute'}, ...
            'Value', cfg.coordinateMode);
        setGridPosition(app.coordinateMode, 1, 2);
        app.psoOutput = addNumericAt(grid, 'PSO output', cfg.psoOutput, 1, 3, 4);

        label = uilabel(grid, 'Text', 'PSO axis');
        setGridPosition(label, 2, 1);
        app.psoAxis = uieditfield(grid, 'text', 'Value', cfg.psoAxis);
        setGridPosition(app.psoAxis, 2, 2);
        label = uilabel(grid, 'Text', 'Aero DLL dir');
        setGridPosition(label, 3, 1);
        app.aerotechDotNetDir = uieditfield(grid, 'text', 'Value', cfg.aerotechDotNetDir);
        setGridPosition(app.aerotechDotNetDir, 3, [2 4]);

        label = uilabel(grid, 'Text', 'Relative command');
        setGridPosition(label, 4, 1);
        app.relativeModeCommand = uieditfield(grid, 'text', 'Value', cfg.relativeModeCommand);
        setGridPosition(app.relativeModeCommand, 4, 2);
        label = uilabel(grid, 'Text', 'Absolute command');
        setGridPosition(label, 4, 3);
        app.absoluteModeCommand = uieditfield(grid, 'text', 'Value', cfg.absoluteModeCommand);
        setGridPosition(app.absoluteModeCommand, 4, 4);

        app.includePsoControl = uicheckbox(grid, 'Text', 'Emit PSO on/off', 'Value', cfg.includePsoControl);
        setGridPosition(app.includePsoControl, 5, [1 2]);
        app.emitCoordinateModeCommand = uicheckbox(grid, 'Text', 'Emit mode command', ...
            'Value', cfg.emitCoordinateModeCommand);
        setGridPosition(app.emitCoordinateModeCommand, 5, [3 4]);
        app.buildAeroBasic = uicheckbox(grid, 'Text', 'Build with AeroBasic .NET', ...
            'Value', cfg.buildAeroBasic);
        setGridPosition(app.buildAeroBasic, 6, [1 2]);
        app.overwriteOutput = uicheckbox(grid, 'Text', 'Overwrite output folder', ...
            'Value', cfg.overwriteOutput);
        setGridPosition(app.overwriteOutput, 6, 3);
        app.requireRunConfirmation = uicheckbox(grid, 'Text', 'Confirm hardware run', ...
            'Value', cfg.requireRunConfirmation);
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

        button = uibutton(grid, 'Text', 'Preview BMP', 'ButtonPushedFcn', @previewBmp);
        setGridPosition(button, 1, [1 2]);
        button = uibutton(grid, 'Text', 'Generate Scripts', 'ButtonPushedFcn', @generateScripts);
        setGridPosition(button, 1, [3 5]);
        app.runButton = uibutton(grid, 'Text', 'Run Selected Chunks', 'ButtonPushedFcn', @runChunks);
        setGridPosition(app.runButton, 2, [1 3]);
        app.stopButton = uibutton(grid, 'Text', 'Stop / Laser Off', ...
            'ButtonPushedFcn', @stopRun, ...
            'BackgroundColor', [0.82 0.20 0.18], ...
            'FontColor', [1 1 1]);
        setGridPosition(app.stopButton, 2, [4 5]);

        label = uilabel(grid, 'Text', 'Start');
        setGridPosition(label, 3, 1);
        app.startChunk = uieditfield(grid, 'numeric', 'Value', 1, 'Limits', [1 Inf]);
        setGridPosition(app.startChunk, 3, 2);

        label = uilabel(grid, 'Text', 'End');
        setGridPosition(label, 3, 3);
        app.endChunk = uieditfield(grid, 'numeric', 'Value', 0, 'Limits', [0 Inf]);
        setGridPosition(app.endChunk, 3, 4);
        note = uilabel(grid, 'Text', '0 = all');
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

    function configureProgressBar(ax)
        ax.XLim = [0 1];
        ax.YLim = [0 1];
        ax.XTick = [];
        ax.YTick = [];
        ax.XColor = [0.7 0.7 0.7];
        ax.YColor = [0.7 0.7 0.7];
        ax.Box = 'on';
        ax.Color = [0.92 0.93 0.95];
        title(ax, '');
        try
            ax.Toolbar.Visible = 'off';
        catch
        end
        try
            disableDefaultInteractivity(ax);
        catch
        end
        hold(ax, 'on');
    end

    function buildStatusPanel(parent)
        panel = uipanel(parent, 'Title', 'Status');
        grid = uigridlayout(panel, [1 1]);
        grid.Padding = [12 8 12 10];
        app.statusText = uitextarea(grid, 'Editable', 'off');
        app.statusText.Value = {'Ready.'};
    end

    function buildPreviewPanel(parent)
        panel = uipanel(parent, 'Title', 'Physical Write Mask Preview');
        grid = uigridlayout(panel, [1 1]);
        grid.Padding = [12 8 12 10];
        app.previewAxes = uiaxes(grid);
        title(app.previewAxes, 'White = written, black = fast traverse');
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

    function buildManifestTab(tab)
        grid = uigridlayout(tab, [1 1]);
        grid.Padding = [12 10 12 12];
        app.manifestText = uitextarea(grid, 'Editable', 'off');
        app.manifestText.Value = {'Generate scripts to create a manifest.'};
    end

    function field = addNumericAt(parent, labelText, value, row, labelColumn, fieldColumn)
        label = uilabel(parent, 'Text', labelText);
        setGridPosition(label, row, labelColumn);
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

    function browseBmp(~, ~)
        startDir = fileparts(app.bmpPath.Value);
        if isempty(startDir) || ~exist(startDir, 'dir')
            startDir = pwd;
        end
        [fileName, folder] = uigetfile({'*.bmp;*.dib', 'BMP files (*.bmp, *.dib)'; ...
            '*.*', 'All files'}, 'Select black/white BMP', startDir);
        if isequal(fileName, 0)
            return;
        end
        app.bmpPath.Value = fullfile(folder, fileName);
        previewBmp();
    end

    function browseOutputDir(~, ~)
        folder = chooseFolder(app.outputDir.Value, 'Select output folder');
        if ~isequal(folder, 0)
            app.outputDir.Value = folder;
        end
    end

    function browsePreviewDir(~, ~)
        folder = chooseFolder(app.previewDir.Value, 'Select preview folder');
        if ~isequal(folder, 0)
            app.previewDir.Value = folder;
        end
    end

    function folder = chooseFolder(currentValue, prompt)
        if isempty(currentValue) || ~exist(currentValue, 'dir')
            currentValue = pwd;
        end
        folder = uigetdir(currentValue, prompt);
    end

    function previewBmp(varargin)
        try
            cfg = readConfigFromGui();
            [mask, info] = readBmpMaskForGui(cfg);
            app.lastPreviewMask = mask;
            imagesc(app.previewAxes, mask);
            colormap(app.previewAxes, gray(2));
            app.previewAxes.CLim = [0 1];
            axis(app.previewAxes, 'image');
            app.previewAxes.YDir = 'normal';
            title(app.previewAxes, 'Physical write mask');
            xlabel(app.previewAxes, 'X pixel');
            ylabel(app.previewAxes, 'Y pixel');

            [heightPx, widthPx] = size(mask);
            whitePixels = nnz(mask);
            blackPixels = numel(mask) - whitePixels;
            physicalWidth_um = widthPx * cfg.pixelSize_um;
            physicalHeight_um = heightPx * cfg.pixelSize_um;
            scanLineCount = max(1, ceil(physicalHeight_um / cfg.lineSpacing_um));
            updateSummaryText(sprintf(['Preview loaded\n', ...
                'Image: %d x %d px\n', ...
                'Physical size: %.3f um x %.3f um\n', ...
                'Scan lines: %d at %.3f um spacing\n', ...
                'White pixels: %d\n', ...
                'Black pixels: %d\n', ...
                'Gray levels found: %d\n'], ...
                widthPx, heightPx, physicalWidth_um, physicalHeight_um, ...
                scanLineCount, cfg.lineSpacing_um, whitePixels, blackPixels, info.uniqueGrayCount));
            logStatus('Preview updated.');
        catch err
            logStatus(['Preview failed: ' err.message]);
            showErrorDialog('Preview failed', err.message);
        end
    end

    function onRunProgress(info)
        try
            frac = max(0, min(1, info.fractionDone));
            if isfield(app, 'progressPatch') && isvalid(app.progressPatch)
                app.progressPatch.XData = [0 frac frac 0];
            end
            if strcmp(info.phase, 'complete')
                app.progressLabel.Text = sprintf('Done: %d / %d chunks (100%%)', ...
                    info.doneCount, info.totalToRun);
            else
                app.progressLabel.Text = sprintf('Chunk %d / %d  (%.1f%%)', ...
                    info.indexInRun, info.totalToRun, 100 * frac);
            end
            app.etaLabel.Text = sprintf('Elapsed %s   Remaining ~ %s   Finish ~ %s', ...
                fmtDuration(info.elapsed_s), fmtDuration(info.etaRemaining_s), fmtClock(info.finishClock));
            drawnow limitrate;
        catch
        end
    end

    function showReadyProgress(summary)
        if isfield(app, 'progressPatch') && isvalid(app.progressPatch)
            app.progressPatch.XData = [0 0 0 0];
        end
        app.progressLabel.Text = sprintf('Ready: %d chunks', summary.scriptCount);
        app.etaLabel.Text = sprintf('Est. total write time ~ %s', fmtDuration(summary.estimatedMotionTime_s));
    end

    function generateScripts(varargin)
        try
            cfg = readConfigFromGui();
            logStatus('Generating AeroBasic chunks...');
            drawnow;
            summary = twoD_arbitary_printing_generate(cfg);
            app.lastSummary = summary;
            app.endChunk.Value = summary.scriptCount;
            updateSummaryFromManifest(summary);
            showReadyProgress(summary);
            if ~isempty(summary.previewMaskPath) && exist(summary.previewMaskPath, 'file')
                previewBmp();
            end
            logStatus(sprintf('Generated %d chunks with %d motion commands.', ...
                summary.scriptCount, summary.motionCommands));
        catch err
            logStatus(['Generation failed: ' err.message]);
            showErrorDialog('Generation failed', err.message);
        end
    end

    function runChunks(varargin)
        runButton = app.runButton;
        cleanupButton = onCleanup(@() setControlEnabled(runButton, 'on'));

        try
            cfg = readConfigFromGui();
            manifestPath = getManifestPath(cfg);
            if ~exist(manifestPath, 'file')
                error('Manifest not found. Generate scripts first: %s', manifestPath);
            end

            options = struct();
            options.startChunk = round(app.startChunk.Value);
            options.endChunk = round(app.endChunk.Value);
            if options.endChunk == 0
                options.endChunk = -1;
            end
            options.aerotechDotNetDir = cfg.aerotechDotNetDir;
            options.requireConfirmation = false;
            options.psoAxis = cfg.psoAxis;
            options.stopToken = app.runStopToken;
            options.stopRequestedFcn = @() app.runStopToken.IsStopRequested;
            options.runStateFcn = @setActiveRunObjects;
            options.progressFcn = @onRunProgress;

            if cfg.requireRunConfirmation
                answer = confirmHardwareRun(sprintf( ...
                    'Run chunks %d to %s on the Aerotech controller?', ...
                    options.startChunk, endChunkLabel(options.endChunk)));
                if ~strcmp(answer, 'RUN')
                    logStatus('Hardware run cancelled.');
                    return;
                end
            end

            app.runStopToken.reset();
            setControlEnabled(app.runButton, 'off');

            logStatus('Starting Aerotech chunk runner...');
            drawnow;
            twoD_arbitary_printing_run(manifestPath, options);
            logStatus('Aerotech chunk runner completed.');
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

    function cfg = readConfigFromGui()
        cfg = twoD_arbitary_printing_config();
        cfg.bmpPath = char(app.bmpPath.Value);
        cfg.outputDir = char(app.outputDir.Value);
        cfg.previewDir = char(app.previewDir.Value);
        cfg.scriptPrefix = char(app.scriptPrefix.Value);

        cfg.pixelSize_um = app.pixelSize_um.Value;
        cfg.lineSpacing_um = app.lineSpacing_um.Value;
        cfg.xOrigin_mm = app.xOrigin_mm.Value;
        cfg.yOrigin_mm = app.yOrigin_mm.Value;
        cfg.zPosition_mm = app.zPosition_mm.Value;
        cfg.leadIn_um = app.leadIn_um.Value;
        cfg.leadOut_um = app.leadOut_um.Value;

        cfg.writeSpeed_mm_s = app.writeSpeed_mm_s.Value;
        cfg.unwrittenSpeed_mm_s = app.unwrittenSpeed_mm_s.Value;
        cfg.repositionSpeed_mm_s = app.repositionSpeed_mm_s.Value;
        cfg.whiteThreshold = app.whiteThreshold.Value;
        cfg.maxMotionCommandsPerScript = round(app.maxMotionCommandsPerScript.Value);

        cfg.serpentine = app.serpentine.Value;
        cfg.flipY = app.flipY.Value;
        cfg.invertImage = app.invertImage.Value;
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

    function updateSummaryFromManifest(summary)
        text = sprintf(['Generated scripts\n', ...
            'Image: %d x %d px\n', ...
            'Physical size: %.3f um x %.3f um\n', ...
            'Scan lines: %d at %.3f um spacing\n', ...
            'White pixels: %d\n', ...
            'White segments: %d\n', ...
            'Motion commands: %d\n', ...
            'Script chunks: %d\n', ...
            'Estimated motion time: %.2f s\n'], ...
            summary.width_px, summary.height_px, ...
            summary.patternWidth_um, summary.patternHeight_um, ...
            summary.scanLineCount, summary.lineSpacing_um, ...
            summary.whitePixels, summary.whiteSegments, ...
            summary.motionCommands, summary.scriptCount, ...
            summary.estimatedMotionTime_s);
        updateSummaryText(text);

        manifestLines = {
            ['Manifest: ' summary.manifestPath]
            ['Text manifest: ' summary.manifestTextPath]
            ['Output folder: ' summary.outputDir]
            ['Preview: ' summary.previewMaskPath]
            sprintf('Coordinate mode: %s', summary.coordinateMode)
            sprintf('Chunk start/end positions are saved in the manifest.')
            };
        app.manifestText.Value = manifestLines;
    end

    function updateSummaryText(text)
        if ischar(text)
            app.summaryText.Value = regexp(text, '\n', 'split');
        else
            app.summaryText.Value = text;
        end
    end

    function logStatus(message)
        if ~isfield(app, 'statusText') || ~isvalid(app.statusText)
            return;
        end
        stamp = char(datetime('now', 'Format', 'HH:mm:ss'));
        oldValue = app.statusText.Value;
        if ischar(oldValue)
            oldValue = cellstr(oldValue);
        end
        app.statusText.Value = [{[stamp '  ' message]}; oldValue(:)];
        drawnow;
    end

    function pathValue = getManifestPath(cfg)
        pathValue = fullfile(cfg.outputDir, [cfg.scriptPrefix '_manifest.mat']);
    end

    function label = endChunkLabel(endChunk)
        if endChunk < 0
            label = 'all remaining chunks';
        else
            label = num2str(endChunk);
        end
    end

    function answer = confirmHardwareRun(message)
        if exist('uiconfirm', 'file') == 2 || exist('uiconfirm', 'builtin') == 5
            answer = uiconfirm(app.fig, message, 'Confirm Hardware Motion', ...
                'Options', {'RUN', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2);
        else
            answer = questdlg(message, 'Confirm Hardware Motion', ...
                'RUN', 'Cancel', 'Cancel');
            if isempty(answer)
                answer = 'Cancel';
            end
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

function setControlEnabled(control, value)
try
    if ~isempty(control) && isvalid(control)
        control.Enable = value;
    end
catch
end
end

function s = fmtDuration(seconds_in)
% Seconds -> HH:MM:SS, or '--' for unknown/NaN.
if isempty(seconds_in) || ~isfinite(seconds_in) || seconds_in < 0
    s = '--';
    return;
end
seconds_in = round(seconds_in);
h = floor(seconds_in / 3600);
m = floor(mod(seconds_in, 3600) / 60);
sec = mod(seconds_in, 60);
s = sprintf('%02d:%02d:%02d', h, m, sec);
end

function s = fmtClock(dt)
% datetime -> HH:mm clock string, or '--' for unset.
if isempty(dt) || ~isdatetime(dt) || any(isnat(dt))
    s = '--';
    return;
end
s = char(datetime(dt, 'Format', 'HH:mm'));
end

function [writeMaskPhysical, sourceInfo] = readBmpMaskForGui(cfg)
[raw, map] = imread(cfg.bmpPath);

if ~isempty(map)
    grayImage = indexedToGrayForGui(raw, map);
elseif ndims(raw) == 3
    rawDouble = double(raw);
    grayRaw = 0.2989 * rawDouble(:, :, 1) + ...
        0.5870 * rawDouble(:, :, 2) + ...
        0.1140 * rawDouble(:, :, 3);
    grayImage = grayRaw ./ imageClassMaxForGui(raw);
else
    grayImage = double(raw) ./ imageClassMaxForGui(raw);
end

grayImage = min(max(grayImage, 0), 1);
writeMaskPhysical = grayImage >= cfg.whiteThreshold;
if cfg.flipY
    writeMaskPhysical = flipud(writeMaskPhysical);
end
if cfg.invertImage
    writeMaskPhysical = ~writeMaskPhysical;
end

sourceInfo = struct();
sourceInfo.class = class(raw);
sourceInfo.size = size(raw);
sourceInfo.hasColormap = ~isempty(map);
sourceInfo.grayMin = min(grayImage(:));
sourceInfo.grayMax = max(grayImage(:));
sourceInfo.uniqueGrayCount = numel(unique(grayImage(:)));
end

function grayImage = indexedToGrayForGui(raw, map)
if isfloat(raw)
    idx = raw;
else
    idx = double(raw) + 1;
end
idx(idx < 1) = 1;
idx(idx > size(map, 1)) = size(map, 1);
rgb = map(idx(:), :);
grayVector = 0.2989 * rgb(:, 1) + 0.5870 * rgb(:, 2) + 0.1140 * rgb(:, 3);
grayImage = reshape(grayVector, size(raw));
end

function maxValue = imageClassMaxForGui(raw)
if islogical(raw)
    maxValue = 1;
elseif isa(raw, 'uint8')
    maxValue = double(intmax('uint8'));
elseif isa(raw, 'uint16')
    maxValue = double(intmax('uint16'));
elseif isa(raw, 'uint32')
    maxValue = double(intmax('uint32'));
else
    maxValue = max(double(raw(:)));
    if maxValue <= 0 || maxValue <= 1
        maxValue = 1;
    end
end
end
