local config = require("codesplainer.config")
local lsp = require("codesplainer.lsp")
local markdown = require("codesplainer.markdown")
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

local function provider()
  if config.options.provider == "openai" then
    return require("codesplainer.providers.openai")
  end
  if config.options.provider == "codex" then
    return require("codesplainer.providers.codex")
  end
  error("Unknown provider: " .. tostring(config.options.provider))
end

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
      "Persistent chat. Type at the bottom and press Enter. Visual-select code and run `:CodesplainerAsk` to include LSP context.",
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

local function parse_tool_call(text)
  local body = text:match("```lsp%-tool%s*\n(.-)\n```") or text:match("```json%s*\n(.-)\n```")
  if not body then
    return nil
  end
  local ok, decoded = pcall(vim.fn.json_decode, body)
  if ok and type(decoded) == "table" and decoded.tool then
    return decoded
  end
  return nil
end

local function finish_response(answer)
  table.insert(state.messages, { role = "assistant", content = answer })
  window.remove_last_nonblank_matching("^_Thinking%.%.%_$")
  window.append(markdown.format_lines(answer))
  state.busy = false
  window.start_prompt()
end

local function fail_response(err)
  window.remove_last_nonblank_matching("^_Thinking%.%.%_$")
  append_section("Error", { err })
  state.busy = false
  window.start_prompt()
end

local function request_round(round)
  provider().complete(state.messages, function(answer, err)
    if err then
      fail_response(err)
      return
    end

    local call = parse_tool_call(answer)
    if not call or round >= config.options.max_tool_rounds then
      finish_response(answer)
      return
    end

    window.append({ "", "Model requested LSP tool:", "```json", vim.fn.json_encode(call), "```", "" })
    local tool_result = lsp.run_tool(call)
    table.insert(state.messages, { role = "assistant", content = answer })
    table.insert(state.messages, {
      role = "user",
      content = "LSP tool result for " .. call.tool .. ":\n```\n" .. tool_result .. "\n```",
    })
    request_round(round + 1)
  end)
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
  append_section("Assistant", { "_Thinking..._" })
  state.busy = true
  request_round(0)
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
