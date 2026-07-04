local M = {}

local function before_input_end(input, row0)
  return input and input.end_row > input.start_row and row0 < input.end_row
end

local function plan(key, opts)
  if opts == nil then
    opts = {}
  end
  return {
    key = key,
    append_newline = opts.append_newline == true,
    cleanup_trailing_newline = opts.cleanup_trailing_newline == true,
  }
end

function M.below(input, row0, is_visual)
  if not input then
    return plan('p')
  end

  if not is_visual and before_input_end(input, row0) then
    return plan('p')
  end

  if not is_visual and input.value == '' then
    return plan('P', { cleanup_trailing_newline = true })
  end

  return plan('p', {
    append_newline = true,
    cleanup_trailing_newline = true,
  })
end

function M.above(input, row0, is_visual)
  if not input then
    return plan('P')
  end

  if not is_visual and before_input_end(input, row0) then
    return plan('P')
  end

  if is_visual then
    return plan('P', {
      append_newline = true,
      cleanup_trailing_newline = true,
    })
  end

  return plan('P', {
    cleanup_trailing_newline = input.value == '',
  })
end

return M
