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

vim.api.nvim_create_user_command("CodesplainerShow", function()
  require("codesplainer").show()
end, { desc = "Show the persistent Codesplainer window" })

vim.api.nvim_create_user_command("CodesplainerHide", function()
  require("codesplainer").hide()
end, { desc = "Hide the Codesplainer window" })

vim.api.nvim_create_user_command("CodesplainerClear", function()
  require("codesplainer").clear()
end, { desc = "Clear the persistent Codesplainer conversation" })

vim.api.nvim_create_user_command("Codesplainer", function(opts)
  if opts.args == "" then
    require("codesplainer").show()
  else
    require("codesplainer").chat(opts.args)
  end
end, { nargs = "*", desc = "Show chat or send a direct message to Codesplainer" })
