local h = require('tests.helpers')
local scope = 'hlcraft ui detail info'

local config = require('hlcraft.config')
local detail_info = require('hlcraft.ui.detail')
local hlcraft = require('hlcraft')
local theme = require('hlcraft.ui.theme')

local persist_dir = h.temp_dir('hlcraft-ui-detail-info')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
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
  local text = ''
  for _, chunk in ipairs(line or {}) do
    text = text .. tostring(chunk[1] or '')
  end
  return text
end

local function virt_line_with_label(lines, label)
  local prefix = label .. ':'
  for _, line in ipairs(lines or {}) do
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

local style_line = virt_line_with_label(detail_info_lines, 'Style')
h.assert_true(style_line ~= nil, 'detail style line missing', scope)
h.assert_equal(style_line[1][2], theme.groups.section, 'detail style label lacks contrast', scope)

local metrics_line = virt_line_with_label(detail_info_lines, 'Metrics')
h.assert_true(metrics_line ~= nil, 'detail metrics line missing', scope)
h.assert_equal(metrics_line[2][2], theme.groups.muted, 'detail metrics label lacks muted contrast', scope)

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

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui detail info: OK')
