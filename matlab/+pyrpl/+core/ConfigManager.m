classdef ConfigManager < handle
    %CONFIGMANAGER Load and manage PyRPL MATLAB configuration files.
    %   The configuration file is a JSON document that contains hardware
    %   parameters and a list of software modules.  Name/value overrides can
    %   be applied at construction time to facilitate scripted workflows.

    properties (SetAccess = private)
        ConfigPath (1, :) char
        ConfigStruct struct = struct()
    end

    properties (Access = private)
        Overrides cell = {}
    end

    methods
        function obj = ConfigManager(configPath, varargin)
            %CONFIGMANAGER Construct a configuration manager.
            arguments
                configPath (1, :) char
            end
            arguments (Repeating)
                varargin
            end
            obj.ConfigPath = configPath;
            obj.Overrides = varargin;
        end

        function load(obj)
            %LOAD Read the configuration file and apply overrides.
            if ~isfile(obj.ConfigPath)
                error('pyrpl:ConfigManager:FileNotFound', ...
                    'Configuration file "%s" does not exist.', obj.ConfigPath);
            end
            jsonText = fileread(obj.ConfigPath);
            obj.ConfigStruct = jsondecode(jsonText);
            if ~isempty(obj.Overrides)
                for k = 1:2:numel(obj.Overrides)
                    key = obj.Overrides{k};
                    value = obj.Overrides{k + 1};
                    obj.ConfigStruct = obj.applyOverride(obj.ConfigStruct, key, value);
                end
            end
        end

        function save(obj, destinationPath)
            %SAVE Persist the current configuration to disk.
            if nargin < 2 || isempty(destinationPath)
                destinationPath = obj.ConfigPath;
            end
            jsonText = jsonencode(obj.ConfigStruct, 'PrettyPrint', true);
            fid = fopen(destinationPath, 'w');
            if fid < 0
                error('pyrpl:ConfigManager:WriteError', ...
                    'Unable to open "%s" for writing.', destinationPath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fwrite(fid, jsonText, 'char'); %#ok<NASGU>
        end

        function refresh(obj)
            %REFRESH Reload the configuration from disk discarding overrides.
            overrides = obj.Overrides;
            obj.Overrides = {};
            obj.load();
            obj.Overrides = overrides;
        end

        function hwConfig = getHardwareConfig(obj)
            %GETHARDWARECONFIG Retrieve hardware-specific settings.
            if ~isfield(obj.ConfigStruct, 'hardware')
                error('pyrpl:ConfigManager:MissingHardware', ...
                    'Configuration does not define a hardware section.');
            end
            hwConfig = obj.ConfigStruct.hardware;
        end

        function moduleConfigs = getModuleConfigs(obj)
            %GETMODULECONFIGS Return the list of module specifications.
            if ~isfield(obj.ConfigStruct, 'modules')
                moduleConfigs = struct([]);
                return
            end
            moduleConfigs = obj.ConfigStruct.modules;
            if ~isstruct(moduleConfigs)
                error('pyrpl:ConfigManager:InvalidModules', ...
                    'The "modules" field must be an array of objects.');
            end
            if ~isempty(moduleConfigs)
                moduleConfigs = moduleConfigs(:).';
            end
        end

        function value = get(obj, path, defaultValue)
            %GET Retrieve a configuration value using dot notation.
            %   value = manager.get('hardware.hostname') returns the hostname.
            arguments
                obj
                path (1, :) char
                defaultValue = []
            end
            tokens = strsplit(path, '.');
            value = obj.ConfigStruct;
            for k = 1:numel(tokens)
                token = tokens{k};
                if isstruct(value) && isfield(value, token)
                    value = value.(token);
                else
                    value = defaultValue;
                    return
                end
            end
        end
    end

    methods (Access = private)
        function structOut = applyOverride(~, structIn, key, value)
            tokens = strsplit(key, '.');
            structOut = pyrpl.core.ConfigManager.setNestedValue(structIn, tokens, value);
        end
    end

    methods (Static, Access = private)
        function s = setNestedValue(s, tokens, value)
            token = tokens{1};
            if numel(tokens) == 1
                s.(token) = value;
                return
            end
            if ~isfield(s, token) || ~isstruct(s.(token))
                s.(token) = struct();
            end
            s.(token) = pyrpl.core.ConfigManager.setNestedValue(s.(token), tokens(2:end), value);
        end
    end
end
