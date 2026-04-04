--- @type table
local M = {}

local config = require('hlcraft.config')

local level_map = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

--- Read the current log level threshold from config at call time (per Pitfall 6).
--- Returns nil when logging is off or not configured, otherwise the numeric level.
--- @return number|nil
local function current_threshold()
  local cfg = config.config.debug
  if not cfg or cfg.level == 'off' then
    return nil
  end
  return level_map[cfg.level]
end

--- Check whether a message at the given level should be emitted.
--- @param msg_level number vim.log.levels constant for the message
--- @return boolean
local function should_log(msg_level)
  local threshold = current_threshold()
  if not threshold then
    return false
  end
  return msg_level >= threshold
end

--- Log a trace-level debug message.
--- @param msg string Message to log
function M.trace(msg)
  if should_log(vim.log.levels.TRACE) then
    vim.notify(('hlcraft [trace]: %s'):format(msg), vim.log.levels.TRACE)
  end
end

--- Log a debug-level debug message.
--- @param msg string Message to log
function M.debug(msg)
  if should_log(vim.log.levels.DEBUG) then
    vim.notify(('hlcraft [debug]: %s'):format(msg), vim.log.levels.DEBUG)
  end
end

--- Log an info-level debug message.
--- @param msg string Message to log
function M.info(msg)
  if should_log(vim.log.levels.INFO) then
    vim.notify(('hlcraft [info]: %s'):format(msg), vim.log.levels.INFO)
  end
end

--- Log a warn-level debug message.
--- @param msg string Message to log
function M.warn(msg)
  if should_log(vim.log.levels.WARN) then
    vim.notify(('hlcraft [warn]: %s'):format(msg), vim.log.levels.WARN)
  end
end

--- Log an error-level debug message.
--- @param msg string Message to log
function M.error(msg)
  if should_log(vim.log.levels.ERROR) then
    vim.notify(('hlcraft [error]: %s'):format(msg), vim.log.levels.ERROR)
  end
end

return M
