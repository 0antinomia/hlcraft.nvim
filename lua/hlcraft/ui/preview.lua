local search_scene = require('hlcraft.ui.scene.search')
local config = require('hlcraft.config')
local timers = require('hlcraft.core.timers')

local M = {}

local preview_fg = '#00e5ff'
local preview_bg = '#ff3b30'
local preview_timeout_ms = 500

local function preview_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('preview requires an instance', 3)
  end
  local preview = instance.state.preview
  if type(preview) ~= 'table' then
    error('preview state must be a table', 3)
  end
  return instance.state, preview
end

local function result_list(state)
  if type(state.results) ~= 'table' then
    error('preview results must be a table', 3)
  end
  return state.results
end

local function preview_key()
  local lhs = config.config.preview_key
  if lhs == false or lhs == nil or lhs == '' then
    return nil
  end
  if type(lhs) ~= 'string' then
    error('preview key must be a non-empty string or false', 3)
  end
  return lhs
end

local function snapshot_existing_keymap(lhs)
  local info = vim.fn.maparg(lhs, 'n', false, true)
  if type(info) ~= 'table' or vim.tbl_isempty(info) then
    return nil
  end

  return info
end

local function restore_keymap(map)
  if not map or not map.lhs then
    return
  end

  local opts = {
    silent = map.silent == 1,
    expr = map.expr == 1,
    noremap = map.noremap == 1,
    nowait = map.nowait == 1,
    script = map.script == 1,
    replace_keycodes = map.replace_keycodes == 1,
  }

  if map.desc and map.desc ~= '' then
    opts.desc = map.desc
  end

  if map.callback then
    vim.keymap.set('n', map.lhs, map.callback, opts)
    return
  end

  if type(map.rhs) ~= 'string' then
    error('preview keymap restore requires a string rhs', 2)
  end
  vim.api.nvim_set_keymap('n', map.lhs, map.rhs, opts)
end

local function restore(instance)
  local _, preview = preview_state(instance)
  if preview.name == nil and preview.spec == nil then
    return
  end
  if type(preview.name) ~= 'string' or type(preview.spec) ~= 'table' then
    error('preview restore state is invalid', 3)
  end

  pcall(vim.api.nvim_set_hl, 0, preview.name, vim.deepcopy(preview.spec))
  preview.name = nil
  preview.spec = nil
end

local function stop_timer(instance)
  local _, preview = preview_state(instance)
  if not preview.timer then
    return
  end

  timers.stop(preview.timer)
  preview.timer = nil
end

local function current_result(instance, state)
  local results = result_list(state)
  if state.detail_index then
    return results[state.detail_index]
  end

  local list_index = state.list_cursor
  if list_index and results[list_index] then
    return results[list_index]
  end

  local entry = search_scene.current_entry(instance)
  return entry and entry.result or nil
end

--- Flash the currently focused highlight group with a temporary high-contrast color.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.flash_current(instance)
  local state, preview = preview_state(instance)
  local result = current_result(instance, state)
  if not result or not result.name then
    return
  end

  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = result.name, create = false })
  if not ok or not spec or vim.tbl_isempty(spec) then
    return
  end

  stop_timer(instance)
  restore(instance)

  preview.name = result.name
  preview.spec = vim.deepcopy(spec)

  pcall(vim.api.nvim_set_hl, 0, result.name, {
    fg = preview_fg,
    bg = preview_bg,
    bold = true,
  })

  preview.timer = timers.once(
    preview_timeout_ms,
    vim.schedule_wrap(function()
      stop_timer(instance)
      restore(instance)
    end)
  )
  if not preview.timer then
    restore(instance)
  end
end

--- Stop any pending preview timer and restore the original highlight immediately.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.cleanup(instance)
  preview_state(instance)
  stop_timer(instance)
  restore(instance)
end

--- Install the temporary global preview keymap for the workspace lifetime.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.install_keymap(instance)
  local _, preview = preview_state(instance)
  local lhs = preview_key()
  if lhs == nil then
    return
  end

  M.uninstall_keymap(instance)

  preview.keymap = {
    lhs = lhs,
    previous = snapshot_existing_keymap(lhs),
  }

  vim.keymap.set('n', lhs, function()
    M.flash_current(instance)
  end, {
    silent = true,
    nowait = true,
    desc = 'hlcraft flash current highlight',
  })
end

--- Remove the temporary global preview keymap and restore any previous mapping.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.uninstall_keymap(instance)
  local _, preview = preview_state(instance)
  local map = preview.keymap
  if map == nil then
    return
  end
  if type(map) ~= 'table' then
    error('preview keymap state must be a table', 2)
  end
  if type(map.lhs) ~= 'string' or map.lhs == '' then
    error('preview keymap lhs must be a non-empty string', 2)
  end

  pcall(vim.keymap.del, 'n', map.lhs)
  restore_keymap(map.previous)
  preview.keymap = nil
end

return M
