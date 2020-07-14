function [deviceSettingsOut,stimStatus,stimState]  = loadSenseStimSettings(fn)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% reads device settings file (deviceSettings.json) and parses out all relevant device settings data from a session
% Arguments
% input arg: path to deviceSettings.json
% output args:
%   deviceSettingsOut
%   stimStatus
%   stimRate
%__________________________________________________________________________
% History
% origin(master): https://github.com/roeegilron/rcsanalysis/blob/master/matlab/loadDeviceSettingsForMontage.m
% dev_version1(branch): https://github.com/roeegilron/rcsanalysis/blob/rcsanalysis_ja/matlab/loadDeviceSettingsForMontage.m
% dev_version2(branch): https://github.com/starrlab/rcsviz/blob/rcsviz_ja/code/toolboxes/gettersLoadersSettings/loadSenseStimSettings.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% check and fix json malformations in case needed
DeviceSettings = jsondecode(fixMalformedJson(fileread(fn),'DeviceSettings'));

% fix issues with device settings sometiems being a cell array and sometimes not 
if isstruct(DeviceSettings)
    DeviceSettings = {DeviceSettings};
end

%% print raw device settings strucutre
% ## uncomment this for code dev ##
% for f = 1:length(DeviceSettings)
%     curStr = DeviceSettings{f};
%     fieldnames1 = fieldnames(curStr); 
%     fprintf('[%0.3d]\n',f);
%     for f1 = 1:length(fieldnames1)
%        fprintf('\t%s\n',fieldnames1{f1});
%        curStr2 = curStr.(fieldnames1{f1});
%        if isstruct(curStr2)
%            fieldnames2 = fieldnames(curStr2);
%            for f2 = 1:length(fieldnames2)
%                fprintf('\t\t%s\n',fieldnames2{f2});
%            end
%        end
%     end
%     fprintf('\n');
% end

%% 
deviceSettingTable = table();
recNum = 1; 
f = 1;
strCnt = 1; 
strmStopCnt = 1; 
senseStopCnt = 1; 
instream = 0;
while f <= length(DeviceSettings)
    fnms = fieldnames(DeviceSettings{f});
    curStr = DeviceSettings{f};
    if isfield(curStr,'SensingConfig')
        if isfield(curStr.SensingConfig,'timeDomainChannels')
            tdData = translateTimeDomainChannelsStruct(curStr.SensingConfig.timeDomainChannels);
            timenum = curStr.RecordInfo.HostUnixTime;
            t = datetime(timenum/1000,'ConvertFrom','posixTime','TimeZone','America/Los_Angeles','Format','dd-MMM-yyyy HH:mm:ss.SSS'); 
            outRec(recNum).timeStart = t;
            outRec(recNum).unixtimeStart  = timenum;
            outRec(recNum).tdData = tdData;
            deviceSettingTable.action{recNum} = 'sense config';
            deviceSettingTable.recNum(recNum) = NaN;
            deviceSettingTable.timeStart{recNum} = t;
            for c = 1:4
                fnuse = sprintf('chan%d',c);
                deviceSettingTable.(fnuse){recNum} = tdData(c).chanFullStr;
            end
            deviceSettingTable.tdDataStruc{recNum} = tdData;
            recNum = recNum + 1;
        end
    end
    % check if streaming started 
    if isfield(curStr,'StreamState')
        if curStr.StreamState.TimeDomainStreamEnabled
            if ~instream % if not instream then streaming is starting 
                timenum = curStr.RecordInfo.HostUnixTime;
                t = datetime(timenum/1000,'ConvertFrom','posixTime','TimeZone','America/Los_Angeles','Format','dd-MMM-yyyy HH:mm:ss.SSS');
                actionuse = sprintf('stream start %d',strCnt);
                deviceSettingTable.action{recNum} = actionuse;
                deviceSettingTable.recNum(recNum) = strCnt;
                deviceSettingTable.timeStart{recNum} = t;
                for c = 1:4
                    fnuse = sprintf('chan%d',c);
                    deviceSettingTable.(fnuse){recNum} = tdData(c).chanFullStr;
                end
                deviceSettingTable.tdDataStruc{recNum} = tdData;
                strCnt = strCnt + 1;
                recNum = recNum + 1;
                instream = 1;
            end
        end 
    end
    % check if streaming stopped - 
    % it can either be stopped by turning streaming off (MOST LOGICAL1)
    % or it can be stopped by turning sensing off (DO WE EVER TURN SENSE OFF???, ask Randy/Roee)
    % option 1 - stream has been turned off ()
    if isfield(curStr,'StreamState')
        if instream % streaming is happening detect it's stop
            if ~curStr.StreamState.TimeDomainStreamEnabled
                timenum = curStr.RecordInfo.HostUnixTime;
                t = datetime(timenum/1000,'ConvertFrom','posixTime','TimeZone','America/Los_Angeles','Format','dd-MMM-yyyy HH:mm:ss.SSS');
                actionuse = sprintf('stop stream %d',strmStopCnt);
                deviceSettingTable.action{recNum} = actionuse;
                deviceSettingTable.recNum(recNum) = strmStopCnt;
                deviceSettingTable.timeStart{recNum} = t;
                for c = 1:4
                    fnuse = sprintf('chan%d',c);
                    deviceSettingTable.(fnuse){recNum} = tdData(c).chanFullStr;
                end
                deviceSettingTable.tdDataStruc{recNum} = tdData;
                instream = 0;
                strmStopCnt = strmStopCnt + 1;
                recNum = recNum + 1;
            end
        end
    end
    % option 2 sense has been turned off
    if isfield(curStr,'SenseState')
        if instream % streaming is happening detect it's stop
            if isfield(curStr.SenseState,'state')
                sensestat = dec2bin(curStr.SenseState.state,4);
                % blow is assuming we only care about time domain streaming
                % starting / stopping, see:
                % enum
                % Medtronic.NeuroStim.Olympus.DataTypes.Sensing.SenseStates : byte
                % for details re what the binary number means
                if strcmp(sensestat(4),'0') % time domain off
                    timenum = curStr.RecordInfo.HostUnixTime;
                    t = datetime(timenum/1000,'ConvertFrom','posixTime','TimeZone','America/Los_Angeles','Format','dd-MMM-yyyy HH:mm:ss.SSS');
                    actionuse = sprintf('stop sense %d',senseStopCnt);
                    deviceSettingTable.action{recNum} = actionuse;
                    deviceSettingTable.recNum(recNum) = senseStopCnt;
                    deviceSettingTable.timeStart{recNum} = t;
                    for c = 1:4
                        fnuse = sprintf('chan%d',c);
                        deviceSettingTable.(fnuse){recNum} = tdData(c).chanFullStr;
                    end
                    deviceSettingTable.tdDataStruc{recNum} = tdData;
                    instream = 0;
                    senseStopCnt = senseStopCnt + 1;
                    recNum = recNum + 1;
                end
            end
        end
    end
    f = f+1;
end
% loop on deviceSettigs and extract the start and stop time for each
% recording in the file.
deviceSettingsOut = table(); 
idxnotnan = ~isnan(deviceSettingTable.recNum);
unqRecs = unique(deviceSettingTable.recNum(idxnotnan)); 
for u = 1:length(unqRecs)
    idxuse = deviceSettingTable.recNum == unqRecs(u);
    dt = deviceSettingTable(idxuse,:);
    if size(dt,1) == 1 % this means that stream didn't stop properly
    else
        deviceSettingsOut.recNum(u) = unqRecs(u);
        deviceSettingsOut.timeStart(u) = dt.timeStart{1};
        deviceSettingsOut.timeStop(u) = dt.timeStart{2};
        deviceSettingsOut.duration(u) = deviceSettingsOut.timeStop(u) - deviceSettingsOut.timeStart(u);
        for c = 1:4 % find sample rate
            if ~strcmp(dt.tdDataStruc{1}(c).sampleRate,'disabled')
                deviceSettingsOut.samplingRate(u) = str2num(dt.tdDataStruc{1}(c).sampleRate(1:end-2));
            end
        end
        for c = 1:4
            fnuse = sprintf('chan%d',c);
            deviceSettingsOut.(fnuse){u} = dt.(fnuse){1};
        end
        deviceSettingsOut.TimeDomainDataStruc{u} = dt.tdDataStruc{1};
    end
end

%% load stimulation config
% this code (re stim sweep part) assumes no change in stimulation from initial states
% this code will fail for stim sweeps or if any changes were made to
% stimilation 
% need to fix this to include stim changes and when the occured to color
% data properly according to stim changes and when the took place for in
% clinic testing 

if isstruct(DeviceSettings)
    DeviceSettings = {DeviceSettings};
end
therapyStatus = DeviceSettings{1}.GeneralData.therapyStatusData;
groups = [ 0 1 2 3]; 
groupNames = {'A','B','C','D'}; 
stimState = table(); 
cnt = 1; 
for g = 1:length(groups) 
    fn = sprintf('TherapyConfigGroup%d',groups(g));
    for p = 1:4
        if DeviceSettings{1}.TherapyConfigGroup0.programs(p).isEnabled==0
            stimState.group(cnt) = groupNames{g};
            if (g-1) == therapyStatus.activeGroup
                stimState.activeGroup(cnt) = 1;
                if therapyStatus.therapyStatus
                    stimState.stimulation_on(cnt) = 1;
                else
                    stimState.stimulation_on(cnt) = 0;
                end
            else
                stimState.activeGroup(cnt) = 0;
                stimState.stimulation_on(cnt) = 0;
            end
            
            stimState.program(cnt) = p;
            stimState.pulseWidth_mcrSec(cnt) = DeviceSettings{1}.(fn).programs(p).pulseWidthInMicroseconds;
            stimState.amplitude_mA(cnt) = DeviceSettings{1}.(fn).programs(p).amplitudeInMilliamps;
            stimState.rate_Hz(cnt) = DeviceSettings{1}.(fn).rateInHz;
            elecs = DeviceSettings{1}.(fn).programs(p).electrodes.electrodes;
            elecStr = ''; 
            for e = 1:length(elecs)
                if elecs(e).isOff == 0 % electrode active 
                    if e == 17
                        elecUse = 'c'; 
                    else
                        elecUse = num2str(e-1);
                    end
                    if elecs(e).electrodeType==1 % anode 
                        elecSign = '-';
                    else
                        elecSign = '+';
                    end
                    elecSnippet = [elecSign elecUse ' '];
                    elecStr = [elecStr elecSnippet];
                end
            end

            stimState.electrodes{cnt} = elecStr; 
            cnt = cnt + 1; 
        end
    end
end 
if ~isempty(stimState)
    stimStatus = stimState(logical(stimState.activeGroup),:);
else
    stimStatus = [];
end

end

function outstruc = translateTimeDomainChannelsStruct(tdDat)
%% assume no bridging
outstruc = tdDat;
for f = 1:length(outstruc)
    % lpf 1 (front end)
    switch tdDat(f).lpf1
        case 9
            outstruc(f).lpf1 = '450Hz';
        case 18
            outstruc(f).lpf1 = '100Hz';
        case 36
            outstruc(f).lpf1 = '50Hz';
        otherwise
            outstruc(f).lpf1 = 'unexpected';
    end
    % lpf 2 (bacnk end amplifier)
    switch tdDat(f).lpf2
        case 9
            outstruc(f).lpf2 = '100Hz';
        case 11
            outstruc(f).lpf2 = '160Hz';
        case 12
            outstruc(f).lpf2 = '350Hz';
        case 14
            outstruc(f).lpf2 = '1700Hz';
        otherwise
            outstruc(f).lpf2 = 'unexpected';
    end
    % channels - minus input
    switch tdDat(f).minusInput
        case 0
            outstruc(f).minusInput = 'floating';
        case 1
            outstruc(f).minusInput = '0';
        case 2
            outstruc(f).minusInput = '1';
        case 4
            outstruc(f).minusInput = '2';
        case 8
            outstruc(f).minusInput = '3';
        case 16
            outstruc(f).minusInput = '4';
        case 32
            outstruc(f).minusInput = '5';
        case 64
            outstruc(f).minusInput = '6';
        case 128
            outstruc(f).minusInput = '7';
        otherwise
            outstruc(f).minusInput = 'unexpected';
    end
    if ~strcmp(outstruc(f).minusInput,'floating') & ~strcmp(outstruc(f).minusInput,'unexpected')
        if f > 2 % asssumes there is no bridging 
            outstruc(f).minusInput = num2str( str2num(outstruc(f).minusInput)+8);
        end
    end
    % channels - plus input
      switch tdDat(f).plusInput
        case 0
            outstruc(f).plusInput = 'floating';
        case 1
            outstruc(f).plusInput = '0';
        case 2
            outstruc(f).plusInput = '1';
        case 4
            outstruc(f).plusInput = '2';
        case 8
            outstruc(f).plusInput = '3';
        case 16
            outstruc(f).plusInput = '4';
        case 32
            outstruc(f).plusInput = '5';
        case 64
            outstruc(f).plusInput = '6';
        case 128
            outstruc(f).plusInput = '7';
        otherwise
            outstruc(f).plusInput = 'unexpected';
      end
      if ~strcmp(outstruc(f).plusInput,'floating') & ~strcmp(outstruc(f).plusInput,'unexpected')
          if f > 2 % asssumes there is no bridging
              outstruc(f).plusInput = num2str( str2num(outstruc(f).plusInput)+8);
          end
      end
    % sample rate 
    switch tdDat(f).sampleRate
        case 0
            outstruc(f).sampleRate = '250Hz';
        case 1
            outstruc(f).sampleRate = '500Hz';
        case 2 
            outstruc(f).sampleRate = '1000Hz';
        case 240
            outstruc(f).sampleRate = 'disabled';     
        otherwise
            outstruc(f).plusInput = 'unexpected';
    end
    outstruc(f).chanOut = sprintf('+%s-%s',...
        outstruc(f).plusInput,outstruc(f).minusInput);
    outstruc(f).chanFullStr = sprintf('%s lpf1-%s lpf2-%s sr-%s',...
        outstruc(f).chanOut,...
        outstruc(f).lpf1,outstruc(f).lpf2,outstruc(f).sampleRate);
end
end