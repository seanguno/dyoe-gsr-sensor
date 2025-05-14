clear; clc; close all

%% ------------------------ define parameters -----------------------------
daqDevice      = "Dev1";   % change if NI board is named different
daqChan        = "ai1";    % change to whatever it is wired as on your PC
fs             = 20;       % sampling rate  (Hz)
baselineSecs   = 60;       % length of baseline recording (s)
plotWindowSecs = 30;       % width of scrolling plot window (s)
minProminence  = 0.10;     % voltage above baseline considered a peak (V)
minPeakSecs    = 1.0;      % min time between peaks (s)
saveRoot       = datestr(now,"yyyy-mm-dd_HHMMSS");  % file‑name timestamp

%% ------------------------ initalize DAQ ------------------------------
d = daq("ni");
addinput(d,daqDevice,daqChan,"Voltage");
d.Rate = fs;
% capture data in small blocks for responsive plotting:
d.NotifyWhenDataAvailableExceeds = round(fs/3);
lh = addlistener(d,"DataAvailable",@processData);
global buff timeVec filtCoeff baselineMean peakTimes peakVals
buff = [];           % live data buffer
timeVec = [];        % time stamps
peakTimes = [];      % detected peak times
peakVals  = [];      % detected peak values


%% 1. record baseline -----------------------------------------------
disp(">>>  Collecting baseline...")
[dataBL,tsBL] = read(d,seconds(baselineSecs),"OutputFormat","Matrix");
dataBL = filter(filtB,filtA,dataBL);
baselineMean = mean(dataBL);
disp(">>>  Baseline mean voltage: " + num2str(baselineMean,"%.3f") + " V")
start(d,"continuous")   % start live acquisition
disp(">>>  Real‑time acquisition started.  Press Ctrl‑C to stop.")

%% -------------------- real-time callback function --------------------------
function processData(src,evt)
    % access globals inside the callback
    global buff timeVec filtCoeff baselineMean minProminence ...
           minPeakSecs peakTimes peakVals plotWindowSecs
    
    % add new data ---------------------------------
    newV   = evt.Data;                        % raw volts
    newT   = seconds(evt.TimeStamps - evt.TimeStamps(1)); % relative time
    if isempty(timeVec)
        offset = 0;
    else
        offset = timeVec(end);
    end
    newT = newT + offset;
    
    buff    = [buff ; newV];
    timeVec = [timeVec ; newT];
    
    % adaptive baseline using moving avg of last 5 sec -----------
    win = timeVec > (timeVec(end)-5);         % 5‑sec window
    if any(win)
        baseline = mean(buff(win));
    else
        baseline = baselineMean;
    end
    detrended = newV - baseline;
    
    % detect peaks in current block -----------------------------
    [pks,locs] = findpeaks(detrended, ...
        'MinPeakProminence',minProminence, ...
        'MinPeakDistance',minPeakSecs*src.Rate);
    
    if ~isempty(pks)
        pkTime = timeVec(locs);
        % avoid duplicate peaks: only save if > minPeakSecs from last
        if isempty(peakTimes) || all(abs(pkTime - peakTimes(end)) > minPeakSecs)
            peakTimes = [peakTimes ; pkTime];
            peakVals  = [peakVals  ; pks   + baseline];
            fprintf('*** Peak detected @ %.2f s  (%.3f V)\n', pkTime, pks+baseline)
        end
    end
    
    % ------- live plotting ----------------------------------------
    persistent hPlot hBase hPeaks
    if isempty(hPlot) || ~isvalid(hPlot)
        figure('Name','Live GSR','Color','w')
        hPlot  = animatedline('Color',[0.99 0.7 0],'LineWidth',1.2);
        hBase  = animatedline('Color',[0 0.5 0.9],'LineStyle','--');
        hPeaks = animatedline('Color',[0.85 0 0],'Marker','o','LineStyle','none');
        xlabel('Time (s)'); ylabel('Voltage (V)');
        title('Real‑Time GSR'); grid on
    end
    addpoints(hPlot,newT,newV)
    addpoints(hBase,newT,baseline*ones(size(newT)))
    if ~isempty(locs)
        addpoints(hPeaks,pkTime,pks+baseline)
    end
    xlim([max(0,timeVec(end)-plotWindowSecs) , timeVec(end)])
    drawnow limitrate
end

%% -------------------- save data -----------------------------
%  press Ctrl + C to stop the loop
stop(d);
delete(lh);

%  save data
data.GSR        = buff;
data.Time_s     = timeVec;
data.PeakTimes  = peakTimes;
data.PeakVals   = peakVals;
save([saveRoot '_GSR.mat'],'data')
writematrix([timeVec buff],   [saveRoot '_GSR.csv'])
writematrix([peakTimes peakVals], [saveRoot '_peaks.csv'])

disp("Acquisition stopped  –  data saved to disk.")
