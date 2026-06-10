function AFG_Standalone(RST,Impedance,Function,Frequency,Unit,Voltage,State)
%AFG_CONFIG Summary of this function goes here
%   IMPedance = '<Num>OHM|INFinity|MINimum|MAXimum'
%   FUNction = 'SINusoid|SQUare|PULSe|RAMP|PRNoise|DC|SINC|GAUSsian|LORentz|ERISe|EDECay|HAVersine|USER[1]|USER2|USER3|USER4|EMEMory|EFILe'
%   Frequency = '<frequency>|MINimum|MAXimum'
%   Unit = 'VPP|VRMS|DBM'
%   Voltage = '<Num>'
%   State = 'ON|OFF|<NR1>'
%% Instrument Connection
AFG = visa('ni', 'USB0::0x0699::0x0340::C010200::0::INSTR');
% Connect to instrument object, obj1.
fopen(AFG);
%% Instrument Configuration and Control

% Communicating with instrument object, obj1.
% IDN=query(AFG, '*IDN?\n');
if RST==true
    fprintf(AFG,'*RST\n');
end
fprintf(AFG,'OUTPut1:IMPedance %s\n',Impedance);
fprintf(AFG,'SOURce1:FUNCtion:SHAPe %s\n',Function);
fprintf(AFG,'SOURce1:FREQuency:CW %fHz\n',Frequency); 
fprintf(AFG,'SOURce1:VOLTage:UNIT %s\n',Unit);
fprintf(AFG,'SOURce1:VOLTage:LEVel:IMMediate:AMPLitude %f\n',Voltage);
fprintf(AFG,'OUTPut1:STATe %s\n',State);

pause(2);

fclose(AFG);
end
% Impedance='INFinity';
% Function='SQUare';
% Frequency=1000;
% Unit='VRMS';
% State='ON';
% Voltage=3.7;

