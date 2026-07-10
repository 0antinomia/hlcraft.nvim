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

  local placeholder_mark_id = marks[1][1]
  instance.state.placeholder_marks.underdashed = false
  local invalid_mark_ok = pcall(placeholders.refresh, instance)
  h.assert_true(not invalid_mark_ok, 'placeholders accepted invalid extmark id', scope)
  instance.state.placeholder_marks.underdashed = placeholder_mark_id

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'false' })
  local original_del_extmark = vim.api.nvim_buf_del_extmark
  vim.api.nvim_buf_del_extmark = function(target_buf, target_ns, mark_id)
    if target_buf == buf and target_ns == ns and mark_id == placeholder_mark_id then
      error('placeholder delete failed')
    end
    return original_del_extmark(target_buf, target_ns, mark_id)
  end
  local failed_delete_ok = pcall(placeholders.refresh, instance)
  vim.api.nvim_buf_del_extmark = original_del_extmark
  local failed_delete_mark = instance.state.placeholder_marks.underdashed
  placeholders.refresh(instance)
  marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  if #marks > 0 then
    original_del_extmark(buf, ns, placeholder_mark_id)
  end
  h.assert_true(not failed_delete_ok, 'placeholder refresh accepted failed extmark cleanup', scope)
  h.assert_equal(
    failed_delete_mark,
    placeholder_mark_id,
    'failed placeholder cleanup dropped the live extmark id',
    scope
  )
  h.assert_equal(#marks, 0, 'placeholder cleanup retry kept the extmark', scope)
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
  local non_sequence_geometry_ok = pcall(placeholders.refresh, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-placeholders-nonsequential-test'),
    state = {
      buf = buf,
      geometry = {
        inputs = {
          [2] = { name = 'late', kind = 'name', line = 1 },
        },
      },
      placeholder_marks = {},
    },
  })
  h.assert_true(not non_sequence_geometry_ok, 'placeholders accepted non-sequence geometry inputs', scope)
  local missing_instance_ok = pcall(placeholders.refresh, nil)
  h.assert_true(not missing_instance_ok, 'placeholders accepted missing instance', scope)
  local missing_marks_ok = pcall(placeholders.refresh, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-placeholders-missing-marks-test'),
    state = {
      buf = buf,
      geometry = {
        inputs = {},
      },
    },
  })
  h.assert_true(not missing_marks_ok, 'placeholders accepted missing mark state', scope)
  local missing_namespace_ok = pcall(placeholders.refresh, {
    state = {
      buf = buf,
      geometry = {
        inputs = {},
      },
      placeholder_marks = {},
    },
  })
  h.assert_true(not missing_namespace_ok, 'placeholders accepted missing namespace', scope)
  local invalid_detail_index_ok = pcall(placeholders.refresh, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-placeholders-invalid-detail-test'),
    state = {
      buf = buf,
      detail_index = 0,
      geometry = {
        inputs = {
          { key = 'fg', name = 'field', kind = 'detail', line = 1 },
        },
      },
      placeholder_marks = {},
      results = {},
    },
  })
  h.assert_true(not invalid_detail_index_ok, 'placeholders accepted invalid detail index', scope)
  local invalid_line_ok = pcall(placeholders.refresh, {
    ns = vim.api.nvim_create_namespace('hlcraft-ui-placeholders-invalid-line-test'),
    state = {
      buf = buf,
      geometry = {
        inputs = {
          { name = 'name', kind = 'name', line = 0 },
        },
      },
      placeholder_marks = {},
    },
  })
  h.assert_true(not invalid_line_ok, 'placeholders accepted invalid field line', scope)
end)

print('hlcraft ui placeholders: OK')
