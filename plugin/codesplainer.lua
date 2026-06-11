if vim.g.loaded_codesplainer == 1 then
  return
end
vim.g.loaded_codesplainer = 1

vim.api.nvim_create_user_command("CodesplainerAsk", function(opts)
  require("codesplainer").ask_visual(opts.args)
end, {
  range = true,
  nargs = "*",
  desc = "Ask an LLM about the current visual selection with LSP context",
})

vim.api.nvim_create_user_command("CodesplainerClear", function()
  require("codesplainer").clear()
end, { desc = "Clear the persistent Codesplainer conversation" })

vim.api.nvim_create_user_command("Codesplainer", function(opts)
  if opts.args == "" then
    require("codesplainer").toggle()
  else
    require("codesplainer").chat(opts.args)
  end
end, { nargs = "*", desc = "Toggle chat or send a direct message to Codesplainer" })
