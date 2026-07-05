local numbers = require('hlcraft.core.number')

local M = {}

local function assert_row0(row0)
  if type(row0) ~= 'number' then
    error('paste plan row must be a number', 3)
  end
  if not numbers.is_finite(row0) or math.floor(row0) ~= row0 or row0 < 0 then
    error('paste plan row must be a non-negative finite integer', 3)
  end
  return row0
end

local function assert_visual_flag(is_visual)
  if type(is_visual) ~= 'boolean' then
    error('paste plan visual flag must be boolean', 3)
  end
  return is_visual
end

local function assert_input(input)
  if input == nil then
    return nil
  end
  if type(input) ~= 'table' then
    error('paste plan input must be a table or nil', 3)
  end
  if
    type(input.start_row) ~= 'number'
    or not numbers.is_finite(input.start_row)
    or math.floor(input.start_row) ~= input.start_row
    or input.start_row < 0
  then
    error('paste plan input start row must be a non-negative finite integer', 3)
  end
  if
    type(input.end_row) ~= 'number'
    or not numbers.is_finite(input.end_row)
    or math.floor(input.end_row) ~= input.end_row
    or input.end_row < input.start_row
  then
    error('paste plan input end row must be a finite integer greater than or equal to start row', 3)
  end
  if type(input.value) ~= 'string' then
    error('paste plan input value must be a string', 3)
  end
  return input
end

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
  input = assert_input(input)
  row0 = assert_row0(row0)
  is_visual = assert_visual_flag(is_visual)
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
  input = assert_input(input)
  row0 = assert_row0(row0)
  is_visual = assert_visual_flag(is_visual)
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
