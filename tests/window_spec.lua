vim.opt.runtimepath:prepend(vim.fn.getcwd())

local window = require("codesplainer.window")
local failures = 0

local function assert_equal(name, actual, expected)
  if vim.inspect(actual) ~= vim.inspect(expected) then
    failures = failures + 1
    io.stderr:write("FAIL: " .. name .. "\n")
    io.stderr:write("expected: " .. vim.inspect(expected) .. "\n")
    io.stderr:write("actual:   " .. vim.inspect(actual) .. "\n\n")
  end
end

window.replace({ "## Codesplainer", "", "_Thinking..._", "" })
window.prepare_response_body()
window.append_text_delta(table.concat({ "```json", vim.fn.json_encode({ tool = "snippet" }), "```" }, "\n"))
window.prepare_response_body()
window.append_text_delta("final answer")

assert_equal("tool call and text blocks have consistent spacing", vim.api.nvim_buf_get_lines(0, 0, -1, false), {
  "## Codesplainer",
  "",
  "_Thinking..._",
  "",
  "```json",
  '{"tool": "snippet"}',
  "```",
  "",
  "final answer",
})

window.replace({ "# Codesplainer", "", "intro" })
window.start_prompt()
window.discard_empty_prompt()
assert_equal("empty prompt can be discarded before explicit user section", vim.api.nvim_buf_get_lines(0, 0, -1, false), {
  "# Codesplainer",
  "",
  "intro",
})

if failures > 0 then
  vim.cmd("cquit 1")
end

print("window_spec.lua: ok")
vim.cmd("quit")
