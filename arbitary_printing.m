function arbitary_printing()
%ARBITARY_PRINTING Integrated UI for DLW toolpath generation.
%
% One window with three mode tabs, each hosting the full standalone tool:
%   - 2D Binary Write      -> twoD_arbitary_printing
%   - 3D Curvature Write   -> threeD_arbitary_printing
%   - 2D Multi-Voltage     -> multiVoltage_arbitary_printing
%
% Run from MATLAB:
%   arbitary_printing
%
% Each tab is independent (its own settings, preview, and run state); only one
% hardware run can be active at a time. The individual tools can still be opened
% as separate windows by calling their functions with no arguments.

fig = uifigure('Name', 'Arbitrary Printing - DLW Toolpaths', 'Position', [40 40 1400 900]);

layout = uigridlayout(fig, [1 1]);
layout.Padding = [6 6 6 6];

tabs = uitabgroup(layout);

binaryTab = uitab(tabs, 'Title', '2D Binary Write');
curvatureTab = uitab(tabs, 'Title', '3D Curvature Write');
multiTab = uitab(tabs, 'Title', '2D Multi-Voltage Write');

twoD_arbitary_printing(binaryTab);
threeD_arbitary_printing(curvatureTab);
multiVoltage_arbitary_printing(multiTab);
end
