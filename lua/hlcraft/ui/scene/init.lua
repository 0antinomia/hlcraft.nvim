local M = {}

local registry = {}
local scene_methods = { 'enter', 'render', 'handle', 'back' }
local state_snapshot_keys = {
  'clamping_cursor',
  'color_query',
  'detail_index',
  'extmark_ids',
  'field_editor',
  'geometry',
  'input_marks',
  'list_cursor',
  'name_query',
  'placeholder_marks',
  'rendering',
  'results',
  'scene',
}

local function assert_scene_name(name, label, level)
  if type(name) ~= 'string' or name == '' then
    error(('%s must be a non-empty string'):format(label), level or 3)
  end
  return name
end

local function scene_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('scene lookup requires an instance', 3)
  end
  local state = instance.state.scene
  if type(state) ~= 'table' then
    error('scene state must be a table', 3)
  end
  assert_scene_name(state.name, 'scene name', 3)
  return state
end

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('scene set requires an instance', 3)
  end
  return instance.state
end

local function optional_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('scene options must be a table', 3)
  end
  if opts.name ~= nil then
    error('scene options must not define name', 3)
  end
  return opts
end

local function assert_scene(scene)
  if type(scene) ~= 'table' then
    error('scene registration must be a table', 3)
  end
  for _, method in ipairs(scene_methods) do
    if scene[method] ~= nil and type(scene[method]) ~= 'function' then
      error(('scene %s method must be a function'):format(method), 3)
    end
  end
  return scene
end

local function snapshot_state(state)
  local snapshot = {}
  for _, key in ipairs(state_snapshot_keys) do
    snapshot[key] = vim.deepcopy(state[key])
  end
  return snapshot
end

local function restore_state(state, snapshot)
  for _, key in ipairs(state_snapshot_keys) do
    state[key] = snapshot[key]
  end
end

function M.register(name, scene)
  name = assert_scene_name(name, 'scene registration name', 2)
  scene = assert_scene(scene)
  if registry[name] ~= nil then
    error(('scene already registered: %s'):format(name), 2)
  end
  registry[name] = scene
end

function M.current_name(instance)
  return scene_state(instance).name
end

function M.current(instance)
  local name = M.current_name(instance)
  local current = registry[name]
  if not current then
    error(('unknown current scene: %s'):format(name), 2)
  end
  return current
end

function M.set(instance, name, opts)
  name = assert_scene_name(name, 'scene name', 2)
  opts = optional_opts(opts)
  local state = instance_state(instance)
  local scene = registry[name]
  if not scene then
    return false, ('unknown scene: %s'):format(tostring(name))
  end
  local snapshot = snapshot_state(state)
  state.scene = vim.tbl_extend('force', opts, { name = name })
  if scene.enter then
    local ok, err = pcall(scene.enter, instance, opts)
    if not ok then
      restore_state(state, snapshot)
      error(err, 0)
    end
  end
  return true, nil
end

function M.render(instance)
  local state = instance_state(instance)
  local scene = M.current(instance)
  if scene.render then
    local snapshot = snapshot_state(state)
    local ok, result = xpcall(function()
      return scene.render(instance)
    end, debug.traceback)
    if not ok then
      restore_state(state, snapshot)
      error(result, 0)
    end
    return result
  end
end

function M.handle(instance, action, ...)
  action = assert_scene_name(action, 'scene action', 2)
  local scene = M.current(instance)
  if scene.handle then
    return scene.handle(instance, action, ...)
  end
  return false, ('unsupported action: %s'):format(tostring(action))
end

function M.back(instance)
  local scene = M.current(instance)
  if scene.back then
    return scene.back(instance)
  end
  return false, 'current scene cannot go back'
end

return M
