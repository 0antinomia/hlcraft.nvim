local actions = require('hlcraft.ui.actions')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local commands = require('hlcraft.ui.keymap_commands')
local navigation = require('hlcraft.ui.navigation')
local ui_fields = require('hlcraft.ui.fields')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')

local M = {}
local unpack = unpack or table.unpack

local function keymap_opts(opts, extra)
  if extra == nil then
    return opts
  end
  return vim.tbl_extend('force', opts, extra)
end

local function set_keymap(mode, lhs, callback, opts, extra)
  vim.keymap.set(mode, lhs, callback, keymap_opts(opts, extra))
end

local function map(mode, lhs, run, extra)
  return {
    mode = mode,
    lhs = lhs,
    run = run,
    opts = extra,
  }
end

local function call(fn, ...)
  local args = { ... }
  return function(instance)
    return fn(instance, unpack(args))
  end
end

local function jump_to_edge(instance, edge)
  local rows = navigation.allowed_rows(instance)
  if #rows == 0 then
    return
  end

  navigation.jump_to_row(instance, edge == 'last' and rows[#rows] or rows[1], false)
end

local function jump_first(instance)
  jump_to_edge(instance, 'first')
end

local function jump_last_or_adjust_green(instance)
  if commands.adjust_color(instance, 'g', ui_fields.color_step) then
    return
  end
  jump_to_edge(instance, 'last')
end

local function save_or_feed(instance)
  if not instance.state.detail_index then
    commands.feed_normal_key(instance, 's')
    return
  end
  actions.dispatch(instance, 'save')
end

local function adjust_dynamic_or_small_blend(delta)
  return function(instance)
    if commands.adjust_dynamic_color(instance, delta) then
      return
    end
    commands.adjust_blend(instance, delta * ui_fields.blend_small_step, delta > 0 and '+' or '-')
  end
end

local function input_or_jump(instance)
  if commands.input_current_editor_field(instance) then
    return
  end
  commands.jump_to_input_at_cursor(instance, true)
end

local function raw_json_or_feed(instance)
  if commands.open_dynamic_raw_json(instance) then
    return
  end
  commands.feed_normal_key(instance, 'e')
end

local function append_or_feed(instance)
  if commands.jump_to_input_at_cursor(instance, true) then
    return
  end
  commands.feed_normal_key(instance, 'a')
end

local function activate(instance)
  vim.schedule(function()
    actions.dispatch(instance, 'activate')
  end)
  return ''
end

local workspace_keymaps = {
  map('n', '<Esc>', actions.back),
  map('n', 'q', actions.back),
  map('n', '?', lifecycle.toggle_help),
  map('n', 'j', call(navigation.move_interactive, 1)),
  map('n', 'k', call(navigation.move_interactive, -1)),
  map('n', '<Down>', call(navigation.move_interactive, 1)),
  map('n', '<Up>', call(navigation.move_interactive, -1)),
  map('n', 'gg', jump_first),
  map('n', 'G', jump_last_or_adjust_green),
  map('n', '<Tab>', buffer_fields.goto_next),
  map('n', '<S-Tab>', buffer_fields.goto_prev),
  map('n', 'J', call(commands.run_search_action, 'next_result')),
  map('n', 'K', call(commands.run_search_action, 'prev_result')),
  map('n', 'gr', call(commands.run_search_action, 'first_result')),
  map('n', 'p', call(buffer_fields.paste_below, false)),
  map('x', 'p', call(buffer_fields.paste_below, true)),
  map('n', 'P', call(buffer_fields.paste_above, false)),
  map('x', 'P', call(buffer_fields.paste_above, true)),
  map('n', 'o', buffer_fields.open_below),
  map('n', 's', save_or_feed),
  map('n', 'r', call(commands.adjust_color, 'r', -ui_fields.color_step, 'r')),
  map('n', 'R', call(commands.adjust_color, 'r', ui_fields.color_step, 'R')),
  map('n', 'g', call(commands.adjust_color, 'g', -ui_fields.color_step, 'g'), { nowait = false }),
  map('n', 'b', call(commands.adjust_color, 'b', -ui_fields.color_step, 'b')),
  map('n', 'B', call(commands.adjust_color, 'b', ui_fields.color_step, 'B')),
  map('n', 'n', call(commands.set_color, 'NONE', 'n')),
  map('n', 'd', commands.toggle_dynamic_color),
  map('n', 'm', call(commands.cycle_dynamic_preset, 'm')),
  map('n', '[', call(commands.feed_normal_key, '[')),
  map('n', ']', call(commands.feed_normal_key, ']')),
  map('n', '+', adjust_dynamic_or_small_blend(1)),
  map('n', '-', adjust_dynamic_or_small_blend(-1)),
  map('n', '>', call(commands.adjust_blend, ui_fields.blend_large_step, '>')),
  map('n', '<', call(commands.adjust_blend, -ui_fields.blend_large_step, '<')),
  map('n', 'u', call(commands.unset_blend, 'u')),
  map('n', 'i', input_or_jump),
  map('n', 'e', raw_json_or_feed),
  map('n', 'x', call(commands.feed_normal_key, 'x')),
  map('n', 'a', append_or_feed),
  map({ 'n', 'i' }, '<CR>', activate, { expr = true }),
}

local function install_specs(instance, opts)
  for _, spec in ipairs(workspace_keymaps) do
    local mode, lhs, run, extra = spec.mode, spec.lhs, spec.run, spec.opts
    set_keymap(mode, lhs, function()
      return run(instance)
    end, opts, extra)
  end
end

--- Set up insert and normal mode keymaps that protect input field boundaries
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle to attach keymaps to
--- @return nil
local function setup_input_boundary_keys(instance, buf)
  local insert_opts = { buffer = buf, silent = true }
  local normal_opts = { buffer = buf, silent = true, nowait = true }

  for _, spec in ipairs({
    { '<BS>', buffer_fields.should_block_backward_delete },
    { '<C-h>', buffer_fields.should_block_backward_delete },
    { '<C-w>', buffer_fields.should_block_backward_delete },
    { '<C-u>', buffer_fields.should_block_backward_delete },
    { '<Del>', buffer_fields.should_block_forward_delete },
  }) do
    local key, should_block = spec[1], spec[2]
    set_keymap('i', key, function()
      if should_block(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
    end, insert_opts)
  end

  for _, lhs in ipairs({ 'X', 'S', 'D', 'c', 'C', 'I', 'A', 'O' }) do
    local key = lhs
    set_keymap('n', key, function()
      commands.feed_normal_key(instance, key)
    end, normal_opts)
  end
end

--- Set up all workspace keymaps for navigation, search, detail editing, and input cycling
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle to attach keymaps to
--- @return nil
function M.setup_workspace_keymaps(instance, buf)
  local opts = { buffer = buf, silent = true, nowait = true }

  install_specs(instance, opts)
  setup_input_boundary_keys(instance, buf)
end

return M
