local config = require("lsp-llm-chat.config")

local M = {}

local function read_all(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return table.concat(lines, "\n")
end

function M.complete(messages)
  local opts = config.options.openrouter
  local api_key = opts.api_key or vim.env[opts.api_key_env]
  if not api_key or api_key == "" then
    return nil, "Missing OpenRouter API key. Set " .. opts.api_key_env .. " or pass openrouter.api_key."
  end

  local headers = {
    "Content-Type: application/json",
    "Authorization: Bearer " .. api_key,
  }
  if opts.site_url then
    table.insert(headers, "HTTP-Referer: " .. opts.site_url)
  end
  if opts.app_name then
    table.insert(headers, "X-Title: " .. opts.app_name)
  end

  local body = {
    model = opts.model,
    messages = messages,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
  }

  local body_file = vim.fn.tempname()
  local out_file = vim.fn.tempname()
  vim.fn.writefile({ vim.fn.json_encode(body) }, body_file)

  local cmd = { "curl", "-sS", "-X", "POST", opts.endpoint }
  for _, header in ipairs(headers) do
    table.insert(cmd, "-H")
    table.insert(cmd, header)
  end
  table.insert(cmd, "--data-binary")
  table.insert(cmd, "@" .. body_file)
  table.insert(cmd, "-o")
  table.insert(cmd, out_file)
  table.insert(cmd, "-w")
  table.insert(cmd, "%{http_code}")

  local status = vim.fn.system(cmd)
  local body_text = read_all(out_file) or ""
  pcall(vim.fn.delete, body_file)
  pcall(vim.fn.delete, out_file)

  if vim.v.shell_error ~= 0 then
    return nil, "curl failed: " .. status .. "\n" .. body_text
  end
  local code = tonumber(status)
  if not code or code < 200 or code >= 300 then
    return nil, "OpenRouter HTTP " .. tostring(status) .. ":\n" .. body_text
  end

  local ok, decoded = pcall(vim.fn.json_decode, body_text)
  if not ok then
    return nil, "Could not decode OpenRouter response:\n" .. body_text
  end
  local choice = decoded.choices and decoded.choices[1]
  local content = choice and choice.message and choice.message.content
  if not content then
    return nil, "OpenRouter response did not include message content:\n" .. body_text
  end
  return content, nil
end

return M
