local config = require("codesplainer.config")

local M = {}

local CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
local AUTH_BASE_URL = "https://auth.openai.com"
local AUTHORIZE_URL = AUTH_BASE_URL .. "/oauth/authorize"
local TOKEN_URL = AUTH_BASE_URL .. "/oauth/token"
local REDIRECT_URI = "http://localhost:1455/auth/callback"
local SCOPE = "openid profile email offline_access"
local JWT_CLAIM_PATH = "https://api.openai.com/auth"

local function notify(message, level)
  vim.schedule(function()
    vim.notify(message, level or vim.log.levels.INFO)
  end)
end

local function urlencode(value)
  return tostring(value):gsub("([^%w%-_%.~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local function form_encode(values)
  local parts = {}
  for key, value in pairs(values) do
    table.insert(parts, urlencode(key) .. "=" .. urlencode(value))
  end
  return table.concat(parts, "&")
end

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64_encode(data)
  return ((data:gsub(".", function(char)
    local bits = ""
    local byte = char:byte()
    for index = 8, 1, -1 do
      bits = bits .. (byte % 2 ^ index - byte % 2 ^ (index - 1) > 0 and "1" or "0")
    end
    return bits
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
    if #bits < 6 then
      return ""
    end
    local value = 0
    for index = 1, 6 do
      value = value + (bits:sub(index, index) == "1" and 2 ^ (6 - index) or 0)
    end
    return BASE64_ALPHABET:sub(value + 1, value + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

local function base64_decode(data)
  data = data:gsub("[^" .. BASE64_ALPHABET .. "=]", "")
  return (data:gsub(".", function(char)
    if char == "=" then
      return ""
    end
    local value = BASE64_ALPHABET:find(char, 1, true) - 1
    local bits = ""
    for index = 6, 1, -1 do
      bits = bits .. (value % 2 ^ index - value % 2 ^ (index - 1) > 0 and "1" or "0")
    end
    return bits
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
    if #bits ~= 8 then
      return ""
    end
    local value = 0
    for index = 1, 8 do
      value = value + (bits:sub(index, index) == "1" and 2 ^ (8 - index) or 0)
    end
    return string.char(value)
  end))
end

local function base64url(bytes)
  return (base64_encode(bytes):gsub("+", "-"):gsub("/", "_"):gsub("=+$", ""))
end

local function base64url_decode(value)
  local b64 = value:gsub("-", "+"):gsub("_", "/")
  local pad = #b64 % 4
  if pad > 0 then
    b64 = b64 .. string.rep("=", 4 - pad)
  end
  return base64_decode(b64)
end

local function random_bytes(length)
  local file = assert(io.open("/dev/urandom", "rb"))
  local bytes = file:read(length)
  file:close()
  return bytes
end

local function random_urlsafe(length)
  return base64url(random_bytes(length))
end

local function sha256_bytes(value)
  local hex = vim.fn.sha256(value)
  return (hex:gsub("..", function(byte)
    return string.char(tonumber(byte, 16))
  end))
end

local function auth_path()
  return vim.fn.expand(config.options.codex.auth_file)
end

local function ensure_auth_dir()
  vim.fn.mkdir(vim.fn.fnamemodify(auth_path(), ":h"), "p", "0700")
end

local function read_auth()
  local path = auth_path()
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  local ok, decoded = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(path), "\n"))
  if ok and type(decoded) == "table" then
    return decoded
  end
  return nil
end

local function write_auth(auth)
  ensure_auth_dir()
  vim.fn.writefile({ vim.fn.json_encode(auth) }, auth_path())
  pcall(vim.fn.setfperm, auth_path(), "rw-------")
end

local function extract_account_id(access_token)
  local payload = access_token:match("^[^.]+%.([^.]+)%.")
  if not payload then
    return nil, "Access token is not a JWT"
  end
  local ok_decode, raw = pcall(base64url_decode, payload)
  if not ok_decode then
    return nil, "Could not decode access token"
  end
  local ok_json, decoded = pcall(vim.fn.json_decode, raw)
  if not ok_json or type(decoded) ~= "table" then
    return nil, "Could not parse access token"
  end
  local auth = decoded[JWT_CLAIM_PATH]
  local account_id = type(auth) == "table" and auth.chatgpt_account_id or nil
  if not account_id or account_id == "" then
    return nil, "Access token did not include ChatGPT account id"
  end
  return account_id, nil
end

local function token_request(fields, callback)
  local body = form_encode(fields)
  local cmd = {
    "curl",
    "-sS",
    "-X",
    "POST",
    TOKEN_URL,
    "-H",
    "Content-Type: application/x-www-form-urlencoded",
    "--data-binary",
    body,
    "-w",
    "\n%{http_code}",
  }

  local function finish(stdout, stderr, exit_code)
    if exit_code ~= 0 then
      callback(nil, "curl failed: " .. (stderr or stdout or ""))
      return
    end
    local response_body, http_code = (stdout or ""):match("^(.*)\n(%d%d%d)%s*$")
    local code = tonumber(http_code)
    if not code or code < 200 or code >= 300 then
      callback(nil, "OpenAI Codex token request failed (" .. tostring(http_code) .. "):\n" .. (response_body or ""))
      return
    end
    local ok, decoded = pcall(vim.fn.json_decode, response_body or "")
    if not ok or type(decoded) ~= "table" then
      callback(nil, "Could not decode OpenAI Codex token response:\n" .. (response_body or ""))
      return
    end
    if not decoded.access_token or not decoded.refresh_token or type(decoded.expires_in) ~= "number" then
      callback(nil, "OpenAI Codex token response missing fields:\n" .. (response_body or ""))
      return
    end
    local account_id, err = extract_account_id(decoded.access_token)
    if err then
      callback(nil, err)
      return
    end
    callback({
      access = decoded.access_token,
      refresh = decoded.refresh_token,
      expires = math.floor(os.time() * 1000 + decoded.expires_in * 1000),
      accountId = account_id,
    }, nil)
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

local function refresh_auth(auth, callback)
  token_request({
    grant_type = "refresh_token",
    refresh_token = auth.refresh,
    client_id = CLIENT_ID,
  }, function(new_auth, err)
    if new_auth then
      write_auth(new_auth)
    end
    callback(new_auth, err)
  end)
end

local function get_auth(callback)
  local auth = read_auth()
  if not auth or not auth.access or not auth.refresh then
    callback(nil, "Not logged in to OpenAI Codex. Run :CodesplainerCodexLogin first.")
    return
  end
  if type(auth.expires) == "number" and auth.expires > (os.time() * 1000 + 60000) then
    callback(auth, nil)
    return
  end
  refresh_auth(auth, callback)
end

local function exchange_code(code, verifier, callback)
  token_request({
    grant_type = "authorization_code",
    client_id = CLIENT_ID,
    code = code,
    code_verifier = verifier,
    redirect_uri = REDIRECT_URI,
  }, callback)
end

local function open_browser(url)
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
    return
  end
  local opener = vim.fn.has("mac") == 1 and "open" or "xdg-open"
  vim.fn.jobstart({ opener, url }, { detach = true })
end

local function urldecode(value)
  return (value or ""):gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function parse_query(query)
  local result = {}
  for key, value in (query or ""):gmatch("([^&=?]+)=?([^&]*)") do
    result[urldecode(key)] = urldecode(value)
  end
  return result
end

local function start_callback_server(expected_state, on_code)
  local uv = vim.loop
  local server = uv.new_tcp()
  local settled = false

  local function settle(code, err)
    if settled then
      return
    end
    settled = true
    pcall(function()
      server:close()
    end)
    on_code(code, err)
  end

  local ok, bind_result, bind_err = pcall(function()
    return server:bind("127.0.0.1", 1455)
  end)
  if not ok or bind_result == nil then
    settle(nil, tostring(bind_err or bind_result))
    return nil
  end

  server:listen(1, function(err)
    if err then
      settle(nil, err)
      return
    end
    local client = uv.new_tcp()
    server:accept(client)
    client:read_start(function(read_err, chunk)
      if read_err then
        settle(nil, read_err)
        return
      end
      if not chunk then
        return
      end
      local path = chunk:match("^[A-Z]+%s+([^%s]+)") or ""
      local query = path:match("%?(.*)") or ""
      local params = parse_query(query)
      local code = params.code
      local state = params.state
      local ok = code and state == expected_state
      local body = ok and "OpenAI authentication completed. You can close this window." or "OpenAI authentication failed. Return to Neovim."
      local status = ok and "200 OK" or "400 Bad Request"
      client:write(table.concat({
        "HTTP/1.1 " .. status,
        "Content-Type: text/html; charset=utf-8",
        "Connection: close",
        "",
        "<html><body><p>" .. body .. "</p></body></html>",
      }, "\r\n"), function()
        client:shutdown(function()
          client:close()
        end)
      end)
      if ok then
        settle(code, nil)
      else
        settle(nil, "OAuth state mismatch or missing code")
      end
    end)
  end)

  return server
end

function M.login()
  local verifier = random_urlsafe(32)
  local challenge = base64url(sha256_bytes(verifier))
  local state = random_urlsafe(16)
  local url = AUTHORIZE_URL
    .. "?response_type=code"
    .. "&client_id="
    .. urlencode(CLIENT_ID)
    .. "&redirect_uri="
    .. urlencode(REDIRECT_URI)
    .. "&scope="
    .. urlencode(SCOPE)
    .. "&code_challenge="
    .. urlencode(challenge)
    .. "&code_challenge_method=S256"
    .. "&state="
    .. urlencode(state)
    .. "&id_token_add_organizations=true"
    .. "&codex_cli_simplified_flow=true"
    .. "&originator=codesplainer.nvim"

  local server = start_callback_server(state, function(code, err)
    if err then
      notify("Codesplainer Codex login failed: " .. err, vim.log.levels.ERROR)
      return
    end
    notify("Codesplainer Codex login: exchanging authorization code...")
    exchange_code(code, verifier, function(auth, exchange_err)
      if exchange_err then
        notify("Codesplainer Codex login failed: " .. exchange_err, vim.log.levels.ERROR)
        return
      end
      write_auth(auth)
      notify("Codesplainer Codex login complete.")
    end)
  end)
  if not server then
    return
  end

  notify("Opening browser for Codesplainer Codex login...")
  open_browser(url)
end

local function split_messages(messages)
  local instructions = nil
  local input = {}
  for _, message in ipairs(messages) do
    if message.role == "system" then
      instructions = message.content
    elseif message.role == "user" or message.role == "assistant" then
      table.insert(input, {
        role = message.role,
        content = message.content,
      })
    end
  end
  return instructions or "You are a helpful assistant.", input
end

local function parse_sse(body)
  local deltas = {}
  local final_text = nil
  for line in (body or ""):gmatch("[^\r\n]+") do
    local data = line:match("^data:%s*(.*)$")
    if data and data ~= "[DONE]" then
      local ok, event = pcall(vim.fn.json_decode, data)
      if ok and type(event) == "table" then
        if event.type == "response.output_text.delta" and event.delta then
          table.insert(deltas, event.delta)
        elseif event.type == "response.completed" and type(event.response) == "table" then
          local output = event.response.output or {}
          local parts = {}
          for _, item in ipairs(output) do
            for _, content in ipairs(item.content or {}) do
              if content.text then
                table.insert(parts, content.text)
              end
            end
          end
          if #parts > 0 then
            final_text = table.concat(parts, "")
          end
        elseif event.type == "response.failed" then
          local err = event.response and event.response.error
          return nil, "OpenAI Codex response failed: " .. vim.fn.json_encode(err or event)
        end
      end
    end
  end
  local text = final_text or table.concat(deltas, "")
  if text == "" then
    return nil, "OpenAI Codex response did not include output text:\n" .. (body or "")
  end
  return text, nil
end

function M.complete(messages, callback)
  get_auth(function(auth, auth_err)
    if auth_err then
      callback(nil, auth_err)
      return
    end

    local opts = config.options.codex
    local instructions, input = split_messages(messages)
    local body = {
      model = opts.model,
      store = false,
      stream = true,
      instructions = instructions,
      input = input,
      text = { verbosity = opts.verbosity },
      include = { "reasoning.encrypted_content" },
      tool_choice = "auto",
      parallel_tool_calls = true,
    }
    if opts.reasoning_effort then
      body.reasoning = { effort = opts.reasoning_effort, summary = "auto" }
    end

    local body_file = vim.fn.tempname()
    vim.fn.writefile({ vim.fn.json_encode(body) }, body_file)
    local cmd = {
      "curl",
      "-sS",
      "-N",
      "-X",
      "POST",
      opts.endpoint,
      "-H",
      "Authorization: Bearer " .. auth.access,
      "-H",
      "chatgpt-account-id: " .. (auth.accountId or ""),
      "-H",
      "originator: codesplainer.nvim",
      "-H",
      "OpenAI-Beta: responses=experimental",
      "-H",
      "Accept: text/event-stream",
      "-H",
      "Content-Type: application/json",
      "--data-binary",
      "@" .. body_file,
      "-w",
      "\n%{http_code}",
    }

    local function finish(stdout, stderr, exit_code)
      pcall(vim.fn.delete, body_file)
      if exit_code ~= 0 then
        callback(nil, "curl failed: " .. (stderr or stdout or ""))
        return
      end
      local response_body, http_code = (stdout or ""):match("^(.*)\n(%d%d%d)%s*$")
      local code = tonumber(http_code)
      if not code or code < 200 or code >= 300 then
        callback(nil, "OpenAI Codex API HTTP " .. tostring(http_code) .. ":\n" .. (response_body or ""))
        return
      end
      callback(parse_sse(response_body))
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
  end)
end

return M
