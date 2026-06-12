vim.opt.runtimepath:prepend(vim.fn.getcwd())

package.preload["codesplainer.providers.openai"] = function()
  return {
    complete = function(_, cb)
      cb("stub response", nil)
    end,
  }
end

vim.cmd("runtime plugin/codesplainer.lua")

local failures = 0

local function assert_true(name, condition, detail)
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL: " .. name .. "\n")
    if detail then
      io.stderr:write(detail .. "\n")
    end
  end
end

local function buffer_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function has_line(lines, target)
  return vim.tbl_contains(lines, target)
end

local function line_index(lines, target)
  for index, line in ipairs(lines) do
    if line == target then
      return index
    end
  end
  return nil
end

local function count_lines(lines, target)
  local count = 0
  for _, line in ipairs(lines) do
    if line == target then
      count = count + 1
    end
  end
  return count
end

assert_true("Codesplainer command exists", vim.fn.exists(":Codesplainer") == 2)
assert_true("CodesplainerAsk command exists", vim.fn.exists(":CodesplainerAsk") == 2)
assert_true("CodesplainerClear command exists", vim.fn.exists(":CodesplainerClear") == 2)
assert_true("CodesplainerCodexLogin command exists", vim.fn.exists(":CodesplainerCodexLogin") == 2)
assert_true("CodesplainerShow command removed", vim.fn.exists(":CodesplainerShow") == 0)
assert_true("CodesplainerHide command removed", vim.fn.exists(":CodesplainerHide") == 0)

local initial_windows = vim.fn.winnr("$")
vim.cmd("Codesplainer")
assert_true("Codesplainer opens chat", vim.fn.winnr("$") == initial_windows + 1)
assert_true("Codesplainer buffer named", vim.api.nvim_buf_get_name(0):match("Codesplainer$") ~= nil)
assert_true("chat intro mentions normal-mode send", has_line(buffer_lines(), "Persistent chat. Type at the bottom; press Enter in normal mode to send. Visual-select code and run `:CodesplainerAsk` to include LSP context."))
assert_true("normal Enter submits chat", not vim.tbl_isempty(vim.fn.maparg("<CR>", "n", false, true)))
assert_true("insert Enter is unmapped", vim.tbl_isempty(vim.fn.maparg("<CR>", "i", false, true)))

vim.cmd("Codesplainer hello")
local lines = buffer_lines()
assert_true("assistant section labeled Codesplainer", has_line(lines, "## Codesplainer"))
assert_true("assistant section not labeled Assistant", not has_line(lines, "## Assistant"))
assert_true("empty prompt is deduplicated before direct message", count_lines(lines, "## You") == 2)
local thinking_index = line_index(lines, "_Thinking..._")
assert_true("Thinking has one newline before response", thinking_index and lines[thinking_index + 1] == "" and lines[thinking_index + 2] == "stub response")

vim.cmd("stopinsert")
vim.cmd("Codesplainer")
assert_true("Codesplainer toggles chat closed", vim.fn.winnr("$") == initial_windows)

if failures > 0 then
  vim.cmd("cquit 1")
end

print("command_spec.lua: ok")
vim.cmd("quit")
