classdef RedPitayaClient < handle
    %REDPITAYACLIENT Hardware abstraction layer for Red Pitaya/STEMlab boards.
    %   The class exposes a MATLAB-friendly API mirroring the Python
    %   implementation.  When operating in ``mock`` mode, a configurable plant
    %   model is simulated using Control System Toolbox primitives, enabling
    %   offline development and automated testing.

    properties (SetAccess = private)
        Hostname (1, :) char = ''
        Port (1, 1) double = 5000
        Timeout (1, 1) double = 5.0
        SampleRate (1, 1) double = 125e6
        AnalogInChannels (1, 1) double = 2
        AnalogOutChannels (1, 1) double = 2
        IsConnected (1, 1) logical = false
        MockMode (1, 1) logical = true
        Logger (1, 1) pyrpl.core.Logger
    end

    properties (Access = private)
        TcpClient
        MockPlant
        MockState
        NoiseLevel (1, 1) double = 0.0
        PhaseNoise (1, 1) double = deg2rad(0.2)
    end

    methods
        function obj = RedPitayaClient(config, logger)
            %REDPITAYACLIENT Constructor using configuration structure.
            if nargin < 2 || isempty(logger)
                logger = pyrpl.core.Logger('info');
            end
            obj.Logger = logger;

            if isfield(config, 'hostname'); obj.Hostname = config.hostname; end
            if isfield(config, 'port'); obj.Port = config.port; end
            if isfield(config, 'timeout'); obj.Timeout = config.timeout; end
            if isfield(config, 'samplingRate'); obj.SampleRate = config.samplingRate; end
            if isfield(config, 'analogInChannels'); obj.AnalogInChannels = config.analogInChannels; end
            if isfield(config, 'analogOutChannels'); obj.AnalogOutChannels = config.analogOutChannels; end
            if isfield(config, 'mock'); obj.MockMode = config.mock; end
            if isfield(config, 'noiseLevel'); obj.NoiseLevel = config.noiseLevel; end

            obj.MockState = struct('AnalogOut', zeros(obj.AnalogOutChannels, 1), ...
                                   'PlantState', []);

            if isfield(config, 'plant')
                obj.MockPlant = obj.createPlantFromConfig(config.plant);
            else
                obj.MockPlant = tf(1, [1/(2*pi*5e3), 1]);
            end
        end

        function connect(obj)
            %CONNECT Establish a TCP connection or prepare the mock backend.
            if obj.IsConnected
                return
            end
            if obj.MockMode || isempty(obj.Hostname)
                obj.Logger.debug('RedPitayaClient operating in mock mode.');
                obj.IsConnected = true;
                return
            end
            try
                obj.TcpClient = tcpclient(obj.Hostname, obj.Port, 'Timeout', obj.Timeout);
                obj.IsConnected = true;
                obj.Logger.info('Connected to Red Pitaya at %s:%d.', obj.Hostname, obj.Port);
            catch err
                obj.Logger.warning('Falling back to mock mode: %s', err.message);
                obj.MockMode = true;
                obj.IsConnected = true;
            end
        end

        function disconnect(obj)
            %DISCONNECT Release the TCP connection.
            if obj.MockMode
                obj.IsConnected = false;
                return
            end
            if isempty(obj.TcpClient)
                obj.IsConnected = false;
                return
            end
            try
                clear obj.TcpClient;
            catch
            end
            obj.TcpClient = [];
            obj.IsConnected = false;
        end

        function setAnalogOut(obj, channel, value)
            %SETANALOGOUT Set the DC value of an analog output.
            obj.validateChannel(channel, obj.AnalogOutChannels, 'output');
            if obj.MockMode
                obj.MockState.AnalogOut(channel) = value;
                return
            end
            % Implement hardware-specific command sequence here.
            error('RedPitayaClient:setAnalogOut:NotImplemented', ...
                'Direct hardware control is not implemented in this example.');
        end

        function configureSineOutput(obj, channel, amplitude, frequency, offset)
            %CONFIGURESINEOUTPUT Configure a sinewave excitation on an analog output.
            if nargin < 5
                offset = 0;
            end
            obj.validateChannel(channel, obj.AnalogOutChannels, 'output');
            if obj.MockMode
                obj.MockState.Sine(channel) = struct( ...
                    'Amplitude', amplitude, ...
                    'Frequency', frequency, ...
                    'Offset', offset);
                return
            end
            error('RedPitayaClient:configureSineOutput:NotImplemented', ...
                'Direct hardware control is not implemented in this example.');
        end

        function data = acquireAnalogIn(obj, channel, numSamples)
            %ACQUIREANALOGIN Capture analog input samples.
            arguments
                obj
                channel (1, 1) double
                numSamples (1, 1) double {mustBePositive} = 2^14
            end
            obj.validateChannel(channel, obj.AnalogInChannels, 'input');
            if obj.MockMode
                data = obj.generateMockAnalogInput(channel, numSamples);
                return
            end
            error('RedPitayaClient:acquireAnalogIn:NotImplemented', ...
                'Direct hardware acquisition is not implemented in this example.');
        end

        function response = measureFrequencyResponse(obj, frequencyHz, amplitude)
            %MEASUREFREQUENCYRESPONSE Estimate the plant response at a frequency.
            %   response is a struct with fields frequency, gain, and phase (rad).
            if nargin < 3
                amplitude = 1.0;
            end
            if obj.MockMode
                w = 2 * pi * frequencyHz;
                H = squeeze(freqresp(obj.MockPlant, w));
                gain = abs(H);
                phase = angle(H);
                response.frequency = frequencyHz;
                response.gain = gain;
                response.outputAmplitude = amplitude * gain + obj.NoiseLevel * randn();
                response.phase = phase + obj.PhaseNoise * randn();
                return
            end
            error('RedPitayaClient:measureFrequencyResponse:NotImplemented', ...
                'Direct hardware frequency response is not implemented in this example.');
        end

        function plant = getMockPlant(obj)
            %GETMOCKPLANT Accessor for the simulated plant (useful for modules).
            plant = obj.MockPlant;
        end
    end

    methods (Access = private)
        function validateChannel(~, channel, limit, label)
            if channel < 1 || channel > limit
                error('pyrpl:RedPitayaClient:ChannelOutOfRange', ...
                    'Analog %s channel %d out of range 1..%d.', label, channel, limit);
            end
        end

        function data = generateMockAnalogInput(obj, channel, numSamples)
            if nargin < 3
                numSamples = 2^14;
            end
            t = (0:numSamples-1).' / obj.SampleRate;
            inputSignal = zeros(numSamples, 1);
            if isfield(obj.MockState, 'Sine')
                sineStates = obj.MockState.Sine;
                sineChannels = fieldnames(sineStates);
                for k = 1:numel(sineChannels)
                    state = sineStates.(sineChannels{k});
                    inputSignal = inputSignal + state.Amplitude * sin(2*pi*state.Frequency*t) + state.Offset;
                end
            else
                excitationFreq = 10e3;
                inputSignal = 0.1 * sin(2*pi*excitationFreq*t);
            end
            [y, ~, x] = lsim(obj.MockPlant, inputSignal, t, obj.MockState.PlantState);
            if isempty(x)
                obj.MockState.PlantState = [];
            else
                obj.MockState.PlantState = x(end, :).';
            end
            noise = obj.NoiseLevel * randn(size(y));
            data = y + noise;
            if channel == 2
                data = data + 0.02 * sin(2*pi*2e3*t);
            end
        end

        function plant = createPlantFromConfig(~, config)
            zerosVec = []; polesVec = []; gain = 1;
            if isfield(config, 'zeros'); zerosVec = config.zeros(:); end
            if isfield(config, 'poles'); polesVec = config.poles(:); end
            if isfield(config, 'gain'); gain = config.gain; end
            s = tf('s');
            numerator = gain;
            denominator = 1;
            for k = 1:numel(zerosVec)
                numerator = numerator * (s - zerosVec(k));
            end
            for k = 1:numel(polesVec)
                denominator = denominator * (s - polesVec(k));
            end
            plant = numerator / denominator;
        end
    end
end
