local M = {}

local function is_blank(line)
  return line == nil or line:match("^%s*$") ~= nil
end

local function split_lines(text)
  text = text or ""
  -- Some APIs/models return literal escaped newlines in otherwise single-line text.
  if not text:find("\n", 1, true) and text:find("\\n", 1, true) then
    text = text:gsub("\\n", "\n")
  end
  return vim.split(text, "\n", { plain = true })
end

local function append_blank(out)
  if #out > 0 and not is_blank(out[#out]) then
    table.insert(out, "")
  end
end

local function append_line(out, line)
  if is_blank(line) then
    append_blank(out)
  else
    table.insert(out, line)
  end
end

local function fence_marker(line)
  local ticks = line:match("^%s*(```+)")
  if ticks then
    return ticks
  end
  return line:match("^%s*(~~~+)")
end

local function is_math_fence(line)
  return line:match("^%s*%$%$%s*$") ~= nil
end

local function is_directive_fence(line)
  return line:match("^%s*:::+") ~= nil
end

local function is_atx_heading(line)
  return line:match("^%s*#+%s+") ~= nil
end

local function is_setext_underline(line)
  return line:match("^%s*=+%s*$") ~= nil or line:match("^%s*%-+%s*$") ~= nil
end

local function is_hr(line)
  local trimmed = vim.trim(line)
  return trimmed:match("^%-%-%-+%s*$") ~= nil or trimmed:match("^%*%*%*+%s*$") ~= nil or trimmed:match("^___+%s*$") ~= nil
end

local function is_list(line)
  return line:match("^%s*[%-%+%*]%s+") ~= nil
    or line:match("^%s*[%-%+%*]%s+%[[ xX]%]%s+") ~= nil
    or line:match("^%s*%d+[.)]%s+") ~= nil
end

local function is_blockquote(line)
  return line:match("^%s*>") ~= nil
end

local function is_table(line)
  if not line:find("|", 1, true) then
    return false
  end
  return line:match("^%s*|.*|%s*$") ~= nil or line:match("^%s*:?%-+.*|.*%-+:?%s*$") ~= nil
end

local function is_indented_code(line)
  return line:match("^    %S") ~= nil or line:match("^\t%S") ~= nil
end

local function is_html(line)
  return line:match("^%s*</?[%a][%w-]*") ~= nil or line:match("^%s*<!(%-%-)?") ~= nil
end

local function classify(line, previous_line, next_line)
  if is_blank(line) then
    return "blank"
  end
  if fence_marker(line) then
    return "fence"
  end
  if is_math_fence(line) then
    return "math"
  end
  if is_directive_fence(line) then
    return "directive"
  end
  if is_atx_heading(line) then
    return "heading"
  end
  if is_setext_underline(line) and previous_line and not is_blank(previous_line) and not is_blank(next_line) then
    return "heading"
  end
  if is_hr(line) then
    return "hr"
  end
  if is_blockquote(line) then
    return "blockquote"
  end
  if is_list(line) then
    return "list"
  end
  if is_table(line) then
    return "table"
  end
  if is_indented_code(line) then
    return "indented_code"
  end
  if is_html(line) then
    return "html"
  end
  return "paragraph"
end

local isolated = {
  heading = true,
  hr = true,
  fence = true,
  math = true,
  directive = true,
  indented_code = true,
  html = true,
}

local cohesive = {
  paragraph = true,
  list = true,
  blockquote = true,
  table = true,
  indented_code = true,
  html = true,
}

local function needs_boundary(previous_kind, current_kind)
  if not previous_kind or previous_kind == "blank" or current_kind == "blank" then
    return false
  end
  if previous_kind == current_kind and cohesive[current_kind] then
    return false
  end
  if isolated[previous_kind] or isolated[current_kind] then
    return true
  end
  return previous_kind ~= current_kind
end

local function append_block_line(out, line, kind, state)
  if needs_boundary(state.previous_kind, kind) then
    append_blank(out)
  end
  append_line(out, line)
  if kind ~= "blank" then
    state.previous_kind = kind
  end
end

local function handle_fenced_block(out, line, next_line, state, marker)
  if not state.fence_marker then
    if needs_boundary(state.previous_kind, "fence") then
      append_blank(out)
    end
    state.fence_marker = marker
    table.insert(out, line)
    return true
  end

  table.insert(out, line)
  if line:match("^%s*" .. vim.pesc(state.fence_marker)) then
    state.fence_marker = nil
    state.previous_kind = "fence"
    if not is_blank(next_line) then
      append_blank(out)
    end
  end
  return true
end

local function handle_delimited_block(out, line, next_line, state, field, kind, is_delimiter)
  if not state[field] then
    if needs_boundary(state.previous_kind, kind) then
      append_blank(out)
    end
    state[field] = true
    table.insert(out, line)
    return true
  end

  table.insert(out, line)
  if is_delimiter(line) then
    state[field] = false
    state.previous_kind = kind
    if not is_blank(next_line) then
      append_blank(out)
    end
  end
  return true
end

function M.format_lines(text)
  local input = split_lines(text)
  local output = {}
  local state = {
    previous_kind = nil,
    fence_marker = nil,
    in_math = false,
    in_directive = false,
  }

  for i, line in ipairs(input) do
    local previous_line = input[i - 1]
    local next_line = input[i + 1]

    if state.fence_marker or fence_marker(line) then
      handle_fenced_block(output, line, next_line, state, fence_marker(line))
    elseif state.in_math or is_math_fence(line) then
      handle_delimited_block(output, line, next_line, state, "in_math", "math", is_math_fence)
    elseif state.in_directive or is_directive_fence(line) then
      handle_delimited_block(output, line, next_line, state, "in_directive", "directive", is_directive_fence)
    else
      append_block_line(output, line, classify(line, previous_line, next_line), state)
    end
  end

  if not is_blank(output[#output]) then
    table.insert(output, "")
  end

  return output
end

M._private = {
  classify = classify,
  needs_boundary = needs_boundary,
}

return M
