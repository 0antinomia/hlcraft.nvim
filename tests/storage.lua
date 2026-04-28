local h = require('tests.helpers')
local scope = 'hlcraft storage'

local config = require('hlcraft.config')
local storage = require('hlcraft.storage')
local codec = require('hlcraft.storage.codec')
local files = require('hlcraft.storage.files')

local persist_dir = h.temp_dir('hlcraft-storage')
vim.fn.mkdir(persist_dir, 'p')
config.setup({ persist_dir = persist_dir })

h.write_file(persist_dir .. '/manual.toml', {
  '# comment',
  '["ui.group"]',
  '"Normal Float" = { bg = "NONE", blend = 12, bold = true, fg = "#aabbcc", note = "quoted \\"value\\"" }',
  '"Line,WithComma" = { fg = "#010203", italic = false }',
})

local decoded = storage.load(persist_dir)
h.assert_equal(decoded.groups['Normal Float'], 'ui.group', 'quoted highlight group was not assigned to section', scope)
h.assert_equal(decoded.entries['Normal Float'].fg, '#aabbcc', 'string scalar did not parse', scope)
h.assert_equal(decoded.entries['Normal Float'].bg, 'NONE', 'NONE string did not parse', scope)
h.assert_equal(decoded.entries['Normal Float'].blend, 12, 'numeric scalar did not parse', scope)
h.assert_equal(decoded.entries['Normal Float'].bold, true, 'boolean scalar did not parse', scope)
h.assert_equal(decoded.entries['Normal Float'].note, 'quoted "value"', 'escaped string did not parse', scope)
h.assert_equal(decoded.groups['Line,WithComma'], 'ui.group', 'quoted key with comma did not parse', scope)
h.assert_equal(decoded.entries['Line,WithComma'].italic, false, 'false boolean scalar did not parse', scope)

h.write_file(persist_dir .. '/dynamic.toml', {
  '["dynamic.group"]',
  '"DynamicNormal" = { fg = "#101010", dyn_fg_mode = "rgb", dyn_fg_speed = 1500 }',
})

local dynamic_decoded = storage.load(persist_dir)
h.assert_equal(
  dynamic_decoded.entries.DynamicNormal.dynamic.fg.mode,
  'rgb',
  'dynamic fg mode did not load',
  scope
)
h.assert_equal(
  dynamic_decoded.entries.DynamicNormal.dynamic.fg.speed,
  1500,
  'dynamic fg speed did not load',
  scope
)
h.assert_true(
  dynamic_decoded.entries.DynamicNormal.dyn_fg_mode == nil,
  'flat dynamic key leaked after load',
  scope
)

local codec_data = codec.decode_lines({
  '["group"]',
  '"Normal" = { fg = "#ffffff", bg = "NONE" }',
})
h.assert_equal(codec_data.groups.Normal, 'group', 'codec.decode_lines did not assign group', scope)
h.assert_equal(codec_data.entries.Normal.fg, '#ffffff', 'codec.decode_lines did not parse entry', scope)

local encoded = table.concat(
  codec.encode_section('group', {
    Normal = { fg = '#ffffff', bg = 'NONE', bold = true },
  }),
  '\n'
)
h.assert_true(encoded:find('%["group"%]') ~= nil, 'codec.encode_section omitted section header', scope)
h.assert_true(
  encoded:find('"Normal" = { bg = "NONE", bold = true, fg = "#ffffff" }', 1, true) ~= nil,
  'codec.encode_section did not produce sorted inline table fields',
  scope
)

h.write_file(persist_dir .. '/stale.toml', {
  '["stale"]',
  '"Stale" = { fg = "#000000" }',
})

local save_ok, save_err = storage.save({
  Normal = { fg = '#111111' },
  Comment = {},
  DynamicNormal = {
    fg = '#101010',
    dynamic = {
      fg = { mode = 'rgb', speed = 1500 },
      bg = { mode = 'breath', speed = 2500 },
    },
  },
}, {
  Normal = 'main/group',
  Comment = 'group-only',
  DynamicNormal = 'dynamic/group',
}, persist_dir)
h.assert_true(save_ok, save_err or 'storage.save failed', scope)

local main_path = files.file_path(persist_dir, 'main/group')
local group_only_path = files.file_path(persist_dir, 'group-only')
h.assert_file_exists(main_path, 'sanitized group file was not created', scope)
h.assert_file_exists(group_only_path, 'group-only file was not created', scope)
h.assert_file_missing(persist_dir .. '/stale.toml', 'stale TOML file was not removed', scope)
h.assert_equal(
  storage.file_path('main/group'),
  main_path,
  'storage.file_path did not use configured persist_dir',
  scope
)

local saved = storage.load(persist_dir)
h.assert_equal(saved.entries.Normal.fg, '#111111', 'saved override did not reload', scope)
h.assert_equal(saved.groups.Normal, 'main/group', 'saved override group did not reload', scope)
h.assert_true(saved.entries.Comment ~= nil, 'group-only save did not reload entry', scope)
h.assert_equal(next(saved.entries.Comment), nil, 'group-only save persisted fields', scope)
h.assert_equal(saved.groups.Comment, 'group-only', 'group-only save did not reload group', scope)
h.assert_equal(
  saved.entries.DynamicNormal.dynamic.fg.mode,
  'rgb',
  'saved dynamic fg mode did not reload',
  scope
)
h.assert_equal(
  saved.entries.DynamicNormal.dynamic.bg.speed,
  2500,
  'saved dynamic bg speed did not reload',
  scope
)
local dynamic_content = h.read_file(files.file_path(persist_dir, 'dynamic/group'))
h.assert_true(
  dynamic_content:find('dyn_fg_mode = "rgb"', 1, true) ~= nil,
  'saved TOML did not include dyn_fg_mode',
  scope
)
h.assert_true(
  dynamic_content:find('dyn_bg_speed = 2500', 1, true) ~= nil,
  'saved TOML did not include dyn_bg_speed',
  scope
)

vim.fn.delete(persist_dir, 'rf')
print('hlcraft storage: OK')
