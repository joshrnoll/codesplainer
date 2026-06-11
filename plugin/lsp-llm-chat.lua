if vim.g.loaded_lsp_llm_chat == 1 then
  return
end
vim.g.loaded_lsp_llm_chat = 1

vim.api.nvim_create_user_command("LspLLMChatAsk", function(opts)
  require("lsp-llm-chat").ask_visual(opts.args)
end, {
  range = true,
  nargs = "*",
  desc = "Ask an LLM about the current visual selection with LSP context",
})

vim.api.nvim_create_user_command("LspLLMChatShow", function()
  require("lsp-llm-chat").show()
end, { desc = "Show the persistent LSP LLM Chat window" })

vim.api.nvim_create_user_command("LspLLMChatHide", function()
  require("lsp-llm-chat").hide()
end, { desc = "Hide the LSP LLM Chat window" })

vim.api.nvim_create_user_command("LspLLMChatClear", function()
  require("lsp-llm-chat").clear()
end, { desc = "Clear the persistent LSP LLM Chat conversation" })

vim.api.nvim_create_user_command("LspLLMChat", function(opts)
  if opts.args == "" then
    require("lsp-llm-chat").show()
  else
    require("lsp-llm-chat").chat(opts.args)
  end
end, { nargs = "*", desc = "Show chat or send a direct message to LSP LLM Chat" })
