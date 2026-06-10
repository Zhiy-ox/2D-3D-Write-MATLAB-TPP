function [Aerotech_Controller,X_Axis,Y_Axis,Z_Axis] = Aerotech_Initialize(aerotechDotNetDir)
%AEROTECH_INITIALIZE Summary of this function goes here
%   Detailed explanation goes here
% Connect to the device
if nargin < 1
    aerotechDotNetDir = [];
end
loadAerotechAssemblies(aerotechDotNetDir);

% Connect to the controller
Aerotech.Ensemble.Controller.Connect();
Aerotech_Controller=Aerotech.Ensemble.Controller.ConnectedControllers.Item(0);

% XYZ Axis Initialization
X_Axis=Aerotech_Controller.Commands.Axes.Item(0);
Y_Axis=Aerotech_Controller.Commands.Axes.Item(1);
Z_Axis=Aerotech_Controller.Commands.Axes.Item(2);

% Enable XYZ Axis
X_Axis.Motion.Enable();
Y_Axis.Motion.Enable();
Z_Axis.Motion.Enable();

end

