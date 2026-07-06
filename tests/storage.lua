local h = require('tests.helpers')
local scope = 'hlcraft storage'

local config = require('hlcraft.config')
local files = require('hlcraft.persistence.files')
local storage = require('hlcraft.persistence.repository')

local persist_dir = h.temp_dir('hlcraft-storage')
vim.fn.mkdir(persist_dir, 'p')
config.setup({
  persistence = {
    dir = persist_dir,
  },
})

h.write_file(persist_dir .. '/manual.toml', {
  '# comment',
  '["ui.group"]',
  '"NormalFloat" = { bg = "NONE", blend = 12, bold = true, fg = "#AABBCC" }',
})

local decoded = storage.load(persist_dir)
h.assert_equal(decoded.groups.NormalFloat, 'ui.group', 'manual TOML group did not load', scope)
h.assert_equal(decoded.entries.NormalFloat.fg, '#aabbcc', 'manual TOML fg did not load', scope)
h.assert_equal(decoded.entries.NormalFloat.bg, 'NONE', 'manual TOML NONE did not load', scope)
h.assert_equal(decoded.entries.NormalFloat.blend, 12, 'manual TOML number did not load', scope)
h.assert_equal(decoded.entries.NormalFloat.bold, true, 'manual TOML boolean did not load', scope)

local invalid_persist_dir = h.temp_dir('hlcraft-storage-invalid')
vim.fn.mkdir(invalid_persist_dir, 'p')
h.write_file(invalid_persist_dir .. '/manual.toml', {
  '["ui.group"]',
  '"UnknownManual" = { fg = "#AABBCC", unknown = "reject" }',
})
local invalid_manual_ok, invalid_manual_err = pcall(storage.load, invalid_persist_dir)
h.assert_true(not invalid_manual_ok, 'storage.load accepted an unknown manual TOML field', scope)
h.assert_true(
  tostring(invalid_manual_err):find('Highlight UnknownManual has unsupported field: unknown', 1, true) ~= nil,
  'unknown manual TOML error changed',
  scope
)
h.cleanup_dir(invalid_persist_dir)

local invalid_load_path_ok = pcall(storage.load, false)
h.assert_true(not invalid_load_path_ok, 'storage.load accepted a non-string path', scope)
local empty_load_path_ok = pcall(storage.load, '   ')
h.assert_true(not empty_load_path_ok, 'storage.load accepted an empty path', scope)

local symlink_target = persist_dir .. '-linked-target.toml'
h.cleanup_dir(symlink_target)
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
})

local dynamic_decoded = storage.load(persist_dir)
h.assert_equal(dynamic_decoded.entries.DynamicNormal.dynamic.fg.preset, 'pulse', 'dynamic preset did not load', scope)
h.assert_equal(dynamic_decoded.entries.DynamicNormal.dynamic.fg.duration, 1500, 'dynamic duration did not load', scope)
h.assert_equal(
  dynamic_decoded.entries.DynamicNormal.dynamic.fg.phase,
  0,
  'dynamic default phase did not normalize on load',
  scope
)
h.assert_equal(
  dynamic_decoded.entries.DynamicNormal.dynamic.fg.interpolation,
  'linear',
  'dynamic default interpolation did not normalize on load',
  scope
)

local invalid_dynamic_dir = h.temp_dir('hlcraft-storage-invalid-dynamic')
vim.fn.mkdir(invalid_dynamic_dir, 'p')
h.write_file(invalid_dynamic_dir .. '/dynamic.toml', {
  '["dynamic.group"]',
  '"InvalidDynamic" = { fg = "#202020", dynamic = { fg = { version = 1, timeline = [] } } }',
})
local invalid_dynamic_ok, invalid_dynamic_err = pcall(storage.load, invalid_dynamic_dir)
h.assert_true(not invalid_dynamic_ok, 'storage.load accepted an invalid dynamic entry', scope)
h.assert_true(
  tostring(invalid_dynamic_err):find('Highlight InvalidDynamic has invalid dynamic override', 1, true) ~= nil,
  'invalid dynamic load error changed',
  scope
)
h.cleanup_dir(invalid_dynamic_dir)

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

local invalid_overrides_ok, invalid_overrides_err = storage.save(false, {}, persist_dir)
h.assert_true(not invalid_overrides_ok, 'storage.save accepted non-table overrides', scope)
h.assert_equal(invalid_overrides_err, 'Overrides must be a table', 'non-table overrides error changed', scope)

local invalid_groups_ok, invalid_groups_err = storage.save({}, false, persist_dir)
h.assert_true(not invalid_groups_ok, 'storage.save accepted non-table groups', scope)
h.assert_equal(invalid_groups_err, 'Groups must be a table', 'non-table groups error changed', scope)

local missing_groups_ok, missing_groups_err = storage.save({}, nil, persist_dir)
h.assert_true(not missing_groups_ok, 'storage.save accepted missing groups', scope)
h.assert_equal(missing_groups_err, 'Groups must be a table', 'missing groups error changed', scope)

local invalid_save_path_ok = pcall(storage.save, {}, {}, false)
h.assert_true(not invalid_save_path_ok, 'storage.save accepted a non-string path', scope)
local empty_save_path_ok = pcall(storage.save, {}, {}, '   ')
h.assert_true(not empty_save_path_ok, 'storage.save accepted an empty path', scope)

local missing_group_ok, missing_group_err = storage.save({
  MissingGroup = { fg = '#111111' },
}, {}, persist_dir)
h.assert_true(not missing_group_ok, 'storage.save accepted an override without a group table', scope)
h.assert_equal(
  missing_group_err,
  'Highlight MissingGroup must have a group before saving',
  'missing group error changed',
  scope
)

local invalid_name_ok, invalid_name_err = storage.save({
  [1] = { fg = '#111111' },
}, {
  [1] = 'group',
}, persist_dir)
h.assert_true(not invalid_name_ok, 'storage.save accepted a non-string highlight name', scope)
h.assert_equal(invalid_name_err, 'Highlight name must be a non-empty string', 'highlight name error changed', scope)

local spaced_name_ok, spaced_name_err = storage.save({
  ['Bad Name'] = { fg = '#111111' },
}, {
  ['Bad Name'] = 'group',
}, persist_dir)
h.assert_true(not spaced_name_ok, 'storage.save accepted whitespace in highlight name', scope)
h.assert_equal(
  spaced_name_err,
  'Highlight name must not contain whitespace or command separators',
  'spaced highlight name error changed',
  scope
)

local invalid_entry_ok, invalid_entry_err = storage.save({
  InvalidEntry = false,
}, {
  InvalidEntry = 'group',
}, persist_dir)
h.assert_true(not invalid_entry_ok, 'storage.save accepted a non-table entry', scope)
h.assert_equal(invalid_entry_err, 'Override entry InvalidEntry must be a table', 'non-table entry error changed', scope)

local invalid_field_ok, invalid_field_err = storage.save({
  InvalidField = { fg = 123 },
}, {
  InvalidField = 'group',
}, persist_dir)
h.assert_true(not invalid_field_ok, 'storage.save accepted an invalid override field', scope)
h.assert_equal(
  invalid_field_err,
  'Highlight InvalidField has invalid fg: Color must be a string or nil, got number',
  'invalid field error changed',
  scope
)

local invalid_create_dir = h.temp_dir('hlcraft-storage-invalid-save-dir')
local invalid_create_ok = storage.save({
  InvalidCreate = { fg = 123 },
}, {
  InvalidCreate = 'group',
}, invalid_create_dir)
h.assert_true(not invalid_create_ok, 'storage.save accepted invalid data for a new directory', scope)
h.assert_file_missing(invalid_create_dir, 'invalid storage.save created the target directory', scope)

local unknown_field_ok, unknown_field_err = storage.save({
  UnknownField = { unknown = true },
}, {
  UnknownField = 'group',
}, persist_dir)
h.assert_true(not unknown_field_ok, 'storage.save accepted an unknown override field', scope)
h.assert_equal(
  unknown_field_err,
  'Highlight UnknownField has unsupported field: unknown',
  'unknown field error changed',
  scope
)

local invalid_dynamic_save_ok, invalid_dynamic_save_err = storage.save({
  InvalidDynamicSave = {
    dynamic = {
      fg = {
        version = 1,
        timeline = {},
      },
    },
  },
}, {
  InvalidDynamicSave = 'group',
}, persist_dir)
h.assert_true(not invalid_dynamic_save_ok, 'storage.save accepted an invalid dynamic override', scope)
h.assert_equal(
  invalid_dynamic_save_err,
  'Highlight InvalidDynamicSave has invalid dynamic override',
  'invalid dynamic save error changed',
  scope
)

local invalid_group_ok, invalid_group_err = storage.save({
  InvalidGroup = { fg = '#111111' },
}, {
  InvalidGroup = 42,
}, persist_dir)
h.assert_true(not invalid_group_ok, 'storage.save accepted a non-string group', scope)
h.assert_equal(
  invalid_group_err,
  'Group for highlight InvalidGroup must be a string',
  'storage.save reported wrong non-string group error',
  scope
)

local empty_group_ok, empty_group_err = storage.save({}, {
  EmptyGroup = '  ',
}, persist_dir)
h.assert_true(not empty_group_ok, 'storage.save accepted an empty group', scope)
h.assert_equal(
  empty_group_err,
  'Highlight EmptyGroup must have a group before saving',
  'storage.save reported wrong empty group error',
  scope
)

h.assert_file_exists(files.file_path(persist_dir, 'main/group'), 'main group file was not created', scope)
h.assert_file_missing(persist_dir .. '/stale.toml', 'stale TOML file was not removed', scope)
h.assert_true(files.file_path(persist_dir, nil) == nil, 'nil group file path should stay unset', scope)

local numeric_filename_ok = pcall(files.sanitize_filename, 1)
h.assert_true(not numeric_filename_ok, 'filename sanitizer accepted a non-string name', scope)
h.assert_true(
  files.sanitize_filename('main/group') ~= files.sanitize_filename('main_2Fgroup'),
  'filename sanitizer allows escaped-name collisions',
  scope
)
local numeric_path_ok = pcall(files.file_path, 1, 'group')
h.assert_true(not numeric_path_ok, 'file_path accepted a non-string directory path', scope)
local empty_path_ok = pcall(files.file_path, '   ', 'group')
h.assert_true(not empty_path_ok, 'file_path accepted an empty directory path', scope)
local invalid_toml_dir_opts_ok = pcall(files.toml_files_in_dir, persist_dir, false)
h.assert_true(not invalid_toml_dir_opts_ok, 'toml directory scan accepted non-table options', scope)
local empty_toml_dir_ok = pcall(files.toml_files_in_dir, '   ')
h.assert_true(not empty_toml_dir_ok, 'toml directory scan accepted an empty path', scope)
local invalid_toml_link_opts_ok = pcall(files.toml_files_in_dir, persist_dir, { include_links = 'yes' })
h.assert_true(not invalid_toml_link_opts_ok, 'toml directory scan accepted non-boolean link option', scope)
local unknown_toml_dir_opts_ok = pcall(files.toml_files_in_dir, persist_dir, { unknown = true })
h.assert_true(not unknown_toml_dir_opts_ok, 'toml directory scan accepted an unknown option', scope)
local invalid_atomic_lines_ok = pcall(files.atomic_write, persist_dir .. '/bad.toml', { false })
h.assert_true(not invalid_atomic_lines_ok, 'atomic_write accepted a non-string content line', scope)
local empty_atomic_path_ok = pcall(files.atomic_write, '   ', {})
h.assert_true(not empty_atomic_path_ok, 'atomic_write accepted an empty path', scope)
local non_sequence_atomic_lines_ok = pcall(files.atomic_write, persist_dir .. '/bad.toml', { ok = 'line' })
h.assert_true(not non_sequence_atomic_lines_ok, 'atomic_write accepted non-sequence content lines', scope)
local invalid_stale_sections_ok = pcall(files.remove_stale_toml_files, persist_dir, false)
h.assert_true(not invalid_stale_sections_ok, 'stale TOML cleanup accepted non-table section names', scope)
local empty_stale_path_ok = pcall(files.remove_stale_toml_files, '   ', {})
h.assert_true(not empty_stale_path_ok, 'stale TOML cleanup accepted an empty path', scope)
local non_sequence_stale_sections_ok = pcall(files.remove_stale_toml_files, persist_dir, { active = true })
h.assert_true(not non_sequence_stale_sections_ok, 'stale TOML cleanup accepted non-sequence section names', scope)

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
h.assert_true(dynamic_content:find('transforms = []', 1, true) == nil, 'saved TOML kept empty transforms', scope)
h.assert_true(dynamic_content:find('phase = 0', 1, true) == nil, 'saved TOML kept default phase', scope)
h.assert_true(
  dynamic_content:find('interpolation = "linear"', 1, true) == nil,
  'saved TOML kept default interpolation',
  scope
)
h.assert_true(dynamic_content:find('unknown = ', 1, true) == nil, 'saved TOML wrote unknown field', scope)

h.cleanup_dir(persist_dir)
h.cleanup_dir(symlink_target)

print('hlcraft storage: OK')
