local M = {}

local registry = {}

local function scene_state(instance)
  if not instance or not instance.state then
    error('scene lookup requires an instance', 3)
  end
  local state = instance.state.scene
  if type(state) ~= 'table' then
    error('scene state must be a table', 3)
  end
  if type(state.name) ~= 'string' then
    error('scene name must be a string', 3)
  end
  return state
end

local function optional_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('scene options must be a table', 3)
  end
  return opts
end

function M.register(name, scene)
  registry[name] = scene
end

function M.current_name(instance)
  return scene_state(instance).name
end

function M.current(instance)
  return registry[M.current_name(instance)]
end

function M.set(instance, name, opts)
  if type(name) ~= 'string' then
    error('scene name must be a string', 2)
  end
  opts = optional_opts(opts)
  local scene = registry[name]
  if not scene then
    return false, ('unknown scene: %s'):format(tostring(name))
  end
  instance.state.scene = vim.tbl_extend('force', { name = name }, opts)
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
