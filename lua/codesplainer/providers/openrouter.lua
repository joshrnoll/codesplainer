local config = require("codesplainer.config")

local M = {}

local function api_key(opts)
  return opts.api_key or vim.env[opts.api_key_env]
end

local function headers(opts, key)
  local result = {
    "Content-Type: application/json",
    "Authorization: Bearer " .. key,
  }
  if opts.site_url then
    table.insert(result, "HTTP-Referer: " .. opts.site_url)
  end
  if opts.app_name then
    table.insert(result, "X-Title: " .. opts.app_name)
  end
  return result
end

local function decode_response(http_code, body)
  local code = tonumber(http_code)
  if not code or code < 200 or code >= 300 then
    return nil, "OpenRouter HTTP " .. tostring(http_code) .. ":\n" .. (body or "")
  end

  local ok, decoded = pcall(vim.fn.json_decode, body or "")
  if not ok then
    return nil, "Could not decode OpenRouter response:\n" .. (body or "")
  end

  local choice = decoded.choices and decoded.choices[1]
  local content = choice and choice.message and choice.message.content
  if not content then
    return nil, "OpenRouter response did not include message content:\n" .. (body or "")
  end
  return content, nil
end

local function curl_command(opts, key, body_file)
  local cmd = { "curl", "-sS", "-X", "POST", opts.endpoint }
  for _, header in ipairs(headers(opts, key)) do
    table.insert(cmd, "-H")
    table.insert(cmd, header)
  end
  vim.list_extend(cmd, { "--data-binary", "@" .. body_file, "-w", "\n%{http_code}" })
  return cmd
end

function M.complete(messages, callback)
  local opts = config.options.openrouter
  local key = api_key(opts)
  if not key or key == "" then
    callback(nil, "Missing OpenRouter API key. Set " .. opts.api_key_env .. " or pass openrouter.api_key.")
    return
  end

  local body = {
    model = opts.model,
    messages = messages,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
  }

  local body_file = vim.fn.tempname()
  vim.fn.writefile({ vim.fn.json_encode(body) }, body_file)
  local cmd = curl_command(opts, key, body_file)

  local function finish(stdout, stderr, exit_code)
    pcall(vim.fn.delete, body_file)
    if exit_code ~= 0 then
      callback(nil, "curl failed: " .. (stderr or stdout or ""))
      return
    end

    local response_body, http_code = (stdout or ""):match("^(.*)\n(%d%d%d)%s*$")
    local content, err = decode_response(http_code, response_body)
    callback(content, err)
  end

  if vim.system then
    vim.system(cmd, { text = true }, function(result)
      vim.schedule(function()
        finish(result.stdout, result.stderr, result.code)
      end)
    end)
  else
    vim.schedule(function()
      local stdout = vim.fn.system(cmd)
      finish(stdout, "", vim.v.shell_error)
    end)
  end
end

return M
