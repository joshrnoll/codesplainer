local config = require("lsp-llm-chat.config")
local lsp = require("lsp-llm-chat.lsp")
local markdown = require("lsp-llm-chat.markdown")
local window = require("lsp-llm-chat.window")

local M = {}

local chat = {
  messages = nil,
}

local SYSTEM_PROMPT = [[
You are an expert coding assistant inside Neovim. The user selected code and asked a question.
Use the provided LSP context before answering. If more context is needed, request exactly one LSP tool call by replying only with a fenced block like:
```lsp-tool
{"tool":"definition","file":"/absolute/path","line":10,"character":4}
```
Supported tools: hover, definition, typeDefinition, implementation, references, diagnostics, symbols, snippet.
For snippet use: {"tool":"snippet","file":"/absolute/path","start_line":1,"end_line":80}.
Line numbers are 1-based. character is 0-based.
When you have enough context, give a direct final answer with code references where useful.
]]

local function provider()
  if config.options.provider == "openrouter" then
    return require("lsp-llm-chat.providers.openrouter")
  end
  error("Unknown provider: " .. tostring(config.options.provider))
end

local function build_user_prompt(question, ctx)
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
  if not ok or type(decoded) ~= "table" or not decoded.tool then
    return nil
  end
  return decoded
end

local function ensure_chat()
  if not chat.messages then
    chat.messages = { { role = "system", content = SYSTEM_PROMPT } }
  end
  if window.is_empty() then
    window.set_lines({
      "# LSP LLM Chat",
      "",
      "Persistent chat. Type a message at the bottom and press Enter. Ask about highlighted code with `:LspLLMChatAsk`, hide with `q`, reopen with `:LspLLMChatShow`.",
    })
    window.prompt()
  else
    window.show()
  end
end

local function strip_pending_prompt()
  -- If the cursor is in an empty prompt created for direct chat, leave it behind harmlessly.
  -- Keeping this simple avoids deleting user text while a visual ask is started from another window.
end

local function append_section(title, lines)
  local section = { "", "## " .. title, "" }
  vim.list_extend(section, lines)
  if section[#section] ~= "" then
    table.insert(section, "")
  end
  window.append(section)
end


local function complete_chat()
  append_section("Assistant", { "_Thinking..._" })

  vim.schedule(function()
    for round = 1, config.options.max_tool_rounds + 1 do
      local answer, err = provider().complete(chat.messages)
      if err then
        window.remove_last_line_if("^_Thinking%.%.%_$")
        append_section("Error", { err })
        window.prompt()
        return
      end

      local call = parse_tool_call(answer)
      if not call or round > config.options.max_tool_rounds then
        table.insert(chat.messages, { role = "assistant", content = answer })
        window.remove_last_line_if("^_Thinking%.%.%_$")
        window.append(markdown.format_lines(answer))
        window.prompt()
        return
      end

      window.append({
        "",
        "Model requested LSP tool:",
        "```json",
        vim.fn.json_encode(call),
        "```",
      })
      local tool_result = lsp.run_tool(call)
      table.insert(chat.messages, { role = "assistant", content = answer })
      table.insert(chat.messages, {
        role = "user",
        content = "LSP tool result for " .. call.tool .. ":\n```\n" .. tool_result .. "\n```",
      })
    end
  end)
end

local function run_chat(question, selection)
  ensure_chat()
  strip_pending_prompt()

  local ctx = lsp.collect_initial(selection)
  table.insert(chat.messages, { role = "user", content = build_user_prompt(question, ctx) })

  append_section("You", {
    question,
    "",
    string.format("_%s:%s_", ctx.file, ctx.range),
    "",
    "```",
    ctx.selection,
    "```",
  })
  complete_chat()
end

local function run_direct_chat(question, already_displayed)
  ensure_chat()
  table.insert(chat.messages, { role = "user", content = question })
  if not already_displayed then
    append_section("You", { question })
  end
  complete_chat()
end

function M.ask_visual(question)
  local selection = lsp.visual_selection()
  if not selection then
    vim.notify("No visual selection found", vim.log.levels.WARN)
    return
  end
  if question and question ~= "" then
    run_chat(question, selection)
    return
  end
  vim.ui.input({ prompt = "Ask about selection: " }, function(input)
    if not input or input == "" then
      return
    end
    run_chat(input, selection)
  end)
end

function M.chat(question)
  if not question or question == "" then
    return
  end
  run_direct_chat(question, false)
end

function M.submit()
  local line = window.submit_line()
  if not line then
    return
  end
  run_direct_chat(line, true)
end

function M.show()
  ensure_chat()
end

function M.clear()
  chat.messages = { { role = "system", content = SYSTEM_PROMPT } }
  window.set_lines({
    "# LSP LLM Chat",
    "",
    "Chat cleared.",
  })
  window.prompt()
end

function M.setup(opts)
  config.setup(opts)
end

return M
