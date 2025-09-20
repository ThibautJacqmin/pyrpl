classdef Lockbox < pyrpl.modules.Module
    %LOCKBOX Digital lockbox module implementing PID control.
    %   Provides discrete-time PID control with optional simulation tools for
    %   tuning controller parameters against the mock plant.  The controller is
    %   realized as a discrete transfer function obtained via bilinear
    %   transformation of a continuous-time PID specification.

    properties (Access = private)
        InputChannel (1, 1) double = 1
        OutputChannel (1, 1) double = 1
        Setpoint (1, 1) double = 0.0
        ControllerConfig struct = struct()
        SearchConfig struct = struct('strategy', 'raster', 'range', 0.5, 'speed', 0.05)
        SimulationConfig struct = struct('duration', 0.02, 'disturbanceAmplitude', 0.05)
        SampleTime (1, 1) double = 1e-6
        ControllerB double = 0
        ControllerA double = 1
        ControllerState double = 0
        ContinuousController
        LastSimulation struct = struct()
    end

    methods
        function obj = Lockbox(app, name, config)
            obj@pyrpl.modules.Module(app, name, config);
        end

        function setup(obj)
            setup@pyrpl.modules.Module(obj);
            cfg = obj.Config;
            hw = obj.App.Hardware;
            obj.SampleTime = 1 / hw.SampleRate;
            if isfield(cfg, 'inputChannel'); obj.InputChannel = cfg.inputChannel; end
            if isfield(cfg, 'outputChannel'); obj.OutputChannel = cfg.outputChannel; end
            if isfield(cfg, 'setpoint'); obj.Setpoint = cfg.setpoint; end
            if isfield(cfg, 'controller'); obj.ControllerConfig = cfg.controller; end
            if isfield(cfg, 'search'); obj.SearchConfig = cfg.search; end
            if isfield(cfg, 'simulation'); obj.SimulationConfig = cfg.simulation; end
            obj.configureController();
        end

        function start(obj)
            start@pyrpl.modules.Module(obj);
            obj.resetControllerState();
        end

        function output = update(obj, measurement)
            %UPDATE Compute the new actuator value for the provided measurement.
            errorSignal = obj.Setpoint - measurement;
            output = obj.applyController(errorSignal);
            try
                obj.App.Hardware.setAnalogOut(obj.OutputChannel, output);
            catch controlErr
                obj.App.Logger.debug('Lockbox output dispatch skipped: %s', controlErr.message);
            end
            notify(obj, 'Updated');
        end

        function simulation = simulateLock(obj, duration)
            %SIMULATELOCK Simulate the closed-loop response using the mock plant.
            if nargin < 2 || isempty(duration)
                if isfield(obj.SimulationConfig, 'duration')
                    duration = obj.SimulationConfig.duration;
                else
                    duration = 0.02;
                end
            end
            plant = obj.App.Hardware.getMockPlant();
            controller = obj.ContinuousController;
            closedLoop = feedback(controller * plant, 1);
            Ts = obj.SampleTime;
            t = 0:Ts:duration;
            disturbanceAmplitude = 0;
            if isfield(obj.SimulationConfig, 'disturbanceAmplitude')
                disturbanceAmplitude = obj.SimulationConfig.disturbanceAmplitude;
            end
            disturbance = disturbanceAmplitude * square(2*pi*50*t);
            [y, tOut] = lsim(closedLoop, disturbance, t);
            simulation = struct('time', tOut, 'output', y, 'disturbance', disturbance, ...
                                'controller', controller, 'plant', plant);
            obj.LastSimulation = simulation;
        end

        function searchProfile = search(obj, range)
            %SEARCH Perform a coarse scan over the actuator output.
            if nargin < 2 || isempty(range)
                if isfield(obj.SearchConfig, 'range')
                    range = obj.SearchConfig.range;
                else
                    range = 0.5;
                end
            end
            points = 200;
            actuator = linspace(-range, range, points);
            plant = obj.App.Hardware.getMockPlant();
            dcGain = dcgain(plant);
            measurements = actuator * dcGain;
            searchProfile = struct('actuator', actuator, 'measurement', measurements, 'dcGain', dcGain);
        end
    end

    methods (Access = private)
        function configureController(obj)
            cfg = obj.ControllerConfig;
            if ~isfield(cfg, 'proportional'); cfg.proportional = 0.1; end
            if ~isfield(cfg, 'integral'); cfg.integral = 100.0; end
            if ~isfield(cfg, 'derivative'); cfg.derivative = 0.0; end
            if ~isfield(cfg, 'filterCoefficient'); cfg.filterCoefficient = 100.0; end
            obj.ControllerConfig = cfg;
            obj.ContinuousController = pid(cfg.proportional, cfg.integral, cfg.derivative, cfg.filterCoefficient);
            discrete = c2d(obj.ContinuousController, obj.SampleTime, 'tustin');
            [b, a] = tfdata(discrete, 'v');
            obj.ControllerB = b;
            obj.ControllerA = a;
            obj.ControllerState = zeros(max(numel(a), numel(b)) - 1, 1);
        end

        function resetControllerState(obj)
            obj.ControllerState(:) = 0;
        end

        function output = applyController(obj, errorSignal)
            [y, obj.ControllerState] = filter(obj.ControllerB, obj.ControllerA, errorSignal, obj.ControllerState);
            output = y(end);
        end
    end
end
