local agent = require("codesplainer.agent")
local lsp = require("codesplainer.lsp")
local window = require("codesplainer.window")

local M = {}

local SYSTEM_PROMPT = [[
You are an expert code-reading assistant inside Neovim. The user may ask directly or about selected code.
Your job is to help the user read, navigate, and understand existing code. Do not write new code, generate patches, implement features, or provide copy-paste replacement code. If the user asks for code-writing help, politely redirect to explaining how the existing code works, where relevant logic lives, or what the user should inspect next.
Use provided LSP context. If more code context is needed, request exactly one tool call by replying only with:
```lsp-tool
{"tool":"definition","file":"/absolute/path","line":10,"character":4}
```
Supported tools: hover, definition, typeDefinition, implementation, references, diagnostics, symbols, snippet.
For snippet use: {"tool":"snippet","file":"/absolute/path","start_line":1,"end_line":80}.
Line numbers are 1-based. character is 0-based. When ready, give a direct final answer.
]]

local state = {
  messages = nil,
  busy = false,
}

local function ensure_messages()
  if not state.messages then
    state.messages = { { role = "system", content = SYSTEM_PROMPT } }
  end
end

local function ensure_window()
  ensure_messages()
  if window.is_empty() then
    window.replace({
      "# Codesplainer",
      "",
      "Persistent chat. Type at the bottom; press Enter in normal mode to send. Visual-select code and run `:CodesplainerAsk` to include LSP context.",
    })
    window.start_prompt()
  else
    window.show()
  end
end

local function append_section(title, lines)
  local section = { "", "## " .. title, "" }
  vim.list_extend(section, lines or {})
  if section[#section] ~= "" then
    table.insert(section, "")
  end
  window.append(section)
end

local function build_context_prompt(question, ctx)
  return table.concat({
    "Question:",
    question,
    "",
    "Selected code:",
    "```",
    ctx.selection,
    "```",
    "",
    "Initial LSP context:",
    "File: " .. ctx.file,
    "Range: " .. ctx.range,
    "",
    "Hover:",
    ctx.hover or "",
    "",
    "Definitions:",
    ctx.definitions or "",
    "",
    "Type definitions:",
    ctx.type_definitions or "",
    "",
    "Implementations:",
    ctx.implementations or "",
    "",
    "References:",
    ctx.references or "",
    "",
    "Diagnostics on selected start line:",
    ctx.diagnostics or "",
    "",
    "Document symbols:",
    ctx.document_symbols or "",
  }, "\n")
end

local function fail_response(err)
  window.remove_last_nonblank_matching("^_Thinking%.%.%_$")
  append_section("Error", { err })
  state.busy = false
  window.start_prompt()
end

local function request_agent_response()
  local response_started = false

  local function ensure_response_started()
    if response_started then
      return
    end
    window.prepare_response_body()
    response_started = true
  end

  agent.run(state.messages, {
    on_text = function(text)
      ensure_response_started()
      window.append_text_delta(text)
    end,
    on_tool_call = function(call)
      ensure_response_started()
      window.append_text_delta(table.concat({ "```json", vim.fn.json_encode(call), "```" }, "\n"))
      response_started = false
    end,
    on_done = function(answer)
      table.insert(state.messages, { role = "assistant", content = answer })
      state.busy = false
      window.start_prompt()
    end,
    on_error = fail_response,
  })
end

local function send_user_message(message, display_lines)
  ensure_window()
  if state.busy then
    append_section("Error", { "A request is already in progress." })
    return
  end

  table.insert(state.messages, { role = "user", content = message })
  if display_lines then
    append_section("You", display_lines)
  end
  append_section("Codesplainer", { "_Thinking..._", "" })
  state.busy = true
  request_agent_response()
end

function M.show()
  ensure_window()
end

function M.toggle()
  if window.is_open() then
    window.hide()
  else
    ensure_window()
  end
end

function M.clear()
  state.messages = { { role = "system", content = SYSTEM_PROMPT } }
  state.busy = false
  window.replace({ "# Codesplainer", "", "Chat cleared." })
  window.start_prompt()
end

function M.submit_prompt()
  local text = window.finish_prompt()
  if text then
    -- The prompt text is already rendered in the chat buffer; don't append a duplicate "You" section.
    send_user_message(text, nil)
  end
end

function M.send_text(text)
  if text and vim.trim(text) ~= "" then
    send_user_message(text, vim.split(text, "\n", { plain = true }))
  end
end

function M.ask_selection(question, selection)
  local ctx = lsp.collect_initial(selection)
  local message = build_context_prompt(question, ctx)
  send_user_message(message, {
    question,
    "",
    string.format("_%s:%s_", ctx.file, ctx.range),
    "",
    "```",
    ctx.selection,
    "```",
  })
end

return M
