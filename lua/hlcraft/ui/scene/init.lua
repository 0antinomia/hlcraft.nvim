local M = {}

local registry = {}

function M.register(name, scene)
  registry[name] = scene
end

function M.current_name(instance)
  return instance.state.scene and instance.state.scene.name or 'search'
end

function M.current(instance)
  return registry[M.current_name(instance)]
end

function M.set(instance, name, opts)
  opts = opts or {}
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
