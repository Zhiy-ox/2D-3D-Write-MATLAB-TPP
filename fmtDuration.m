function s = fmtDuration(seconds_in)
%FMTDURATION Format a duration in seconds as HH:MM:SS ('--' if unknown/NaN).
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
