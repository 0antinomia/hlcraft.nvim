local M = {}

local constants = require('hlcraft.dynamic.constants')

local ordered_names = { 'pulse', 'breath', 'hue', 'gradient', 'blink', 'duotone' }
M.default_name = ordered_names[1]

local templates = {
  pulse = {
    version = constants.version,
    preset = 'pulse',
    duration = constants.default_duration,
    loop = 'pingpong',
    interpolation = 'smooth',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ff6699' },
    },
  },
  breath = {
    version = constants.version,
    preset = 'breath',
    duration = constants.default_duration,
    loop = 'pingpong',
    timeline = {
      { at = 0, color = 'base' },
    },
    transforms = {
      {
        type = 'brightness',
        interpolation = 'sine',
        timeline = {
          { at = 0, value = 0.45 },
          { at = 1, value = 1.0 },
        },
      },
    },
  },
  hue = {
    version = constants.version,
    preset = 'hue',
    duration = 3000,
    loop = constants.default_loop,
    timeline = {
      { at = 0, color = 'base' },
    },
    transforms = {
      {
        type = 'hue_shift',
        timeline = {
          { at = 0, value = 0 },
          { at = 1, value = 360 },
        },
      },
    },
  },
  gradient = {
    version = constants.version,
    preset = 'gradient',
    duration = 3000,
    loop = constants.default_loop,
    timeline = {
      { at = 0, color = '#ff0000' },
      { at = 0.3333333333333333, color = '#00ff00' },
      { at = 0.6666666666666666, color = '#0000ff' },
      { at = 1, color = '#ff0000' },
    },
  },
  blink = {
    version = constants.version,
    preset = 'blink',
    duration = 1000,
    loop = constants.default_loop,
    interpolation = 'step',
    timeline = {
      { at = 0, color = 'base' },
      { at = 0.5, color = '#ffffff' },
      { at = 1, color = 'base' },
    },
  },
  duotone = {
    version = constants.version,
    preset = 'duotone',
    duration = 2400,
    loop = 'pingpong',
    interpolation = 'smooth',
    timeline = {
      { at = 0, color = '#7aa2f7' },
      { at = 1, color = '#bb9af7' },
    },
  },
}

function M.names()
  return vim.deepcopy(ordered_names)
end

function M.get(name)
  local template = templates[name]
  return template and vim.deepcopy(template) or nil
end

function M.default()
  return M.get(M.default_name)
end

return M
