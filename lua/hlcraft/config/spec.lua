local M = {}

local function static(default)
  return function()
    return vim.deepcopy(default)
  end
end

M.fields = {
  transparent = {
    default = static({
      enabled = false,
      scope = 'extended',
    }),
    keys = {
      enabled = true,
      scope = true,
    },
  },
  search = {
    default = static({
      threshold = 100,
      include_sp = false,
      debounce_ms = 100,
    }),
    keys = {
      debounce_ms = true,
      include_sp = true,
      threshold = true,
    },
    fields = {
      debounce_ms = {
        range = {
          min = 0,
        },
      },
      threshold = {
        range = {
          min = 0,
          max = 1000,
        },
      },
    },
  },
  persistence = {
    default = function()
      return {
        dir = vim.fn.stdpath('config') .. '/hlcraft',
        reapply_events = {
          enabled = true,
          events = {
            'ColorScheme',
          },
        },
      }
    end,
    keys = {
      dir = true,
      reapply_events = true,
    },
    reapply_events_keys = {
      enabled = true,
      events = true,
    },
    reapply_event_keys = {
      event = true,
      once = true,
      pattern = true,
    },
  },
  dynamic = {
    default = static({
      interval_ms = 80,
    }),
    keys = {
      interval_ms = true,
    },
    fields = {
      interval_ms = {
        range = {
          min = 16,
          max = 1000,
        },
      },
    },
  },
  keymaps = {
    default = static({
      preview = {
        lhs = 'z',
        mode = 'n',
        opts = {
          desc = 'hlcraft flash current highlight',
          silent = true,
          nowait = true,
        },
      },
    }),
    keys = {
      preview = true,
    },
    preview_keys = {
      lhs = true,
      mode = true,
      opts = true,
    },
    preview_opts_keys = {
      desc = true,
      nowait = true,
      silent = true,
    },
  },
}

M.known_keys = {}
for key, _ in pairs(M.fields) do
  M.known_keys[key] = true
end

function M.defaults()
  local values = {}
  for key, field in pairs(M.fields) do
    values[key] = field.default()
  end
  return values
end

function M.field(name)
  local field = M.fields[name]
  if not field then
    error(('unknown config spec field: %s'):format(tostring(name)), 2)
  end
  return field
end

return M
