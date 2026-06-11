local M = {}

M.defaults = {
  provider = "openrouter",
  window = {
    -- Number >= 1 is an absolute column width; number between 0 and 1 is a screen fraction.
    width = 80,
    filetype = "markdown",
  },
  max_tool_rounds = 4,
  context = {
    max_references = 12,
    max_snippet_lines = 80,
  },
  openrouter = {
    api_key = nil,
    api_key_env = "OPENROUTER_API_KEY",
    model = "anthropic/claude-3.5-sonnet",
    endpoint = "https://openrouter.ai/api/v1/chat/completions",
    temperature = 0.2,
    max_tokens = 4000,
    site_url = nil,
    app_name = "lsp-llm-chat.nvim",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
