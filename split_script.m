function [t_total,t_total_line] = split_script()
%SPLIT_SCRIPT Summary of this function goes here
%   Detailed explanation goes here
loadAerotechAssemblies();

fid=fopen('6_Zhiyu 8_Block_D1_XT_1.00_YT_0.00_B_0.00.txt');
k=0;
i=0;
t_total=0;
tline=fgetl(fid);
while ischar(tline)
    sub_fid=fopen(['.\Split_Script\' num2str(k) '.ab'],'w');
    fprintf(sub_fid,'%s\r\n','PSOOUTPUT X CONTROL 2');
    fprintf(sub_fid,'%s\r\n','PSOCONTROL X ON');
    t_total_line(k+1)=0;
    while ischar(tline)
        [A,~]=sscanf(tline,'linear X %f Y %f Z %f F %f');
        t(i+1)=abs(A(1))/A(4)+abs(A(2))/A(4)+abs(A(3))/A(4);
        t_total_line(k+1)=t_total_line(k+1)+t(i+1);
        if (A(1)<0 && A(2)<0)
            break;
        end
        fprintf(sub_fid,'%s\r\n',tline);
        tline = fgetl(fid);
        i=i+1;
    end
    fprintf(sub_fid,'%s\r\n','PSOCONTROL X OFF');
    if ischar(tline)
        fprintf(sub_fid,'%s\r\n',tline);
    end
    tline = fgetl(fid);
    i=i+1;
    t_total=t_total+t_total_line(k+1);
    fclose(sub_fid);
    Aerotech.AeroBasic.Builder.Build([pwd '.\Split_Script\' num2str(k) '.ab']);
    k=k+1;
end
fclose(fid);
% movefile('.\Split_Script\*.bcx', '.\Split_Script_Run');
% movefile('.\Split_Script\*.bco', '.\Split_Script_Run');
end

