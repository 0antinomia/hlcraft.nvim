local M = {}

local function key_set(values)
  local result = {}
  for _, value in ipairs(values) do
    result[value] = true
  end
  return result
end

M.version = 1
M.default_duration = 2000
M.default_interpolation = 'linear'
M.default_loop = 'repeat'
M.default_phase = 0
M.min_duration = 250
M.max_duration = 10000

M.loops = { 'repeat', 'pingpong', 'once' }
M.loop_set = key_set(M.loops)

M.interpolations = { 'linear', 'step', 'smooth', 'smoothstep', 'sine' }
M.interpolation_set = key_set(M.interpolations)

M.transform_types = { 'brightness', 'hue_shift', 'saturation' }
M.transform_type_set = key_set(M.transform_types)

return M
