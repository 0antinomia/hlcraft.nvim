local actions = require('hlcraft.ui.actions')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local commands = require('hlcraft.ui.keymap_commands')
local navigation = require('hlcraft.ui.navigation')
local ui_fields = require('hlcraft.ui.fields')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')

local M = {}

--- Set up insert and normal mode keymaps that protect input field boundaries
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle to attach keymaps to
--- @return nil
local function setup_input_boundary_keys(instance, buf)
  local function setup_deletion(key, should_block)
    vim.keymap.set('i', key, function()
      if should_block(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
    end, { buffer = buf, silent = true })
  end

  setup_deletion('<BS>', buffer_fields.should_block_backward_delete)
  setup_deletion('<C-h>', buffer_fields.should_block_backward_delete)
  setup_deletion('<C-w>', buffer_fields.should_block_backward_delete)
  setup_deletion('<C-u>', buffer_fields.should_block_backward_delete)
  setup_deletion('<Del>', buffer_fields.should_block_forward_delete)

  for _, lhs in ipairs({ 'X', 'S', 'D', 'c', 'C' }) do
    vim.keymap.set('n', lhs, function()
      commands.feed_normal_key(instance, lhs)
    end, { buffer = buf, silent = true, nowait = true })
  end

  for _, lhs in ipairs({ 'I', 'A', 'O' }) do
    vim.keymap.set('n', lhs, function()
      commands.feed_normal_key(instance, lhs)
    end, { buffer = buf, silent = true, nowait = true })
  end
end

--- Set up all workspace keymaps for navigation, search, detail editing, and input cycling
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle to attach keymaps to
--- @return nil
function M.setup_workspace_keymaps(instance, buf)
  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set('n', '<Esc>', function()
    actions.back(instance)
  end, opts)
  vim.keymap.set('n', 'q', function()
    actions.back(instance)
  end, opts)
  vim.keymap.set('n', '?', function()
    lifecycle.toggle_help(instance)
  end, opts)
  vim.keymap.set('n', 'j', function()
    navigation.move_interactive(instance, 1)
  end, opts)
  vim.keymap.set('n', 'k', function()
    navigation.move_interactive(instance, -1)
  end, opts)
  vim.keymap.set('n', '<Down>', function()
    navigation.move_interactive(instance, 1)
  end, opts)
  vim.keymap.set('n', '<Up>', function()
    navigation.move_interactive(instance, -1)
  end, opts)
  vim.keymap.set('n', 'gg', function()
    local rows = navigation.allowed_rows(instance)
    if #rows > 0 then
      navigation.jump_to_row(instance, rows[1], false)
    end
  end, opts)
  vim.keymap.set('n', 'G', function()
    if commands.adjust_color(instance, 'g', ui_fields.color_step) then
      return
    end
    local rows = navigation.allowed_rows(instance)
    if #rows > 0 then
      navigation.jump_to_row(instance, rows[#rows], false)
    end
  end, opts)
  vim.keymap.set('n', '<Tab>', function()
    buffer_fields.goto_next(instance)
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    buffer_fields.goto_prev(instance)
  end, opts)
  vim.keymap.set('n', 'J', function()
    commands.run_search_action(instance, 'next_result')
  end, opts)
  vim.keymap.set('n', 'K', function()
    commands.run_search_action(instance, 'prev_result')
  end, opts)
  vim.keymap.set('n', 'gr', function()
    commands.run_search_action(instance, 'first_result')
  end, opts)
  vim.keymap.set('n', 'p', function()
    buffer_fields.paste_below(instance, false)
  end, opts)
  vim.keymap.set('x', 'p', function()
    buffer_fields.paste_below(instance, true)
  end, opts)
  vim.keymap.set('n', 'P', function()
    buffer_fields.paste_above(instance, false)
  end, opts)
  vim.keymap.set('x', 'P', function()
    buffer_fields.paste_above(instance, true)
  end, opts)
  vim.keymap.set('n', 'o', function()
    buffer_fields.open_below(instance)
  end, opts)
  vim.keymap.set('n', 's', function()
    if not instance.state.detail_index then
      commands.feed_normal_key(instance, 's')
      return
    end
    actions.dispatch(instance, 'save')
  end, opts)
  vim.keymap.set('n', 'r', function()
    commands.adjust_color(instance, 'r', -ui_fields.color_step, 'r')
  end, opts)
  vim.keymap.set('n', 'R', function()
    commands.adjust_color(instance, 'r', ui_fields.color_step, 'R')
  end, opts)
  vim.keymap.set('n', 'g', function()
    commands.adjust_color(instance, 'g', -ui_fields.color_step, 'g')
  end, vim.tbl_extend('force', opts, { nowait = false }))
  vim.keymap.set('n', 'b', function()
    commands.adjust_color(instance, 'b', -ui_fields.color_step, 'b')
  end, opts)
  vim.keymap.set('n', 'B', function()
    commands.adjust_color(instance, 'b', ui_fields.color_step, 'B')
  end, opts)
  vim.keymap.set('n', 'n', function()
    commands.set_color(instance, 'NONE', 'n')
  end, opts)
  vim.keymap.set('n', 'd', function()
    commands.toggle_dynamic_color(instance)
  end, opts)
  vim.keymap.set('n', 'm', function()
    commands.cycle_dynamic_preset(instance, 'm')
  end, opts)
  vim.keymap.set('n', '[', function()
    commands.feed_normal_key(instance, '[')
  end, opts)
  vim.keymap.set('n', ']', function()
    commands.feed_normal_key(instance, ']')
  end, opts)
  vim.keymap.set('n', '+', function()
    if commands.adjust_dynamic_color(instance, 1) then
      return
    end
    commands.adjust_blend(instance, ui_fields.blend_small_step, '+')
  end, opts)
  vim.keymap.set('n', '-', function()
    if commands.adjust_dynamic_color(instance, -1) then
      return
    end
    commands.adjust_blend(instance, -ui_fields.blend_small_step, '-')
  end, opts)
  vim.keymap.set('n', '>', function()
    commands.adjust_blend(instance, ui_fields.blend_large_step, '>')
  end, opts)
  vim.keymap.set('n', '<', function()
    commands.adjust_blend(instance, -ui_fields.blend_large_step, '<')
  end, opts)
  vim.keymap.set('n', 'u', function()
    commands.unset_blend(instance, 'u')
  end, opts)
  vim.keymap.set('n', 'i', function()
    if commands.input_current_editor_field(instance) then
      return
    end
    commands.jump_to_input_at_cursor(instance, true)
  end, opts)
  vim.keymap.set('n', 'e', function()
    if commands.open_dynamic_raw_json(instance) then
      return
    end
    commands.feed_normal_key(instance, 'e')
  end, opts)
  vim.keymap.set('n', 'x', function()
    commands.feed_normal_key(instance, 'x')
  end, opts)
  vim.keymap.set('n', 'a', function()
    if commands.jump_to_input_at_cursor(instance, true) then
      return
    end
    commands.feed_normal_key(instance, 'a')
  end, opts)

  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    vim.schedule(function()
      actions.dispatch(instance, 'activate')
    end)
    return ''
  end, vim.tbl_extend('force', opts, { expr = true }))

  setup_input_boundary_keys(instance, buf)
end

return M
