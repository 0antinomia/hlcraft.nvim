local normalize = require('hlcraft.config.normalize')
local spec = require('hlcraft.config.spec')
local validate = require('hlcraft.config.validate')

local M = {}

M.defaults = spec.defaults()
M.normalize = normalize.config
M.validate = validate.config

return M
