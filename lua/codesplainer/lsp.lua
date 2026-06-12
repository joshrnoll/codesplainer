local config = require("codesplainer.config")

local M = {}

local function params_at(bufnr, line, character)
  return {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = line, character = character },
  }
end

local function client_supports_method(client, method, bufnr)
  if client.supports_method then
    local ok, supported = pcall(client.supports_method, client, method, bufnr)
    return ok and supported
  end
  return true
end

local function supporting_clients(bufnr, method)
  local clients = vim.lsp.get_clients and vim.lsp.get_clients({ bufnr = bufnr }) or vim.lsp.get_active_clients({ bufnr = bufnr })
  local supported = {}
  for _, client in ipairs(clients) do
    if client_supports_method(client, method, bufnr) then
      table.insert(supported, client)
    end
  end
  return supported
end

local function request(bufnr, method, params)
  local clients = supporting_clients(bufnr, method)
  if #clients == 0 then
    return {}
  end

  local out = {}
  local remaining = #clients
  local done = false

  for _, client in ipairs(clients) do
    client.request(method, params, function(err, result)
      if not err and result ~= nil then
        table.insert(out, { client_id = client.id, result = result })
      end
      remaining = remaining - 1
      if remaining == 0 then
        done = true
      end
    end, bufnr)
  end

  vim.wait(3000, function()
    return done
  end, 20)

  return out
end

local function location_to_text(loc)
  local uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange or loc.targetRange
  if not uri or not range then
    return vim.inspect(loc)
  end
  return string.format("%s:%d:%d", vim.uri_to_fname(uri), range.start.line + 1, range.start.character)
end

local function locations_to_text(results)
  local lines = {}
  for _, item in ipairs(results) do
    local result = item.result
    if vim.tbl_islist(result) then
      for _, loc in ipairs(result) do
        table.insert(lines, location_to_text(loc))
      end
    elseif result then
      table.insert(lines, location_to_text(result))
    end
  end
  return table.concat(lines, "\n")
end

local function markdown_to_text(value)
  if type(value) == "string" then
    return value
  end
  if type(value) == "table" then
    if value.value then
      return value.value
    end
    if vim.tbl_islist(value) then
      local parts = {}
      for _, v in ipairs(value) do
        table.insert(parts, markdown_to_text(v))
      end
      return table.concat(parts, "\n")
    end
  end
  return vim.inspect(value)
end

local function read_snippet(path, start_line, end_line)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return "Could not read file: " .. path
  end
  start_line = math.max(1, start_line or 1)
  end_line = math.min(#lines, end_line or start_line + config.options.context.max_snippet_lines - 1)
  local out = {}
  for i = start_line, end_line do
    table.insert(out, string.format("%5d  %s", i, lines[i]))
  end
  return table.concat(out, "\n")
end

local function bufnr_for_file(path)
  path = vim.fn.fnamemodify(path, ":p")
  local bufnr = vim.fn.bufadd(path)
  vim.fn.bufload(bufnr)
  return bufnr
end

local function normalize_selection(srow, scol, erow, ecol)
  if srow > erow or (srow == erow and scol > ecol) then
    srow, erow = erow, srow
    scol, ecol = ecol, scol
  end
  return srow, scol, erow, ecol
end

local function visual_mark_positions()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local srow, scol = start_pos[2], start_pos[3]
  local erow, ecol = end_pos[2], end_pos[3]
  if srow <= 0 or erow <= 0 then
    return nil
  end
  return normalize_selection(srow, scol, erow, ecol)
end

local function active_visual_positions()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return nil
  end

  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getcurpos()
  local srow, scol = start_pos[2], start_pos[3]
  local erow, ecol = end_pos[2], end_pos[3]
  if srow <= 0 or erow <= 0 then
    return nil
  end
  if mode == "V" then
    scol = 1
    ecol = #vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1]
  end
  return normalize_selection(srow, scol, erow, ecol)
end

local function range_positions(range)
  if not range or not range.range or range.range == 0 then
    return nil
  end

  local srow = range.line1
  local erow = range.line2
  if not srow or not erow or srow <= 0 or erow <= 0 then
    return nil
  end

  local mark_srow, mark_scol, mark_erow, mark_ecol = visual_mark_positions()
  if mark_srow == srow and mark_erow == erow then
    return mark_srow, mark_scol, mark_erow, mark_ecol
  end

  local last_line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1] or ""
  return normalize_selection(srow, 1, erow, #last_line)
end

function M.visual_selection(range)
  local bufnr = vim.api.nvim_get_current_buf()
  local srow, scol, erow, ecol = active_visual_positions()
  if not srow then
    srow, scol, erow, ecol = range_positions(range)
  end
  if not srow then
    srow, scol, erow, ecol = visual_mark_positions()
  end
  if not srow then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, srow - 1, erow, false)
  if #lines == 0 then
    return nil
  end
  lines[1] = string.sub(lines[1], scol)
  if #lines == 1 then
    lines[1] = string.sub(lines[1], 1, math.max(0, ecol - scol + 1))
  else
    lines[#lines] = string.sub(lines[#lines], 1, ecol)
  end
  return {
    bufnr = bufnr,
    file = vim.api.nvim_buf_get_name(bufnr),
    start_line = srow,
    end_line = erow,
    line = srow - 1,
    character = math.max(0, scol - 1),
    text = table.concat(lines, "\n"),
  }
end

function M.collect_initial(selection)
  local bufnr = selection.bufnr
  local params = params_at(bufnr, selection.line, selection.character)
  local hover = request(bufnr, "textDocument/hover", params)
  local defs = request(bufnr, "textDocument/definition", params)
  local type_defs = request(bufnr, "textDocument/typeDefinition", params)
  local impls = request(bufnr, "textDocument/implementation", params)
  local refs_params = vim.deepcopy(params)
  refs_params.context = { includeDeclaration = true }
  local refs = request(bufnr, "textDocument/references", refs_params)
  local symbols = request(bufnr, "textDocument/documentSymbol", { textDocument = { uri = vim.uri_from_bufnr(bufnr) } })
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = selection.line })

  return {
    file = selection.file,
    range = string.format("%d-%d", selection.start_line, selection.end_line),
    selection = selection.text,
    hover = markdown_to_text(hover),
    definitions = locations_to_text(defs),
    type_definitions = locations_to_text(type_defs),
    implementations = locations_to_text(impls),
    references = locations_to_text(refs):gsub("([^\n]*\n)", function(line)
      return line
    end),
    diagnostics = vim.inspect(diagnostics),
    document_symbols = vim.inspect(symbols),
  }
end

function M.run_tool(call)
  if type(call) ~= "table" then
    return "Invalid tool request"
  end
  local tool = call.tool
  local file = call.file
  if not file or file == "" then
    return "Tool request must include an absolute file path"
  end
  local bufnr = bufnr_for_file(file)
  local line = math.max(0, (call.line or 1) - 1)
  local character = math.max(0, call.character or 0)

  if tool == "snippet" then
    return read_snippet(file, call.start_line or call.line or 1, call.end_line)
  end
  if tool == "diagnostics" then
    return vim.inspect(vim.diagnostic.get(bufnr))
  end
  if tool == "symbols" then
    return vim.inspect(request(bufnr, "textDocument/documentSymbol", { textDocument = { uri = vim.uri_from_bufnr(bufnr) } }))
  end

  local method_by_tool = {
    hover = "textDocument/hover",
    definition = "textDocument/definition",
    typeDefinition = "textDocument/typeDefinition",
    implementation = "textDocument/implementation",
    references = "textDocument/references",
  }
  local method = method_by_tool[tool]
  if not method then
    return "Unknown LSP tool: " .. tostring(tool)
  end
  local params = params_at(bufnr, line, character)
  if tool == "references" then
    params.context = { includeDeclaration = true }
  end
  local result = request(bufnr, method, params)
  if tool == "hover" then
    return markdown_to_text(result)
  end
  return locations_to_text(result)
end

return M
