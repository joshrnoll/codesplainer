local config = require("lsp-llm-chat.config")

local M = {}

local state = { bufnr = nil, winid = nil }

local function valid_window()
  return state.winid and vim.api.nvim_win_is_valid(state.winid)
end

local function valid_buffer()
  return state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)
end

local function configure_buffer(bufnr)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = config.options.window.filetype
  vim.keymap.set("n", "q", M.hide, { buffer = bufnr, silent = true, desc = "Hide LSP LLM Chat" })
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    require("lsp-llm-chat").submit()
  end, { buffer = bufnr, silent = true, desc = "Send LSP LLM Chat message" })
end

local function window_width()
  local width = config.options.window.width
  if type(width) == "number" and width > 0 and width < 1 then
    return math.max(20, math.floor(vim.o.columns * width))
  end
  return width
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
    vim.api.nvim_buf_set_name(state.bufnr, "LSP LLM Chat")
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
  if not valid_window() then
    return
  end
  vim.api.nvim_win_close(state.winid, false)
  state.winid = nil
end

function M.is_empty()
  if not valid_buffer() then
    return true
  end
  local line_count = vim.api.nvim_buf_line_count(state.bufnr)
  return line_count == 1 and vim.api.nvim_buf_get_lines(state.bufnr, 0, 1, false)[1] == ""
end

local function normalize_lines(lines)
  local normalized = {}
  for _, line in ipairs(lines) do
    if type(line) ~= "string" then
      line = tostring(line)
    end
    local parts = vim.split(line, "\n", { plain = true })
    vim.list_extend(normalized, parts)
  end
  return normalized
end

function M.set_lines(lines)
  local bufnr = M.open()
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, normalize_lines(lines))
  vim.bo[bufnr].modifiable = false
end

function M.append(lines)
  local bufnr = M.open()
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, normalize_lines(lines))
  vim.bo[bufnr].modifiable = false
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(state.winid, { line_count, 0 })
end

function M.remove_last_line_if(pattern)
  local bufnr = M.open()
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count == 0 then
    return
  end

  local target = line_count
  while target > 0 do
    local line = vim.api.nvim_buf_get_lines(bufnr, target - 1, target, false)[1] or ""
    if line ~= "" then
      if not line:match(pattern) then
        return
      end
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, target - 1, target, false, {})
      vim.bo[bufnr].modifiable = false
      return
    end
    target = target - 1
  end
end

function M.prompt()
  local bufnr = M.open()
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "## You", "", "" })
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(state.winid, { line_count, 0 })
  vim.cmd("startinsert")
end

function M.submit_line()
  local bufnr = M.open()
  local row = vim.api.nvim_win_get_cursor(state.winid)[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  line = vim.trim(line)
  if line == "" then
    return nil
  end
  vim.cmd("stopinsert")
  vim.bo[bufnr].modifiable = false
  return line
end

return M
