local base_specs = require('hlcraft.engine.base_specs')
local config = require('hlcraft.config')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local notify = require('hlcraft.notify')
local presets = require('hlcraft.core.presets')
local snapshot = require('hlcraft.engine.snapshot')
local store = require('hlcraft.engine.store')

local M = {}

local state = store.data

function M.build_preset_overrides()
  if not config.from_none_enabled() then
    return {}
  end

  return presets.transparent(config.from_none_scope())
end

function M.refresh_base_specs()
  dynamic_runtime.stop()
  snapshot.refresh_base_specs()
end

function M.uninstall_pending_hook()
  if not state.hooked then
    return
  end

  if vim.api.nvim_set_hl ~= state.original_set_hl then
    state.hooked = false
    return
  end
  vim.api.nvim_set_hl = state.original_set_hl
  state.hooked = false
end

function M.apply_group(name)
  local override = state.active[name]
  if not override or next(override) == nil then
    state.pending[name] = nil
    base_specs.restore(state, name)
    dynamic_runtime.clear_group(name, state.base_specs[name])
    return
  end

  if not base_specs.group_exists(name) then
    state.pending[name] = true
    M.install_pending_hook()
    return
  end

  state.pending[name] = nil
  local dynamic_base_spec = dynamic_runtime.base_spec(name)
  if dynamic_base_spec then
    dynamic_runtime.clear_group(name, dynamic_base_spec)
  end

  state.applying = true
  local spec = base_specs.merged(state, name)
  local ok, err = pcall(state.original_set_hl, 0, name, spec)
  state.applying = false

  if not ok then
    notify.warn(('failed to apply highlight %s: %s'):format(name, tostring(err)))
    return
  end

  dynamic_runtime.sync_group(name, spec, override)
end

function M.install_pending_hook()
  if state.hooked then
    return
  end

  vim.api.nvim_set_hl = function(ns_id, name, spec)
    state.original_set_hl(ns_id, name, spec)

    if state.applying then
      return
    end
    if ns_id ~= 0 or type(name) ~= 'string' or name == '' then
      return
    end

    if not state.pending[name] then
      return
    end

    state.base_specs[name] = vim.deepcopy(spec or {})
    M.apply_group(name)

    if next(state.pending) == nil then
      M.uninstall_pending_hook()
    end
  end

  state.hooked = true
end

function M.apply_all()
  for name, _ in pairs(state.active) do
    M.apply_group(name)
  end
end

function M.register_reapply_events(replay)
  if not config.config.reapply_events.enabled then
    return
  end

  for index, hook in ipairs(config.config.reapply_events.events or {}) do
    local event = hook
    local opts = {}

    if type(hook) == 'table' then
      event = hook.event
      opts.pattern = hook.pattern
      if hook.once ~= nil then
        opts.once = hook.once
      end
    end

    if type(event) == 'string' and event ~= '' then
      vim.api.nvim_create_autocmd(event, {
        group = state.group,
        pattern = opts.pattern,
        once = opts.once,
        callback = function()
          vim.schedule(function()
            M.refresh_base_specs()
            replay()
          end)
        end,
        desc = ('hlcraft replay hook %d'):format(index),
      })
    end
  end
end

return M
