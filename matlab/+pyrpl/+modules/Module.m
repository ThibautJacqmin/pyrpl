classdef (Abstract) Module < handle
    %MODULE Abstract base class for MATLAB implementations of PyRPL modules.
    %   Derived modules implement ``setup``, ``start``, and ``stop`` methods and
    %   can optionally override ``update`` to execute periodic logic.

    properties (SetAccess = immutable)
        App (1, 1) pyrpl.PyrplApp
        Name (1, :) char
    end

    properties (SetAccess = protected)
        Config struct
        IsSetup (1, 1) logical = false
        IsRunning (1, 1) logical = false
    end

    events
        Started
        Stopped
        Updated
    end

    methods
        function obj = Module(app, name, config)
            arguments
                app (1, 1) pyrpl.PyrplApp
                name (1, :) char
                config struct = struct()
            end
            obj.App = app;
            obj.Name = name;
            obj.Config = config;
        end

        function setup(obj)
            %SETUP Prepare the module (override in subclasses).
            obj.IsSetup = true;
        end

        function start(obj)
            %START Begin module execution (override in subclasses if needed).
            if ~obj.IsSetup
                obj.setup();
            end
            obj.IsRunning = true;
            notify(obj, 'Started');
        end

        function stop(obj)
            %STOP Halt module activity (override in subclasses if needed).
            if ~obj.IsRunning
                return
            end
            obj.IsRunning = false;
            notify(obj, 'Stopped');
        end

        function update(obj, varargin)
            %UPDATE Optional periodic update callback.
            %#ok<INUSD>
            notify(obj, 'Updated');
        end

        function applyConfig(obj, newConfig)
            %APPLYCONFIG Update the module configuration.
            obj.Config = newConfig;
            if obj.IsSetup
                obj.setup();
            end
        end
    end
end
