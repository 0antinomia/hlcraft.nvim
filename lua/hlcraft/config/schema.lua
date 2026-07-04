local defaults = require('hlcraft.config.defaults')
local normalize = require('hlcraft.config.normalize')
local validate = require('hlcraft.config.validate')

local M = {}

M.defaults = defaults.values
M.normalize = normalize.config
M.validate = validate.config

return M
