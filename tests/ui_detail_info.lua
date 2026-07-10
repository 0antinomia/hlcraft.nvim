local h = require('tests.helpers')
local scope = 'hlcraft ui detail info'

local config = require('hlcraft.config')
local detail_info = require('hlcraft.ui.detail')
local dynamic_model = require('hlcraft.dynamic.model')
local engine = require('hlcraft.engine.service')
local hlcraft = require('hlcraft')
local theme = require('hlcraft.ui.theme')

local persist_dir = h.temp_dir('hlcraft-ui-detail-info')
hlcraft.setup({
  persistence = {
    dir = persist_dir,
    reapply_events = {
      enabled = false,
    },
  },
  search = {
    debounce_ms = 0,
  },
})

local result = {
  name = 'HlcraftUiDetailInfoNormal',
  fg = '#111111',
  resolved_fg = '#111111',
  bg = '#222222',
  resolved_bg = '#222222',
  sp = '#333333',
}

local function virt_line_text(line)
  if type(line) ~= 'table' then
    error('detail info virtual line must be a table', 2)
  end
  local text = ''
  for _, chunk in ipairs(line) do
    if type(chunk) ~= 'table' or type(chunk[1]) ~= 'string' then
      error('detail info virtual line chunk text must be a string', 2)
    end
    text = text .. chunk[1]
  end
  return text
end

local function virt_line_with_label(lines, label)
  if type(lines) ~= 'table' then
    error('detail info virtual lines must be a table', 2)
  end
  local prefix = label .. ':'
  for _, line in ipairs(lines) do
    if virt_line_text(line):find(prefix, 1, true) == 1 then
      return line
    end
  end
  return nil
end

local detail_info_lines = detail_info.build_virt_lines(result, function()
  return theme.groups.value
end, 80)
h.assert_equal(detail_info_lines[2][1][2], theme.groups.section, 'detail info label lacks contrast', scope)
h.assert_equal(detail_info_lines[2][2][2], theme.groups.title, 'detail info name lacks title contrast', scope)
h.assert_equal(detail_info_lines[3][1][2], theme.groups.section, 'detail color label lacks contrast', scope)

local missing_result_ok = pcall(detail_info.build_virt_lines, nil, function()
  return theme.groups.value
end, 80)
h.assert_true(not missing_result_ok, 'detail info accepted missing result', scope)
local nameless_result_ok = pcall(detail_info.build_virt_lines, {}, function()
  return theme.groups.value
end, 80)
h.assert_true(not nameless_result_ok, 'detail info accepted nameless result', scope)
local invalid_highlighter_ok = pcall(detail_info.build_virt_lines, result, false, 80)
h.assert_true(not invalid_highlighter_ok, 'detail info accepted invalid highlighter callback', scope)
local invalid_width_ok = pcall(detail_info.build_virt_lines, result, function()
  return theme.groups.value
end, 12.5)
h.assert_true(not invalid_width_ok, 'detail info accepted fractional width', scope)
local invalid_link_chain_ok = pcall(detail_info.build_virt_lines, {
  name = 'HlcraftUiDetailInfoInvalidLinkChain',
  link_chain = { 'Source', false },
}, function()
  return theme.groups.value
end, 80)
h.assert_true(not invalid_link_chain_ok, 'detail info accepted invalid link chain entries', scope)
local non_table_link_chain_ok = pcall(detail_info.build_virt_lines, {
  name = 'HlcraftUiDetailInfoNonTableLinkChain',
  link_chain = false,
}, function()
  return theme.groups.value
end, 80)
h.assert_true(not non_table_link_chain_ok, 'detail info accepted non-table link chain', scope)
local sparse_link_chain_ok = pcall(detail_info.build_virt_lines, {
  name = 'HlcraftUiDetailInfoSparseLinkChain',
  link_chain = { [2] = 'Target' },
}, function()
  return theme.groups.value
end, 80)
h.assert_true(not sparse_link_chain_ok, 'detail info accepted sparse link chain', scope)
local invalid_blend_ok = pcall(detail_info.build_virt_lines, {
  name = 'HlcraftUiDetailInfoInvalidBlend',
  blend = '12',
}, function()
  return theme.groups.value
end, 80)
h.assert_true(not invalid_blend_ok, 'detail info accepted invalid blend metadata', scope)
local invalid_distance_ok = pcall(detail_info.build_virt_lines, {
  name = 'HlcraftUiDetailInfoInvalidDistance',
  distance = 0 / 0,
}, function()
  return theme.groups.value
end, 80)
h.assert_true(not invalid_distance_ok, 'detail info accepted invalid distance metadata', scope)

local style_line = virt_line_with_label(detail_info_lines, 'Style')
h.assert_true(style_line ~= nil, 'detail style line missing', scope)
h.assert_equal(style_line[1][2], theme.groups.section, 'detail style label lacks contrast', scope)

local metrics_line = virt_line_with_label(detail_info_lines, 'Metrics')
h.assert_true(metrics_line ~= nil, 'detail metrics line missing', scope)
h.assert_equal(metrics_line[2][2], theme.groups.muted, 'detail metrics label lacks muted contrast', scope)

local dynamic_ok, dynamic_err = engine.set_dynamic(
  'HlcraftUiDetailInfoNormal',
  'fg',
  dynamic_model.normalize_channel({
    version = 1,
    duration = 1000,
    loop = 'repeat',
    timeline = {
      { at = 0, color = 'base' },
    },
  })
)
h.assert_true(dynamic_ok, dynamic_err or 'detail info dynamic fixture did not set', scope)
local dynamic_detail_info_lines = detail_info.build_virt_lines(result, function()
  return theme.groups.value
end, 80)
local dynamic_colors_line = virt_line_with_label(dynamic_detail_info_lines, 'Colors')
local dynamic_token
for _, chunk in ipairs(dynamic_colors_line) do
  if chunk[1] == 'Dynamic' then
    dynamic_token = chunk
    break
  end
end
h.assert_true(dynamic_token ~= nil, 'detail info did not show dynamic color placeholder', scope)
h.assert_equal(dynamic_token[2], theme.groups.dynamic, 'detail info dynamic placeholder lacks contrast', scope)

local narrow_detail_info_lines = detail_info.build_virt_lines({
  name = 'HlcraftUiDetailInfoNarrow',
  fg = 'NONE',
  resolved_fg = 'NONE',
  bg = 'NONE',
  resolved_bg = 'NONE',
  sp = 'NONE',
  link_chain = {
    'HlcraftUiDetailInfoNarrow',
    'HlcraftUiDetailInfoLinkedTarget',
  },
}, function()
  return theme.groups.value
end, 40)
h.assert_true(
  vim.fn.strdisplaywidth(virt_line_with_label(narrow_detail_info_lines, 'Links')[2][1]) <= 32,
  'detail info link value ignored narrow width',
  scope
)

engine.clear('HlcraftUiDetailInfoNormal')
h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui detail info: OK')
