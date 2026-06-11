# lsp-llm-chat.nvim

A small Neovim plugin for asking an LLM about a visual selection while giving it LSP-powered code context.

- Ask about highlighted code from visual mode
- Opens the chat in a vertical split
- Collects LSP context: hover, definitions, type definitions, implementations, references, diagnostics, and document symbols
- Supports iterative LSP tool requests from the model
- Uses OpenRouter as the LLM provider

## Requirements

- Neovim 0.9+
- `curl`
- A configured Neovim LSP client for the target buffer
- An OpenRouter API key in `OPENROUTER_API_KEY`

## Installation

Use your plugin manager of choice. With lazy.nvim:

```lua
{
  "yourname/lsp-llm-chat.nvim",
  config = function()
    require("lsp-llm-chat").setup({
      openrouter = {
        model = "anthropic/claude-3.5-sonnet",
      },
    })
  end,
}
```

For local development:

```lua
vim.opt.runtimepath:append("/path/to/lsp-enabled-llm-chat-nvim-plugin")
require("lsp-llm-chat").setup()
```

## Usage

Highlight code in visual mode and run:

```vim
:'<,'>LspLLMChatAsk
```

You can also pass the question directly:

```vim
:'<,'>LspLLMChatAsk Why is this function failing?
```

The answer appears in a persistent vertical chat split. Each new visual ask appends to the same conversation, so the model can use prior turns as context.

You can also chat directly in the split: type on the prompt line at the bottom and press `<Enter>` to send.

Window commands:

- `q` in the chat split or `:LspLLMChatHide` hides the split without deleting the chat
- `:LspLLMChatShow` reopens the existing chat and prompt
- `:LspLLMChatClear` clears the conversation

Default mappings are intentionally not installed. Add your own:

```lua
vim.keymap.set("v", "<leader>la", function()
  require("lsp-llm-chat").ask_visual()
end, { desc = "Ask LLM about selection" })
```

## Configuration

```lua
require("lsp-llm-chat").setup({
  provider = "openrouter",
  max_tool_rounds = 4,
  window = {
    width = 80, -- fixed columns; use 0.25 for 25% of screen width
    filetype = "markdown",
  }
  openrouter = {
    api_key = nil, -- defaults to os.getenv("OPENROUTER_API_KEY")
    api_key_env = "OPENROUTER_API_KEY",
    model = "anthropic/claude-3.5-sonnet",
    endpoint = "https://openrouter.ai/api/v1/chat/completions",
    temperature = 0.2,
    max_tokens = 4000,
    site_url = nil,
    app_name = "lsp-llm-chat.nvim",
  },
})
```

## Testing

```sh
make test
```

## LSP traversal protocol

The plugin gives the model a context bundle up front. It also supports iterative tool calls. If the model needs more context it can respond with a fenced JSON block:

````markdown
```lsp-tool
{"tool":"definition","file":"/abs/file.lua","line":10,"character":4}
```
````

Supported tools: `hover`, `definition`, `typeDefinition`, `implementation`, `references`, `diagnostics`, `symbols`, `snippet`.

The plugin executes the request through Neovim's LSP APIs, appends the result, and asks the model again until it returns a final answer or `max_tool_rounds` is reached.
