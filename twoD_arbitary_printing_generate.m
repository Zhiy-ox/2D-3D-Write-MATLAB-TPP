function summary = twoD_arbitary_printing_generate(cfg)
%TWOD_ARBITARY_PRINTING_GENERATE Convert a 1-bit BMP into chunked AeroBasic files.
%
% Usage:
%   cfg = twoD_arbitary_printing_config();
%   cfg.bmpPath = fullfile(pwd, 'my_pattern.bmp');
%   cfg.pixelSize_um = 7.03125;  % BMP pixel pitch in X and Y
%   cfg.lineSpacing_um = 1.0;    % physical spacing between written scan lines
%   cfg.writeSpeed_mm_s = 0.02;
%   cfg.unwrittenSpeed_mm_s = 10;
%   summary = twoD_arbitary_printing_generate(cfg);
%
% Output:
%   Generated_Scripts/*.ab
%   Generated_Scripts/<prefix>_manifest.mat
%   Generated_Scripts/<prefix>_manifest.txt
%   Preview/<prefix>_physical_write_mask.png

if nargin < 1 || isempty(cfg)
    cfg = twoD_arbitary_printing_config();
end

cfg = fillDefaultConfig(cfg);
validateConfig(cfg);
prepareOutputFolders(cfg);

if isfield(cfg, 'maskOverride') && ~isempty(cfg.maskOverride)
    [writeMaskImage, sourceInfo] = useMaskOverride(cfg);
else
    [writeMaskImage, sourceInfo] = readBmpAsWriteMask(cfg);
end
writeMaskPhysical = writeMaskImage;
if cfg.flipY
    writeMaskPhysical = flipud(writeMaskPhysical);
end
if cfg.invertImage
    writeMaskPhysical = ~writeMaskPhysical;
end

[heightPx, widthPx] = size(writeMaskPhysical);
dims = makeDims(cfg, widthPx, heightPx);

scriptFiles = {};
chunkCommandCounts = [];
chunkEstimatedTime_s = [];
chunkStartPositions_mm = zeros(0, 3);
chunkEndPositions_mm = zeros(0, 3);
buildWarnings = {};

chunkIndex = 0;
fid = -1;
commandsInChunk = 0;
commandsTimeInChunk = 0;

currentPos = [0, 0, 0];
totalMotionCommands = 0;
whiteSegmentCount = 0;
blackSegmentCount = 0;
estimatedMotionTime_s = 0;
whitePixels = nnz(writeMaskPhysical);
blackPixels = numel(writeMaskPhysical) - whitePixels;
rowCommandCounts = zeros(dims.scanLineCount, 1);
rowWhiteSegments = zeros(dims.scanLineCount, 1);
rowBlackSegments = zeros(dims.scanLineCount, 1);
sourceRowByScanLine = zeros(dims.scanLineCount, 1);

for scanLineIndex = 1:dims.scanLineCount
    sourceRowIndex = sourceRowForScanLine(scanLineIndex, dims);
    sourceRowByScanLine(scanLineIndex) = sourceRowIndex;
    rowMask = writeMaskPhysical(sourceRowIndex, :);
    [cmds, rowEndPos, rowStats] = buildRowCommands(rowMask, scanLineIndex, currentPos, cfg, dims);
    writeCommandBlock(cmds);

    currentPos = rowEndPos;
    rowCommandCounts(scanLineIndex) = numel(cmds);
    rowWhiteSegments(scanLineIndex) = rowStats.whiteSegments;
    rowBlackSegments(scanLineIndex) = rowStats.blackSegments;
    whiteSegmentCount = whiteSegmentCount + rowStats.whiteSegments;
    blackSegmentCount = blackSegmentCount + rowStats.blackSegments;
end

% Optionally return to the physical start so the program has net-zero
% displacement (used to keep multi-session patterns registered).
if isfield(cfg, 'returnToStart') && cfg.returnToStart
    returnCmd = makeMoveCommand(currentPos, [0, 0, 0], cfg.repositionSpeed_mm_s, cfg, false);
    if ~isempty(returnCmd)
        writeCommandBlock(returnCmd);
        currentPos = [0, 0, 0];
    end
end

if fid >= 0
    closeChunk(currentPos);
end

previewMaskPath = '';
if cfg.savePreview
    previewMaskPath = savePreviewMask(writeMaskPhysical, cfg);
end

manifestPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_manifest.mat']);
manifestTextPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_manifest.txt']);

summary = struct();
summary.sourceBmp = cfg.bmpPath;
summary.sourceInfo = sourceInfo;
summary.coordinateMode = cfg.coordinateMode;
summary.outputDir = cfg.outputDir;
summary.previewMaskPath = previewMaskPath;
summary.manifestPath = manifestPath;
summary.manifestTextPath = manifestTextPath;
summary.scriptFiles = scriptFiles;
summary.scriptCount = numel(scriptFiles);
summary.chunkCommandCounts = chunkCommandCounts;
summary.chunkEstimatedTime_s = chunkEstimatedTime_s;
summary.chunkStartPositions_mm = chunkStartPositions_mm;
summary.chunkEndPositions_mm = chunkEndPositions_mm;
summary.width_px = widthPx;
summary.height_px = heightPx;
summary.pixelSize_um = cfg.pixelSize_um;
summary.lineSpacing_um = cfg.lineSpacing_um;
summary.scanLineCount = dims.scanLineCount;
summary.sourceRowByScanLine = sourceRowByScanLine;
summary.patternWidth_um = dims.patternWidth_mm * 1000;
summary.patternHeight_um = dims.patternHeight_mm * 1000;
summary.whitePixels = whitePixels;
summary.blackPixels = blackPixels;
summary.whiteSegments = whiteSegmentCount;
summary.blackSegments = blackSegmentCount;
summary.motionCommands = totalMotionCommands;
summary.rowCommandCounts = rowCommandCounts;
summary.rowWhiteSegments = rowWhiteSegments;
summary.rowBlackSegments = rowBlackSegments;
summary.estimatedMotionTime_s = estimatedMotionTime_s;
summary.config = cfg;
summary.buildWarnings = buildWarnings;

manifest = summary;
save(manifestPath, 'manifest');
writeManifestText(summary, cfg);

fprintf('Generated %d script chunk(s).\n', summary.scriptCount);
fprintf('Motion commands: %d\n', summary.motionCommands);
fprintf('Estimated motion time: %.2f s\n', summary.estimatedMotionTime_s);
fprintf('Manifest: %s\n', manifestPath);

    function writeCommandBlock(cmds)
        if isempty(cmds)
            return;
        end

        if fid >= 0 && commandsInChunk > 0 && ...
                commandsInChunk + numel(cmds) > cfg.maxMotionCommandsPerScript && ...
                numel(cmds) <= cfg.maxMotionCommandsPerScript
            closeChunk(cmds(1).startPos);
        end

        for cmdIndex = 1:numel(cmds)
            cmd = cmds(cmdIndex);
            if fid < 0
                openChunk(cmd.startPos);
            end
            if commandsInChunk >= cfg.maxMotionCommandsPerScript
                closeChunk(cmd.startPos);
                openChunk(cmd.startPos);
            end

            fprintf(fid, '%s\r\n', cmd.text);
            commandsInChunk = commandsInChunk + 1;
            commandsTimeInChunk = commandsTimeInChunk + cmd.time_s;
            totalMotionCommands = totalMotionCommands + 1;
            estimatedMotionTime_s = estimatedMotionTime_s + cmd.time_s;
        end
    end

    function openChunk(startPos)
        chunkIndex = chunkIndex + 1;
        chunkPath = fullfile(cfg.outputDir, sprintf('%s_%06d.ab', cfg.scriptPrefix, chunkIndex));
        fid = fopen(chunkPath, 'w');
        if fid < 0
            error('Could not open output script: %s', chunkPath);
        end

        if cfg.emitCoordinateModeCommand
            if strcmpi(cfg.coordinateMode, 'relative')
                emitOptionalCommand(fid, cfg.relativeModeCommand);
            else
                emitOptionalCommand(fid, cfg.absoluteModeCommand);
            end
        end
        if cfg.includePsoControl
            fprintf(fid, 'PSOOUTPUT %s CONTROL %d\r\n', cfg.psoAxis, cfg.psoOutput);
            fprintf(fid, 'PSOCONTROL %s ON\r\n', cfg.psoAxis);
        end

        scriptFiles{chunkIndex, 1} = chunkPath;
        chunkCommandCounts(chunkIndex, 1) = 0;
        chunkEstimatedTime_s(chunkIndex, 1) = 0;
        chunkStartPositions_mm(chunkIndex, :) = startPos;
        commandsInChunk = 0;
        commandsTimeInChunk = 0;
    end

    function closeChunk(endPos)
        if fid < 0
            return;
        end

        if cfg.includePsoControl
            fprintf(fid, 'PSOCONTROL %s OFF\r\n', cfg.psoAxis);
        end
        fclose(fid);
        fid = -1;

        chunkCommandCounts(chunkIndex, 1) = commandsInChunk;
        chunkEstimatedTime_s(chunkIndex, 1) = commandsTimeInChunk;
        chunkEndPositions_mm(chunkIndex, :) = endPos;

        if cfg.buildAeroBasic
            try
                ensureAerotechBuilderLoaded(cfg);
                Aerotech.AeroBasic.Builder.Build(scriptFiles{chunkIndex});
            catch buildErr
                buildWarnings{end + 1, 1} = sprintf('Build failed for %s: %s', ...
                    scriptFiles{chunkIndex}, buildErr.message);
            end
        end
        commandsInChunk = 0;
    end
end

function emitOptionalCommand(fid, commandText)
commandText = strtrim(char(commandText));
if ~isempty(commandText)
    fprintf(fid, '%s\r\n', commandText);
end
end

function cfg = fillDefaultConfig(cfg)
defaults = twoD_arbitary_printing_config();
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(cfg, names{k}) || isempty(cfg.(names{k}))
        cfg.(names{k}) = defaults.(names{k});
    end
end
end

function validateConfig(cfg)
hasMaskOverride = isfield(cfg, 'maskOverride') && ~isempty(cfg.maskOverride);
if ~hasMaskOverride && ~exist(cfg.bmpPath, 'file')
    error('BMP file not found: %s', cfg.bmpPath);
end
mustBePositiveScalar(cfg.pixelSize_um, 'pixelSize_um');
mustBePositiveScalar(cfg.lineSpacing_um, 'lineSpacing_um');
mustBePositiveScalar(cfg.writeSpeed_mm_s, 'writeSpeed_mm_s');
mustBePositiveScalar(cfg.unwrittenSpeed_mm_s, 'unwrittenSpeed_mm_s');
mustBePositiveScalar(cfg.repositionSpeed_mm_s, 'repositionSpeed_mm_s');
mustBePositiveScalar(cfg.maxMotionCommandsPerScript, 'maxMotionCommandsPerScript');
mustBeNonnegativeScalar(cfg.leadIn_um, 'leadIn_um');
mustBeNonnegativeScalar(cfg.leadOut_um, 'leadOut_um');
if cfg.includePsoControl
    validatePsoAxis(cfg.psoAxis);
    mustBeNonnegativeInteger(cfg.psoOutput, 'psoOutput');
end
if cfg.maxMotionCommandsPerScript < 10
    error('maxMotionCommandsPerScript should be at least 10.');
end
if cfg.whiteThreshold < 0 || cfg.whiteThreshold > 1
    error('whiteThreshold must be between 0 and 1.');
end
if ~any(strcmpi(cfg.coordinateMode, {'relative', 'absolute'}))
    error('coordinateMode must be ''relative'' or ''absolute''.');
end
end

function mustBePositiveScalar(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || value <= 0
    error('%s must be a positive finite scalar.', name);
end
end

function mustBeNonnegativeScalar(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || value < 0
    error('%s must be a nonnegative finite scalar.', name);
end
end

function mustBeNonnegativeInteger(value, name)
if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || value < 0 || value ~= round(value)
    error('%s must be a nonnegative integer scalar.', name);
end
end

function validatePsoAxis(psoAxis)
psoAxis = strtrim(char(psoAxis));
if isempty(regexp(psoAxis, '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
    error('psoAxis must be a single Aerotech axis name such as X.');
end
end

function prepareOutputFolders(cfg)
if exist(cfg.outputDir, 'dir')
    if ~cfg.overwriteOutput
        error('Output directory exists and overwriteOutput=false: %s', cfg.outputDir);
    end
else
    mkdir(cfg.outputDir);
end

if cfg.savePreview && ~exist(cfg.previewDir, 'dir')
    mkdir(cfg.previewDir);
end
end

function [writeMask, sourceInfo] = useMaskOverride(cfg)
% Use a caller-supplied binary write mask instead of reading the BMP. The mask
% is in image orientation (row 1 = top); flipY / invertImage are applied later
% by the caller exactly as for the BMP path.
writeMask = logical(cfg.maskOverride);

sourceInfo = struct();
sourceInfo.class = 'maskOverride';
sourceInfo.size = size(writeMask);
sourceInfo.hasColormap = false;
sourceInfo.grayMin = double(min(writeMask(:)));
sourceInfo.grayMax = double(max(writeMask(:)));
sourceInfo.uniqueGrayCount = numel(unique(writeMask(:)));
end

function [writeMask, sourceInfo] = readBmpAsWriteMask(cfg)
[raw, map] = imread(cfg.bmpPath);

if ~isempty(map)
    gray = indexedToGray(raw, map);
elseif ndims(raw) == 3
    rawDouble = double(raw);
    grayRaw = 0.2989 * rawDouble(:, :, 1) + ...
        0.5870 * rawDouble(:, :, 2) + ...
        0.1140 * rawDouble(:, :, 3);
    gray = grayRaw ./ imageClassMax(raw);
else
    gray = double(raw) ./ imageClassMax(raw);
end

gray = min(max(gray, 0), 1);
writeMask = gray >= cfg.whiteThreshold;

sourceInfo = struct();
sourceInfo.class = class(raw);
sourceInfo.size = size(raw);
sourceInfo.hasColormap = ~isempty(map);
sourceInfo.grayMin = min(gray(:));
sourceInfo.grayMax = max(gray(:));
sourceInfo.uniqueGrayCount = numel(unique(gray(:)));
end

function gray = indexedToGray(raw, map)
if isfloat(raw)
    idx = raw;
else
    idx = double(raw) + 1;
end
idx(idx < 1) = 1;
idx(idx > size(map, 1)) = size(map, 1);
rgb = map(idx(:), :);
grayVector = 0.2989 * rgb(:, 1) + 0.5870 * rgb(:, 2) + 0.1140 * rgb(:, 3);
gray = reshape(grayVector, size(raw));
end

function maxValue = imageClassMax(raw)
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

function dims = makeDims(cfg, widthPx, heightPx)
dims = struct();
dims.pixel_mm = cfg.pixelSize_um / 1000;
dims.lineSpacing_mm = cfg.lineSpacing_um / 1000;
dims.leadIn_mm = cfg.leadIn_um / 1000;
dims.leadOut_mm = cfg.leadOut_um / 1000;
dims.patternWidth_mm = widthPx * dims.pixel_mm;
dims.patternHeight_mm = heightPx * dims.pixel_mm;
dims.scanLineCount = countScanLines(dims.patternHeight_mm, dims.lineSpacing_mm);
dims.heightPx = heightPx;
dims.widthPx = widthPx;
end

function scanLineCount = countScanLines(patternHeight_mm, lineSpacing_mm)
lastIncludedY_mm = max(0, patternHeight_mm - eps(patternHeight_mm));
scanLineCount = max(1, floor(lastIncludedY_mm / lineSpacing_mm) + 1);
end

function sourceRowIndex = sourceRowForScanLine(scanLineIndex, dims)
scanLineY_mm = (scanLineIndex - 1) * dims.lineSpacing_mm;
sourceRowIndex = floor(scanLineY_mm / dims.pixel_mm) + 1;
sourceRowIndex = min(max(sourceRowIndex, 1), dims.heightPx);
end

function [cmds, endPos, stats] = buildRowCommands(rowMask, scanLineIndex, startPos, cfg, dims)
cmds = emptyCommandStruct();
currentPos = startPos;

direction = 1;
if cfg.serpentine && mod(scanLineIndex, 2) == 0
    direction = -1;
end

y = cfg.yOrigin_mm + (scanLineIndex - 1) * dims.lineSpacing_mm;
z = cfg.zPosition_mm;

if direction > 0
    lineStart = [cfg.xOrigin_mm - dims.leadIn_mm, y, z];
    patternStart = [cfg.xOrigin_mm, y, z];
    lineEnd = [cfg.xOrigin_mm + dims.patternWidth_mm + dims.leadOut_mm, y, z];
    scanRow = rowMask;
else
    lineStart = [cfg.xOrigin_mm + dims.patternWidth_mm + dims.leadIn_mm, y, z];
    patternStart = [cfg.xOrigin_mm + dims.patternWidth_mm, y, z];
    lineEnd = [cfg.xOrigin_mm - dims.leadOut_mm, y, z];
    scanRow = fliplr(rowMask);
end

[cmd, currentPos] = makeMoveCommand(currentPos, lineStart, cfg.repositionSpeed_mm_s, cfg, false);
cmds = appendCommand(cmds, cmd);

if dims.leadIn_mm > 0
    [cmd, currentPos] = makeMoveCommand(currentPos, patternStart, cfg.repositionSpeed_mm_s, cfg, false);
    cmds = appendCommand(cmds, cmd);
end

runs = encodeRuns(scanRow);
whiteSegments = 0;
blackSegments = 0;

for runIndex = 1:numel(runs)
    sEnd = runs(runIndex).endIndex * dims.pixel_mm;
    if direction > 0
        xTarget = cfg.xOrigin_mm + sEnd;
    else
        xTarget = cfg.xOrigin_mm + dims.patternWidth_mm - sEnd;
    end

    target = [xTarget, y, z];
    if runs(runIndex).isWhite
        speed = cfg.writeSpeed_mm_s;
        whiteSegments = whiteSegments + 1;
    else
        speed = cfg.unwrittenSpeed_mm_s;
        blackSegments = blackSegments + 1;
    end

    [cmd, currentPos] = makeMoveCommand(currentPos, target, speed, cfg, runs(runIndex).isWhite);
    cmds = appendCommand(cmds, cmd);
end

if dims.leadOut_mm > 0
    [cmd, currentPos] = makeMoveCommand(currentPos, lineEnd, cfg.repositionSpeed_mm_s, cfg, false);
    cmds = appendCommand(cmds, cmd);
end

endPos = currentPos;
stats = struct();
stats.whiteSegments = whiteSegments;
stats.blackSegments = blackSegments;
end

function runs = encodeRuns(scanRow)
runs = struct('isWhite', {}, 'startIndex', {}, 'endIndex', {});
if isempty(scanRow)
    return;
end

runStart = 1;
currentValue = scanRow(1);
runCount = 0;
for idx = 2:numel(scanRow)
    if scanRow(idx) ~= currentValue
        runCount = runCount + 1;
        runs(runCount).isWhite = currentValue;
        runs(runCount).startIndex = runStart;
        runs(runCount).endIndex = idx - 1;
        runStart = idx;
        currentValue = scanRow(idx);
    end
end

runCount = runCount + 1;
runs(runCount).isWhite = currentValue;
runs(runCount).startIndex = runStart;
runs(runCount).endIndex = numel(scanRow);
end

function [cmd, newPos] = makeMoveCommand(currentPos, targetPos, speed, cfg, isWhiteMove)
delta = targetPos - currentPos;
distance = sqrt(sum(delta .^ 2));
if distance < 1e-12
    cmd = [];
    newPos = currentPos;
    return;
end

if strcmpi(cfg.coordinateMode, 'relative')
    outputPos = delta;
else
    outputPos = targetPos;
end

cmd = struct();
cmd.startPos = currentPos;
cmd.endPos = targetPos;
cmd.speed = speed;
cmd.distance_mm = distance;
cmd.time_s = distance / speed;
cmd.isWhiteMove = isWhiteMove;
cmd.text = sprintf('linear X %.9f Y %.9f Z %.9f F %.6f', ...
    outputPos(1), outputPos(2), outputPos(3), speed);
newPos = targetPos;
end

function cmds = appendCommand(cmds, cmd)
if isempty(cmd)
    return;
end
if isempty(cmds)
    cmds = cmd;
else
    cmds(end + 1) = cmd;
end
end

function cmds = emptyCommandStruct()
cmds = struct('startPos', {}, 'endPos', {}, 'speed', {}, 'distance_mm', {}, ...
    'time_s', {}, 'isWhiteMove', {}, 'text', {});
end

function previewPath = savePreviewMask(writeMaskPhysical, cfg)
previewPath = fullfile(cfg.previewDir, [cfg.scriptPrefix '_physical_write_mask.png']);
imwrite(uint8(writeMaskPhysical) * 255, previewPath);
end

function writeManifestText(summary, cfg)
fid = fopen(summary.manifestTextPath, 'w');
if fid < 0
    error('Could not write manifest text file: %s', summary.manifestTextPath);
end

fprintf(fid, 'twoD BMP Aerotech toolpath manifest\r\n');
fprintf(fid, 'Source BMP: %s\r\n', summary.sourceBmp);
fprintf(fid, 'Coordinate mode: %s\r\n', summary.coordinateMode);
fprintf(fid, 'Image: %d x %d px\r\n', summary.width_px, summary.height_px);
fprintf(fid, 'BMP pixel size: %.9g um\r\n', summary.pixelSize_um);
fprintf(fid, 'Scan line spacing: %.9g um\r\n', summary.lineSpacing_um);
fprintf(fid, 'Pattern size: %.9g um x %.9g um\r\n', ...
    summary.patternWidth_um, summary.patternHeight_um);
fprintf(fid, 'Scan lines: %d\r\n', summary.scanLineCount);
fprintf(fid, 'White pixels: %d\r\n', summary.whitePixels);
fprintf(fid, 'Black pixels: %d\r\n', summary.blackPixels);
fprintf(fid, 'White segments: %d\r\n', summary.whiteSegments);
fprintf(fid, 'Black segments: %d\r\n', summary.blackSegments);
fprintf(fid, 'Motion commands: %d\r\n', summary.motionCommands);
fprintf(fid, 'Script chunks: %d\r\n', summary.scriptCount);
fprintf(fid, 'Max motion commands per script: %d\r\n', cfg.maxMotionCommandsPerScript);
fprintf(fid, 'Estimated motion time: %.3f s\r\n', summary.estimatedMotionTime_s);
fprintf(fid, '\r\nChunks:\r\n');
for k = 1:summary.scriptCount
    startPos = summary.chunkStartPositions_mm(k, :);
    endPos = summary.chunkEndPositions_mm(k, :);
    fprintf(fid, '%06d\tcommands=%d\tstart=[%.9f %.9f %.9f]\tend=[%.9f %.9f %.9f]\t%s\r\n', ...
        k, summary.chunkCommandCounts(k), ...
        startPos(1), startPos(2), startPos(3), ...
        endPos(1), endPos(2), endPos(3), ...
        summary.scriptFiles{k});
end

if ~isempty(summary.buildWarnings)
    fprintf(fid, '\r\nBuild warnings:\r\n');
    for k = 1:numel(summary.buildWarnings)
        fprintf(fid, '%s\r\n', summary.buildWarnings{k});
    end
end

fclose(fid);
end

function ensureAerotechBuilderLoaded(cfg)
persistent loaded
if ~isempty(loaded) && loaded
    return;
end
loadAerotechAssemblies(cfg.aerotechDotNetDir);
loaded = true;
end
