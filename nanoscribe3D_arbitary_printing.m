function nanoscribe3D_arbitary_printing(parentContainer)
%NANOSCRIBE3D_ARBITARY_PRINTING GUI for layer-by-layer 3D DLW printing.
%
% Run from MATLAB:
%   nanoscribe3D_arbitary_printing                 % standalone window
%   nanoscribe3D_arbitary_printing(parentContainer)% embed in a container/tab
%
% Wraps nanoscribe3D_arbitary_printing_config / _slice / _generate / _run.
% The model (.stl or .mat heightmap) is sliced into layers; each layer is a
% hatched 2D slice written at its own Z (crosshatch alternates X/Y), and the
% stage steps one layer height between layers.

cfg0 = nanoscribe3D_arbitary_printing_config();

app = struct();
app.lastLayers = [];
app.lastSlices = [];
app.runStopToken = AerotechRunStopToken();
app.activeController = [];
app.activeTask = [];

if nargin < 1 || isempty(parentContainer)
    app.fig = uifigure('Name', 'nanoscribe3D Arbitrary Printing', 'Position', [50 40 1380 880]);
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

logStatus('Ready. Pick a model (.stl / .mat heightmap), set slicing, preview layers.');
updateSummaryText('No layers generated yet.');

    function buildHeader(parent)
        panel = uipanel(parent, 'BorderType', 'none');
        grid = uigridlayout(panel, [2 4]);
        grid.ColumnWidth = {'1x', 110, 110, 110};
        grid.RowHeight = {30, 22};
        grid.Padding = [4 0 4 0];
        grid.RowSpacing = 0;
        titleLabel = uilabel(grid, 'Text', 'nanoscribe3D Arbitrary Printing', ...
            'FontSize', 22, 'FontWeight', 'bold');
        setGridPosition(titleLabel, 1, 1);
        subtitle = uilabel(grid, 'Text', ...
            'STL / heightmap sliced into crosshatched layers written Z-step by Z-step');
        subtitle.FontColor = [0.28 0.32 0.38];
        setGridPosition(subtitle, 2, 1);
        b = uibutton(grid, 'Text', 'Slice Preview', 'ButtonPushedFcn', @previewSlices);
        setGridPosition(b, 1, 2);
        b = uibutton(grid, 'Text', '3D View', 'ButtonPushedFcn', @preview3D);
        setGridPosition(b, 1, 3);
        b = uibutton(grid, 'Text', 'Generate', 'ButtonPushedFcn', @generateLayers);
        setGridPosition(b, 1, 4);
    end

    function buildFilesPanel(parent, cfg)
        panel = uipanel(parent, 'Title', 'Model Files');
        grid = uigridlayout(panel, [5 3]);
        grid.ColumnWidth = {60, '1x', 74};
        grid.RowHeight = {28, 28, 28, 28, 24};
        grid.Padding = [12 8 12 8];
        grid.RowSpacing = 6;
        grid.ColumnSpacing = 8;
        uilabel(grid, 'Text', 'Model');
        app.inputPath = uieditfield(grid, 'text', 'Value', cfg.inputPath);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browseInput);
        uilabel(grid, 'Text', 'Output');
        app.outputDir = uieditfield(grid, 'text', 'Value', cfg.outputDir);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browseOutputDir);
        uilabel(grid, 'Text', 'Preview');
        app.previewDir = uieditfield(grid, 'text', 'Value', cfg.previewDir);
        uibutton(grid, 'Text', 'Browse', 'ButtonPushedFcn', @browsePreviewDir);
        uilabel(grid, 'Text', 'MAT var');
        app.matVariableName = uieditfield(grid, 'text', 'Value', cfg.matVariableName);
        app.scriptPrefix = uieditfield(grid, 'text', 'Value', cfg.scriptPrefix);
        note = uilabel(grid, 'Text', 'STL is sliced; a .mat heightmap is extruded into layers.');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 5, [1 3]);
    end

    function buildSettingsTabs(parent, cfg)
        tg = uitabgroup(parent);
        buildInputTab(uitab(tg, 'Title', 'Input'), cfg);
        buildSlicingTab(uitab(tg, 'Title', 'Slicing'), cfg);
        buildMotionTab(uitab(tg, 'Title', 'Motion'), cfg);
        buildAerotechTab(uitab(tg, 'Title', 'Aerotech'), cfg);
        buildSummaryTab(uitab(tg, 'Title', 'Summary'));
        buildLayersTab(uitab(tg, 'Title', 'Layers'));
    end

    function buildInputTab(tab, cfg)
        grid = uigridlayout(tab, [4 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;
        app.stlScale_um_per_unit = addNumericAt(grid, 'STL scale (um/unit)', cfg.stlScale_um_per_unit, 1, 1, 2);
        lbl = uilabel(grid, 'Text', 'Interp (heightmap)');
        setGridPosition(lbl, 1, 3);
        app.interpMethod = uidropdown(grid, 'Items', {'nearest', 'linear', 'cubic', 'spline', 'makima'}, ...
            'Value', cfg.interpMethod);
        setGridPosition(app.interpMethod, 1, 4);
        app.targetSizeX_um = addNumericAt(grid, 'Heightmap size X (um)', cfg.targetSizeX_um, 2, 1, 2);
        app.targetSizeY_um = addNumericAt(grid, 'Heightmap size Y (um)', cfg.targetSizeY_um, 2, 3, 4);
        app.heightScale_um_per_unit = addNumericAt(grid, 'Height scale (um/unit)', cfg.heightScale_um_per_unit, 3, 1, 2);
        app.heightOffset_um = addNumericAt(grid, 'Height offset (um)', cfg.heightOffset_um, 3, 3, 4);
        note = uilabel(grid, 'Text', ['STL scale: 1000 for a mesh authored in mm, 1 for um. ', ...
            'Heightmap fields apply only to .mat input.']);
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 4, [1 4]);
    end

    function buildSlicingTab(tab, cfg)
        grid = uigridlayout(tab, [4 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;
        app.layerHeight_um = addNumericAt(grid, 'Layer height (um)', cfg.layerHeight_um, 1, 1, 2);
        app.xyResolution_um = addNumericAt(grid, 'XY resolution (um)', cfg.xyResolution_um, 1, 3, 4);
        app.hatchSpacing_um = addNumericAt(grid, 'Hatch spacing (um)', cfg.hatchSpacing_um, 2, 1, 2);
        app.firstLayerZOffset_um = addNumericAt(grid, 'First layer Z offset (um)', cfg.firstLayerZOffset_um, 2, 3, 4);
        app.maxLayers = addNumericAt(grid, 'Max layers', cfg.maxLayers, 3, 1, 2);
        app.crossHatch = uicheckbox(grid, 'Text', 'Crosshatch 0/90 between layers', 'Value', cfg.crossHatch);
        setGridPosition(app.crossHatch, 3, [3 4]);
        app.layersTowardNegZ = uicheckbox(grid, 'Text', 'Layers build toward -Z (fixed objective)', ...
            'Value', cfg.zLayerSign < 0);
        setGridPosition(app.layersTowardNegZ, 4, [1 2]);
        note = uilabel(grid, 'Text', 'Layer k is written at z = sign*(offset + (k-1/2)*layerHeight).');
        note.FontColor = [0.36 0.40 0.46];
        setGridPosition(note, 4, [3 4]);
    end

    function buildMotionTab(tab, cfg)
        grid = uigridlayout(tab, [4 4]);
        grid.ColumnWidth = {'1x', 120, '1x', 150};
        grid.RowHeight = {28, 28, 28, 30};
        grid.Padding = [14 12 14 12];
        grid.RowSpacing = 8;
        grid.ColumnSpacing = 12;
        app.writeSpeed_mm_s = addNumericAt(grid, 'Write speed (mm/s)', cfg.writeSpeed_mm_s, 1, 1, 2);
        app.unwrittenSpeed_mm_s = addNumericAt(grid, 'Traverse speed (mm/s)', cfg.unwrittenSpeed_mm_s, 1, 3, 4);
        app.repositionSpeed_mm_s = addNumericAt(grid, 'Reposition speed', cfg.repositionSpeed_mm_s, 2, 1, 2);
        app.maxMotionCommandsPerScript = addNumericAt(grid, 'Max commands/chunk', cfg.maxMotionCommandsPerScript, 2, 3, 4);
        app.leadIn_um = addNumericAt(grid, 'Lead-in (um)', cfg.leadIn_um, 3, 1, 2);
        app.leadOut_um = addNumericAt(grid, 'Lead-out (um)', cfg.leadOut_um, 3, 3, 4);
        app.serpentine = uicheckbox(grid, 'Text', 'Serpentine scan', 'Value', cfg.serpentine);
        setGridPosition(app.serpentine, 4, [1 2]);
        app.pauseBetweenLayers_s = addNumericAt(grid, 'Pause between layers (s)', cfg.pauseBetweenLayers_s, 4, 3, 4);
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
        b = uibutton(grid, 'Text', 'Slice Preview', 'ButtonPushedFcn', @previewSlices);
        setGridPosition(b, 1, [1 2]);
        b = uibutton(grid, 'Text', 'Generate Layers', 'ButtonPushedFcn', @generateLayers);
        setGridPosition(b, 1, [3 5]);
        app.runButton = uibutton(grid, 'Text', 'Run Layers', 'ButtonPushedFcn', @runLayers);
        setGridPosition(app.runButton, 2, [1 3]);
        app.stopButton = uibutton(grid, 'Text', 'Stop / Laser Off', 'ButtonPushedFcn', @stopRun, ...
            'BackgroundColor', [0.82 0.20 0.18], 'FontColor', [1 1 1]);
        setGridPosition(app.stopButton, 2, [4 5]);
        lbl = uilabel(grid, 'Text', 'From');
        setGridPosition(lbl, 3, 1);
        app.startLayer = uieditfield(grid, 'numeric', 'Value', 1, 'Limits', [1 Inf]);
        setGridPosition(app.startLayer, 3, 2);
        lbl = uilabel(grid, 'Text', 'To');
        setGridPosition(lbl, 3, 3);
        app.endLayer = uieditfield(grid, 'numeric', 'Value', 0, 'Limits', [0 Inf]);
        setGridPosition(app.endLayer, 3, 4);
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
        panel = uipanel(parent, 'Title', 'Layer Slice Preview');
        grid = uigridlayout(panel, [2 2]);
        grid.RowHeight = {'1x', 34};
        grid.ColumnWidth = {'1x', 130};
        grid.Padding = [12 8 12 10];
        grid.RowSpacing = 4;
        app.previewAxes = uiaxes(grid);
        setGridPosition(app.previewAxes, 1, [1 2]);
        title(app.previewAxes, 'Slice');
        xlabel(app.previewAxes, 'X (um)');
        ylabel(app.previewAxes, 'Y (um)');
        axis(app.previewAxes, 'image');
        app.previewAxes.YDir = 'normal';
        app.layerSlider = uislider(grid, 'Limits', [1 2], 'Value', 1, ...
            'ValueChangedFcn', @(s, ~) showLayer(round(s.Value)));
        setGridPosition(app.layerSlider, 2, 1);
        app.layerLabel = uilabel(grid, 'Text', 'Layer - / -');
        setGridPosition(app.layerLabel, 2, 2);
    end

    function buildSummaryTab(tab)
        grid = uigridlayout(tab, [1 1]);
        grid.Padding = [12 10 12 12];
        app.summaryText = uitextarea(grid, 'Editable', 'off');
    end

    function buildLayersTab(tab)
        grid = uigridlayout(tab, [1 1]);
        grid.Padding = [12 10 12 12];
        app.layersText = uitextarea(grid, 'Editable', 'off');
        app.layersText.Value = {'Generate to list layers.'};
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

    function browseInput(~, ~)
        startDir = fileparts(app.inputPath.Value);
        if isempty(startDir) || ~exist(startDir, 'dir'), startDir = pwd; end
        [f, p] = uigetfile({'*.stl;*.mat', 'Models (*.stl, *.mat)'; '*.*', 'All files'}, ...
            'Select STL mesh or heightmap .mat', startDir);
        if isequal(f, 0), return; end
        app.inputPath.Value = fullfile(p, f);
        previewSlices();
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

    function previewSlices(varargin)
        try
            cfg = readConfigFromGui();
            logStatus('Slicing...');
            drawnow;
            slices = nanoscribe3D_arbitary_printing_slice(cfg);
            app.lastSlices = slices;
            if slices.nLayers > 1
                app.layerSlider.Limits = [1 slices.nLayers];
            else
                app.layerSlider.Limits = [1 1 + eps];
            end
            app.layerSlider.Value = 1;
            showLayer(1);
            est = totalPixels(slices) * cfg.xyResolution_um / 1000 / cfg.writeSpeed_mm_s;
            updateSummaryText(sprintf(['Sliced (%s)\n', ...
                'Extent: %.4g x %.4g x %.4g um\n', ...
                'Layers: %d at %.4g um\n', ...
                'Grid: %d x %d at %.4g um\n', ...
                'Solid pixels: %d\n', ...
                'Rough write time (writes only): %s\n%s'], ...
                slices.sourceType, slices.extent_um(1), slices.extent_um(2), slices.extent_um(3), ...
                slices.nLayers, cfg.layerHeight_um, ...
                numel(slices.x_um), numel(slices.y_um), cfg.xyResolution_um, ...
                totalPixels(slices), fmtDuration(est), openMeshNote(slices)));
            logStatus(sprintf('Sliced: %d layers.', slices.nLayers));
        catch err
            logStatus(['Slice failed: ' err.message]);
            showErrorDialog('Slice failed', err.message);
        end
    end

    function n = totalPixels(slices)
        n = nnz(slices.masks);
    end

    function s = openMeshNote(slices)
        if slices.oddCrossingRows > 0
            s = sprintf('WARNING: %d odd-crossing rows (mesh may be open)', slices.oddCrossingRows);
        else
            s = '';
        end
    end

    function showLayer(k)
        if isempty(app.lastSlices)
            return;
        end
        k = min(max(1, k), app.lastSlices.nLayers);
        imagesc(app.previewAxes, app.lastSlices.x_um, app.lastSlices.y_um, ...
            double(app.lastSlices.masks(:, :, k)));
        colormap(app.previewAxes, gray(2));
        app.previewAxes.CLim = [0 1];
        axis(app.previewAxes, 'image');
        app.previewAxes.YDir = 'normal';
        title(app.previewAxes, sprintf('Layer %d  (z = %.4g um)', k, app.lastSlices.z_um(k)));
        xlabel(app.previewAxes, 'X (um)');
        ylabel(app.previewAxes, 'Y (um)');
        app.layerLabel.Text = sprintf('Layer %d / %d', k, app.lastSlices.nLayers);
    end

    function preview3D(varargin)
        try
            if isempty(app.lastSlices)
                previewSlices();
            end
            slices = app.lastSlices;
            if isempty(slices)
                return;
            end
            f = figure('Name', '3D Model Preview', 'NumberTitle', 'off', 'Color', 'w');
            ax = axes('Parent', f);
            if strcmp(slices.sourceType, 'stl')
                trisurf(slices.mesh.ConnectivityList, slices.mesh.Points(:, 1), ...
                    slices.mesh.Points(:, 2), slices.mesh.Points(:, 3), ...
                    'Parent', ax, 'FaceColor', [0.35 0.60 0.90], 'EdgeColor', 'none', ...
                    'FaceAlpha', 0.85);
                camlight(ax); lighting(ax, 'gouraud');
            else
                [Xg, Yg] = meshgrid(slices.x_um, slices.y_um);
                surf(ax, Xg, Yg, slices.height_um, 'EdgeColor', 'none');
                colormap(ax, parula(256));
                colorbar(ax);
                shading(ax, 'interp');
            end
            view(ax, 3);
            axis(ax, 'tight');
            grid(ax, 'on');
            xlabel(ax, 'X (um)'); ylabel(ax, 'Y (um)'); zlabel(ax, 'Z (um)');
            title(ax, sprintf('%s: %.4g x %.4g x %.4g um, %d layers', slices.sourceType, ...
                slices.extent_um(1), slices.extent_um(2), slices.extent_um(3), slices.nLayers));
            try
                rotate3d(ax, 'on');
            catch
            end
            logStatus('Opened 3D model preview.');
        catch err
            logStatus(['3D preview failed: ' err.message]);
            showErrorDialog('3D preview failed', err.message);
        end
    end

    function generateLayers(varargin)
        try
            cfg = readConfigFromGui();
            logStatus('Generating layer sessions...');
            drawnow;
            layers = nanoscribe3D_arbitary_printing_generate(cfg);
            app.lastLayers = layers;
            app.endLayer.Value = layers.nLayers;
            updateLayersText(layers);
            showReadyProgress(layers);
            previewSlices();
            logStatus(sprintf('Generated %d layers (%d chunks).', ...
                layers.nLayers, layers.totalScriptCount));
        catch err
            logStatus(['Generation failed: ' err.message]);
            showErrorDialog('Generation failed', err.message);
        end
    end

    function runLayers(varargin)
        runButton = app.runButton;
        cleanupButton = onCleanup(@() setControlEnabled(runButton, 'on'));
        try
            cfg = readConfigFromGui();
            layersPath = getLayersPath(cfg);
            if ~exist(layersPath, 'file')
                error('Layers index not found. Generate first: %s', layersPath);
            end
            options = struct();
            options.startLayer = round(app.startLayer.Value);
            options.endLayer = round(app.endLayer.Value);
            if options.endLayer == 0, options.endLayer = -1; end
            options.pauseBetweenLayers_s = cfg.pauseBetweenLayers_s;
            options.aerotechDotNetDir = cfg.aerotechDotNetDir;
            options.requireConfirmation = false;
            options.stopToken = app.runStopToken;
            options.stopRequestedFcn = @() app.runStopToken.IsStopRequested;
            options.runStateFcn = @setActiveRunObjects;
            options.progressFcn = @onRunProgress;

            if cfg.requireRunConfirmation
                answer = confirmHardwareRun('Run the layer-by-layer print on the Aerotech controller?');
                if ~strcmp(answer, 'RUN')
                    logStatus('Run cancelled.');
                    return;
                end
            end
            app.runStopToken.reset();
            setControlEnabled(app.runButton, 'off');
            logStatus('Starting layer-by-layer run...');
            drawnow;
            nanoscribe3D_arbitary_printing_run(layersPath, options);
            logStatus('Layer-by-layer run finished.');
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

    function onRunProgress(info)
        try
            frac = max(0, min(1, info.fractionDone));
            if isfield(app, 'progressPatch') && isvalid(app.progressPatch)
                app.progressPatch.XData = [0 frac frac 0];
            end
            layerTxt = '';
            if isfield(info, 'layerIndex')
                layerTxt = sprintf('L%d/%d z=%.3gum  ', info.layerIndex, ...
                    info.layerTotal, info.layerZ_um);
            end
            if strcmp(info.phase, 'complete')
                app.progressLabel.Text = sprintf('%sDone: %d / %d chunks', layerTxt, ...
                    info.doneCount, info.totalToRun);
            else
                app.progressLabel.Text = sprintf('%sChunk %d / %d  (%.1f%%)', layerTxt, ...
                    info.indexInRun, info.totalToRun, 100 * frac);
            end
            app.etaLabel.Text = sprintf('Elapsed %s   Remaining ~ %s   Finish ~ %s', ...
                fmtDuration(info.elapsed_s), fmtDuration(info.etaRemaining_s), fmtClock(info.finishClock));
            drawnow limitrate;
        catch
        end
    end

    function showReadyProgress(layers)
        if isfield(app, 'progressPatch') && isvalid(app.progressPatch)
            app.progressPatch.XData = [0 0 0 0];
        end
        app.progressLabel.Text = sprintf('Ready: %d layers, %d chunks', ...
            layers.nLayers, layers.totalScriptCount);
        app.etaLabel.Text = sprintf('Est. total write time ~ %s', fmtDuration(layers.totalEstTime_s));
    end

    function cfg = readConfigFromGui()
        cfg = nanoscribe3D_arbitary_printing_config();
        cfg.inputPath = char(app.inputPath.Value);
        cfg.matVariableName = char(app.matVariableName.Value);
        cfg.outputDir = char(app.outputDir.Value);
        cfg.previewDir = char(app.previewDir.Value);
        cfg.scriptPrefix = char(app.scriptPrefix.Value);

        cfg.stlScale_um_per_unit = app.stlScale_um_per_unit.Value;
        cfg.targetSizeX_um = app.targetSizeX_um.Value;
        cfg.targetSizeY_um = app.targetSizeY_um.Value;
        cfg.interpMethod = char(app.interpMethod.Value);
        cfg.heightScale_um_per_unit = app.heightScale_um_per_unit.Value;
        cfg.heightOffset_um = app.heightOffset_um.Value;

        cfg.layerHeight_um = app.layerHeight_um.Value;
        cfg.xyResolution_um = app.xyResolution_um.Value;
        cfg.hatchSpacing_um = app.hatchSpacing_um.Value;
        cfg.crossHatch = app.crossHatch.Value;
        cfg.firstLayerZOffset_um = app.firstLayerZOffset_um.Value;
        cfg.maxLayers = round(app.maxLayers.Value);
        if app.layersTowardNegZ.Value
            cfg.zLayerSign = -1;
        else
            cfg.zLayerSign = 1;
        end

        cfg.writeSpeed_mm_s = app.writeSpeed_mm_s.Value;
        cfg.unwrittenSpeed_mm_s = app.unwrittenSpeed_mm_s.Value;
        cfg.repositionSpeed_mm_s = app.repositionSpeed_mm_s.Value;
        cfg.maxMotionCommandsPerScript = round(app.maxMotionCommandsPerScript.Value);
        cfg.leadIn_um = app.leadIn_um.Value;
        cfg.leadOut_um = app.leadOut_um.Value;
        cfg.serpentine = app.serpentine.Value;
        cfg.pauseBetweenLayers_s = app.pauseBetweenLayers_s.Value;

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

    function p = getLayersPath(cfg)
        p = fullfile(cfg.outputDir, [cfg.scriptPrefix '_layers.mat']);
    end

    function updateLayersText(layers)
        lines = {sprintf('Layers: %d (%d written)   Total chunks: %d   Est total: %s', ...
            layers.nLayers, layers.writtenLayerCount, layers.totalScriptCount, ...
            fmtDuration(layers.totalEstTime_s))};
        for k = 1:layers.nLayers
            L = layers.layerList(k);
            lines{end + 1} = sprintf('  %04d) z=%.4g um  scan %s  |  %d px  |  %d chunks  |  est %s', ...
                L.index, L.z_um, L.scanAxis, L.pixelCount, L.scriptCount, fmtDuration(L.estTime_s)); %#ok<AGROW>
        end
        lines{end + 1} = ['Index: ' layers.layersPath];
        app.layersText.Value = lines;
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
