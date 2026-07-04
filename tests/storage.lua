local h = require('tests.helpers')
local scope = 'hlcraft storage'

local config = require('hlcraft.config')
local files = require('hlcraft.persistence.files')
local storage = require('hlcraft.persistence.repository')

local persist_dir = h.temp_dir('hlcraft-storage')
vim.fn.mkdir(persist_dir, 'p')
config.setup({ persist_dir = persist_dir })

h.write_file(persist_dir .. '/manual.toml', {
  '# comment',
  '["ui.group"]',
  '"Normal Float" = { bg = "NONE", blend = 12, bold = true, fg = "#aabbcc", unknown = "drop" }',
})

local decoded = storage.load(persist_dir)
h.assert_equal(decoded.groups['Normal Float'], 'ui.group', 'manual TOML group did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].fg, '#aabbcc', 'manual TOML fg did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].bg, 'NONE', 'manual TOML NONE did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].blend, 12, 'manual TOML number did not load', scope)
h.assert_equal(decoded.entries['Normal Float'].bold, true, 'manual TOML boolean did not load', scope)
h.assert_true(decoded.entries['Normal Float'].unknown == nil, 'unknown manual TOML field leaked after load', scope)

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
  '"DynamicNormal" = { fg = "#101010", dynamic = { fg = { version = 1, preset = "pulse", duration = 1500, loop = "pingpong", timeline = [{ at = 0, color = "base" }, { at = 1, color = "#ffffff" }] } } }',
  '"InvalidDynamic" = { fg = "#202020", dynamic = { fg = { version = 1, timeline = [] } } }',
})

local dynamic_decoded = storage.load(persist_dir)
h.assert_equal(dynamic_decoded.entries.DynamicNormal.dynamic.fg.preset, 'pulse', 'dynamic preset did not load', scope)
h.assert_equal(dynamic_decoded.entries.DynamicNormal.dynamic.fg.duration, 1500, 'dynamic duration did not load', scope)
h.assert_true(dynamic_decoded.entries.InvalidDynamic ~= nil, 'invalid dynamic entry did not load', scope)
h.assert_true(dynamic_decoded.entries.InvalidDynamic.dynamic == nil, 'invalid dynamic config should not load', scope)

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
        version = 1,
        preset = 'pulse',
        duration = 1500,
        loop = 'pingpong',
        timeline = {
          { at = 0, color = 'base' },
          { at = 1, color = '#ffffff' },
        },
      },
      bg = {
        version = 1,
        preset = 'breath',
        duration = 2500,
        loop = 'pingpong',
        timeline = {
          { at = 0, color = 'base' },
        },
        transforms = {
          {
            type = 'brightness',
            interpolation = 'sine',
            timeline = {
              { at = 0, value = 0.2 },
              { at = 1, value = 0.8 },
            },
          },
        },
      },
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
  saved.entries.DynamicNormal.dynamic.fg.timeline[2].color,
  '#ffffff',
  'saved dynamic fg did not reload',
  scope
)
h.assert_equal(
  saved.entries.DynamicNormal.dynamic.bg.transforms[1].timeline[2].value,
  0.8,
  'saved dynamic bg transform did not reload',
  scope
)

local dynamic_content = h.read_file(files.file_path(persist_dir, 'dynamic/group'))
h.assert_true(dynamic_content:find('dynamic = {', 1, true) ~= nil, 'saved TOML omitted nested dynamic config', scope)
h.assert_true(
  dynamic_content:find('timeline = [{ at = 0, color = "base" }', 1, true) ~= nil,
  'saved TOML omitted dynamic timeline',
  scope
)
h.assert_true(
  dynamic_content:find('transforms = [{ type = "brightness"', 1, true) ~= nil,
  'saved TOML omitted dynamic transforms',
  scope
)
h.assert_true(dynamic_content:find('dyn_', 1, true) == nil, 'saved TOML wrote non-declarative dynamic key', scope)
h.assert_true(dynamic_content:find('unknown = ', 1, true) == nil, 'saved TOML wrote unknown field', scope)

vim.fn.delete(persist_dir, 'rf')
vim.fn.delete(symlink_target, 'rf')

print('hlcraft storage: OK')
