local M = {}

local registry = {}

local function assert_scene_name(name, label, level)
  if type(name) ~= 'string' or name == '' then
    error(('%s must be a non-empty string'):format(label), level or 3)
  end
  return name
end

local function scene_state(instance)
  if not instance or not instance.state then
    error('scene lookup requires an instance', 3)
  end
  local state = instance.state.scene
  if type(state) ~= 'table' then
    error('scene state must be a table', 3)
  end
  assert_scene_name(state.name, 'scene name', 3)
  return state
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

function M.register(name, scene)
  name = assert_scene_name(name, 'scene registration name', 2)
  if type(scene) ~= 'table' then
    error('scene registration must be a table', 2)
  end
  registry[name] = scene
end

function M.current_name(instance)
  return scene_state(instance).name
end

function M.current(instance)
  return registry[M.current_name(instance)]
end

function M.set(instance, name, opts)
  name = assert_scene_name(name, 'scene name', 2)
  opts = optional_opts(opts)
  local scene = registry[name]
  if not scene then
    return false, ('unknown scene: %s'):format(tostring(name))
  end
  instance.state.scene = vim.tbl_extend('force', opts, { name = name })
  if scene.enter then
    scene.enter(instance, opts)
  end
  return true, nil
end

function M.render(instance)
  local scene = M.current(instance)
  if scene and scene.render then
    return scene.render(instance)
  end
end

function M.handle(instance, action, ...)
  local scene = M.current(instance)
  if scene and scene.handle then
    return scene.handle(instance, action, ...)
  end
  return false, ('unsupported action: %s'):format(tostring(action))
end

function M.back(instance)
  local scene = M.current(instance)
  if scene and scene.back then
    return scene.back(instance)
  end
  return false, 'current scene cannot go back'
end

return M
