local h = require('tests.helpers')
local scope = 'hlcraft ui render search'

local search_renderer = require('hlcraft.ui.render.search')
local theme = require('hlcraft.ui.theme')
local ui_state = require('hlcraft.ui.state')

local result = {
  name = 'HlcraftUiRenderSearchNormal',
  fg = '#111111',
  bg = '#222222',
  sp = '#333333',
}

h.with_temp_buf(function(buf)
  local instance = {
    id = 'ui-render-search-test',
    ns = vim.api.nvim_create_namespace('hlcraft-ui-render-search-test'),
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      results = { result },
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  search_renderer.render(instance)
  h.assert_equal(instance.state.geometry.result_lines[7], 1, 'search renderer did not register result row', scope)
  local rendered = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  h.assert_true(rendered:find(result.name, 1, true) ~= nil, 'search renderer did not render result name', scope)

  local missing_instance_ok = pcall(search_renderer.render, nil)
  h.assert_true(not missing_instance_ok, 'search renderer accepted missing instance', scope)
  local missing_results_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-missing-results-test',
    ns = instance.ns,
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      dynamic_preview = ui_state.dynamic_preview(),
    },
  })
  h.assert_true(not missing_results_ok, 'search renderer accepted missing results', scope)
  local sparse_results_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-sparse-results-test',
    ns = instance.ns,
    input_label_hl = theme.groups.label,
    state = {
      results = {
        [2] = result,
      },
    },
  })
  h.assert_true(not sparse_results_ok, 'search renderer accepted sparse results', scope)
  local missing_namespace_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-missing-namespace-test',
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      results = { result },
      dynamic_preview = ui_state.dynamic_preview(),
    },
  })
  h.assert_true(not missing_namespace_ok, 'search renderer accepted missing namespace', scope)
  local invalid_color_ok = pcall(search_renderer.render, {
    id = 'ui-render-search-invalid-color-test',
    ns = instance.ns,
    input_label_hl = theme.groups.label,
    state = {
      buf = buf,
      name_query = '',
      color_query = '',
      results = {
        {
          name = 'InvalidColorResult',
          fg = false,
        },
      },
      dynamic_preview = ui_state.dynamic_preview(),
    },
  })
  h.assert_true(not invalid_color_ok, 'search renderer accepted invalid result color', scope)
end, { current = true })

print('hlcraft ui render search: OK')
