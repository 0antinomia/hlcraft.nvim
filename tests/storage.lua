local h = require('tests.helpers')
local scope = 'hlcraft storage'

local config = require('hlcraft.config')
local files = require('hlcraft.persistence.files')
local storage = require('hlcraft.storage')

local persist_dir = h.temp_dir('hlcraft-storage')
vim.fn.mkdir(persist_dir, 'p')
config.setup({ persist_dir = persist_dir })

h.write_file(persist_dir .. '/manual.toml', {
  '# comment',
  '["ui.group"]',
  '"Normal Float" = { bg = "NONE", blend = 12, bold = true, fg = "#aabbcc" }',
})

local decoded = storage.load(persist_dir)
h.assert_equal(decoded.groups['Normal Float'], 'ui.group', 'manual TOML group did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].fg, '#aabbcc', 'manual TOML fg did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].bg, 'NONE', 'manual TOML NONE did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].blend, 12, 'manual TOML number did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].bold, true, 'manual TOML boolean did not load', scope)

local symlink_target = persist_dir .. '-linked-target.toml'
vim.fn.delete(symlink_target, 'rf')
h.write_file(symlink_target, {
  '["linked.group"]',
  '"LinkedNormal" = { fg = "#123456" }',
})
local symlink_ok, symlink_err = vim.uv.fs_symlink(symlink_target, persist_dir .. '/linked.toml')
h.assert_true(symlink_ok, ('failed to create symlink TOML fixture: %s'):format(tostring(symlink_err)), scope)
local symlink_decoded = storage.load(persist_dir)
h.assert_equal(symlink_decoded.groups.LinkedNormal, 'linked.group', 'symlinked TOML group did not load', scope)
h.assert_equal(symlink_decoded.entries.LinkedNormal.fg, '#123456', 'symlinked TOML entry did not load', scope)

h.write_file(persist_dir .. '/dynamic.toml', {
  '["dynamic.group"]',
  '"DynamicNormal" = { fg = "#101010", dyn_fg_mode = "rgb", dyn_fg_params = "{\\"phase\\":0.25}", dyn_fg_palette = "[\\"#000000\\",\\"#ffffff\\"]", dyn_fg_speed = 1500 }',
  '"OldDynamic" = { fg = "#202020", dyn_fg_mode = "rgb", dyn_fg_speed = 1500 }',
})

local dynamic_decoded = storage.load(persist_dir)
h.assert_equal(dynamic_decoded.entries.DynamicNormal.dynamic.fg.mode, 'rgb', 'dynamic mode did not load', scope)
h.assert_equal(dynamic_decoded.entries.DynamicNormal.dynamic.fg.speed, 1500, 'dynamic speed did not load', scope)
h.assert_equal(
  dynamic_decoded.entries.DynamicNormal.dynamic.fg.params.phase,
  0.25,
  'dynamic params did not load',
  scope
)
h.assert_equal(
  dynamic_decoded.entries.DynamicNormal.dynamic.fg.palette[2],
  '#ffffff',
  'dynamic palette did not load',
  scope
)
h.assert_equal(
  dynamic_decoded.entries.OldDynamic.dynamic.fg.palette[1],
  '#ff0000',
  'old dynamic default palette did not load',
  scope
)
h.assert_true(dynamic_decoded.entries.DynamicNormal.dyn_fg_mode == nil, 'flat dynamic key leaked after load', scope)

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
      fg = {
        mode = 'rgb',
        speed = 1500,
        params = { phase = 0.25 },
        palette = { '#000000', '#ffffff' },
      },
      bg = { mode = 'breath', speed = 2500, params = { min = 0.2, max = 0.8 } },
    },
  },
}, {
  Normal = 'main/group',
  Comment = 'group-only',
  DynamicNormal = 'dynamic/group',
}, persist_dir)
h.assert_true(save_ok, save_err or 'storage.save failed', scope)

h.assert_file_exists(files.file_path(persist_dir, 'main/group'), 'main group file was not created', scope)
h.assert_file_missing(persist_dir .. '/stale.toml', 'stale TOML file was not removed', scope)

local saved = storage.load(persist_dir)
h.assert_equal(saved.entries.Normal.fg, '#111111', 'saved override did not reload', scope)
h.assert_equal(saved.groups.Normal, 'main/group', 'saved group did not reload', scope)
h.assert_true(saved.entries.Comment ~= nil, 'group-only entry did not reload', scope)
h.assert_equal(next(saved.entries.Comment), nil, 'group-only entry persisted fields', scope)
h.assert_equal(saved.groups.Comment, 'group-only', 'group-only group did not reload', scope)
h.assert_equal(
  saved.entries.DynamicNormal.dynamic.fg.palette[2],
  '#ffffff',
  'saved dynamic palette did not reload',
  scope
)
h.assert_equal(saved.entries.DynamicNormal.dynamic.bg.params.max, 0.8, 'saved breath params did not reload', scope)

local dynamic_content = h.read_file(files.file_path(persist_dir, 'dynamic/group'))
h.assert_true(dynamic_content:find('dyn_fg_mode = "rgb"', 1, true) ~= nil, 'saved TOML omitted dynamic mode', scope)
h.assert_true(dynamic_content:find('dyn_fg_palette = ', 1, true) ~= nil, 'saved TOML omitted dynamic palette', scope)

vim.fn.delete(persist_dir, 'rf')
vim.fn.delete(symlink_target, 'rf')

print('hlcraft storage: OK')
