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
    return nil, "OpenAI-compatible API HTTP " .. tostring(http_code) .. ":\n" .. (body or "")
  end

  local ok, decoded = pcall(vim.fn.json_decode, body or "")
  if not ok then
    return nil, "Could not decode OpenAI-compatible API response:\n" .. (body or "")
  end

  local choice = decoded.choices and decoded.choices[1]
  local content = choice and choice.message and choice.message.content
  if not content then
    return nil, "OpenAI-compatible API response did not include message content:\n" .. (body or "")
  end
  return content, nil
end

local function curl_command(opts, key, body_file, streaming)
  local cmd = { "curl", "-sS", "-X", "POST", opts.endpoint }
  if streaming then
    table.insert(cmd, "-N")
    table.insert(cmd, "--fail-with-body")
  end
  for _, header in ipairs(headers(opts, key)) do
    table.insert(cmd, "-H")
    table.insert(cmd, header)
  end
  vim.list_extend(cmd, { "--data-binary", "@" .. body_file })
  if not streaming then
    vim.list_extend(cmd, { "-w", "\n%{http_code}" })
  end
  return cmd
end

local function parse_sse_chunk(buffer, chunk, on_data)
  buffer = buffer .. (chunk or "")
  while true do
    local newline = buffer:find("\n", 1, true)
    if not newline then
      break
    end
    local line = buffer:sub(1, newline - 1):gsub("\r$", "")
    buffer = buffer:sub(newline + 1)
    local data = line:match("^data:%s*(.*)$")
    if data then
      on_data(data)
    end
  end
  return buffer
end

local function emit_stream_event(data, emit)
  if data == "[DONE]" then
    emit({ type = "done" })
    return
  end
  local ok, decoded = pcall(vim.fn.json_decode, data)
  if not ok or type(decoded) ~= "table" then
    return
  end
  local choice = decoded.choices and decoded.choices[1]
  local delta = choice and choice.delta
  local content = delta and delta.content
  if content then
    emit({ type = "text_delta", text = content })
  end
  if choice and choice.finish_reason then
    emit({ type = "done" })
  end
end

function M.stream(messages, emit)
  local opts = config.options.openai
  local key = api_key(opts)
  if not key or key == "" then
    emit({ type = "error", error = "Missing OpenAI-compatible API key. Set " .. opts.api_key_env .. " or pass openai.api_key." })
    return nil
  end

  local body = {
    model = opts.model,
    messages = messages,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
    stream = true,
  }

  local body_file = vim.fn.tempname()
  vim.fn.writefile({ vim.fn.json_encode(body) }, body_file)
  local cmd = curl_command(opts, key, body_file, true)

  if not vim.fn.jobstart then
    M.complete(messages, function(answer, err)
      if err then
        emit({ type = "error", error = err })
      else
        emit({ type = "text_delta", text = answer })
        emit({ type = "done" })
      end
    end)
    return nil
  end

  local stdout_buffer = ""
  local stderr = {}
  local completed = false
  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = true,
    on_stdout = function(_, data)
      vim.schedule(function()
        for _, chunk in ipairs(data or {}) do
          if chunk ~= "" then
            stdout_buffer = parse_sse_chunk(stdout_buffer, chunk .. "\n", function(item)
              emit_stream_event(item, function(event)
                if event.type == "done" then
                  completed = true
                end
                emit(event)
              end)
            end)
          end
        end
      end)
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          table.insert(stderr, line)
        end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        pcall(vim.fn.delete, body_file)
        if code ~= 0 then
          emit({ type = "error", error = "curl failed: " .. table.concat(stderr, "\n") })
        elseif not completed then
          emit({ type = "done" })
        end
      end)
    end,
  })

  return {
    cancel = function()
      if job_id and job_id > 0 then
        pcall(vim.fn.jobstop, job_id)
      end
      pcall(vim.fn.delete, body_file)
    end,
  }
end

function M.complete(messages, callback)
  local opts = config.options.openai
  local key = api_key(opts)
  if not key or key == "" then
    callback(nil, "Missing OpenAI-compatible API key. Set " .. opts.api_key_env .. " or pass openai.api_key.")
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
  local cmd = curl_command(opts, key, body_file, false)

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
