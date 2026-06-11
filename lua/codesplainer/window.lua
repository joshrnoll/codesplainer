local config = require("codesplainer.config")

local M = {}

local state = {
  bufnr = nil,
  winid = nil,
  input_start = nil,
}

local function valid_window()
  return state.winid and vim.api.nvim_win_is_valid(state.winid)
end

local function valid_buffer()
  return state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)
end

local function normalize_lines(lines)
  local normalized = {}
  for _, line in ipairs(lines or {}) do
    local parts = vim.split(tostring(line), "\n", { plain = true })
    vim.list_extend(normalized, parts)
  end
  return normalized
end

local function set_modifiable(bufnr, value)
  vim.bo[bufnr].modifiable = value
end

local function window_width()
  local width = config.options.window.width
  if type(width) == "number" and width > 0 and width < 1 then
    return math.max(20, math.floor(vim.o.columns * width))
  end
  return width
end

local function configure_buffer(bufnr)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = config.options.window.filetype
  vim.keymap.set("n", "q", function()
    M.hide()
  end, { buffer = bufnr, silent = true, desc = "Hide Codesplainer" })
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    require("codesplainer").submit()
  end, { buffer = bufnr, silent = true, desc = "Send Codesplainer message" })
end

function M.open()
  if valid_window() then
    vim.api.nvim_set_current_win(state.winid)
    vim.api.nvim_win_set_width(state.winid, window_width())
    return state.bufnr, state.winid
  end

  vim.cmd("botright vertical new")
  state.winid = vim.api.nvim_get_current_win()

  if valid_buffer() then
    vim.api.nvim_win_set_buf(state.winid, state.bufnr)
  else
    state.bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(state.bufnr, "Codesplainer")
    configure_buffer(state.bufnr)
  end

  vim.wo[state.winid].wrap = true
  vim.api.nvim_win_set_width(state.winid, window_width())
  return state.bufnr, state.winid
end

function M.show()
  return M.open()
end

function M.hide()
  if valid_window() then
    vim.api.nvim_win_close(state.winid, false)
  end
  state.winid = nil
end

function M.is_empty()
  if not valid_buffer() then
    return true
  end
  local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
  return #lines == 0 or (#lines == 1 and lines[1] == "")
end

function M.replace(lines)
  local bufnr = M.open()
  set_modifiable(bufnr, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, normalize_lines(lines))
  set_modifiable(bufnr, false)
  state.input_start = nil
end

function M.append(lines)
  local bufnr = M.open()
  set_modifiable(bufnr, true)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, normalize_lines(lines))
  set_modifiable(bufnr, false)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(state.winid, { line_count, 0 })
end

function M.remove_last_nonblank_matching(pattern)
  local bufnr = M.open()
  for row = vim.api.nvim_buf_line_count(bufnr), 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    if line ~= "" then
      if line:match(pattern) then
        set_modifiable(bufnr, true)
        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, {})
        set_modifiable(bufnr, false)
      end
      return
    end
  end
end

function M.start_prompt()
  local bufnr = M.open()
  set_modifiable(bufnr, true)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "## You", "", "" })
  state.input_start = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(state.winid, { state.input_start, 0 })
  vim.cmd("startinsert")
end

function M.finish_prompt()
  local bufnr = M.open()
  if not state.input_start then
    return nil
  end

  local last = vim.api.nvim_buf_line_count(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, state.input_start - 1, last, false)
  local text = vim.trim(table.concat(lines, "\n"))
  if text == "" then
    return nil
  end

  vim.cmd("stopinsert")
  set_modifiable(bufnr, false)
  state.input_start = nil
  return text
end

return M
