local h = require('tests.helpers')
local scope = 'hlcraft ui unsaved prompt'

local prompt = require('hlcraft.ui.scene.unsaved_prompt')

local missing_prompt_state_ok = pcall(prompt.close, {
  state = {},
})
h.assert_true(not missing_prompt_state_ok, 'unsaved prompt accepted missing state schema', scope)

local instance = {
  ns = vim.api.nvim_create_namespace('hlcraft-ui-unsaved-prompt-test'),
  state = {
    unsaved_prompt = {},
  },
}

prompt.open(instance, 'HlcraftUiUnsavedPrompt', function() end)

local buf = instance.state.unsaved_prompt.buf
local win = instance.state.unsaved_prompt.win
h.assert_true(vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not created', scope)
h.assert_true(vim.api.nvim_win_is_valid(win), 'prompt window was not created', scope)
h.assert_equal(
  table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
  table.concat(prompt.lines, '\n'),
  'prompt lines changed',
  scope
)
h.assert_true(vim.tbl_contains(prompt.lines, '[s] save draft'), 'prompt save keycap line missing', scope)
h.assert_true(vim.tbl_contains(prompt.lines, '[c/q/Esc] cancel'), 'prompt cancel keycap line missing', scope)

local mappings = {}
for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
  mappings[item.lhs] = true
end
for _, lhs in ipairs({ 's', 'd', 'c', 'q', '<Esc>' }) do
  h.assert_true(mappings[lhs], ('missing prompt mapping %s'):format(lhs), scope)
end

local marks = vim.api.nvim_buf_get_extmarks(buf, instance.ns, 0, -1, { details = true })
h.assert_true(#marks > 0, 'prompt did not apply visual hierarchy highlights', scope)

prompt.close(instance)
h.assert_true(instance.state.unsaved_prompt.buf == nil, 'prompt buffer handle was not cleared', scope)
h.assert_true(instance.state.unsaved_prompt.win == nil, 'prompt window handle was not cleared', scope)
h.assert_true(not vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not deleted', scope)

print('hlcraft ui unsaved prompt: OK')
