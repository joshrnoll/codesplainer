# codesplainer.nvim

Persistent Neovim chat for reading and understanding code with LSP-powered context traversal, any OpenAI-compatible chat completions API, or a ChatGPT Plus/Pro Codex subscription.

## Features

- Persistent vertical chat split
- Direct chat inside the split: type at the bottom and press `<Enter>`
- Visual selection asks with LSP context
- LSP traversal tools: hover, definition, type definition, implementation, references, diagnostics, symbols, snippets
- OpenAI-compatible provider, including vanilla OpenAI API and OpenRouter
- ChatGPT Plus/Pro Codex subscription provider with browser OAuth
- Markdown response formatting for headings, code fences, lists, blockquotes, tables, math, directives, HTML-ish blocks, and more

## Requirements

- Neovim 0.9+
- `curl`
- A configured Neovim LSP client for code context
- An API key for an OpenAI-compatible chat completions API, or a ChatGPT Plus/Pro subscription for the Codex provider

## Installation

With lazy.nvim:

```lua
{
  url = "https://github.com/joshrnoll/codesplainer",
  cmd = { "CodesplainerAsk", "CodesplainerClear", "CodesplainerCodexLogin", "Codesplainer" },
  keys = {
    { "<leader>ca", ":'<,'>CodesplainerAsk<CR>", mode = "v", desc = "Ask Codesplainer about selection" },
    { "<leader>ct", "<Cmd>Codesplainer<CR>", mode = "n", desc = "Toggle Codesplainer" },
  },
  opts = {},
}
```

## Usage

Visual-select code and run:

```vim
:'<,'>CodesplainerAsk Why does this fail?
```

Toggle the persistent chat:

```vim
:Codesplainer
```

Then type at the bottom prompt and press `<Enter>`.

Other commands:

```vim
:Codesplainer        " toggle chat open/closed
:CodesplainerClear
:CodesplainerCodexLogin
:Codesplainer hello from command mode
```

## Configuration

### Providers

Codesplainer supports two provider modes:

| Provider | Use case | Auth |
| --- | --- | --- |
| `codex` | ChatGPT Plus/Pro Codex subscription | Browser OAuth |
| `openai` | OpenAI-compatible Chat Completions APIs, including OpenAI and OpenRouter | API key |

Set the active provider with `provider = "codex"` or `provider = "openai"`.

#### Codex provider

Use the `codex` provider to talk to the ChatGPT Codex backend with your ChatGPT Plus/Pro subscription. This does not require an OpenAI API key.

Full lazy.nvim example:

```lua
{
  url = "https://github.com/joshrnoll/codesplainer",
  cmd = { "CodesplainerAsk", "CodesplainerClear", "CodesplainerCodexLogin", "Codesplainer" },
  keys = {
    { "<leader>ca", ":'<,'>CodesplainerAsk<CR>", mode = "v", desc = "Ask Codesplainer about selection" },
    { "<leader>ct", "<Cmd>Codesplainer<CR>", mode = "n", desc = "Toggle Codesplainer" },
  },
  opts = {
    provider = "codex",
  },
}
```

After installing, log in from Neovim:

```vim
:CodesplainerCodexLogin
```

The command opens a browser OAuth flow. Complete login in the browser, then return to Neovim. Credentials are stored by the plugin and refreshed automatically when possible.

#### OpenAI-compatible API keys

Use the `openai` provider for APIs that implement OpenAI Chat Completions.

OpenAI API key example. Set `OPENAI_API_KEY`, then:

```lua
require("codesplainer").setup({
  provider = "openai",
})
```

OpenRouter API key example. Set `OPENROUTER_API_KEY`, then:

```lua
require("codesplainer").setup({
  provider = "openai",
  openai = {
    api_key_env = "OPENROUTER_API_KEY",
    model = "google/gemini-3.1-flash-lite",
    endpoint = "https://openrouter.ai/api/v1/chat/completions",
  },
})
```

### Window/options

```lua
require("codesplainer").setup({
  window = {
    width = 0.25, -- 25% of screen width
  },
})
```

## Testing

```sh
make test
```
