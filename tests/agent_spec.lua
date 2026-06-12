vim.opt.runtimepath:prepend(vim.fn.getcwd())

local failures = 0

local function assert_equal(name, actual, expected)
  if vim.inspect(actual) ~= vim.inspect(expected) then
    failures = failures + 1
    io.stderr:write("FAIL: " .. name .. "\n")
    io.stderr:write("expected: " .. vim.inspect(expected) .. "\n")
    io.stderr:write("actual:   " .. vim.inspect(actual) .. "\n\n")
  end
end

local tool_calls = {}
package.preload["codesplainer.lsp"] = function()
  return {
    run_tool = function(call)
      table.insert(tool_calls, call)
      return "tool result"
    end,
  }
end

local stream_runs = 0
package.preload["codesplainer.providers.openai"] = function()
  return {
    stream = function(_, emit)
      stream_runs = stream_runs + 1
      if stream_runs == 1 then
        emit({ type = "text_delta", text = "```lsp-tool\n" })
        emit({ type = "text_delta", text = '{"tool":"snippet","file":"/tmp/example.lua","start_line":1,"end_line":2}' })
        emit({ type = "text_delta", text = "\n```" })
      else
        emit({ type = "text_delta", text = "final " })
        emit({ type = "text_delta", text = "answer" })
        emit({ type = "done" })
      end
      return { cancel = function() end }
    end,
  }
end

local config = require("codesplainer.config")
config.setup({ provider = "openai" })
local agent = require("codesplainer.agent")

local messages = { { role = "system", content = "system" }, { role = "user", content = "question" } }
local text = {}
local observed_tool = nil
local done_answer = nil

agent.run(messages, {
  on_text = function(delta)
    table.insert(text, delta)
  end,
  on_tool_call = function(call)
    observed_tool = call
  end,
  on_done = function(answer)
    done_answer = answer
  end,
  on_error = function(err)
    failures = failures + 1
    io.stderr:write("FAIL: unexpected error: " .. tostring(err) .. "\n")
  end,
})

assert_equal("streams final answer after tool result", table.concat(text, ""), "final answer")
assert_equal("reports parsed tool call", observed_tool and observed_tool.tool, "snippet")
assert_equal("runs lsp tool", tool_calls[1] and tool_calls[1].file, "/tmp/example.lua")
assert_equal("adds assistant tool-call message", messages[3] and messages[3].role, "assistant")
assert_equal("adds tool result as user message", messages[4] and messages[4].role, "user")
assert_equal("done answer", done_answer, "final answer")

if failures > 0 then
  vim.cmd("cquit 1")
end

print("agent_spec.lua: ok")
vim.cmd("quit")
