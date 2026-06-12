local config = require("codesplainer.config")
local lsp = require("codesplainer.lsp")

local M = {}

local TOOL_FENCE_PATTERNS = {
  "```lsp-tool\n",
  "```json\n",
}

local function leading_trimmed_prefix(value)
  return (value or ""):gsub("^%s*", "")
end

local function is_possible_tool_prefix(value)
  local trimmed = leading_trimmed_prefix(value)
  for _, fence in ipairs(TOOL_FENCE_PATTERNS) do
    if fence:sub(1, #trimmed) == trimmed then
      return true
    end
  end
  return false
end

local function has_tool_fence_start(value)
  local trimmed = leading_trimmed_prefix(value)
  for _, fence in ipairs(TOOL_FENCE_PATTERNS) do
    if trimmed:sub(1, #fence) == fence then
      return true
    end
  end
  return false
end

local function tool_fence_body(value)
  return (value or ""):match("^%s*```lsp%-tool%s*\n(.-)\n```") or (value or ""):match("^%s*```json%s*\n(.-)\n```")
end

local function decode_tool_call(value)
  local body = tool_fence_body(value)
  if not body then
    return nil
  end
  local ok, decoded = pcall(vim.fn.json_decode, body)
  if ok and type(decoded) == "table" and decoded.tool then
    return decoded
  end
  return nil
end

local function provider()
  if config.options.provider == "openai" then
    return require("codesplainer.providers.openai")
  end
  if config.options.provider == "codex" then
    return require("codesplainer.providers.codex")
  end
  error("Unknown provider: " .. tostring(config.options.provider))
end

local function append_tool_result(messages, assistant_content, call)
  local tool_result = lsp.run_tool(call)
  table.insert(messages, { role = "assistant", content = assistant_content })
  table.insert(messages, {
    role = "user",
    content = "LSP tool result for " .. call.tool .. ":\n```\n" .. tool_result .. "\n```",
  })
end

local function run_complete_fallback(provider_module, messages, callbacks, round)
  provider_module.complete(messages, function(answer, err)
    if err then
      callbacks.on_error(err)
      return
    end

    local call = decode_tool_call(answer)
    if call and round < config.options.max_tool_rounds then
      append_tool_result(messages, answer, call)
      M.run(messages, callbacks, round + 1)
      return
    end

    if callbacks.on_text then
      callbacks.on_text(answer or "")
    end
    callbacks.on_done(answer or "")
  end)
end

function M.run(messages, callbacks, round)
  round = round or 0
  callbacks = callbacks or {}
  local provider_module = provider()

  if not provider_module.stream then
    run_complete_fallback(provider_module, messages, callbacks, round)
    return
  end

  local full_text = ""
  local pending = ""
  local done = false
  local handle = nil

  local function emit_text(text)
    if text and text ~= "" and callbacks.on_text then
      callbacks.on_text(text)
    end
  end

  local function finish_tool(call, assistant_content)
    if done then
      return
    end
    done = true
    if handle and handle.cancel then
      handle.cancel()
    end
    if round >= config.options.max_tool_rounds then
      emit_text(assistant_content)
      callbacks.on_done(assistant_content)
      return
    end
    if callbacks.on_tool_call then
      callbacks.on_tool_call(call)
    end
    append_tool_result(messages, assistant_content, call)
    M.run(messages, callbacks, round + 1)
  end

  local function handle_text_delta(text)
    if done then
      return
    end
    full_text = full_text .. (text or "")
    pending = pending .. (text or "")

    local call = decode_tool_call(pending)
    if call then
      finish_tool(call, pending)
      return
    end

    if is_possible_tool_prefix(pending) or has_tool_fence_start(pending) then
      return
    end

    emit_text(pending)
    pending = ""
  end

  handle = provider_module.stream(messages, function(event)
    if done then
      return
    end
    if event.type == "text_delta" then
      handle_text_delta(event.text)
    elseif event.type == "tool_call" then
      finish_tool(event.call, event.raw or vim.fn.json_encode(event.call))
    elseif event.type == "error" then
      done = true
      callbacks.on_error(event.error)
    elseif event.type == "done" then
      done = true
      emit_text(pending)
      callbacks.on_done(full_text)
    end
  end)
end

return M
