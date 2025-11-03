if not BCCWavesDebug then
    ---@class BCCWavesDebugLib
    ---@field Info fun(message: string)
    ---@field Error fun(message: string)
    ---@field Warning fun(message: string)
    ---@field Success fun(message: string)
    ---@field DevModeActive boolean
    BCCWavesDebug = {}

    BCCWavesDebug.DevModeActive = (Config and Config.devMode and Config.devMode.active) or false

    local function noop() end

    local function createLogger(prefix, color)
        if BCCWavesDebug.DevModeActive then
            return function(message)
                print(("^%d[%s] ^3%s^0"):format(color, prefix, message))
            end
        else
            return noop
        end
    end

    -- Create loggers with appropriate colors
    BCCWavesDebug.Info = createLogger("INFO", 5)       -- Purple
    BCCWavesDebug.Error = createLogger("ERROR", 1)     -- Red
    BCCWavesDebug.Warning = createLogger("WARNING", 3) -- Yellow
    BCCWavesDebug.Success = createLogger("SUCCESS", 2) -- Green
end
