vim.opt.runtimepath:prepend(vim.fn.getcwd())

local lsp = require("codesplainer.lsp")
local failures = 0

local function assert_equal(name, actual, expected)
  if actual ~= expected then
    failures = failures + 1
    io.stderr:write("FAIL: " .. name .. "\n")
    io.stderr:write("expected: " .. vim.inspect(expected) .. "\n")
    io.stderr:write("actual:   " .. vim.inspect(actual) .. "\n")
  end
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "alpha beta",
  "gamma delta",
  "epsilon zeta",
})

local ranged = lsp.visual_selection({ range = 2, line1 = 1, line2 = 2 })
assert_equal("range fallback captures requested lines", ranged and ranged.text, "alpha beta\ngamma delta")
assert_equal("range fallback start line", ranged and ranged.start_line, 1)
assert_equal("range fallback end line", ranged and ranged.end_line, 2)

vim.cmd("normal! 3G0v5l")
local active = lsp.visual_selection()
assert_equal("active visual selection works before visual marks are finalized", active and active.text, "epsilo")
vim.cmd("normal! \027")

if failures > 0 then
  vim.cmd("cquit 1")
end

print("visual_selection_spec.lua: ok")
vim.cmd("quit!")
