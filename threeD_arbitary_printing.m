function threeD_arbitary_printing()
%THREED_ARBITARY_PRINTING User interface for matrix-based 3D surface DLW toolpaths.
%
% Run from MATLAB:
%   threeD_arbitary_printing
%
% The GUI wraps threeD_arbitary_printing_config, threeD_arbitary_printing_generate,
% and reuses twoD_arbitary_printing_run (the chunk runner is pattern-agnostic).

cfg0 = threeD_arbitary_printing_config();

app = struct();
app.lastSummary = [];
app.lastSurface = [];
app.runStopToken = AerotechRunStopToken();
app.activeController = [];
app.activeTask = [];

app.fig = uifigure('Name', 'threeD Arbitrary Printing', ...
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
right.RowHeight = {'1x', 320};
right.Padding = [0 0 0 0];
right.RowSpacing = 10;

buildFilesPanel(left, cfg0);
buildActionPanel(left);
buildStatusPanel(left);
buildPreviewPanel(right);
buildSettingsTabs(right, cfg0);

logStatus('GUI ready. Select a matrix (.csv/.mat), preview it, then generate scripts.');
updateSummaryText('No script generated yet.');

    function buildHeader(parent)
        panel = uipanel(parent, 'BorderType', 'none');
        grid = uigridlayout(panel, [2 4]);
        grid.ColumnWidth = {'1x', 110, 110, 110};
        grid.RowHeight = {30, 22};
        grid.Padding = [4 0 4 0];
        grid.RowSpacing = 0;

        titleLabel = uilabel(grid, 'Text', 'threeD Arbitrary Printing', ...
            'FontSize', 22, 'FontWeight', 'bold');
        setGridPosition(titleLabel, 1, 1);
        subtitle = uilabel(grid, 'Text', ...
            'Phase/height matrix to chunked AeroBasic surface scripts for DLW writing');
        subtitle.FontColor = [0.28 0.32 0.38];
        setGridPosition(subtitle, 2, 1);

        button = uibutton(grid, 'Text', 'Preview', 'ButtonPushedFcn', @previewMatrix);
        setGridPosition(button, 1, 2);
        button = uibutton(grid, 'Text', '3D View', 'ButtonPushedFcn', @preview3D);
        setGridPosition(button, 1, 3);
        button = uibutton(grid, 'Text', 'Generate', 'ButtonPushedFcn', @generateScripts);
        setGridPosition(button, 1, 4);
    end

    function buildFilesPanel(parent, cfg)
        panel = uipanel(parent, 'Title', 'Surface Files');
        grid = uigridlayout(panel, [5 3]);
        grid.ColumnWidth = {60, '1x', 74};
        grid.RowHeight = {28, 28, 28, 28, 24};
        grid.Padding = [12 8 12 8];
        grid.RowSpacing = 6;
        grid.ColumnSpacing = 8;

        uilabel(grid, 'Text', 'Matrix');
        app.matrixPath = uieditfield(grid, 'text', 'Value', cfg.matrixPath);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browseMatrix);

        uilabel(grid, 'Text', 'Output');
        app.outputDir = uieditfield(grid, 'text', 'Value', cfg.outputDir);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browseOutputDir);

        uilabel(grid, 'Text', 'Preview');
        app.previewDir = uieditfield(grid, 'text', 'Value', cfg.previewDir);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browsePreviewDir);

        uilabel(grid, 'Text', 'MAT var');
        app.matVariableName = uieditfield(grid, 'text', 'Value', cfg.matVariableName);
        app.scriptPrefix = uieditfield(grid, 'text', 'Value', cfg.scriptPrefix);

        note = uilabel(grid, 'Text', 'Matrix value -> height (linear) + tilt plane; Z tracks the surface.');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 5, [1 3]);
    end

    function buildSettingsTabs(parent, cfg)
        tabGroup = uitabgroup(parent);
        buildGeometryTab(uitab(tabGroup, 'Title', 'Geometry'), cfg);
        buildSurfaceTab(uitab(tabGroup, 'Title', 'Surface'), cfg);
        buildMotionTab(uitab(tabGroup, 'Title', 'Motion'), cfg);
        buildAerotechTab(uitab(tabGroup, 'Title', 'Aerotech'), cfg);
        buildSummaryTab(uitab(tabGroup, 'Title', 'Summary'));
        buildManifestTab(uitab(tabGroup, 'Title', 'Manifest'));
    end

    function buildGeometryTab(tab, cfg)
        grid = uigridlayout(tab, [7 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 28, 28, 28, 24};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;

        app.targetSizeX_um = addNumericAt(grid, 'Target size X (um)', cfg.targetSizeX_um, 1, 1, 2);
        app.targetSizeY_um = addNumericAt(grid, 'Target size Y (um)', cfg.targetSizeY_um, 1, 3, 4);
        app.pixelSize_um = addNumericAt(grid, 'X step (um)', cfg.pixelSize_um, 2, 1, 2);
        app.lineSpacing_um = addNumericAt(grid, 'Y step (um)', cfg.lineSpacing_um, 2, 3, 4);
        app.xOrigin_mm = addNumericAt(grid, 'X origin (mm)', cfg.xOrigin_mm, 3, 1, 2);
        app.yOrigin_mm = addNumericAt(grid, 'Y origin (mm)', cfg.yOrigin_mm, 3, 3, 4);
        app.zBase_mm = addNumericAt(grid, 'Z base (mm)', cfg.zBase_mm, 4, 1, 2);

        label = uilabel(grid, 'Text', 'Interp method');
        setGridPosition(label, 4, 3);
        app.interpMethod = uidropdown(grid, 'Items', ...
            {'nearest', 'linear', 'cubic', 'spline', 'makima'}, 'Value', cfg.interpMethod);
        setGridPosition(app.interpMethod, 4, 4);

        app.flipY = uicheckbox(grid, 'Text', 'Write physical bottom row first', 'Value', cfg.flipY);
        setGridPosition(app.flipY, 5, [1 2]);
        note = uilabel(grid, 'Text', 'X/Y steps are toolpath sampling; footprint = target size.');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 5, [3 4]);

        app.reverseXStage = uicheckbox(grid, 'Text', 'Reverse X stage axis', 'Value', cfg.xAxisSign < 0);
        setGridPosition(app.reverseXStage, 6, [1 2]);
        app.reverseYStage = uicheckbox(grid, 'Text', 'Reverse Y stage axis', 'Value', cfg.yAxisSign < 0);
        setGridPosition(app.reverseYStage, 6, [3 4]);
        app.invertHeightZ = uicheckbox(grid, 'Text', 'Height builds toward -Z', 'Value', cfg.heightZSign < 0);
        setGridPosition(app.invertHeightZ, 7, [1 2]);
        note2 = uilabel(grid, 'Text', 'Set these to match your stage''s reversed coordinates.');
        note2.FontColor = [0.36 0.40 0.46];
        setGridPosition(note2, 7, [3 4]);
    end

    function buildSurfaceTab(tab, cfg)
        grid = uigridlayout(tab, [6 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 28, 28, 56};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;

        app.phaseHeightSlope = addNumericAt(grid, 'Height slope (um/unit)', cfg.phaseHeightSlope, 1, 1, 2);
        app.phaseHeightOffset_um = addNumericAt(grid, 'Height offset (um)', cfg.phaseHeightOffset_um, 1, 3, 4);
        app.xTilt_um_per_mm = addNumericAt(grid, 'X tilt (um/mm, +=>+X up)', cfg.xTilt_um_per_mm, 2, 1, 2);
        app.yTilt_um_per_mm = addNumericAt(grid, 'Y tilt (um/mm, +=>+Y up)', cfg.yTilt_um_per_mm, 2, 3, 4);
        app.xTiltIntrinsic_um = addNumericAt(grid, 'X intrinsic (um, +=>+X up)', cfg.xTiltIntrinsic_um, 3, 1, 2);
        app.yTiltIntrinsic_um = addNumericAt(grid, 'Y intrinsic (um, +=>+Y up)', cfg.yTiltIntrinsic_um, 3, 3, 4);
        app.wrapModulus = addNumericAt(grid, 'Wrap modulus', cfg.wrapModulus, 4, 1, 2);
        app.liftHeight_um = addNumericAt(grid, 'Gap lift (um)', cfg.liftHeight_um, 4, 3, 4);

        app.xTilt_um_per_mm.Tooltip = 'Slope. +value raises the +X (right of preview) side. um of height per mm of X.';
        app.yTilt_um_per_mm.Tooltip = 'Slope. +value raises the +Y (top of preview) side. um of height per mm of Y.';
        app.xTiltIntrinsic_um.Tooltip = 'Total um rise from the origin edge to the far +X edge across the field. +value: +X (right) higher.';
        app.yTiltIntrinsic_um.Tooltip = 'Total um rise from the origin edge to the far +Y edge across the field. +value: +Y (top) higher.';

        app.wrapPhase = uicheckbox(grid, 'Text', 'Wrap phase before convert', 'Value', cfg.wrapPhase);
        setGridPosition(app.wrapPhase, 5, [1 2]);
        app.skipNaN = uicheckbox(grid, 'Text', 'Skip NaN cells (no-write)', 'Value', cfg.skipNaN);
        setGridPosition(app.skipNaN, 5, [3 4]);

        note = uilabel(grid, 'Text', ['Tilt sign: + raises the +X (right) and +Y (top) side of the ', ...
            'preview surface. "um/mm" = slope per mm; "intrinsic um" = total rise across the whole ', ...
            'field. Example: make the right edge 5 um higher -> X intrinsic = +5, or X tilt = +5/width_mm.']);
        note.FontColor = [0.36 0.40 0.46];
        if isprop(note, 'WordWrap')
            note.WordWrap = 'on';
        end
        setGridPosition(note, 6, [1 4]);
    end

    function buildMotionTab(tab, cfg)
        grid = uigridlayout(tab, [4 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;

        app.writeSpeed_mm_s = addNumericAt(grid, 'Write speed (mm/s)', cfg.writeSpeed_mm_s, 1, 1, 2);
        app.repositionSpeed_mm_s = addNumericAt(grid, 'Reposition speed', cfg.repositionSpeed_mm_s, 1, 3, 4);
        app.maxMotionCommandsPerScript = addNumericAt(grid, 'Max commands/chunk', ...
            cfg.maxMotionCommandsPerScript, 2, 1, 2);
        app.mergeColinearTolerance_um = addNumericAt(grid, 'Merge tol (um)', ...
            cfg.mergeColinearTolerance_um, 2, 3, 4);
        app.leadIn_um = addNumericAt(grid, 'Lead-in (um)', cfg.leadIn_um, 3, 1, 2);
        app.leadOut_um = addNumericAt(grid, 'Lead-out (um)', cfg.leadOut_um, 3, 3, 4);

        app.serpentine = uicheckbox(grid, 'Text', 'Serpentine scan', 'Value', cfg.serpentine);
        setGridPosition(app.serpentine, 4, [1 2]);
        app.savePreview = uicheckbox(grid, 'Text', 'Save preview PNG', 'Value', cfg.savePreview);
        setGridPosition(app.savePreview, 4, [3 4]);
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

        button = uibutton(grid, 'Text', 'Preview Matrix', 'ButtonPushedFcn', @previewMatrix);
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

    function buildStatusPanel(parent)
        panel = uipanel(parent, 'Title', 'Status');
        grid = uigridlayout(panel, [1 1]);
        grid.Padding = [12 8 12 10];
        app.statusText = uitextarea(grid, 'Editable', 'off');
        app.statusText.Value = {'Ready.'};
    end

    function buildPreviewPanel(parent)
        panel = uipanel(parent, 'Title', 'Surface Height Map Preview');
        grid = uigridlayout(panel, [1 1]);
        grid.Padding = [12 8 12 10];
        app.previewAxes = uiaxes(grid);
        title(app.previewAxes, 'Surface height (um)');
        xlabel(app.previewAxes, 'X (um)');
        ylabel(app.previewAxes, 'Y (um)');
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

    function browseMatrix(~, ~)
        startDir = fileparts(app.matrixPath.Value);
        if isempty(startDir) || ~exist(startDir, 'dir')
            startDir = pwd;
        end
        [fileName, folder] = uigetfile({'*.csv;*.mat;*.txt;*.dat', ...
            'Matrix files (*.csv, *.mat, *.txt, *.dat)'; '*.*', 'All files'}, ...
            'Select phase/height matrix', startDir);
        if isequal(fileName, 0)
            return;
        end
        app.matrixPath.Value = fullfile(folder, fileName);
        previewMatrix();
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

    function previewMatrix(varargin)
        try
            cfg = readConfigFromGui();
            surface = computeSurfaceForGui(cfg);
            app.lastSurface = surface;

            imagesc(app.previewAxes, surface.xLocal_um, surface.yLocal_um, surface.displayHeight_um);
            try
                colormap(app.previewAxes, parula(256));
            catch
                colormap(app.previewAxes, gray(256));
            end
            colorbar(app.previewAxes);
            axis(app.previewAxes, 'image');
            app.previewAxes.YDir = 'normal';
            title(app.previewAxes, 'Surface height (um)');
            xlabel(app.previewAxes, 'X (um)');
            ylabel(app.previewAxes, 'Y (um)');

            updateSummaryText(sprintf(['Preview loaded\n', ...
                'Matrix: %d x %d\n', ...
                'Target size: %.3f um x %.3f um\n', ...
                'Toolpath grid: %d x %d samples\n', ...
                'Effective step: %.4f um (X) x %.4f um (Y)\n', ...
                'Height range: %.4g to %.4g um\n', ...
                'Z range: %.6g to %.6g mm\n', ...
                'Written points: %d  (skipped %d)\n'], ...
                surface.matrixRows, surface.matrixCols, ...
                cfg.targetSizeX_um, cfg.targetSizeY_um, ...
                surface.nx, surface.ny, surface.effPixel_um, surface.effLine_um, ...
                surface.heightMin_um, surface.heightMax_um, ...
                surface.zMin_mm, surface.zMax_mm, ...
                surface.writtenPoints, surface.skippedPoints));
            logStatus('Preview updated.');
        catch err
            logStatus(['Preview failed: ' err.message]);
            showErrorDialog('Preview failed', err.message);
        end
    end

    function preview3D(varargin)
        try
            cfg = readConfigFromGui();
            surface = computeSurfaceForGui(cfg);
            app.lastSurface = surface;

            [Xg, Yg] = meshgrid(surface.xLocal_um, surface.yLocal_um);
            f = figure('Name', '3D Surface Preview', 'NumberTitle', 'off', 'Color', 'w');
            ax = axes('Parent', f);
            surf(ax, Xg, Yg, surface.displayHeight_um, 'EdgeColor', 'none');
            try
                colormap(ax, parula(256));
            catch
                colormap(ax, gray(256));
            end
            colorbar(ax);
            shading(ax, 'interp');
            view(ax, 3);
            axis(ax, 'tight');
            grid(ax, 'on');
            xlabel(ax, 'X (um)   + = +X side (right of preview)');
            ylabel(ax, 'Y (um)   + = +Y side (top of preview)');
            zlabel(ax, 'Surface height (um)   higher = taller feature');
            Hf = surface.displayHeight_um(isfinite(surface.displayHeight_um));
            if isempty(Hf)
                Hf = 0;
            end
            title(ax, sprintf('3D surface preview   (height %.4g .. %.4g um)', min(Hf), max(Hf)));
            try
                rotate3d(ax, 'on');
            catch
            end
            logStatus('Opened 3D surface preview (drag to rotate).');
        catch err
            logStatus(['3D preview failed: ' err.message]);
            showErrorDialog('3D preview failed', err.message);
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
            logStatus('Generating AeroBasic surface chunks...');
            drawnow;
            summary = threeD_arbitary_printing_generate(cfg);
            app.lastSummary = summary;
            app.endChunk.Value = summary.scriptCount;
            updateSummaryFromManifest(summary);
            showReadyProgress(summary);
            previewMatrix();
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
        cfg = threeD_arbitary_printing_config();
        cfg.matrixPath = char(app.matrixPath.Value);
        cfg.matVariableName = char(app.matVariableName.Value);
        cfg.outputDir = char(app.outputDir.Value);
        cfg.previewDir = char(app.previewDir.Value);
        cfg.scriptPrefix = char(app.scriptPrefix.Value);

        cfg.targetSizeX_um = app.targetSizeX_um.Value;
        cfg.targetSizeY_um = app.targetSizeY_um.Value;
        cfg.pixelSize_um = app.pixelSize_um.Value;
        cfg.lineSpacing_um = app.lineSpacing_um.Value;
        cfg.interpMethod = char(app.interpMethod.Value);
        cfg.xOrigin_mm = app.xOrigin_mm.Value;
        cfg.yOrigin_mm = app.yOrigin_mm.Value;
        cfg.zBase_mm = app.zBase_mm.Value;
        cfg.leadIn_um = app.leadIn_um.Value;
        cfg.leadOut_um = app.leadOut_um.Value;
        cfg.flipY = app.flipY.Value;
        cfg.xAxisSign = signFromReverse(app.reverseXStage.Value);
        cfg.yAxisSign = signFromReverse(app.reverseYStage.Value);
        cfg.heightZSign = signFromReverse(app.invertHeightZ.Value);

        cfg.phaseHeightSlope = app.phaseHeightSlope.Value;
        cfg.phaseHeightOffset_um = app.phaseHeightOffset_um.Value;
        cfg.xTilt_um_per_mm = app.xTilt_um_per_mm.Value;
        cfg.yTilt_um_per_mm = app.yTilt_um_per_mm.Value;
        cfg.xTiltIntrinsic_um = app.xTiltIntrinsic_um.Value;
        cfg.yTiltIntrinsic_um = app.yTiltIntrinsic_um.Value;
        cfg.wrapPhase = app.wrapPhase.Value;
        cfg.wrapModulus = app.wrapModulus.Value;
        cfg.skipNaN = app.skipNaN.Value;
        cfg.liftHeight_um = app.liftHeight_um.Value;

        cfg.writeSpeed_mm_s = app.writeSpeed_mm_s.Value;
        cfg.repositionSpeed_mm_s = app.repositionSpeed_mm_s.Value;
        cfg.maxMotionCommandsPerScript = round(app.maxMotionCommandsPerScript.Value);
        cfg.mergeColinearTolerance_um = app.mergeColinearTolerance_um.Value;
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

    function updateSummaryFromManifest(summary)
        text = sprintf(['Generated scripts\n', ...
            'Matrix: %d x %d\n', ...
            'Target size: %.3f um x %.3f um\n', ...
            'Toolpath grid: %d x %d samples\n', ...
            'Height range: %.4g to %.4g um\n', ...
            'Z range: %.6g to %.6g mm\n', ...
            'Written points: %d  (skipped %d)\n', ...
            'Write segments: %d\n', ...
            'Motion commands: %d\n', ...
            'Script chunks: %d\n', ...
            'Estimated motion time: %.2f s\n'], ...
            summary.matrixRows, summary.matrixCols, ...
            summary.targetSizeX_um, summary.targetSizeY_um, ...
            summary.nx, summary.ny, ...
            summary.heightMin_um, summary.heightMax_um, ...
            summary.zMin_mm, summary.zMax_mm, ...
            summary.writtenPoints, summary.skippedPoints, ...
            summary.writeSegments, summary.motionCommands, ...
            summary.scriptCount, summary.estimatedMotionTime_s);
        updateSummaryText(text);

        manifestLines = {
            ['Manifest: ' summary.manifestPath]
            ['Text manifest: ' summary.manifestTextPath]
            ['Output folder: ' summary.outputDir]
            ['Preview: ' summary.previewHeightMapPath]
            sprintf('Coordinate mode: %s', summary.coordinateMode)
            sprintf('Tilt: %.4g um/mm (X), %.4g um/mm (Y)', ...
                summary.xTilt_um_per_mm, summary.yTilt_um_per_mm)
            sprintf('Intrinsic tilt: %.4g um (X), %.4g um (Y) across footprint', ...
                summary.xTiltIntrinsic_um, summary.yTiltIntrinsic_um)
            sprintf('Axis signs: X %+d, Y %+d, height->Z %+d', ...
                summary.xAxisSign, summary.yAxisSign, summary.heightZSign)
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

function s = signFromReverse(tf)
% Checkbox "reversed" -> -1, unchecked -> +1.
if tf
    s = -1;
else
    s = 1;
end
end

function surface = computeSurfaceForGui(cfg)
% Lightweight surface computation for the preview, mirroring buildSurface in
% threeD_arbitary_printing_generate.
[~, ~, ext] = fileparts(cfg.matrixPath);
ext = lower(ext);
if strcmp(ext, '.mat')
    S = load(cfg.matrixPath);
    M = pickMatrixVariableForGui(S, cfg.matVariableName, cfg.matrixPath);
else
    M = readmatrix(cfg.matrixPath);
end
M = double(M);
if ndims(M) ~= 2 || size(M, 1) < 2 || size(M, 2) < 2 %#ok<ISMAT>
    error('Source must be a 2D matrix of at least 2 x 2 (got size [%s]).', num2str(size(M)));
end

matrixRows = size(M, 1);
matrixCols = size(M, 2);
if cfg.flipY
    M = flipud(M);
end
[nRows, nCols] = size(M);

nx = max(2, round(cfg.targetSizeX_um / cfg.pixelSize_um) + 1);
ny = max(2, round(cfg.targetSizeY_um / cfg.lineSpacing_um) + 1);
x_um = linspace(0, cfg.targetSizeX_um, nx);
y_um = linspace(0, cfg.targetSizeY_um, ny);

colQ = 1 + (x_um / cfg.targetSizeX_um) * (nCols - 1);
rowQ = 1 + (y_um / cfg.targetSizeY_um) * (nRows - 1);
[CQ, RQ] = meshgrid(colQ, rowQ);
sampled = interp2(M, CQ, RQ, cfg.interpMethod);

if cfg.wrapPhase
    sampled = mod(sampled, cfg.wrapModulus);
end
height_um = cfg.phaseHeightSlope * sampled + cfg.phaseHeightOffset_um;

[XX_um, YY_um] = meshgrid(x_um, y_um);
tilt_um = cfg.xTilt_um_per_mm * (XX_um / 1000) + cfg.yTilt_um_per_mm * (YY_um / 1000) ...
    + cfg.xTiltIntrinsic_um * (XX_um / cfg.targetSizeX_um) ...
    + cfg.yTiltIntrinsic_um * (YY_um / cfg.targetSizeY_um);
surfaceHeight_um = height_um + tilt_um;
Z_mm = cfg.zBase_mm + cfg.heightZSign * surfaceHeight_um / 1000;
invalid = ~isfinite(sampled);
if cfg.skipNaN
    Z_mm(invalid) = NaN;
end
displayHeight_um = surfaceHeight_um;
displayHeight_um(invalid) = NaN;

surface = struct();
surface.X_mm = cfg.xOrigin_mm + cfg.xAxisSign * (XX_um / 1000);
surface.Y_mm = cfg.yOrigin_mm + cfg.yAxisSign * (YY_um / 1000);
surface.Z_mm = Z_mm;
surface.displayHeight_um = displayHeight_um;
surface.xLocal_um = x_um;
surface.yLocal_um = y_um;
surface.matrixRows = matrixRows;
surface.matrixCols = matrixCols;
surface.nx = nx;
surface.ny = ny;
surface.effPixel_um = cfg.targetSizeX_um / (nx - 1);
surface.effLine_um = cfg.targetSizeY_um / (ny - 1);
finiteH = height_um(isfinite(sampled));
surface.heightMin_um = min(finiteH);
surface.heightMax_um = max(finiteH);
finiteZ = Z_mm(isfinite(Z_mm));
surface.zMin_mm = min(finiteZ);
surface.zMax_mm = max(finiteZ);
surface.writtenPoints = nnz(isfinite(Z_mm));
surface.skippedPoints = nnz(~isfinite(Z_mm));
end

function M = pickMatrixVariableForGui(S, requestedName, matPath)
requestedName = strtrim(char(requestedName));
if ~isempty(requestedName)
    if ~isfield(S, requestedName)
        error('Variable "%s" not found in %s.', requestedName, matPath);
    end
    M = S.(requestedName);
    return;
end
names = fieldnames(S);
candidates = {};
for k = 1:numel(names)
    v = S.(names{k});
    if isnumeric(v) && ismatrix(v) && size(v, 1) >= 2 && size(v, 2) >= 2
        candidates{end + 1} = names{k}; %#ok<AGROW>
    end
end
if numel(candidates) == 1
    M = S.(candidates{1});
elseif isempty(candidates)
    error('No 2D numeric matrix (>= 2 x 2) found in %s.', matPath);
else
    error('Multiple matrices in %s: %s. Set MAT var.', matPath, strjoin(candidates, ', '));
end
end
