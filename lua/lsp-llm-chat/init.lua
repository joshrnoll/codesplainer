local chat = require("lsp-llm-chat.chat")
local config = require("lsp-llm-chat.config")
local lsp = require("lsp-llm-chat.lsp")
local window = require("lsp-llm-chat.window")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.show()
  chat.show()
end

function M.hide()
  window.hide()
end

function M.clear()
  chat.clear()
end

function M.submit()
  chat.submit_prompt()
end

function M.chat(message)
  chat.send_text(message)
end

function M.ask_visual(question)
  local selection = lsp.visual_selection()
  if not selection then
    vim.notify("No visual selection found", vim.log.levels.WARN)
    return
  end

  if question and question ~= "" then
    chat.ask_selection(question, selection)
    return
  end

  vim.ui.input({ prompt = "Ask about selection: " }, function(input)
    if input and input ~= "" then
      chat.ask_selection(input, selection)
    end
  end)
end

return M
