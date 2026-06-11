# codesplainer.nvim

Persistent Neovim chat for reading and understanding code with LSP-powered context traversal and any OpenAI-compatible chat completions API.

## Features

- Persistent vertical chat split
- Direct chat inside the split: type at the bottom and press `<Enter>`
- Visual selection asks with LSP context
- LSP traversal tools: hover, definition, type definition, implementation, references, diagnostics, symbols, snippets
- OpenAI-compatible provider, including vanilla OpenAI API and OpenRouter
- Markdown response formatting for headings, code fences, lists, blockquotes, tables, math, directives, HTML-ish blocks, and more

## Requirements

- Neovim 0.9+
- `curl`
- A configured Neovim LSP client for code context
- An API key for an OpenAI-compatible chat completions API

## Installation

With lazy.nvim:

```lua
{
  url = "https://github.com/joshrnoll/codesplainer",
  name = "codesplainer.nvim",
  cmd = { "CodesplainerAsk", "CodesplainerShow", "CodesplainerHide", "CodesplainerClear", "Codesplainer" },
  keys = {
    { "<leader>la", ":CodesplainerAsk ", mode = "v", desc = "Ask Codesplainer about selection" },
    { "<leader>ls", "<Cmd>CodesplainerShow<CR>", mode = "n", desc = "Show Codesplainer" },
  },
  opts = {
    openai = {
      model = "gpt-4.1-mini",
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

### Vanilla OpenAI API

Set `OPENAI_API_KEY`, then:

```lua
require("codesplainer").setup({
  provider = "openai",
  openai = {
    api_key = nil, -- defaults to os.getenv("OPENAI_API_KEY")
    api_key_env = "OPENAI_API_KEY",
    model = "gpt-4.1-mini",
    endpoint = "https://api.openai.com/v1/chat/completions",
    temperature = 0.2,
    max_tokens = 4000,
  },
})
```

### OpenRouter

Set `OPENROUTER_API_KEY`, then point the OpenAI-compatible provider at OpenRouter:

```lua
require("codesplainer").setup({
  provider = "openai",
  openai = {
    api_key = nil, -- defaults to os.getenv("OPENROUTER_API_KEY")
    api_key_env = "OPENROUTER_API_KEY",
    model = "google/gemini-3.1-flash-lite",
    endpoint = "https://openrouter.ai/api/v1/chat/completions",
    site_url = nil,
    app_name = "codesplainer.nvim",
  },
})
```

### Window/options

```lua
require("codesplainer").setup({
  max_tool_rounds = 4,
  window = {
    width = 80, -- columns; use 0.25 for 25% of screen width
    filetype = "markdown",
  },
})
```

## Testing

```sh
make test
```
