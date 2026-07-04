local h = require('tests.helpers')
local scope = 'hlcraft ui placeholders'

local placeholders = require('hlcraft.ui.render.placeholders')
local theme = require('hlcraft.ui.theme')

h.with_temp_buf(function(buf)
  local ns = vim.api.nvim_create_namespace('hlcraft-ui-placeholders-test')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })

  local instance = {
    ns = ns,
    state = {
      buf = buf,
      detail_index = 1,
      geometry = {
        inputs = {
          { key = 'underdashed', name = 'field', kind = 'detail', line = 1 },
        },
      },
      placeholder_marks = {},
      results = {
        {
          name = 'HlcraftUiPlaceholders',
          underdashed = true,
        },
      },
    },
  }

  placeholders.refresh(instance)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  h.assert_equal(#marks, 1, 'extended style placeholder was not created', scope)
  h.assert_equal(marks[1][4].virt_text[1][1], 'true', 'extended style placeholder value changed', scope)
  h.assert_equal(marks[1][4].virt_text[1][2], theme.groups.muted, 'placeholder highlight changed', scope)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'false' })
  placeholders.refresh(instance)
  marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  h.assert_equal(#marks, 0, 'placeholder was not cleared after input text', scope)
end)

h.with_temp_buf(function(buf)
  local invalid_geometry_ok = pcall(placeholders.refresh, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-placeholders-invalid-test'),
    state = {
      buf = buf,
      geometry = {},
      placeholder_marks = {},
    },
  })
  h.assert_true(not invalid_geometry_ok, 'placeholders accepted missing geometry inputs', scope)
end)

print('hlcraft ui placeholders: OK')
