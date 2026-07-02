function sessions = multiVoltage_arbitary_printing_generate(cfg)
%MULTIVOLTAGE_ARBITARY_PRINTING_GENERATE Split a multi-value BMP into per-voltage sessions.
%
% Each value in cfg.writtenValues becomes one written session (a full set of
% chunked .ab files), produced by reusing twoD_arbitary_printing_generate with a
% per-value binary mask and returnToStart enabled. A combined session index is
% written so multiVoltage_arbitary_printing_run can run them in order with a
% voltage change (manual and/or AFG) between sessions.
%
% Usage:
%   cfg = multiVoltage_arbitary_printing_config();
%   cfg.bmpPath = fullfile(pwd, 'my_3value.bmp');
%   cfg.writtenValues = [128 255];
%   cfg.voltages = [2.0 4.0];
%   sessions = multiVoltage_arbitary_printing_generate(cfg);

if nargin < 1 || isempty(cfg)
    cfg = multiVoltage_arbitary_printing_config();
end

cfg = fillDefaultConfig(cfg);
validateConfig(cfg);
prepareOutputFolders(cfg);

[gray255, sourceInfo] = readBmpGray255(cfg);

nSessions = numel(cfg.writtenValues);
sessionList = struct('index', {}, 'value', {}, 'voltage', {}, 'manifestPath', {}, ...
    'outputDir', {}, 'scriptCount', {}, 'estTime_s', {}, 'pixelCount', {});

classMap = zeros(size(gray255));   % 0 = background, i = i-th written value
for i = 1:nSessions
    v = cfg.writtenValues(i);
    mask = abs(gray255 - v) <= cfg.valueTolerance;   % image orientation
    classMap(mask & classMap == 0) = i;              % first-listed value wins ties
    pixelCount = nnz(mask);
    if pixelCount == 0
        warning('multiVoltage:EmptyValue', ...
            'Value %d has no pixels within tolerance %g; session %d will be empty.', ...
            v, cfg.valueTolerance, i);
    end

    sessCfg = makeSessionCfg(cfg, i, v, mask);
    sSummary = twoD_arbitary_printing_generate(sessCfg);

    sessionList(i).index = i;
    sessionList(i).value = v;
    sessionList(i).voltage = cfg.voltages(i);
    sessionList(i).manifestPath = sSummary.manifestPath;
    sessionList(i).outputDir = sessCfg.outputDir;
    sessionList(i).scriptCount = sSummary.scriptCount;
    sessionList(i).estTime_s = sSummary.estimatedMotionTime_s;
    sessionList(i).pixelCount = pixelCount;
end

previewPath = '';
if cfg.savePreview
    previewPath = saveClassPreview(classMap, cfg);
end

sessions = struct();
sessions.config = cfg;
sessions.bmpPath = cfg.bmpPath;
sessions.sourceInfo = sourceInfo;
sessions.sessionList = sessionList;
sessions.nSessions = nSessions;
sessions.classMap = classMap;
sessions.totalScriptCount = sum([sessionList.scriptCount]);
sessions.totalEstTime_s = sum([sessionList.estTime_s]);
sessions.previewPath = previewPath;
sessions.sessionsPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_sessions.mat']);
sessions.sessionsTextPath = fullfile(cfg.outputDir, [cfg.scriptPrefix '_sessions.txt']);
save(sessions.sessionsPath, 'sessions');
writeSessionsText(sessions);

fprintf('Multi-voltage: %d session(s), %d total chunk(s), est %.1f s total.\n', ...
    nSessions, sessions.totalScriptCount, sessions.totalEstTime_s);
for i = 1:nSessions
    fprintf('  session %d: value %d -> %.4g V, %d px, %d chunk(s), est %.1f s\n', ...
        i, sessionList(i).value, sessionList(i).voltage, sessionList(i).pixelCount, ...
        sessionList(i).scriptCount, sessionList(i).estTime_s);
end
fprintf('Sessions index: %s\n', sessions.sessionsPath);
end

function cfg = fillDefaultConfig(cfg)
defaults = multiVoltage_arbitary_printing_config();
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(cfg, names{k}) || isempty(cfg.(names{k}))
        cfg.(names{k}) = defaults.(names{k});
    end
end
end

function validateConfig(cfg)
if ~exist(cfg.bmpPath, 'file')
    error('BMP file not found: %s', cfg.bmpPath);
end
if isempty(cfg.writtenValues) || ~isnumeric(cfg.writtenValues)
    error('writtenValues must be a non-empty numeric vector of gray levels.');
end
if any(~isfinite(cfg.writtenValues)) || any(cfg.writtenValues < 0) || any(cfg.writtenValues > 255)
    error('writtenValues must be finite gray levels on a 0-255 scale.');
end
if numel(cfg.voltages) ~= numel(cfg.writtenValues)
    error('voltages must have the same length as writtenValues (%d).', numel(cfg.writtenValues));
end
if ~isnumeric(cfg.voltages) || any(~isfinite(cfg.voltages))
    error('voltages must be finite numbers.');
end
if ~isscalar(cfg.valueTolerance) || cfg.valueTolerance < 0
    error('valueTolerance must be a nonnegative scalar.');
end
if numel(unique(cfg.writtenValues)) ~= numel(cfg.writtenValues)
    error('writtenValues must be distinct.');
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

function sc = makeSessionCfg(cfg, i, v, mask)
% Build a twoD_arbitary_printing config for one session, reusing the 2D engine
% via maskOverride + returnToStart.
sc = twoD_arbitary_printing_config();
sc.bmpPath = cfg.bmpPath;   % not read (maskOverride present), kept for the record
sc.outputDir = fullfile(cfg.outputDir, sprintf('session%d_v%d', i, v));
sc.previewDir = cfg.previewDir;
sc.scriptPrefix = sprintf('%s_s%d_v%d', cfg.scriptPrefix, i, v);
sc.pixelSize_um = cfg.pixelSize_um;
sc.lineSpacing_um = cfg.lineSpacing_um;
sc.xOrigin_mm = cfg.xOrigin_mm;
sc.yOrigin_mm = cfg.yOrigin_mm;
sc.zPosition_mm = cfg.zPosition_mm;
sc.leadIn_um = cfg.leadIn_um;
sc.leadOut_um = cfg.leadOut_um;
sc.writeSpeed_mm_s = cfg.writeSpeed_mm_s;
sc.unwrittenSpeed_mm_s = cfg.unwrittenSpeed_mm_s;
sc.repositionSpeed_mm_s = cfg.repositionSpeed_mm_s;
sc.serpentine = cfg.serpentine;
sc.flipY = cfg.flipY;
sc.invertImage = false;
sc.whiteThreshold = cfg.whiteThreshold;
sc.coordinateMode = cfg.coordinateMode;
sc.emitCoordinateModeCommand = cfg.emitCoordinateModeCommand;
sc.relativeModeCommand = cfg.relativeModeCommand;
sc.absoluteModeCommand = cfg.absoluteModeCommand;
sc.includePsoControl = cfg.includePsoControl;
sc.psoAxis = cfg.psoAxis;
sc.psoOutput = cfg.psoOutput;
sc.maxMotionCommandsPerScript = cfg.maxMotionCommandsPerScript;
sc.buildAeroBasic = cfg.buildAeroBasic;
sc.aerotechDotNetDir = cfg.aerotechDotNetDir;
sc.savePreview = false;
sc.overwriteOutput = cfg.overwriteOutput;
sc.requireRunConfirmation = cfg.requireRunConfirmation;
sc.maskOverride = mask;
sc.returnToStart = cfg.returnToStartEachSession;
end

function [gray255, sourceInfo] = readBmpGray255(cfg)
[raw, map] = imread(cfg.bmpPath);
if ~isempty(map)
    gray = indexedToGray(raw, map);
elseif ndims(raw) == 3
    rd = double(raw);
    gray = (0.2989 * rd(:, :, 1) + 0.5870 * rd(:, :, 2) + 0.1140 * rd(:, :, 3)) ./ imageClassMax(raw);
else
    gray = double(raw) ./ imageClassMax(raw);
end
gray = min(max(gray, 0), 1);
gray255 = gray * 255;

sourceInfo = struct();
sourceInfo.class = class(raw);
sourceInfo.size = size(raw);
sourceInfo.hasColormap = ~isempty(map);
sourceInfo.uniqueValues = unique(round(gray255(:)))';
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
    if maxValue <= 1
        maxValue = 1;
    end
end
end

function previewPath = saveClassPreview(classMap, cfg)
previewPath = fullfile(cfg.previewDir, [cfg.scriptPrefix '_class_map.png']);
n = max([classMap(:); 0]);
pal = classPalette(n);
[H, W] = size(classMap);
rgb = repmat(reshape([0.85 0.85 0.85], 1, 1, 3), H, W);   % background = light gray
for i = 1:n
    m = classMap == i;
    for c = 1:3
        ch = rgb(:, :, c);
        ch(m) = pal(i, c);
        rgb(:, :, c) = ch;
    end
end
if cfg.flipY
    rgb = flipud(rgb);   % physical bottom at the bottom, matching the write mask
end
imwrite(rgb, previewPath);
end

function pal = classPalette(n)
base = [0.20 0.45 0.90; 0.90 0.30 0.20; 0.20 0.70 0.35; 0.85 0.65 0.10; ...
    0.55 0.30 0.75; 0.20 0.75 0.80];
if n <= size(base, 1)
    pal = base(1:max(n, 1), :);
else
    pal = base(mod(0:n - 1, size(base, 1)) + 1, :);
end
end

function writeSessionsText(sessions)
fid = fopen(sessions.sessionsTextPath, 'w');
if fid < 0
    error('Could not write sessions text file: %s', sessions.sessionsTextPath);
end
cfg = sessions.config;
fprintf(fid, 'Multi-voltage 2D DLW session index\r\n');
fprintf(fid, 'Source BMP: %s\r\n', sessions.bmpPath);
fprintf(fid, 'Sessions: %d   Total chunks: %d   Total est time: %.3f s\r\n', ...
    sessions.nSessions, sessions.totalScriptCount, sessions.totalEstTime_s);
fprintf(fid, 'Value tolerance: +/- %g (0-255)\r\n', cfg.valueTolerance);
fprintf(fid, 'Return to start each session: %d\r\n', cfg.returnToStartEachSession);
fprintf(fid, 'AFG auto-set: %d  (%s, %g Hz, %s)\r\n', cfg.useAFG, ...
    cfg.afgFunction, cfg.afgFrequency_Hz, cfg.afgUnit);
fprintf(fid, '\r\nSessions (write order):\r\n');
for i = 1:sessions.nSessions
    s = sessions.sessionList(i);
    fprintf(fid, '%d\tvalue=%d\tvoltage=%.4g\tpixels=%d\tchunks=%d\test=%.3fs\t%s\r\n', ...
        s.index, s.value, s.voltage, s.pixelCount, s.scriptCount, s.estTime_s, s.manifestPath);
end
fclose(fid);
end
