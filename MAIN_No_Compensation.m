%% Clear unclosed camera
if exist('Thorlabs_Camera')
    Thorlabs_Camera.Exit();
end

%% Include .Net Library
loadAerotechAssemblies();
NET.addAssembly([pwd '\DCx_Camera_Support_DotNet\uc480DotNet.dll']);

%% Clear the workspace
close all;
clear;

%% Instrument Constant
CAM_Exposure = 81.66; % exposure in ms 81.66
CAM_Gain = 350; % max is 891 for DCx camera 350

% Ref in ITO
% X_Position = -7.600000;
% Y_Position = -12.000000;
% Z_Position = -0.710000;

% Ref in non ITO
% X_Position = -16.140000;
% Y_Position = -13.55000;
% Z_Position = -0.623500;
X_Position = -10.370000;
Y_Position = -12.000000;
Z_Position = -0.680000;

STANDARD_POINTS=51;
% STANDARD_POINTS=101;
% SAMPLE_POINTS=31;

%K=[Kp Ki Kd]
% K=[0.01,0.9,0.001];
K=[0.0005,0.9,0.001];

X_REF_TO_ORIGIN=0.000000;
Y_REF_TO_ORIGIN=0.000000; 
Z_REF_TO_ORIGIN=0.000000;%-0.728

IMAGE_SIZE=130;

com_period=200;

SPEED=10;


%% Instrument Initialization
% Initialize Camera
% [Thorlabs_Camera, MemId, Width, Height, Bits]=Thorlabs_Camera_Initialize(CAM_Exposure,CAM_Gain);
% Initialize Stage
[Aerotech_Controller,X_Axis,Y_Axis,Z_Axis] = Aerotech_Initialize();
% Set Stage Position
[X_Ref_Base,Y_Ref_Base,Z_Ref_Base]=STAGE_Move_Position(Aerotech_Controller,X_Axis,Y_Axis,Z_Axis,X_Position,Y_Position,Z_Position);

%% Wait for finding the reference pattern manually
command_string='';
while (~(strcmp(command_string,'y')||strcmp(command_string,'Y')))
    command_string=input('Enter [y/Y] when the reference pattern is captured. [y/N]\n','s');
end
clear command_string;

%% Select Crop Area
% [Data,Img_Crop,rect] = Image_Crop(Thorlabs_Camera, MemId, Width, Height, Bits);
% imwrite(Data, [pwd '\Standard_Capture' '\Initial.png']);
% imwrite(Img_Crop, [pwd '\Standard_Capture' '\Initial_crop.png']);
% fprintf('Cropped Area Selected.\n')
% close all;
% clc

%% Sample the standard values
% fprintf('Standard Measurement Start\n');
% tic;
% [FM_CONT_STANDARD_MAIN,x_MAIN,HIST_MAIN_R,HIST_MAIN_G,HIST_MAIN_B] = Z_Axis_Scan_Standard(STANDARD_POINTS,0.2*10^(-6),1*10^(6),1*10^(3),X_Axis,Y_Axis,Z_Axis,Aerotech_Controller,Thorlabs_Camera,[X_Ref_Base,Y_Ref_Base,Z_Ref_Base],0, MemId, Width, Height, Bits, rect);
% time=toc;
% fprintf('Standard Measurement Time=%.1fs\n',time);

%% Plot the standard values for check
% figure(1);
% hold on;
% grid on;
% box on;
% title('Contrast with sliding-neighborhood operations vs Deviation','Interpreter','latex','FontSize',25)
% xlabel('Deviation/$um$','Interpreter','latex','FontSize',25);
% ylabel('Contrast','Interpreter','latex','FontSize',25);
% xlim([min(x_MAIN) max(x_MAIN)]);
% xticks(min(x_MAIN):1:max(x_MAIN));
% plot(x_MAIN,FM_CONT_STANDARD_MAIN,'Marker','.','MarkerSize',12,'MarkerEdgeColor','red','LineStyle','none');
% plot(x_MAIN,FM_CONT_STANDARD_MAIN,'LineWidth',1);
% set(gcf, 'Position', get(0, 'Screensize'));
% PATH='Standard_Values';
% if ~exist(PATH,'dir')
%     mkdir(PATH);
% end
% savefig([pwd '\' PATH '\Contrast_' datestr(now,'yyyymmddHHMMSS') '.fig']);
% save([pwd '\' PATH '\Results_' datestr(now,'yyyymmddHHMMSS') '.mat'],'FM_CONT_STANDARD_MAIN','x_MAIN');
% fprintf('Standard_Completed.\n');

%% Wait for checking the position of the plot
command_string='';
while (~(strcmp(command_string,'y')||strcmp(command_string,'Y')))
    if (strcmp(command_string,'n')||strcmp(command_string,'N'))
        % If the result is not satisfying, quit the progarm
        error('Adjust the center position.')
    end
    command_string=input('Enter [y/Y] when the reference position is satisfying. [n/N] to exit. [y/N]\n','s');
end
clear command_string;
close all;

[X_Ref_Pos(1),Y_Ref_Pos(1),Z_Ref_Pos(1)] = STAGE_Position_Read(Aerotech_Controller);
% [Z_Current,Log,X_NEW,Y_NEW,Z_NEW] = Compensation(Aerotech_Controller,FM_CONT_STANDARD_MAIN,x_MAIN,HIST_MAIN_R,HIST_MAIN_G,HIST_MAIN_B,K,Thorlabs_Camera, MemId, Width, Height, Bits, rect);

% run('Check.m');

%% Split the Control Script
log_path=['.\Log\log_' datestr(now,'yyyymmddHHMMSS') '.txt'];
% [T_Total,T_Line] = split_script();
diary(log_path)
diary on

%% Move to the starting point
STAGE_Move_Relative(X_Axis,Y_Axis,Z_Axis,X_REF_TO_ORIGIN,Y_REF_TO_ORIGIN,Z_REF_TO_ORIGIN,SPEED);

pause(0.5);

task=Aerotech_Controller.Tasks.Item(Aerotech.Ensemble.TaskId.T01);
% index=(size(FM_CONT_STANDARD_MAIN,1)+1)/2;
for i=0:1:(IMAGE_SIZE-1)    
    tic
    fprintf('Line %2.0d.\t----\t',i+1);
    %task.Program.Run([pwd '\Split_Script_Run\' num2str(i) '.bco']);
    pause(0.5);
    task.Program.Run([pwd '\Split_Script\' num2str(i) '.ab']);
    while (task.State.string~='ProgramComplete')
    end   
    if mod((i+1),com_period)==0
%         [X_Current,Y_Current,Z_Current] = STAGE_Position_Read(Aerotech_Controller);
%         dx=X_Ref_Pos((i+1)/com_period)-X_Current;
%         dy=Y_Ref_Pos((i+1)/com_period)-Y_Current;
%         dz=Z_Ref_Pos((i+1)/com_period)-Z_Current;
%         STAGE_Move_Relative(X_Axis,Y_Axis,Z_Axis,dx,dy,dz,2);
        pause(1);
%         [Z_Reading{(i+1)/com_period},Log{(i+1)/com_period},X_Ref_Pos((i+com_period+1)/com_period),Y_Ref_Pos((i+com_period+1)/com_period),Z_Ref_Pos((i+com_period+1)/com_period)] = Compensation(Aerotech_Controller,FM_CONT_STANDARD_MAIN,x_MAIN,index,HIST_MAIN_R,HIST_MAIN_G,HIST_MAIN_B,K,Z_Axis,Thorlabs_Camera, MemId, Width, Height, Bits, rect);   
%         fprintf('Compensated Z postion: %.6f\tExp. Contrast:%.4f\tActual Contrast:%.4f\t----\t',Z_Reading{(i+1)/com_period}(end),FM_CONT_STANDARD_MAIN(index), Log{(i+1)/com_period}(end));
%         STAGE_Move_Relative(X_Axis,Y_Axis,Z_Axis,-dx,-dy,-dz,2);
    end  
    TT(i+1)=toc;
    fprintf('Line %2.0d Complete in %fs.\n',i+1,TT(i+1));
end
PATH='Results';
% save([pwd '\' PATH '\Compensation_' datestr(now,'yyyymmddHHMMSS') '.mat'],'FM_CONT_STANDARD_MAIN','K','Log','STANDARD_POINTS','TT','time','X_Ref_Pos','Y_Ref_Pos','Z_Ref_Pos','Z_Reading','X_Ref_Base','Y_Ref_Base','Z_Ref_Base');
save([pwd '\' PATH '\Compensation_' datestr(now,'yyyymmddHHMMSS') '.mat'],'TT','X_Ref_Pos','Y_Ref_Pos','Z_Ref_Pos','X_Ref_Base','Y_Ref_Base','Z_Ref_Base');
% Thorlabs_Camera.Exit();
diary off

% run('result_Illu.m');
%% move the log and move the result.
