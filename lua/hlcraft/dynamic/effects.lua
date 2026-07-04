local color = require('hlcraft.core.color')
local model = require('hlcraft.dynamic.model')
local timeline = require('hlcraft.dynamic.timeline')
local transforms = require('hlcraft.dynamic.transforms')

local M = {}

local function normalize_hex(value)
  if type(value) == 'number' then
    return color.int_to_hex(value)
  end
  if type(value) ~= 'string' then
    return nil
  end

  local normalized = color.normalize(value)
  if normalized and normalized ~= 'NONE' then
    return normalized
  end
  return nil
end

local function resolve_color_ref(value, base_hex, context)
  if value == 'base' then
    return base_hex
  end
  if value == 'fg' or value == 'bg' or value == 'sp' then
    return normalize_hex(context and context[value])
  end
  return normalize_hex(value)
end

local function interpolate_hex(left_hex, right_hex, amount)
  local left = color.hex_to_int(left_hex)
  local right = color.hex_to_int(right_hex)
  if not left or not right then
    return nil
  end

  local lr, lg, lb = color.int_to_rgb(left)
  local rr, rg, rb = color.int_to_rgb(right)
  return color.rgb_to_hex(lr + ((rr - lr) * amount), lg + ((rg - lg) * amount), lb + ((rb - lb) * amount))
end

function M.compute(spec, base_hex, now_ms, context)
  local normalized = model.normalize_channel(spec)
  base_hex = normalize_hex(base_hex)
  if not normalized or not base_hex then
    return nil
  end

  local phase = timeline.phase(now_ms, normalized.duration, normalized.phase, normalized.loop)
  local sampled = timeline.sample(normalized.timeline, phase, normalized.interpolation, function(left, right, amount)
    local left_color = resolve_color_ref(left.color, base_hex, context)
    local right_color = resolve_color_ref(right.color, base_hex, context)
    if not left_color or not right_color then
      return nil
    end

    return {
      at = phase,
      color = interpolate_hex(left_color, right_color, amount),
    }
  end)
  local computed = sampled and resolve_color_ref(sampled.color, base_hex, context) or nil
  if not computed then
    return nil
  end

  for _, transform in ipairs(normalized.transforms) do
    local value = timeline.sample_numeric(transform.timeline, phase, transform.interpolation)
    computed = transforms.apply(computed, { type = transform.type, value = value })
    if not computed then
      return nil
    end
  end

  return computed
end

return M
