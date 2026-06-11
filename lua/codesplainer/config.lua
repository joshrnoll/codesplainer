local M = {}

M.defaults = {
  provider = "openai",
  max_tool_rounds = 4,
  window = {
    width = 80,
    filetype = "markdown",
  },
  context = {
    max_references = 12,
    max_snippet_lines = 80,
  },
  openai = {
    api_key = nil,
    api_key_env = "OPENAI_API_KEY",
    model = "gpt-4.1-mini",
    endpoint = "https://api.openai.com/v1/chat/completions",
    temperature = 0.2,
    max_tokens = 4000,
    site_url = nil,
    app_name = "codesplainer.nvim",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
