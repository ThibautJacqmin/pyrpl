classdef Logger < handle
    %LOGGER Simple printf-style logger with adjustable verbosity.
    %   The logger writes to MATLAB's command window and can be shared
    %   across modules.  Supported levels are ``debug``, ``info``,
    %   ``warning``, and ``error``.

    properties (SetAccess = private)
        Level (1, 1) double = 2
    end

    properties (Constant, Access = private)
        LevelMap = struct('debug', 1, 'info', 2, 'warning', 3, 'error', 4);
        LevelNames = {'DEBUG', 'INFO', 'WARN', 'ERROR'};
    end

    methods
        function obj = Logger(level)
            %LOGGER Create a new logger instance with the specified level.
            if nargin < 1
                level = 'info';
            end
            obj.setLevel(level);
        end

        function setLevel(obj, level)
            %SETLEVEL Set the logging threshold.
            if ischar(level) || isstring(level)
                level = char(lower(string(level)));
                if ~isfield(obj.LevelMap, level)
                    error('pyrpl:Logger:InvalidLevel', 'Unknown level: %s', level);
                end
                obj.Level = obj.LevelMap.(level);
            elseif isnumeric(level)
                obj.Level = max(1, min(4, floor(level)));
            else
                error('pyrpl:Logger:InvalidLevelType', 'Unsupported level type.');
            end
        end

        function debug(obj, message, varargin)
            obj.log(1, message, varargin{:});
        end

        function info(obj, message, varargin)
            obj.log(2, message, varargin{:});
        end

        function warning(obj, message, varargin)
            obj.log(3, message, varargin{:});
        end

        function error(obj, message, varargin)
            obj.log(4, message, varargin{:});
        end
    end

    methods (Static)
        function text = toJson(value)
            %TOJSON Utility to stringify structures for debugging.
            try
                text = jsonencode(value, 'PrettyPrint', true);
            catch
                text = '<unavailable>';
            end
        end
    end

    methods (Access = private)
        function log(obj, level, message, varargin)
            if level < obj.Level
                return
            end
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            prefix = obj.LevelNames{level};
            line = sprintf('[%s] [%s] %s\n', timestamp, prefix, message);
            if isempty(varargin)
                fprintf(1, '%s', line);
            else
                fprintf(1, line, varargin{:});
            end
        end
    end
end
