function configureProgressBar(ax)
%CONFIGUREPROGRESSBAR Style a uiaxes as a thin horizontal progress-bar track.
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
