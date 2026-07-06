local h = require('tests.helpers')
local scope = 'hlcraft ui render list'

local list_renderer = require('hlcraft.ui.render.list')

local result = {
  name = 'HlcraftUiRenderListNormal',
  fg = '#111111',
  bg = '#222222',
  sp = '#333333',
}

local list_lines, list_selectable = list_renderer.build({ state = { results = { result } } }, 80)
h.assert_true(#list_lines >= 3, 'result list renderer did not produce rows', scope)
h.assert_equal(list_selectable[3], 1, 'result list renderer did not register selectable row', scope)
local collision_lines, _, collision_cells = list_renderer.build({
  state = {
    results = {
      {
        name = 'HlcraftUiRenderListNONEDynamicName',
        fg = 'NONE',
        bg = '#222222',
        sp = '#333333',
      },
    },
  },
}, 80)
h.assert_true(collision_cells[3].fg.start_col > 0, 'result list renderer did not expose fg cell geometry', scope)
h.assert_true(
  collision_cells[3].fg.start_col > collision_lines[3]:find('NONE', 1, true),
  'result list renderer fg cell geometry pointed at the result name',
  scope
)
local empty_list_lines = list_renderer.build({ state = { results = {}, name_query = '', color_query = '' } }, 80)
h.assert_equal(
  empty_list_lines[3],
  'Use Name and Color search together to narrow highlight groups',
  'result list renderer lost empty message',
  scope
)
local invalid_instance_ok = pcall(list_renderer.build, nil, 80)
h.assert_true(not invalid_instance_ok, 'result list renderer accepted missing instance', scope)
local invalid_results_ok = pcall(list_renderer.build, { state = {} }, 80)
h.assert_true(not invalid_results_ok, 'result list renderer accepted missing results', scope)
local sparse_results_ok = pcall(list_renderer.build, { state = { results = { [2] = result } } }, 80)
h.assert_true(not sparse_results_ok, 'result list renderer accepted sparse results', scope)
local invalid_width_ok = pcall(list_renderer.build, { state = { results = {} } }, math.huge)
h.assert_true(not invalid_width_ok, 'result list renderer accepted non-finite width', scope)
local invalid_result_ok = pcall(list_renderer.build, { state = { results = { {} } } }, 80)
h.assert_true(not invalid_result_ok, 'result list renderer accepted nameless result', scope)
local invalid_color_ok = pcall(list_renderer.build, { state = { results = { { name = 'Normal', fg = false } } } }, 80)
h.assert_true(not invalid_color_ok, 'result list renderer accepted non-string color', scope)

print('hlcraft ui render list: OK')
