classdef SpectrumAnalyzer < pyrpl.modules.Module
    %SPECTRUMANALYZER Estimate single-sided amplitude spectrum.
    %   Uses the mock hardware backend for synthetic data when no hardware is
    %   connected.  The implementation relies on MATLAB's Signal Processing
    %   Toolbox for window generation.

    properties (Access = private)
        InputChannel (1, 1) double = 1
        FFTLength (1, 1) double = 4096
        WindowType (1, :) char = 'hann'
        Averages (1, 1) double = 4
        RefreshRate (1, 1) double = 5.0
        LastSpectrum struct = struct()
    end

    methods
        function obj = SpectrumAnalyzer(app, name, config)
            obj@pyrpl.modules.Module(app, name, config);
        end

        function setup(obj)
            setup@pyrpl.modules.Module(obj);
            cfg = obj.Config;
            if isfield(cfg, 'inputChannel'); obj.InputChannel = cfg.inputChannel; end
            if isfield(cfg, 'fftLength'); obj.FFTLength = cfg.fftLength; end
            if isfield(cfg, 'window'); obj.WindowType = cfg.window; end
            if isfield(cfg, 'averages'); obj.Averages = cfg.averages; end
            if isfield(cfg, 'refreshRate'); obj.RefreshRate = cfg.refreshRate; end
        end

        function spectrum = acquire(obj)
            %ACQUIRE Compute an averaged power spectrum.
            hw = obj.App.Hardware;
            fs = hw.SampleRate;
            n = obj.FFTLength;
            win = obj.createWindow(n);
            acc = zeros(n/2+1, 1);
            for k = 1:obj.Averages
                data = hw.acquireAnalogIn(obj.InputChannel, n);
                windowed = data .* win;
                fftData = fft(windowed);
                psd = (abs(fftData(1:n/2+1)).^2) / (sum(win.^2) * fs);
                psd(2:end-1) = 2 * psd(2:end-1);
                acc = acc + psd;
            end
            meanPsd = acc / obj.Averages;
            freq = (0:n/2)' * (fs / n);
            spectrum = struct('frequency', freq, 'psd', meanPsd, 'window', obj.WindowType, ...
                              'fftLength', obj.FFTLength, 'averages', obj.Averages);
            obj.LastSpectrum = spectrum;
        end
    end

    methods (Access = private)
        function w = createWindow(obj, n)
            switch lower(obj.WindowType)
                case 'hann'
                    w = hann(n, 'periodic');
                case 'hamming'
                    w = hamming(n, 'periodic');
                case 'blackman'
                    w = blackman(n, 'periodic');
                otherwise
                    warning('pyrpl:SpectrumAnalyzer:UnknownWindow', ...
                        'Unknown window %s, using rectangular.', obj.WindowType);
                    w = ones(n, 1);
            end
        end
    end
end
