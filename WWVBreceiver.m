%Code for Receiver of WWVB signal
%   Input is sine_data of a random starting point
%   Output is a digital signal

fc = 40;    %carrier frequency
samplesPerCycle = 32;
samplesPerSecond = fc*samplesPerCycle;
samplesPerMinute = samplesPerSecond*60;
numSamples = samplesPerMinute*numMinutes;
for sigma = 1:.5:10
    %Cut off rand num of signals
    signal = sine_data(1,randi([0, samplesPerMinute-1], 1):end);
    [~, col] = size(signal);
    signal = signal + normrnd(0,sigma,1,col);
    t = 1:col; %Get number of samples

    figure(2)
    plot(t/samplesPerSecond,signal)
    title('Received time signal (cut off)')
    xlabel('Seconds')

    %Input waveform is in the form of sin(2*pi*fc*t + phi)
    %Multiply waveform by sin(2*pi*fc*t) and cos(2*pi*fc*t)
    signalCos = signal .* cos(2*pi*fc * t/samplesPerSecond);
    signalSin = signal .* sin(2*pi*fc * t/samplesPerSecond);

    %DECODE DATA
    %One bit = one second = 40*16 samples (fc*samplesPerCycle/2) (double freq
    %term)

    newSamplesPerCycle = 16;

    %Decode the signalSin function
    avgs_sin = zeros(1, length(signalSin)-newSamplesPerCycle+1);
    for i = newSamplesPerCycle:length(signalSin)
        %Averages last 16 samples from signal * sin and stores them in array
        avgs_sin(i-newSamplesPerCycle+1) = sum( signalSin(i-newSamplesPerCycle+1:i) ) / newSamplesPerCycle;   
    end

    %Decode the signalCos function
    avgs_cos = zeros(1, length(signalCos)-newSamplesPerCycle+1);
    for i = newSamplesPerCycle:length(signalCos)
        %Averages last 16 samples from signal * cos and stores them in array
        avgs_cos(i-newSamplesPerCycle+1) = sum( signalCos( i-newSamplesPerCycle+1: i ) ) / newSamplesPerCycle;    
    end

    %The digital signal is 2 times the magnitude of the average sine and cosine
    %funtions
    finalDigitalSignal = 2*sqrt(avgs_sin.^2 + avgs_cos.^2);

    figure(3)
    plot(t(newSamplesPerCycle:end)/samplesPerSecond, finalDigitalSignal)
    title('Original digital signal (cut off)');
    xlabel('Seconds');

    %CONVERT DIGITAL SIGNAL TO BITS
    %   1280 samples is one second
    %   256 samples is 0.2 seconds
    %   640 samples is 0.5 seconds
    %   1024 samples is 0.8 seconds

    %Discard incomplete bit
    %In 1280 samples, signal starts high, goes low, goes high again. 
    %Delete the first high signal
    incompleteSecondHigh = 0;
    for t = newSamplesPerCycle:1280
        avg = mean(finalDigitalSignal(t-15:t));

        %If the previous samples were 1, and the current sample is 7
        if incompleteSecondHigh==0 && avg>3.5
            incompleteSecondHigh = 1;
        end

        %If previous samples were 7s of cut off bit, and the next bit starts
        %Delete the cut off bit
        if incompleteSecondHigh==1 && avg<3.5
            finalDigitalSignal = finalDigitalSignal(t:end);
            break
        end
    end

    [~, col] = size(finalDigitalSignal);
    data_received = zeros(1,round(col/1280));
    col = 1280*round(col/1280);
    
    %Find indices where the signal goes from 1 to 7 and 7 to 1 (with tolerance)
    for i = 1:1280:col
        try
            avg2 = sum(finalDigitalSignal(i+samplesPerSecond*.2:i+samplesPerSecond*.5)) / (samplesPerSecond*.3);
            avg3 = sum(finalDigitalSignal(i+samplesPerSecond*.5:i+samplesPerSecond*.8)) / (samplesPerSecond*.3);
            avg4 = sum(finalDigitalSignal(i+samplesPerSecond*.8:i+samplesPerSecond-100)) / (samplesPerSecond*.2-100);
        catch IE
            %disp(IE);
            %disp(i);
            %disp(i+samplesPerSecond);
            %disp(i+samplesPerSecond-100);
            error(IE.message)
        end
        
        avg2 = round((avg2-1) / 6);
        avg3 = round((avg3-1) / 6);
        avg4 = round((avg4-1) / 6);
        if avg2 
            data_received(((i-1) / 1280)+1) = 0;
        elseif avg3
            data_received(((i-1) / 1280)+1) = 1;
        elseif avg4
            data_received(((i-1) / 1280)+1) = 2;
        end
    end

    %Two marker bits in a row is the start of minute
    %Discard an incomplete minute
    %   Find two marker bits in a row (two 2's in a row)
    twos = data_received(1:61)==2;  
    same = [-1 diff(data_received(1:61))]==0;
    for ind = 1:61
        if (twos(ind)==1 && same(ind)==1)
            break
        end
    end
    incompleteMinutePosition = ind;
    data_received= data_received(incompleteMinutePosition:end);

    %Call find_time.m on each complete minute
    data_received_length = size(data_received);
    for startOfSecondPosition = 1:60:data_received_length(2)
        disp(find_time(data_received(startOfSecondPosition:startOfSecondPosition+59)));
    end
end
