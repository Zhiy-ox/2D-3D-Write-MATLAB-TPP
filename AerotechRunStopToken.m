classdef AerotechRunStopToken < handle
    %AEROTECHRUNSTOPTOKEN Shared mutable stop flag for GUI and runner callbacks.

    properties
        IsStopRequested = false
    end

    methods
        function requestStop(obj)
            obj.IsStopRequested = true;
        end

        function reset(obj)
            obj.IsStopRequested = false;
        end
    end
end
