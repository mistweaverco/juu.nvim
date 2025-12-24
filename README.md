<div align="center">

![Juu Logo](assets/logo.svg)

# Juu.nvim

[![Made with love](assets/badge-made-with-love.svg)](https://github.com/mistweaverco/juu.nvim/graphs/contributors)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/juu.nvim?style=for-the-badge)](https://github.com/mistweaverco/juu.nvim/releases/latest)

[Requirements](#requirements) • [Installation](#installation) • [Configuration](#configuration) • [Highlights](#highlights) • [Advanced configuration](#advanced-configuration) • [Notes for plugin authors](#notes-for-plugin-authors) • [Alternative and related projects](#alternative-and-related-projects)

<p></p>

A minimal input styling plugin for Neovim with notification and
LSP progress support.

Juu is swahili for "up" or "above".

It styles the input and select windows in Neovim,
provides a configurable `vim.notify()` backend,
and displays LSP progress notifications.

<p></p>

</div>

> [!WARNING]
> This is a fork of the archived [dressing.nvim](https://github.com/stevearc/dressing.nvim)
> that is being maintained.
>
> All the hard work has been done by [Steven Arcangeli](https://github.com/stevearc),
> we're just keeping it alive.

Why the fork? We like snacks.nvim 🍿,
but find it overkill for just styling the inputs.

Additionally, you get notification and LSP progress functionality,
providing a unified UI experience for inputs,
selections, notifications, and LSP progress.

- [Requirements](#requirements)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Configuration](#configuration)
- [Highlights](#highlights)
- [Advanced configuration](#advanced-configuration)
- [Notes for plugin authors](#notes-for-plugin-authors)
- [Alternative and related projects](#alternative-and-related-projects)

## Requirements

- Neovim 0.10.0+

## Installation

juu.nvim supports all the usual plugin managers

<details>
  <summary>lazy.nvim</summary>

```lua
{
  'mistweaverco/juu.nvim',
  opts = {},
}
```

</details>

<details>
  <summary>Packer</summary>

```lua
require('packer').startup(function()
    use {'mistweaverco/juu.nvim'}
end)
```

</details>

<details>
  <summary>Paq</summary>

```lua
require "paq" {
    {'mistweaverco/juu.nvim'};
}
```

</details>

<details>
  <summary>vim-plug</summary>

```vim
Plug 'mistweaverco/juu.nvim'
```

</details>

<details>
  <summary>dein</summary>

```vim
call dein#add('mistweaverco/juu.nvim')
```

</details>

<details>
  <summary>Pathogen</summary>

```sh
git clone --depth=1 https://github.com/mistweaverco/juu.nvim.git ~/.vim/bundle/
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/mistweaverco/juu.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/juu.nvim/start/juu.nvim
```

</details>

## Configuration

If you're fine with the defaults, you're good to go after installation. If you
want to tweak, call this function:

```lua
require("juu").setup({
  -- Notification system (enabled by default, set to false to disable)
  notify = {
    -- Override vim.notify() by default
    override_vim_notify = true,
    -- See below for more notification options
  },

  -- LSP progress tracking (enabled by default, set to false to disable)
  progress = {
    -- See below for more progress options
  },

  -- Input styling configuration
  input = {
    -- Set to false to disable the vim.ui.input implementation
    enabled = true,

    -- Default prompt string
    default_prompt = "Input",

    -- Trim trailing `:` from prompt
    trim_prompt = true,

    -- Can be 'left', 'right', or 'center'
    title_pos = "left",

    -- The initial mode when the window opens (insert|normal|visual|select).
    start_mode = "insert",

    -- These are passed to nvim_open_win
    border = "rounded",
    -- 'editor' and 'win' will default to being centered
    relative = "cursor",

    -- These can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    prefer_width = 40,
    width = nil,
    -- min_width and max_width can be a list of mixed types.
    -- min_width = {20, 0.2} means "the greater of 20 columns or 20% of total"
    max_width = { 140, 0.9 },
    min_width = { 20, 0.2 },

    buf_options = {},
    win_options = {
      -- Disable line wrapping
      wrap = false,
      -- Indicator for when text exceeds window
      list = true,
      listchars = "precedes:…,extends:…",
      -- Increase this for more context when text scrolls off the window
      sidescrolloff = 0,
    },

    -- Set to `false` to disable
    mappings = {
      n = {
        ["<Esc>"] = "Close",
        ["<CR>"] = "Confirm",
      },
      i = {
        ["<C-c>"] = "Close",
        ["<CR>"] = "Confirm",
        ["<Up>"] = "HistoryPrev",
        ["<Down>"] = "HistoryNext",
      },
    },

    override = function(conf)
      -- This is the config that will be passed to nvim_open_win.
      -- Change values here to customize the layout
      return conf
    end,

    get_config = nil,
  },
  select = {
    -- Set to false to disable the vim.ui.select implementation
    enabled = true,

    -- Priority list of preferred vim.select implementations
    backend = { "telescope", "fzf_lua", "fzf", "builtin", "nui" },

    -- Trim trailing `:` from prompt
    trim_prompt = true,

    -- Options for telescope selector
    -- These are passed into the telescope picker directly. Can be used like:
    -- telescope = require('telescope.themes').get_ivy({...})
    telescope = nil,

    -- Options for fzf selector
    fzf = {
      window = {
        width = 0.5,
        height = 0.4,
      },
    },

    -- Options for fzf-lua
    fzf_lua = {
      -- winopts = {
      --   height = 0.5,
      --   width = 0.5,
      -- },
    },

    -- Options for nui Menu
    nui = {
      position = "50%",
      size = nil,
      relative = "editor",
      border = {
        style = "rounded",
      },
      buf_options = {
        swapfile = false,
        filetype = "JuuSelect",
      },
      win_options = {
        winblend = 0,
      },
      max_width = 80,
      max_height = 40,
      min_width = 40,
      min_height = 10,
    },

    -- Options for built-in selector
    builtin = {
      -- Display numbers for options and set up keymaps
      show_numbers = true,
      -- These are passed to nvim_open_win
      border = "rounded",
      -- 'editor' and 'win' will default to being centered
      relative = "editor",

      buf_options = {},
      win_options = {
        cursorline = true,
        cursorlineopt = "both",
        -- disable highlighting for the brackets around the numbers
        winhighlight = "MatchParen:",
        -- adds padding at the left border
        statuscolumn = " ",
      },

      -- These can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
      -- the min_ and max_ options can be a list of mixed types.
      -- max_width = {140, 0.8} means "the lesser of 140 columns or 80% of total"
      width = nil,
      max_width = { 140, 0.8 },
      min_width = { 40, 0.2 },
      height = nil,
      max_height = 0.9,
      min_height = { 10, 0.2 },

      -- Set to `false` to disable
      mappings = {
        ["<Esc>"] = "Close",
        ["<C-c>"] = "Close",
        ["<CR>"] = "Confirm",
      },

      override = function(conf)
        -- This is the config that will be passed to nvim_open_win.
        -- Change values here to customize the layout
        return conf
      end,
    },

    -- Used to override format_item.
    format_item_override = {},

    get_config = nil,
  },
})
```

### Notification Configuration

Juu.nvim includes a notification system that can replace `vim.notify()`. By default,
it overrides `vim.notify()` to display notifications in a corner window. You can
configure it like this:

```lua
require("juu").setup({
  notify = {
    -- Override vim.notify() (default: true)
    override_vim_notify = true,

    -- Poll rate for updating notifications (Hz)
    poll_rate = 10,

    -- Minimum notification level to display
    filter = vim.log.levels.INFO,

    -- Number of removed messages to retain in history
    history_size = 128,

    -- Window configuration
    window = {
      normal_hl = "Comment",      -- Base highlight group
      winblend = 100,             -- Background opacity
      border = "none",            -- Border style
      zindex = 45,                -- Stacking priority
      max_width = 0,              -- Maximum width (0 = auto)
      max_height = 0,             -- Maximum height (0 = auto)
      x_padding = 1,              -- Padding from right edge
      y_padding = 0,              -- Padding from bottom edge
      align = "bottom",           -- Window alignment
      relative = "editor",        -- Position relative to
      avoid = {},                 -- Filetypes to avoid (e.g., { "NvimTree" })
    },
  },
})
```

### LSP Progress Configuration

Juu.nvim automatically tracks and displays LSP progress messages. Configure it like this:

```lua
require("juu").setup({
  progress = {
    -- Poll rate: 0 = immediate, >0 = Hz, false = disabled
    poll_rate = 0,

    -- Suppress new messages while in insert mode
    suppress_on_insert = false,

    -- Ignore new tasks that are already complete
    ignore_done_already = false,

    -- Ignore new tasks that don't contain a message
    ignore_empty_message = false,

    -- How to group progress messages (default: by LSP server name)
    notification_group = function(msg)
      return msg.lsp_client.name
    end,

    -- Clear notification group when LSP server detaches
    clear_on_detach = function(client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client and client.name or nil
    end,

    -- List of LSP servers to ignore
    ignore = {},

    -- Display options
    display = {
      render_limit = 16,          -- How many messages to show at once
      done_ttl = 3,               -- How long completed messages persist (seconds)
      done_icon = "✔",            -- Icon for completed tasks
      progress_icon = { "dots" }, -- Icon for in-progress tasks (animated)
      progress_ttl = math.huge,   -- How long in-progress messages persist
      priority = 30,              -- Ordering priority
      skip_history = true,        -- Omit from history
    },
  },
})
```

## Highlights

A common way to adjust the highlighting of just the juu windows is by
providing a `winhighlight` option in the config. See `:help winhighlight`
for more details. Example:

```lua
require('juu').setup({
  input = {
    win_options = {
      winhighlight = 'NormalFloat:DiagnosticError'
    }
  }
})
```

## Advanced configuration

For each of the `input` and `select` configs, there is an option
`get_config`. This can be a function that accepts the `opts` parameter that
is passed in to `vim.select` or `vim.input`. It must return either `nil` (to
no-op) or config values to use in place of the global config values for that
module.

For example, if you want to use a specific configuration for code actions:

```lua
require('juu').setup({
  select = {
    get_config = function(opts)
      if opts.kind == 'codeaction' then
        return {
          backend = 'nui',
          nui = {
            relative = 'cursor',
            max_width = 40,
          }
        }
      end
    end
  }
})

```

## Notes for plugin authors

TL;DR: you can customize the telescope `vim.ui.select` implementation by passing `telescope` into `opts`.

The `vim.ui` hooks are a great boon for us because we can now assume that users
will have a reasonable UI available for simple input operations. We no longer
have to build separate implementations for each of fzf, telescope, ctrlp, etc.
The tradeoff is that `vim.ui.select` is less customizable than any of these
options, so if you wanted to have a preview window (like telescope supports), it
is no longer an option.

My solution to this is extending the `opts` that are passed to `vim.ui.select`.
You can add a `telescope` field that will be passed directly into the picker,
allowing you to customize any part of the UI. If a user has both juu and
telescope installed, they will get your custom picker UI. If either of those
are not true, the selection UI will gracefully degrade to whatever the user has
configured for `vim.ui.select`.

An example of usage:

```lua
vim.ui.select({'apple', 'banana', 'mango'}, {
  prompt = "Title",
  telescope = require("telescope.themes").get_cursor(),
}, function(selected) end)
```

