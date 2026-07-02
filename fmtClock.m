function s = fmtClock(dt)
%FMTCLOCK Format a datetime as an HH:mm clock string ('--' if unset/NaT).
if isempty(dt) || ~isdatetime(dt) || any(isnat(dt))
    s = '--';
    return;
end
s = char(datetime(dt, 'Format', 'HH:mm'));
end
