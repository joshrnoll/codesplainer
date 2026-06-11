vim.opt.runtimepath:prepend(vim.fn.getcwd())

local markdown = require("codesplainer.markdown")

local failures = 0

local function assert_equal(name, actual, expected)
  if vim.inspect(actual) ~= vim.inspect(expected) then
    failures = failures + 1
    io.stderr:write("FAIL: " .. name .. "\n")
    io.stderr:write("expected: " .. vim.inspect(expected) .. "\n")
    io.stderr:write("actual:   " .. vim.inspect(actual) .. "\n\n")
  end
end

local function format(text)
  return markdown.format_lines(text)
end

assert_equal("heading spacing", format("intro\n## Heading\nbody"), {
  "intro",
  "",
  "## Heading",
  "",
  "body",
  "",
})

assert_equal("fenced code spacing", format("text\n```lua\nprint(1)\n```\nafter"), {
  "text",
  "",
  "```lua",
  "print(1)",
  "```",
  "",
  "after",
  "",
})

assert_equal("variable length tilde fence", format("text\n~~~~python\nprint(1)\n~~~~\nafter"), {
  "text",
  "",
  "~~~~python",
  "print(1)",
  "~~~~",
  "",
  "after",
  "",
})

assert_equal("lists stay cohesive", format("para\n- a\n- b\nafter"), {
  "para",
  "",
  "- a",
  "- b",
  "",
  "after",
  "",
})

assert_equal("ordered and task lists", format("para\n1. one\n2. two\n- [ ] task\nafter"), {
  "para",
  "",
  "1. one",
  "2. two",
  "- [ ] task",
  "",
  "after",
  "",
})

assert_equal("blockquotes stay cohesive", format("para\n> quote\n> more\nafter"), {
  "para",
  "",
  "> quote",
  "> more",
  "",
  "after",
  "",
})

assert_equal("tables stay cohesive", format("para\n| a | b |\n| - | - |\n| 1 | 2 |\nafter"), {
  "para",
  "",
  "| a | b |",
  "| - | - |",
  "| 1 | 2 |",
  "",
  "after",
  "",
})

assert_equal("horizontal rule spacing", format("before\n---\nafter"), {
  "before",
  "",
  "---",
  "",
  "after",
  "",
})

assert_equal("indented code spacing", format("before\n    code\n    more\nafter"), {
  "before",
  "",
  "    code",
  "    more",
  "",
  "after",
  "",
})

assert_equal("html block spacing", format("before\n<details>\nbody\n</details>\nafter"), {
  "before",
  "",
  "<details>",
  "",
  "body",
  "",
  "</details>",
  "",
  "after",
  "",
})

assert_equal("math block spacing", format("para\n$$\nx=1\n$$\nafter"), {
  "para",
  "",
  "$$",
  "x=1",
  "$$",
  "",
  "after",
  "",
})

assert_equal("directive block spacing", format("para\n:::note\nbody\n:::\nafter"), {
  "para",
  "",
  ":::note",
  "body",
  ":::",
  "",
  "after",
  "",
})

assert_equal("escaped newline response", format("para\\n```js\\nx()\\n```"), {
  "para",
  "",
  "```js",
  "x()",
  "```",
  "",
})

assert_equal("headings inside fences untouched", format("before\n```md\n## not heading\ntext\n```\nafter"), {
  "before",
  "",
  "```md",
  "## not heading",
  "text",
  "```",
  "",
  "after",
  "",
})

if failures > 0 then
  vim.cmd("cquit 1")
end

print("markdown_spec.lua: ok")
vim.cmd("quit")
