local M = {}

local ordered_names = { 'pulse', 'breath', 'hue', 'gradient', 'blink', 'duotone' }

local templates = {
  pulse = {
    version = 1,
    preset = 'pulse',
    duration = 2000,
    loop = 'pingpong',
    interpolation = 'smooth',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ff6699' },
    },
  },
  breath = {
    version = 1,
    preset = 'breath',
    duration = 2000,
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
    version = 1,
    preset = 'hue',
    duration = 3000,
    loop = 'repeat',
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
    version = 1,
    preset = 'gradient',
    duration = 3000,
    loop = 'repeat',
    timeline = {
      { at = 0, color = '#ff0000' },
      { at = 0.3333333333333333, color = '#00ff00' },
      { at = 0.6666666666666666, color = '#0000ff' },
      { at = 1, color = '#ff0000' },
    },
  },
  blink = {
    version = 1,
    preset = 'blink',
    duration = 1000,
    loop = 'repeat',
    interpolation = 'step',
    timeline = {
      { at = 0, color = 'base' },
      { at = 0.5, color = '#ffffff' },
      { at = 1, color = 'base' },
    },
  },
  duotone = {
    version = 1,
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
  return vim.deepcopy(templates[name] or templates.pulse)
end

return M
