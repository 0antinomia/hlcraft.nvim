local h = require('tests.helpers')
local scope = 'hlcraft storage'

local config = require('hlcraft.config')
local files = require('hlcraft.persistence.files')
local storage = require('hlcraft.persistence.repository')

local function is_temp_path(path, filepath)
  local prefix = filepath .. '.tmp.'
  return path:sub(1, #prefix) == prefix
end

local function assert_no_temp_files(filepath, message)
  h.assert_equal(#vim.fn.glob(filepath .. '.tmp.*', false, true), 0, message, scope)
end

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

local symlink_save_dir = h.temp_dir('hlcraft-storage-symlink-save')
vim.fn.mkdir(symlink_save_dir, 'p')
local symlink_save_target = symlink_save_dir .. '-target.toml'
h.cleanup_dir(symlink_save_target)
h.write_file(symlink_save_target, {
  '["linked"]',
  '"LinkedNormal" = { fg = "#101010" }',
})
local symlink_save_path = files.file_path(symlink_save_dir, 'linked')
local symlink_save_ok, symlink_save_err = vim.uv.fs_symlink(symlink_save_target, symlink_save_path)
h.assert_true(
  symlink_save_ok,
  ('failed to create writable symlink TOML fixture: %s'):format(tostring(symlink_save_err)),
  scope
)
local symlink_write_ok, symlink_write_err = storage.save({
  LinkedNormal = { fg = '#202020' },
}, {
  LinkedNormal = 'linked',
}, symlink_save_dir)
h.assert_true(symlink_write_ok, symlink_write_err or 'storage.save rejected a symlinked active TOML file', scope)
h.assert_equal(
  vim.uv.fs_lstat(symlink_save_path).type,
  'link',
  'storage.save replaced an active symlinked TOML file',
  scope
)
local symlink_target_content = h.read_file(symlink_save_target)
h.assert_true(
  symlink_target_content:find('LinkedNormal', 1, true) ~= nil and symlink_target_content:find('#202020', 1, true) ~= nil,
  'storage.save did not update the symlink target TOML file',
  scope
)
h.cleanup_dir(symlink_save_dir)
h.cleanup_dir(symlink_save_target)

local temp_symlink_dir = h.temp_dir('hlcraft-storage-temp-symlink')
vim.fn.mkdir(temp_symlink_dir, 'p')
local temp_symlink_path = files.file_path(temp_symlink_dir, 'active')
local temp_symlink_target = temp_symlink_dir .. '-target.toml'
local temp_symlink_original = 'external content\n'
h.cleanup_dir(temp_symlink_target)
h.write_file(temp_symlink_target, { 'external content' })
local temp_symlink_ok, temp_symlink_err = vim.uv.fs_symlink(temp_symlink_target, temp_symlink_path .. '.tmp')
h.assert_true(temp_symlink_ok, ('failed to create temp symlink fixture: %s'):format(tostring(temp_symlink_err)), scope)
local temp_symlink_save_ok, temp_symlink_save_err = storage.save({
  TempSymlink = { fg = '#202020' },
}, {
  TempSymlink = 'active',
}, temp_symlink_dir)
h.assert_true(
  temp_symlink_save_ok,
  temp_symlink_save_err or 'storage.save rejected a pre-existing fixed-name temp symlink',
  scope
)
h.assert_equal(
  h.read_file(temp_symlink_target),
  temp_symlink_original,
  'storage.save followed a pre-existing temp symlink',
  scope
)
h.assert_equal(
  vim.uv.fs_lstat(temp_symlink_path .. '.tmp').type,
  'link',
  'storage.save consumed a pre-existing temp symlink',
  scope
)
h.assert_true(
  h.read_file(temp_symlink_path):find('TempSymlink', 1, true) ~= nil,
  'storage.save did not commit through an isolated staging file',
  scope
)
h.cleanup_dir(temp_symlink_dir)
h.cleanup_dir(temp_symlink_target)

local symlink_same_dir_dir = h.temp_dir('hlcraft-storage-symlink-same-dir-target')
vim.fn.mkdir(symlink_same_dir_dir, 'p')
local symlink_same_dir_target = symlink_same_dir_dir .. '/shared.toml'
h.write_file(symlink_same_dir_target, {
  '["linked"]',
  '"LinkedSameDir" = { fg = "#101010" }',
})
local symlink_same_dir_path = files.file_path(symlink_same_dir_dir, 'linked')
local symlink_same_dir_ok, symlink_same_dir_err = vim.uv.fs_symlink(symlink_same_dir_target, symlink_same_dir_path)
h.assert_true(
  symlink_same_dir_ok,
  ('failed to create same-dir symlink TOML fixture: %s'):format(tostring(symlink_same_dir_err)),
  scope
)
local symlink_same_dir_save_ok, symlink_same_dir_save_err = storage.save({
  LinkedSameDir = { fg = '#303030' },
}, {
  LinkedSameDir = 'linked',
}, symlink_same_dir_dir)
h.assert_true(
  symlink_same_dir_save_ok,
  symlink_same_dir_save_err or 'storage.save rejected same-dir symlinked TOML file',
  scope
)
h.assert_equal(
  vim.uv.fs_lstat(symlink_same_dir_path).type,
  'link',
  'storage.save replaced a same-dir symlinked TOML file',
  scope
)
h.assert_file_exists(symlink_same_dir_target, 'storage.save removed the active same-dir symlink target as stale', scope)
local symlink_same_dir_content = h.read_file(symlink_same_dir_target)
h.assert_true(
  symlink_same_dir_content:find('LinkedSameDir', 1, true) ~= nil
    and symlink_same_dir_content:find('#303030', 1, true) ~= nil,
  'storage.save did not update the same-dir symlink target TOML file',
  scope
)
local symlink_same_dir_decoded = storage.load(symlink_same_dir_dir)
h.assert_equal(
  symlink_same_dir_decoded.entries.LinkedSameDir.fg,
  '#303030',
  'storage.load duplicated a same-directory symlink target',
  scope
)
h.cleanup_dir(symlink_same_dir_dir)

local stale_alias_dir = h.temp_dir('hlcraft-storage-stale-symlink-alias')
vim.fn.mkdir(stale_alias_dir, 'p')
local stale_alias_target = stale_alias_dir .. '/shared.toml'
h.write_file(stale_alias_target, {
  '["linked"]',
  '"LinkedAlias" = { fg = "#101010" }',
})
local stale_alias_active_path = files.file_path(stale_alias_dir, 'linked')
local stale_alias_active_ok, stale_alias_active_err = vim.uv.fs_symlink(stale_alias_target, stale_alias_active_path)
h.assert_true(
  stale_alias_active_ok,
  ('failed to create active symlink alias fixture: %s'):format(tostring(stale_alias_active_err)),
  scope
)
local stale_alias_path = stale_alias_dir .. '/old-link.toml'
local stale_alias_ok, stale_alias_err = vim.uv.fs_symlink(stale_alias_target, stale_alias_path)
h.assert_true(
  stale_alias_ok,
  ('failed to create stale symlink alias fixture: %s'):format(tostring(stale_alias_err)),
  scope
)
local stale_alias_save_ok, stale_alias_save_err = storage.save({
  LinkedAlias = { fg = '#404040' },
}, {
  LinkedAlias = 'linked',
}, stale_alias_dir)
h.assert_true(
  stale_alias_save_ok,
  stale_alias_save_err or 'storage.save rejected a same-target stale symlink alias',
  scope
)
h.assert_equal(
  vim.uv.fs_lstat(stale_alias_active_path).type,
  'link',
  'storage.save replaced the active same-target symlink alias',
  scope
)
h.assert_file_exists(stale_alias_target, 'storage.save removed the active symlink alias target', scope)
h.assert_file_missing(stale_alias_path, 'storage.save kept a stale symlink alias to an active target', scope)
h.assert_file_missing(stale_alias_path .. '.bak', 'storage.save kept a stale symlink alias backup', scope)
h.assert_file_missing(stale_alias_target .. '.bak', 'storage.save kept an active target backup', scope)
assert_no_temp_files(stale_alias_target, 'storage.save kept an active target temp file')
h.cleanup_dir(stale_alias_dir)

local broken_stale_symlink_dir = h.temp_dir('hlcraft-storage-broken-stale-symlink')
vim.fn.mkdir(broken_stale_symlink_dir, 'p')
local broken_stale_symlink_target = broken_stale_symlink_dir .. '/missing.toml'
local broken_stale_symlink_path = broken_stale_symlink_dir .. '/old-link.toml'
local broken_stale_symlink_ok, broken_stale_symlink_err =
  vim.uv.fs_symlink(broken_stale_symlink_target, broken_stale_symlink_path)
h.assert_true(
  broken_stale_symlink_ok,
  ('failed to create broken stale symlink fixture: %s'):format(tostring(broken_stale_symlink_err)),
  scope
)
local broken_stale_symlink_save_ok, broken_stale_symlink_save_err = storage.save({
  FreshAfterBrokenLink = { fg = '#505050' },
}, {
  FreshAfterBrokenLink = 'fresh',
}, broken_stale_symlink_dir)
h.assert_true(
  broken_stale_symlink_save_ok,
  broken_stale_symlink_save_err or 'storage.save rejected cleanup with a broken stale symlink',
  scope
)
h.assert_true(vim.uv.fs_lstat(broken_stale_symlink_path) == nil, 'storage.save kept a broken stale symlink path', scope)
h.assert_true(
  vim.uv.fs_lstat(broken_stale_symlink_path .. '.bak') == nil,
  'storage.save kept a broken stale symlink backup path',
  scope
)
h.cleanup_dir(broken_stale_symlink_dir)

local duplicate_symlink_dir = h.temp_dir('hlcraft-storage-duplicate-symlink-target')
vim.fn.mkdir(duplicate_symlink_dir, 'p')
local duplicate_symlink_target = duplicate_symlink_dir .. '-target.toml'
local duplicate_symlink_original = '["shared"]\n"SharedOriginal" = { fg = "#101010" }\n'
h.cleanup_dir(duplicate_symlink_target)
h.write_file(duplicate_symlink_target, {
  '["shared"]',
  '"SharedOriginal" = { fg = "#101010" }',
})
local duplicate_symlink_a_path = files.file_path(duplicate_symlink_dir, 'aa')
local duplicate_symlink_b_path = files.file_path(duplicate_symlink_dir, 'bb')
local duplicate_symlink_a_ok, duplicate_symlink_a_err =
  vim.uv.fs_symlink(duplicate_symlink_target, duplicate_symlink_a_path)
h.assert_true(
  duplicate_symlink_a_ok,
  ('failed to create first duplicate symlink fixture: %s'):format(tostring(duplicate_symlink_a_err)),
  scope
)
local duplicate_symlink_b_ok, duplicate_symlink_b_err =
  vim.uv.fs_symlink(duplicate_symlink_target, duplicate_symlink_b_path)
h.assert_true(
  duplicate_symlink_b_ok,
  ('failed to create second duplicate symlink fixture: %s'):format(tostring(duplicate_symlink_b_err)),
  scope
)
local duplicate_symlink_save_ok, duplicate_symlink_save_err = storage.save({
  DuplicateA = { fg = '#202020' },
  DuplicateB = { fg = '#303030' },
}, {
  DuplicateA = 'aa',
  DuplicateB = 'bb',
}, duplicate_symlink_dir)
h.assert_true(not duplicate_symlink_save_ok, 'storage.save accepted duplicate symlink write targets', scope)
h.assert_true(
  type(duplicate_symlink_save_err) == 'string'
    and duplicate_symlink_save_err:find('Multiple TOML sections resolve to the same file', 1, true) ~= nil,
  'duplicate symlink target error changed',
  scope
)
h.assert_equal(
  h.read_file(duplicate_symlink_target),
  duplicate_symlink_original,
  'duplicate symlink target rejection changed target content',
  scope
)
h.assert_equal(
  vim.uv.fs_lstat(duplicate_symlink_a_path).type,
  'link',
  'duplicate symlink target rejection replaced first link',
  scope
)
h.assert_equal(
  vim.uv.fs_lstat(duplicate_symlink_b_path).type,
  'link',
  'duplicate symlink target rejection replaced second link',
  scope
)
assert_no_temp_files(duplicate_symlink_target, 'duplicate symlink rejection kept target temp file')
h.assert_file_missing(duplicate_symlink_target .. '.bak', 'duplicate symlink rejection kept target backup file', scope)
h.cleanup_dir(duplicate_symlink_dir)
h.cleanup_dir(duplicate_symlink_target)

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

local file_target_path = h.temp_dir('hlcraft-storage-file-target')
h.cleanup_dir(file_target_path)
h.write_file(file_target_path, { 'not a directory' })
local file_target_pcall_ok, file_target_ok, file_target_err = pcall(storage.save, {}, {}, file_target_path)
h.assert_true(file_target_pcall_ok, 'storage.save threw when target path was a file', scope)
h.assert_true(not file_target_ok, 'storage.save accepted a file as target directory', scope)
h.assert_true(type(file_target_err) == 'string', 'storage.save returned no directory creation error', scope)
h.cleanup_dir(file_target_path)

local partial_save_dir = h.temp_dir('hlcraft-storage-partial-save')
vim.fn.mkdir(partial_save_dir, 'p')
local partial_a_path = files.file_path(partial_save_dir, 'aa')
h.write_file(partial_a_path, {
  '["aa"]',
  '"OldAlpha" = { fg = "#101010" }',
})
vim.fn.mkdir(files.file_path(partial_save_dir, 'zz'), 'p')
local partial_save_ok = storage.save({
  NewAlpha = { fg = '#202020' },
  NewOmega = { fg = '#303030' },
}, {
  NewAlpha = 'aa',
  NewOmega = 'zz',
}, partial_save_dir)
h.assert_true(not partial_save_ok, 'storage.save accepted a blocked later section write', scope)
local partial_a_content = h.read_file(partial_a_path)
h.assert_true(
  partial_a_content:find('OldAlpha', 1, true) ~= nil,
  'failed storage.save overwrote an earlier section',
  scope
)
h.assert_true(
  partial_a_content:find('NewAlpha', 1, true) == nil,
  'failed storage.save partially wrote a new earlier section',
  scope
)
h.cleanup_dir(partial_save_dir)

local partial_write_failure_dir = h.temp_dir('hlcraft-storage-partial-write-failure')
vim.fn.mkdir(partial_write_failure_dir, 'p')
local partial_write_alpha_path = files.file_path(partial_write_failure_dir, 'aa')
local partial_write_omega_path = files.file_path(partial_write_failure_dir, 'zz')
h.write_file(partial_write_alpha_path, {
  '["aa"]',
  '"OldAlpha" = { fg = "#101010" }',
})
local partial_write_original_io_open = io.open
io.open = function(path, mode)
  local file, err = partial_write_original_io_open(path, mode)
  if is_temp_path(path, partial_write_omega_path) and file then
    return {
      write = function()
        return nil, 'write failed'
      end,
      close = function()
        return file:close()
      end,
    }
  end
  return file, err
end
local partial_write_ok = storage.save({
  NewAlpha = { fg = '#202020' },
  NewOmega = { fg = '#303030' },
}, {
  NewAlpha = 'aa',
  NewOmega = 'zz',
}, partial_write_failure_dir)
io.open = partial_write_original_io_open
h.assert_true(not partial_write_ok, 'storage.save accepted a failed later section write', scope)
local partial_write_alpha_content = h.read_file(partial_write_alpha_path)
h.assert_true(
  partial_write_alpha_content:find('OldAlpha', 1, true) ~= nil,
  'failed section write overwrote an earlier section',
  scope
)
h.assert_true(
  partial_write_alpha_content:find('NewAlpha', 1, true) == nil,
  'failed section write partially wrote a new earlier section',
  scope
)
assert_no_temp_files(partial_write_alpha_path, 'failed section write kept earlier temp file')
assert_no_temp_files(partial_write_omega_path, 'failed section write kept failing temp file')
h.cleanup_dir(partial_write_failure_dir)

local partial_commit_failure_dir = h.temp_dir('hlcraft-storage-partial-commit-failure')
vim.fn.mkdir(partial_commit_failure_dir, 'p')
local partial_commit_alpha_path = files.file_path(partial_commit_failure_dir, 'aa')
local partial_commit_omega_path = files.file_path(partial_commit_failure_dir, 'zz')
h.write_file(partial_commit_alpha_path, {
  '["aa"]',
  '"OldAlpha" = { fg = "#101010" }',
})
local partial_commit_original_os_rename = os.rename
os.rename = function(src, dst)
  if is_temp_path(src, partial_commit_omega_path) and dst == partial_commit_omega_path then
    return nil, 'rename failed'
  end
  return partial_commit_original_os_rename(src, dst)
end
local partial_commit_ok = storage.save({
  NewAlpha = { fg = '#202020' },
  NewOmega = { fg = '#303030' },
}, {
  NewAlpha = 'aa',
  NewOmega = 'zz',
}, partial_commit_failure_dir)
os.rename = partial_commit_original_os_rename
h.assert_true(not partial_commit_ok, 'storage.save accepted a failed later section commit', scope)
local partial_commit_alpha_content = h.read_file(partial_commit_alpha_path)
h.assert_true(
  partial_commit_alpha_content:find('OldAlpha', 1, true) ~= nil,
  'failed section commit overwrote an earlier section',
  scope
)
h.assert_true(
  partial_commit_alpha_content:find('NewAlpha', 1, true) == nil,
  'failed section commit partially wrote a new earlier section',
  scope
)
assert_no_temp_files(partial_commit_alpha_path, 'failed section commit kept earlier temp file')
assert_no_temp_files(partial_commit_omega_path, 'failed section commit kept failing temp file')
h.cleanup_dir(partial_commit_failure_dir)

local backup_cleanup_failure_dir = h.temp_dir('hlcraft-storage-backup-cleanup-failure')
vim.fn.mkdir(backup_cleanup_failure_dir, 'p')
local backup_cleanup_alpha_path = files.file_path(backup_cleanup_failure_dir, 'aa')
local backup_cleanup_omega_path = files.file_path(backup_cleanup_failure_dir, 'zz')
h.write_file(backup_cleanup_alpha_path, {
  '["aa"]',
  '"OldAlpha" = { fg = "#101010" }',
})
h.write_file(backup_cleanup_omega_path, {
  '["zz"]',
  '"OldOmega" = { fg = "#101010" }',
})
local backup_cleanup_original_os_remove = os.remove
os.remove = function(path)
  local blocked_backup = backup_cleanup_omega_path .. '.bak'
  if path:sub(1, #blocked_backup) == blocked_backup then
    return nil, 'remove failed'
  end
  return backup_cleanup_original_os_remove(path)
end
local backup_cleanup_ok, backup_cleanup_err = storage.save({
  NewAlpha = { fg = '#202020' },
  NewOmega = { fg = '#303030' },
}, {
  NewAlpha = 'aa',
  NewOmega = 'zz',
}, backup_cleanup_failure_dir)
os.remove = backup_cleanup_original_os_remove
h.assert_true(
  backup_cleanup_ok,
  backup_cleanup_err or 'storage.save rejected non-critical backup cleanup failure',
  scope
)
local backup_cleanup_alpha_content = h.read_file(backup_cleanup_alpha_path)
h.assert_true(
  backup_cleanup_alpha_content:find('NewAlpha', 1, true) ~= nil,
  'commit backup cleanup failure lost committed earlier section',
  scope
)
h.assert_true(
  backup_cleanup_alpha_content:find('OldAlpha', 1, true) == nil,
  'commit backup cleanup failure restored earlier section after finalization',
  scope
)
local backup_cleanup_omega_content = h.read_file(backup_cleanup_omega_path)
h.assert_true(
  backup_cleanup_omega_content:find('NewOmega', 1, true) ~= nil,
  'commit backup cleanup failure lost committed later section',
  scope
)
h.assert_true(
  backup_cleanup_omega_content:find('OldOmega', 1, true) == nil,
  'commit backup cleanup failure restored later section after finalization',
  scope
)
h.assert_file_missing(
  backup_cleanup_alpha_path .. '.bak',
  'commit backup cleanup failure left alpha TOML backup',
  scope
)
h.assert_file_missing(
  backup_cleanup_omega_path .. '.bak',
  'commit backup cleanup failure left omega TOML backup',
  scope
)
h.cleanup_dir(backup_cleanup_failure_dir)

local post_stale_finalize_failure_dir = h.temp_dir('hlcraft-storage-post-stale-finalize-failure')
vim.fn.mkdir(post_stale_finalize_failure_dir, 'p')
local post_stale_finalize_fresh_path = files.file_path(post_stale_finalize_failure_dir, 'fresh')
local post_stale_finalize_stale_path = post_stale_finalize_failure_dir .. '/stale.toml'
local post_stale_finalize_fresh_original = '["fresh"]\n"OldFinalizeFresh" = { fg = "#101010" }\n'
local post_stale_finalize_stale_original = '["stale"]\n"OldFinalizeStale" = { fg = "#202020" }\n'
h.write_file(post_stale_finalize_fresh_path, {
  '["fresh"]',
  '"OldFinalizeFresh" = { fg = "#101010" }',
})
h.write_file(post_stale_finalize_stale_path, {
  '["stale"]',
  '"OldFinalizeStale" = { fg = "#202020" }',
})
local post_stale_finalize_original_os_rename = os.rename
os.rename = function(src, dst)
  local blocked_backup = post_stale_finalize_fresh_path .. '.bak'
  if src == blocked_backup and dst:sub(1, #blocked_backup + 8) == blocked_backup .. '.cleanup' then
    return nil, 'finalize failed'
  end
  return post_stale_finalize_original_os_rename(src, dst)
end
local post_stale_finalize_ok, post_stale_finalize_err = storage.save({
  NewFinalizeFresh = { fg = '#303030' },
}, {
  NewFinalizeFresh = 'fresh',
}, post_stale_finalize_failure_dir)
os.rename = post_stale_finalize_original_os_rename
h.assert_true(not post_stale_finalize_ok, 'storage.save accepted failed post-stale backup finalization', scope)
h.assert_true(
  type(post_stale_finalize_err) == 'string'
    and post_stale_finalize_err:find('Failed to finalize TOML backup', 1, true) ~= nil,
  'post-stale backup finalization failure error changed',
  scope
)
h.assert_equal(
  h.read_file(post_stale_finalize_fresh_path),
  post_stale_finalize_fresh_original,
  'post-stale backup finalization failure did not roll back fresh section',
  scope
)
h.assert_file_exists(
  post_stale_finalize_stale_path,
  'post-stale backup finalization failure did not restore stale section',
  scope
)
h.assert_equal(
  h.read_file(post_stale_finalize_stale_path),
  post_stale_finalize_stale_original,
  'post-stale backup finalization failure did not restore stale section',
  scope
)
assert_no_temp_files(post_stale_finalize_fresh_path, 'post-stale backup finalization failure kept fresh temp file')
h.assert_file_missing(
  post_stale_finalize_fresh_path .. '.bak',
  'post-stale backup finalization failure kept fresh backup file',
  scope
)
h.assert_file_missing(
  post_stale_finalize_stale_path .. '.bak',
  'post-stale backup finalization failure kept stale backup file',
  scope
)
h.cleanup_dir(post_stale_finalize_failure_dir)

local stale_cleanup_dir = h.temp_dir('hlcraft-storage-stale-cleanup-failure')
vim.fn.mkdir(stale_cleanup_dir, 'p')
local stale_cleanup_path = stale_cleanup_dir .. '/stale.toml'
local stale_cleanup_fresh_path = files.file_path(stale_cleanup_dir, 'fresh')
h.write_file(stale_cleanup_path, {
  '["stale"]',
  '"StaleCleanup" = { fg = "#000000" }',
})
local original_stale_rename = os.rename
os.rename = function(src, dst)
  if src == stale_cleanup_path and dst == stale_cleanup_path .. '.bak' then
    return nil, 'backup failed'
  end
  return original_stale_rename(src, dst)
end
local stale_cleanup_ok, stale_cleanup_err = storage.save({
  FreshCleanup = { fg = '#202020' },
}, {
  FreshCleanup = 'fresh',
}, stale_cleanup_dir)
os.rename = original_stale_rename
h.assert_true(not stale_cleanup_ok, 'storage.save accepted failed stale TOML cleanup', scope)
h.assert_true(
  type(stale_cleanup_err) == 'string' and stale_cleanup_err:find('Failed to back up stale TOML file', 1, true) ~= nil,
  'stale cleanup failure error changed',
  scope
)
h.assert_file_exists(stale_cleanup_path, 'failed stale cleanup test lost stale fixture', scope)
h.assert_file_missing(stale_cleanup_fresh_path, 'failed stale cleanup partially committed fresh section', scope)
h.cleanup_dir(stale_cleanup_dir)

local new_section_rollback_failure_dir = h.temp_dir('hlcraft-storage-new-section-rollback-failure')
vim.fn.mkdir(new_section_rollback_failure_dir, 'p')
local new_section_rollback_stale_path = new_section_rollback_failure_dir .. '/stale.toml'
local new_section_rollback_fresh_path = files.file_path(new_section_rollback_failure_dir, 'fresh')
h.write_file(new_section_rollback_stale_path, {
  '["stale"]',
  '"StaleRollback" = { fg = "#000000" }',
})
local original_os_remove = os.remove
original_stale_rename = os.rename
os.remove = function(path)
  if path == new_section_rollback_fresh_path then
    return nil, 'fresh rollback failed'
  end
  return original_os_remove(path)
end
os.rename = function(src, dst)
  if src == new_section_rollback_stale_path and dst == new_section_rollback_stale_path .. '.bak' then
    return nil, 'stale backup failed'
  end
  return original_stale_rename(src, dst)
end
local new_section_rollback_ok, new_section_rollback_err = storage.save({
  FreshRollback = { fg = '#202020' },
}, {
  FreshRollback = 'fresh',
}, new_section_rollback_failure_dir)
os.remove = original_os_remove
os.rename = original_stale_rename
h.assert_true(not new_section_rollback_ok, 'storage.save accepted failed new-section rollback', scope)
h.assert_true(
  type(new_section_rollback_err) == 'string' and new_section_rollback_err:find('fresh rollback failed', 1, true) ~= nil,
  'new-section rollback failure did not report the failed cleanup',
  scope
)
h.assert_file_exists(
  new_section_rollback_fresh_path,
  'new-section rollback failure unexpectedly removed the blocked fresh section',
  scope
)
h.cleanup_dir(new_section_rollback_failure_dir)

local partial_stale_cleanup_dir = h.temp_dir('hlcraft-storage-partial-stale-cleanup-failure')
vim.fn.mkdir(partial_stale_cleanup_dir, 'p')
local partial_stale_first_path = partial_stale_cleanup_dir .. '/old-a.toml'
local partial_stale_second_path = partial_stale_cleanup_dir .. '/old-b.toml'
h.write_file(partial_stale_first_path, {
  '["old-a"]',
  '"OldA" = { fg = "#000000" }',
})
vim.uv.fs_chmod(partial_stale_first_path, 384)
h.write_file(partial_stale_second_path, {
  '["old-b"]',
  '"OldB" = { fg = "#000000" }',
})
original_stale_rename = os.rename
os.rename = function(src, dst)
  if src == partial_stale_second_path and dst == partial_stale_second_path .. '.bak' then
    return nil, 'backup failed'
  end
  return original_stale_rename(src, dst)
end
local partial_stale_ok = storage.save({
  FreshPartialCleanup = { fg = '#202020' },
}, {
  FreshPartialCleanup = 'fresh',
}, partial_stale_cleanup_dir)
os.rename = original_stale_rename
h.assert_true(not partial_stale_ok, 'storage.save accepted a partial stale TOML cleanup', scope)
h.assert_file_exists(partial_stale_first_path, 'partial stale cleanup removed an earlier stale file', scope)
h.assert_equal(
  vim.uv.fs_stat(partial_stale_first_path).mode % 512,
  384,
  'partial stale cleanup rollback broadened file permissions',
  scope
)
h.assert_file_exists(partial_stale_second_path, 'partial stale cleanup lost the failing stale file', scope)
h.cleanup_dir(partial_stale_cleanup_dir)

local stale_symlink_rollback_dir = h.temp_dir('hlcraft-storage-stale-symlink-rollback')
vim.fn.mkdir(stale_symlink_rollback_dir, 'p')
local stale_symlink_rollback_target = stale_symlink_rollback_dir .. '-target.toml'
h.cleanup_dir(stale_symlink_rollback_target)
h.write_file(stale_symlink_rollback_target, {
  '["old-link"]',
  '"OldLink" = { fg = "#101010" }',
})
local stale_symlink_rollback_link = stale_symlink_rollback_dir .. '/old-link.toml'
local stale_symlink_rollback_link_ok, stale_symlink_rollback_link_err =
  vim.uv.fs_symlink(stale_symlink_rollback_target, stale_symlink_rollback_link)
h.assert_true(
  stale_symlink_rollback_link_ok,
  ('failed to create stale symlink rollback fixture: %s'):format(tostring(stale_symlink_rollback_link_err)),
  scope
)
local stale_symlink_rollback_second = stale_symlink_rollback_dir .. '/old-regular.toml'
h.write_file(stale_symlink_rollback_second, {
  '["old-regular"]',
  '"OldRegular" = { fg = "#202020" }',
})
original_stale_rename = os.rename
os.rename = function(src, dst)
  if src == stale_symlink_rollback_second and dst == stale_symlink_rollback_second .. '.bak' then
    return nil, 'backup failed'
  end
  return original_stale_rename(src, dst)
end
local stale_symlink_rollback_ok = storage.save({
  FreshSymlinkRollback = { fg = '#303030' },
}, {
  FreshSymlinkRollback = 'fresh',
}, stale_symlink_rollback_dir)
os.rename = original_stale_rename
h.assert_true(not stale_symlink_rollback_ok, 'storage.save accepted failed stale symlink rollback cleanup', scope)
h.assert_equal(
  vim.uv.fs_lstat(stale_symlink_rollback_link).type,
  'link',
  'failed stale symlink cleanup restored link as a regular file',
  scope
)
h.assert_equal(
  h.read_file(stale_symlink_rollback_target),
  '["old-link"]\n"OldLink" = { fg = "#101010" }\n',
  'failed stale symlink cleanup changed symlink target content',
  scope
)
h.assert_file_exists(stale_symlink_rollback_second, 'failed stale symlink cleanup lost later stale file', scope)
h.cleanup_dir(stale_symlink_rollback_dir)
h.cleanup_dir(stale_symlink_rollback_target)

local stale_backup_cleanup_dir = h.temp_dir('hlcraft-storage-stale-backup-cleanup-failure')
vim.fn.mkdir(stale_backup_cleanup_dir, 'p')
local stale_backup_cleanup_first_path = stale_backup_cleanup_dir .. '/old-a.toml'
local stale_backup_cleanup_second_path = stale_backup_cleanup_dir .. '/old-b.toml'
h.write_file(stale_backup_cleanup_first_path, {
  '["old-a"]',
  '"OldA" = { fg = "#000000" }',
})
h.write_file(stale_backup_cleanup_second_path, {
  '["old"]',
  '"OldB" = { fg = "#000000" }',
})
original_os_remove = os.remove
os.remove = function(path)
  local blocked_backup = stale_backup_cleanup_second_path .. '.bak'
  if path:sub(1, #blocked_backup) == blocked_backup then
    return nil, 'remove failed'
  end
  return original_os_remove(path)
end
local stale_backup_cleanup_ok, stale_backup_cleanup_err = files.remove_stale_toml_files(stale_backup_cleanup_dir, {})
os.remove = original_os_remove
h.assert_true(
  stale_backup_cleanup_ok,
  stale_backup_cleanup_err or 'stale TOML cleanup rejected final backup cleanup',
  scope
)
h.assert_file_missing(stale_backup_cleanup_first_path, 'stale backup cleanup failure kept first stale TOML file', scope)
h.assert_file_missing(
  stale_backup_cleanup_second_path,
  'stale backup cleanup failure kept second stale TOML file',
  scope
)
h.assert_file_missing(
  stale_backup_cleanup_first_path .. '.bak',
  'stale backup cleanup failure left first canonical backup',
  scope
)
h.assert_file_missing(
  stale_backup_cleanup_second_path .. '.bak',
  'stale backup cleanup failure left second canonical backup',
  scope
)
h.cleanup_dir(stale_backup_cleanup_dir)

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
h.assert_file_missing(persist_dir .. '/linked.toml', 'stale symlinked TOML file was not removed', scope)
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
local invalid_toml_broken_link_opts_ok = pcall(files.toml_files_in_dir, persist_dir, { include_broken_links = 'yes' })
h.assert_true(
  not invalid_toml_broken_link_opts_ok,
  'toml directory scan accepted non-boolean broken link option',
  scope
)
local unknown_toml_dir_opts_ok = pcall(files.toml_files_in_dir, persist_dir, { unknown = true })
h.assert_true(not unknown_toml_dir_opts_ok, 'toml directory scan accepted an unknown option', scope)
local invalid_temp_lines_ok = pcall(files.write_temp, persist_dir .. '/bad.toml', { false })
h.assert_true(not invalid_temp_lines_ok, 'write_temp accepted a non-string content line', scope)
local empty_temp_path_ok = pcall(files.write_temp, '   ', {})
h.assert_true(not empty_temp_path_ok, 'write_temp accepted an empty path', scope)
local non_sequence_temp_lines_ok = pcall(files.write_temp, persist_dir .. '/bad.toml', { ok = 'line' })
h.assert_true(not non_sequence_temp_lines_ok, 'write_temp accepted non-sequence content lines', scope)
local failed_write_path = persist_dir .. '/failed-write.toml'
local failed_write_original = '["failed-write"]\n"OldWrite" = { fg = "#111111" }\n'
h.write_file(failed_write_path, {
  '["failed-write"]',
  '"OldWrite" = { fg = "#111111" }',
})
local original_io_open = io.open
io.open = function(path, mode)
  local file, err = original_io_open(path, mode)
  if is_temp_path(path, failed_write_path) and file then
    return {
      write = function()
        return nil, 'write failed'
      end,
      close = function()
        return file:close()
      end,
    }
  end
  return file, err
end
local failed_write_ok, failed_write_err = files.write_temp(failed_write_path, { 'new content' })
io.open = original_io_open
h.assert_true(not failed_write_ok, 'write_temp accepted failed file write', scope)
h.assert_true(
  type(failed_write_err) == 'string' and failed_write_err:find('Failed to write temp file', 1, true) ~= nil,
  'write_temp write failure error changed',
  scope
)
h.assert_equal(h.read_file(failed_write_path), failed_write_original, 'failed write_temp replaced target file', scope)
assert_no_temp_files(failed_write_path, 'failed write_temp kept temp file')
local failed_close_path = persist_dir .. '/failed-close.toml'
local failed_close_original = '["failed-close"]\n"OldClose" = { fg = "#111111" }\n'
h.write_file(failed_close_path, {
  '["failed-close"]',
  '"OldClose" = { fg = "#111111" }',
})
io.open = function(path, mode)
  local file, err = original_io_open(path, mode)
  if is_temp_path(path, failed_close_path) and file then
    return {
      write = function(_, text)
        return file:write(text)
      end,
      close = function()
        file:close()
        return nil, 'close failed'
      end,
    }
  end
  return file, err
end
local failed_close_ok, failed_close_err = files.write_temp(failed_close_path, { 'new content' })
io.open = original_io_open
h.assert_true(not failed_close_ok, 'write_temp accepted failed file close', scope)
h.assert_true(
  type(failed_close_err) == 'string' and failed_close_err:find('Failed to close temp file', 1, true) ~= nil,
  'write_temp close failure error changed',
  scope
)
h.assert_equal(
  h.read_file(failed_close_path),
  failed_close_original,
  'failed close write_temp replaced target file',
  scope
)
assert_no_temp_files(failed_close_path, 'failed close write_temp kept temp file')
local invalid_stale_sections_ok = pcall(files.remove_stale_toml_files, persist_dir, false)
h.assert_true(not invalid_stale_sections_ok, 'stale TOML cleanup accepted non-table section names', scope)
local empty_stale_path_ok = pcall(files.remove_stale_toml_files, '   ', {})
h.assert_true(not empty_stale_path_ok, 'stale TOML cleanup accepted an empty path', scope)
local non_sequence_stale_sections_ok = pcall(files.remove_stale_toml_files, persist_dir, { active = true })
h.assert_true(not non_sequence_stale_sections_ok, 'stale TOML cleanup accepted non-sequence section names', scope)

local saved = storage.load(persist_dir)
h.assert_true(saved.entries.LinkedNormal == nil, 'stale symlinked TOML entry reloaded after save', scope)
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
