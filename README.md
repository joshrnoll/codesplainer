# codesplainer.nvim

Persistent Neovim chat for asking an OpenRouter-backed LLM about code selections with LSP-powered context traversal.

## Features

- Persistent vertical chat split
- Direct chat inside the split: type at the bottom and press `<Enter>`
- Visual selection asks with LSP context
- LSP traversal tools: hover, definition, type definition, implementation, references, diagnostics, symbols, snippets
- OpenRouter provider
- Markdown response formatting for headings, code fences, lists, blockquotes, tables, math, directives, HTML-ish blocks, and more

## Requirements

- Neovim 0.9+
- `curl`
- A configured Neovim LSP client for code context
- OpenRouter API key in `OPENROUTER_API_KEY`

## Installation

With lazy.nvim:

```lua
{
  dir = vim.fn.expand("~/prototypes/codesplainer.nvim"),
  name = "codesplainer.nvim",
  cmd = { "CodesplainerAsk", "CodesplainerShow", "CodesplainerHide", "CodesplainerClear", "Codesplainer" },
  keys = {
    { "<leader>la", ":CodesplainerAsk ", mode = "v", desc = "Ask Codesplainer about selection" },
    { "<leader>ls", "<Cmd>CodesplainerShow<CR>", mode = "n", desc = "Show Codesplainer" },
  },
  opts = {
    openrouter = {
      model = "google/gemini-3.1-flash-lite",
    },
  },
}
```

## Usage

Visual-select code and run:

```vim
:'<,'>CodesplainerAsk Why does this fail?
```

Open/reopen the persistent chat:

```vim
:CodesplainerShow
```

Then type at the bottom prompt and press `<Enter>`.

Other commands:

```vim
:Codesplainer        " show/reopen chat
:CodesplainerHide
:CodesplainerClear
:Codesplainer hello from command mode
```

## Configuration

```lua
require("codesplainer").setup({
  provider = "openrouter",
  max_tool_rounds = 4,
  window = {
    width = 80, -- columns; use 0.25 for 25% of screen width
    filetype = "markdown",
  },
  openrouter = {
    api_key = nil, -- defaults to os.getenv("OPENROUTER_API_KEY")
    api_key_env = "OPENROUTER_API_KEY",
    model = "google/gemini-3.1-flash-lite",
    endpoint = "https://openrouter.ai/api/v1/chat/completions",
    temperature = 0.2,
    max_tokens = 4000,
  },
})
```

## Testing

```sh
make test
```
