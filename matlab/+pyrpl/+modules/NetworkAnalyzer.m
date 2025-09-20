classdef NetworkAnalyzer < pyrpl.modules.Module
    %NETWORKANALYZER Frequency response measurement module.
    %   The MATLAB implementation performs swept-sine measurements either
    %   using the hardware back-end or by interrogating the simulated plant in
    %   mock mode.

    properties (Access = private)
        WindowFunction (1, :) char = 'hann'
        SettlingCycles (1, 1) double = 10
        ExcitationAmplitude (1, 1) double = 0.1
        OutputChannel (1, 1) double = 1
        InputChannel (1, 1) double = 1
    end

    methods
        function obj = NetworkAnalyzer(app, name, config)
            obj@pyrpl.modules.Module(app, name, config);
        end

        function setup(obj)
            setup@pyrpl.modules.Module(obj);
            cfg = obj.Config;
            if isfield(cfg, 'window'); obj.WindowFunction = cfg.window; end
            if isfield(cfg, 'settlingCycles'); obj.SettlingCycles = cfg.settlingCycles; end
            if isfield(cfg, 'excitationAmplitude'); obj.ExcitationAmplitude = cfg.excitationAmplitude; end
            if isfield(cfg, 'outputChannel'); obj.OutputChannel = cfg.outputChannel; end
            if isfield(cfg, 'inputChannel'); obj.InputChannel = cfg.inputChannel; end
        end

        function result = sweep(obj, frequencies)
            %SWEEP Perform a frequency sweep returning gain and phase vectors.
            arguments
                obj
                frequencies (:, 1) double
            end
            hw = obj.App.Hardware;
            gain = zeros(size(frequencies));
            phase = zeros(size(frequencies));
            outputAmplitude = zeros(size(frequencies));
            for k = 1:numel(frequencies)
                response = hw.measureFrequencyResponse(frequencies(k), obj.ExcitationAmplitude);
                gain(k) = response.gain;
                phase(k) = response.phase;
                outputAmplitude(k) = response.outputAmplitude;
            end
            result = struct('frequency', frequencies, ...
                            'gain', gain, ...
                            'phase', phase, ...
                            'outputAmplitude', outputAmplitude, ...
                            'window', obj.WindowFunction, ...
                            'excitationAmplitude', obj.ExcitationAmplitude, ...
                            'settlingCycles', obj.SettlingCycles);
        end
    end
end
