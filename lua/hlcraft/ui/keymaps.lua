local input_actions = require('hlcraft.ui.input.actions')
local input_model = require('hlcraft.ui.input.model')
local navigation = require('hlcraft.ui.navigation')
local results_state = require('hlcraft.ui.state.results')
local detail_form_state = require('hlcraft.ui.state.detail_form')
local workspace = require('hlcraft.ui.workspace')

local M = {}

--- Set up insert and normal mode keymaps that protect input field boundaries
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle to attach keymaps to
--- @return nil
function M.setup_input_boundary_keys(instance, buf)
  local function setup_deletion(key, should_block)
    vim.keymap.set('i', key, function()
      if should_block(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
    end, { buffer = buf, silent = true })
  end

  setup_deletion('<BS>', input_actions.should_block_backward_delete)
  setup_deletion('<C-h>', input_actions.should_block_backward_delete)
  setup_deletion('<C-w>', input_actions.should_block_backward_delete)
  setup_deletion('<C-u>', input_actions.should_block_backward_delete)
  setup_deletion('<Del>', input_actions.should_block_forward_delete)

  for _, lhs in ipairs({ 'x', 'X', 's', 'S', 'd', 'D', 'c', 'C' }) do
    vim.keymap.set('n', lhs, function()
      local win = workspace.get_win(instance)
      if not workspace.is_valid_win(win) then
        return
      end
      if results_state.is_on_row(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
    end, { buffer = buf, silent = true, nowait = true })
  end

  for _, lhs in ipairs({ 'I', 'A', 'O', 'R' }) do
    vim.keymap.set('n', lhs, function()
      if results_state.is_on_row(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
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
    instance:quit_or_back()
  end, opts)
  vim.keymap.set('n', 'q', function()
    instance:quit_or_back()
  end, opts)
  vim.keymap.set('n', '?', function()
    workspace.toggle_help(instance)
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
    local rows = navigation.allowed_rows(instance)
    if #rows > 0 then
      navigation.jump_to_row(instance, rows[#rows], false)
    end
  end, opts)
  vim.keymap.set('n', '<Tab>', function()
    input_actions.goto_next_input(instance)
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    input_actions.goto_prev_input(instance)
  end, opts)
  vim.keymap.set('n', 'J', function()
    results_state.goto_offset(instance, 1)
  end, opts)
  vim.keymap.set('n', 'K', function()
    results_state.goto_offset(instance, -1)
  end, opts)
  vim.keymap.set('n', 'gr', function()
    results_state.goto_first(instance)
  end, opts)
  vim.keymap.set('n', 'p', function()
    input_actions.paste_below(instance, false)
  end, opts)
  vim.keymap.set('x', 'p', function()
    input_actions.paste_below(instance, true)
  end, opts)
  vim.keymap.set('n', 'P', function()
    input_actions.paste_above(instance, false)
  end, opts)
  vim.keymap.set('x', 'P', function()
    input_actions.paste_above(instance, true)
  end, opts)
  vim.keymap.set('n', 'o', function()
    input_actions.open_below(instance)
  end, opts)
  vim.keymap.set('n', 'i', function()
    local win = workspace.get_win(instance)
    if not workspace.is_valid_win(win) then
      return
    end
    local field = input_model.get_input_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
    if field then
      navigation.jump_to_row(instance, field.line, true)
    end
  end, opts)
  vim.keymap.set('n', 'a', function()
    local win = workspace.get_win(instance)
    if not workspace.is_valid_win(win) then
      return
    end
    local field = input_model.get_input_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
    if field then
      navigation.jump_to_row(instance, field.line, true)
    end
  end, opts)

  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    vim.schedule(function()
      local win = workspace.get_win(instance)
      local row = workspace.is_valid_win(win) and vim.api.nvim_win_get_cursor(win)[1] or 0
      local area = input_model.current_area(instance, row)
      if instance.state.detail_index then
        detail_form_state.apply(instance)
      elseif area == 'results' then
        results_state.open_detail(instance)
      else
        if vim.fn.mode():lower():find('i') then
          vim.cmd('stopinsert')
        end
        input_model.sync_queries_from_buffer(instance)
        instance:rerender()
        if #instance.state.results > 0 then
          local target_line = nil
          for _, entry in ipairs(results_state.rows(instance)) do
            if entry.index == instance.state.list_cursor then
              target_line = entry.line
              break
            end
          end
          if target_line then
            navigation.jump_to_row(instance, target_line, false)
          else
            results_state.goto_first(instance)
          end
        end
      end
    end)
    return ''
  end, vim.tbl_extend('force', opts, { expr = true }))

  M.setup_input_boundary_keys(instance, buf)
end

return M
