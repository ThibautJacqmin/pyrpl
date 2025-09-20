classdef PyrplApp < handle
    %PYRPLAPP High-level MATLAB front-end for the PyRPL feature set.
    %   This class orchestrates configuration management, hardware access,
    %   and software modules.  It mirrors the responsibilities of the
    %   Python :mod:`pyrpl.pyrpl` module while embracing MATLAB OOP.
    %
    %   Example
    %   -------
    %   .. code-block:: matlab
    %
    %       app = pyrpl.PyrplApp('config/my_lab.json');
    %       app.initialize();
    %       app.start();
    %       lockbox = app.getModule('Lockbox');
    %       result = lockbox.simulateLock();
    %       app.stop();
    %
    %   The implementation supports both real hardware connections and a
    %   mock simulation backend that enables development without access to
    %   a Red Pitaya board.

    properties (SetAccess = private)
        ConfigManager (1,1) pyrpl.core.ConfigManager
        Logger (1,1) pyrpl.core.Logger
        Hardware (1,1) pyrpl.hardware.RedPitayaClient
        Modules
        IsInitialized (1,1) logical = false
        IsRunning (1,1) logical = false
    end

    properties (Access = private)
        DefaultConfigPath (1, :) char
    end

    methods
        function obj = PyrplApp(configPath, varargin)
            %PyrplApp Construct the application instance.
            %   app = pyrpl.PyrplApp() loads the default configuration
            %   located under matlab/config/default_config.json.
            %
            %   app = pyrpl.PyrplApp(configPath) loads a custom
            %   configuration file.  Additional name/value pairs are
            %   forwarded to the ConfigManager to override parameters at
            %   run time.
            arguments
                configPath (1, :) char = ''
            end
            arguments (Repeating)
                varargin
            end

            obj.DefaultConfigPath = fullfile(fileparts(mfilename('fullpath')), ...
                'config', 'default_config.json');
            if isempty(configPath)
                configPath = obj.DefaultConfigPath;
            end

            obj.Logger = pyrpl.core.Logger('info');
            obj.ConfigManager = pyrpl.core.ConfigManager(configPath, varargin{:});
            obj.Modules = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function initialize(obj)
            %INITIALIZE Load configuration and instantiate modules.
            if obj.IsInitialized
                obj.Logger.debug('Initialization skipped: already initialized.');
                return
            end

            obj.Logger.info('Loading configuration from %s', obj.ConfigManager.ConfigPath);
            obj.ConfigManager.load();

            hwConfig = obj.ConfigManager.getHardwareConfig();
            obj.Logger.debug('Hardware configuration loaded: %s', pyrpl.core.Logger.toJson(hwConfig));
            obj.Hardware = pyrpl.hardware.RedPitayaClient(hwConfig, obj.Logger);
            obj.Hardware.connect();

            obj.Logger.info('Creating software modules.');
            moduleConfigs = obj.ConfigManager.getModuleConfigs();
            for k = 1:numel(moduleConfigs)
                spec = moduleConfigs(k);
                moduleInstance = obj.instantiateModule(spec);
                obj.Modules(spec.name) = moduleInstance;
                obj.Logger.debug('Module "%s" initialized.', spec.name);
            end

            obj.IsInitialized = true;
        end

        function start(obj)
            %START Activate all modules.
            if ~obj.IsInitialized
                obj.initialize();
            end
            if obj.IsRunning
                obj.Logger.debug('Start request ignored: application already running.');
                return
            end

            if ~obj.Hardware.IsConnected
                obj.Hardware.connect();
            end

            moduleNames = obj.Modules.keys;
            for k = 1:numel(moduleNames)
                module = obj.Modules(moduleNames{k});
                module.start();
            end

            obj.IsRunning = true;
            obj.Logger.info('All modules started.');
        end

        function stop(obj)
            %STOP Deactivate modules and release hardware resources.
            if ~obj.IsRunning
                obj.Logger.debug('Stop request ignored: application already stopped.');
                return
            end

            moduleNames = obj.Modules.keys;
            for k = 1:numel(moduleNames)
                module = obj.Modules(moduleNames{k});
                module.stop();
            end

            obj.Hardware.disconnect();
            obj.IsRunning = false;
            obj.Logger.info('Application stopped.');
        end

        function module = getModule(obj, name)
            %GETMODULE Retrieve an instantiated module by name.
            arguments
                obj
                name (1, :) char
            end
            if ~isKey(obj.Modules, name)
                error('pyrpl:PyrplApp:ModuleNotFound', 'Module "%s" is not registered.', name);
            end
            module = obj.Modules(name);
        end

        function modules = listModules(obj)
            %LISTMODULES Return the registered modules as a cell array of names.
            modules = obj.Modules.keys;
        end

        function addModule(obj, moduleInstance)
            %ADDMODULE Register an additional module at run time.
            arguments
                obj
                moduleInstance (1, 1) pyrpl.modules.Module
            end
            name = moduleInstance.Name;
            if isKey(obj.Modules, name)
                warning('pyrpl:PyrplApp:ModuleExists', ...
                    'Module "%s" already exists and will be replaced.', name);
            end
            obj.Modules(name) = moduleInstance;
        end

        function reloadConfiguration(obj)
            %RELOADCONFIGURATION Reload configuration and reinitialize modules.
            obj.Logger.info('Reloading configuration.');
            wasRunning = obj.IsRunning;
            obj.stop();
            obj.Modules = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.IsInitialized = false;
            obj.initialize();
            if wasRunning
                obj.start();
            end
        end

        function delete(obj)
            %DELETE Destructor to ensure resources are released.
            try %#ok<TRYNC>
                obj.stop();
            end
        end
    end

    methods (Access = private)
        function moduleInstance = instantiateModule(obj, spec)
            %INSTANTIATEMODULE Create a module from a configuration specification.
            if ~isfield(spec, 'class')
                error('pyrpl:PyrplApp:MissingClass', 'Module specification must define a class field.');
            end
            if ~isfield(spec, 'name')
                error('pyrpl:PyrplApp:MissingName', 'Module specification must define a name field.');
            end
            if ~isfield(spec, 'config')
                spec.config = struct();
            end

            constructor = str2func(spec.class);
            try
                moduleInstance = constructor(obj, spec.name, spec.config);
                moduleInstance.setup();
            catch err
                obj.Logger.error('Failed to initialize module %s (%s): %s', ...
                    spec.name, spec.class, err.message);
                rethrow(err);
            end
        end
    end
end
