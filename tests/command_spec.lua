vim.opt.runtimepath:prepend(vim.fn.getcwd())
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

assert_true("Codesplainer command exists", vim.fn.exists(":Codesplainer") == 2)
assert_true("CodesplainerAsk command exists", vim.fn.exists(":CodesplainerAsk") == 2)
assert_true("CodesplainerClear command exists", vim.fn.exists(":CodesplainerClear") == 2)
assert_true("CodesplainerShow command removed", vim.fn.exists(":CodesplainerShow") == 0)
assert_true("CodesplainerHide command removed", vim.fn.exists(":CodesplainerHide") == 0)

local initial_windows = vim.fn.winnr("$")
vim.cmd("Codesplainer")
assert_true("Codesplainer opens chat", vim.fn.winnr("$") == initial_windows + 1)
assert_true("Codesplainer buffer named", vim.api.nvim_buf_get_name(0):match("Codesplainer$") ~= nil)

vim.cmd("stopinsert")
vim.cmd("Codesplainer")
assert_true("Codesplainer toggles chat closed", vim.fn.winnr("$") == initial_windows)

if failures > 0 then
  vim.cmd("cquit 1")
end

print("command_spec.lua: ok")
vim.cmd("quit")
