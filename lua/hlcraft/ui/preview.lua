local search_scene = require('hlcraft.ui.scene.search')
local config = require('hlcraft.config')
local notify = require('hlcraft.notify')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local timers = require('hlcraft.core.timers')

local M = {}

local preview_flash_spec = {
  fg = 0x00e5ff,
  bg = 0xff3b30,
  bold = true,
}
local preview_timeout_ms = 500

local function partial_flash_spec_matches(current, expected)
  if type(current) ~= 'table' then
    return false
  end
  current = vim.deepcopy(current)
  local cterm = current.cterm
  current.cterm = nil
  if cterm ~= nil and not vim.deep_equal(cterm, { bold = true }) then
    return false
  end
  return vim.deep_equal(current, expected)
end

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
  return tables.assert_sequence(state.results, 'preview results', 3)
end

local function positive_integer(value, label)
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_integer(value, 1) then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return value
end

local function preview_keymap()
  local keymaps = config.config.keymaps
  if type(keymaps) ~= 'table' then
    error('preview keymap config must be a table', 3)
  end

  local spec = keymaps.preview
  if spec == false or spec == nil then
    return nil
  end
  if type(spec) ~= 'table' then
    error('preview keymap must be false or table', 3)
  end

  local lhs = spec.lhs
  if type(lhs) ~= 'string' then
    error('preview keymap lhs must be a non-empty string', 3)
  end
  lhs = vim.trim(lhs)
  if lhs == '' then
    error('preview keymap lhs must be a non-empty string', 3)
  end

  local mode = spec.mode
  if mode == nil then
    mode = 'n'
  elseif type(mode) == 'string' then
    mode = vim.trim(mode)
  end
  if mode ~= 'n' then
    error('preview keymap mode must be "n"', 3)
  end

  local opts = spec.opts or {}
  if type(opts) ~= 'table' then
    error('preview keymap opts must be a table', 3)
  end
  opts = vim.deepcopy(opts)
  if opts.desc ~= nil then
    if type(opts.desc) ~= 'string' then
      error('preview keymap opts.desc must be a non-empty string', 3)
    end
    opts.desc = vim.trim(opts.desc)
    if opts.desc == '' then
      error('preview keymap opts.desc must be a non-empty string', 3)
    end
  end

  return {
    lhs = lhs,
    mode = mode,
    opts = opts,
  }
end

local function snapshot_existing_keymap(lhs, mode)
  local info = vim.fn.maparg(lhs, mode, false, true)
  if type(info) ~= 'table' or vim.tbl_isempty(info) then
    return nil
  end

  return info
end

local function restore_keymap(map, mode)
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
    vim.keymap.set(mode, map.lhs, map.callback, opts)
    return
  end

  if type(map.rhs) ~= 'string' then
    error('preview keymap restore requires a string rhs', 2)
  end
  vim.api.nvim_set_keymap(mode, map.lhs, map.rhs, opts)
end

local function append_rollback_errors(err, rollback_errors)
  if #rollback_errors == 0 then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, table.concat(rollback_errors, '; '))
end

local function restore(instance)
  local _, preview = preview_state(instance)
  if preview.name == nil and preview.spec == nil and preview.flash_spec == nil then
    return true
  end
  if type(preview.name) ~= 'string' or type(preview.spec) ~= 'table' or type(preview.flash_spec) ~= 'table' then
    error('preview restore state is invalid', 3)
  end
  if preview.flash_spec_partial ~= nil and type(preview.flash_spec_partial) ~= 'boolean' then
    error('preview flash snapshot mode must be a boolean or nil', 3)
  end

  local read_ok, current = pcall(vim.api.nvim_get_hl, 0, { name = preview.name, create = false })
  if not read_ok then
    return false, current
  end
  local unchanged
  if preview.flash_spec_partial == true then
    unchanged = partial_flash_spec_matches(current, preview.flash_spec)
  else
    unchanged = vim.deep_equal(current or {}, preview.flash_spec)
  end
  if not unchanged then
    preview.flash_spec = nil
    preview.flash_spec_partial = false
    preview.name = nil
    preview.spec = nil
    return true
  end

  local ok, err = pcall(vim.api.nvim_set_hl, 0, preview.name, vim.deepcopy(preview.spec))
  if not ok then
    return false, err
  end
  preview.flash_spec = nil
  preview.flash_spec_partial = false
  preview.name = nil
  preview.spec = nil
  return true
end

local function stop_timer(instance)
  local _, preview = preview_state(instance)
  if not preview.timer then
    return
  end

  timers.stop(preview.timer)
  preview.timer = nil
end

local function cleanup_flash(instance)
  local errors = {}
  local stopped, stop_err = xpcall(function()
    stop_timer(instance)
  end, debug.traceback)
  if not stopped then
    errors[#errors + 1] = ('timer: %s'):format(tostring(stop_err))
  end

  local restore_called, restored, restore_err = xpcall(function()
    return restore(instance)
  end, debug.traceback)
  if not restore_called then
    errors[#errors + 1] = ('highlight: %s'):format(tostring(restored))
  elseif not restored then
    errors[#errors + 1] = ('highlight: %s'):format(tostring(restore_err or 'restore failed'))
  end
  return errors
end

local function run_keymap_action(action)
  local ok, err = xpcall(action, debug.traceback)
  if not ok then
    notify.error(('preview keymap failed: %s'):format(tostring(err)))
  end
end

local function current_result(instance, state)
  local results = result_list(state)
  if state.detail_index ~= nil then
    return results[positive_integer(state.detail_index, 'preview detail index')]
  end

  local list_index = state.list_cursor
  if list_index ~= nil then
    list_index = positive_integer(list_index, 'preview list cursor')
  end
  if list_index ~= nil and results[list_index] then
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

  local cleanup_errors = cleanup_flash(instance)
  if #cleanup_errors > 0 then
    notify.error(('preview cleanup failed: %s'):format(table.concat(cleanup_errors, '; ')))
    return
  end

  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = result.name, create = false })
  if not ok or not spec or vim.tbl_isempty(spec) then
    return
  end

  local flash_ok = pcall(vim.api.nvim_set_hl, 0, result.name, vim.deepcopy(preview_flash_spec))
  if not flash_ok then
    return
  end

  local flash_spec_ok, flash_spec = pcall(vim.api.nvim_get_hl, 0, { name = result.name, create = false })
  preview.flash_spec = vim.deepcopy(flash_spec_ok and flash_spec or preview_flash_spec)
  preview.flash_spec_partial = not flash_spec_ok or flash_spec == nil
  preview.name = result.name
  preview.spec = vim.deepcopy(spec)
  if not flash_spec_ok or not flash_spec then
    local restored, restore_err = restore(instance)
    if not restored then
      notify.error(('preview flash rollback failed: %s'):format(tostring(restore_err or 'restore failed')))
    end
    return
  end

  preview.token = (preview.token or 0) + 1
  local token = preview.token

  preview.timer = timers.once(
    preview_timeout_ms,
    vim.schedule_wrap(function()
      local _, current_preview = preview_state(instance)
      if current_preview.token ~= token then
        return
      end
      local errors = cleanup_flash(instance)
      if #errors > 0 then
        notify.error(('preview timer failed: %s'):format(table.concat(errors, '; ')))
      end
    end)
  )
  if not preview.timer then
    local restored, restore_err = restore(instance)
    if not restored then
      notify.error(('preview timer start rollback failed: %s'):format(tostring(restore_err or 'restore failed')))
    end
  end
end

--- Stop any pending preview timer and restore the original highlight immediately.
--- @param instance table The Instance object holding UI state
--- @return boolean ok True when no preview restore is pending or restore succeeded
--- @return string|nil err
function M.cleanup(instance)
  preview_state(instance)
  local errors = cleanup_flash(instance)
  if #errors > 0 then
    return false, table.concat(errors, '; ')
  end
  return true
end

--- Install the temporary global preview keymap for the workspace lifetime.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.install_keymap(instance)
  local _, preview = preview_state(instance)
  local keymap = preview_keymap()
  if keymap == nil then
    return
  end

  M.uninstall_keymap(instance)

  local map = {
    lhs = keymap.lhs,
    mode = keymap.mode,
    previous = snapshot_existing_keymap(keymap.lhs, keymap.mode),
  }

  local ok, err = xpcall(function()
    vim.keymap.set(keymap.mode, keymap.lhs, function()
      run_keymap_action(function()
        M.flash_current(instance)
      end)
    end, keymap.opts)
  end, debug.traceback)
  if not ok then
    local rollback_errors = {}
    local deleted, delete_err = pcall(vim.keymap.del, map.mode, map.lhs)
    if not deleted then
      local current = vim.fn.maparg(map.lhs, map.mode, false, true)
      if type(current) == 'table' and not vim.tbl_isempty(current) then
        rollback_errors[#rollback_errors + 1] = tostring(delete_err)
      end
    end
    local restored, restore_err = xpcall(function()
      restore_keymap(map.previous, map.mode)
    end, debug.traceback)
    if not restored then
      rollback_errors[#rollback_errors + 1] = tostring(restore_err)
    end
    error(append_rollback_errors(err, rollback_errors), 0)
  end

  preview.keymap = map
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
  if type(map.mode) ~= 'string' or map.mode == '' then
    error('preview keymap mode must be a non-empty string', 2)
  end

  local deleted, delete_err = pcall(vim.keymap.del, map.mode, map.lhs)
  if not deleted then
    local current = vim.fn.maparg(map.lhs, map.mode, false, true)
    if type(current) == 'table' and not vim.tbl_isempty(current) then
      error(delete_err, 0)
    end
  end
  restore_keymap(map.previous, map.mode)
  preview.keymap = nil
end

return M
