<div align="center">

![Juu Logo][logo]

# Juu.nvim

[![Made with love][badge-made-with-love]][contributors]
[![Development status][badge-development-status]][development-status]
[![Our manifesto][badge-our-manifesto]][our-manifesto]
![Made with lua][badge-made-with-lua]
[![Latest release][badge-latest-release]][latest-release]

[Terms used](#terms-used) •
[The what](#what) •
[Screenshots](#screenshots) •
[Requirements](#requirements) •
[Installation](#installation) •
[Configuration](#configuration) •
[Highlights](#highlights) •
[Advanced configuration](#advanced-configuration) •

<p></p>

A pretty complete set of Neovim UI components for
notification, input and progress.

Juu is swahili for "up" or "above."

<p></p>

</div>

> [!WARNING]
> This is a revamp of
> [dressing.nvim](https://github.com/stevearc/dressing.nvim)
> and
> [fidget.nvim](https://github.com/j-hui/fidget.nvim).
>
> All the hard work has been done by
> [Steven Arcangeli](https://github.com/stevearc) and
> [John Hui](https://github.com/j-hui).

## Terms used

- *Language Server Protocol* (LSP): A protocol that defines
  how code editors and IDEs communicate with language servers.

## What?

Juu.nvim styles the input and select windows in Neovim,
provides a configurable
[`juu.notify`](./lua/juu/notify/notification.lua) (`vim.notify`) and
[`juu.progress`](./lua/juu/demos/progress/loading.lua) backend,
and displays (LSP) progress notifications.

## Screenshots

### Notifications

![Screenshot of juu.notify][screenshot-notify]

### Progress

![Screenshot of juu.progress][screenshot-progress]

## Requirements

- Neovim 0.11.5+ (might work on earlier versions, but not tested)

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

Juu.nvim includes a notification system that replaces
`vim.notify()` by default.

Notifications are displayed in a corner window.
You can configure it like this:

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

    -- Notification group configuration
    configs = {
      default = {
        -- Enable colored message text based on log level (default: true)
        color_messages = true,

        -- Enable borders around notification items (default: true)
        borders = true,

        -- Highlight styles for different log levels
        debug_style = "Comment",
        info_style = "Question",
        warn_style = "WarningMsg",
        error_style = "ErrorMsg",
      },
    },
  },
})
```

#### Notification Titles and Inverted Colors

Notification titles (annotes) are displayed with
**inverted colors** for better visibility:

the foreground color of the log level becomes the background,
and the background becomes the foreground.
This creates a badge-like appearance for the title.

For example, with an error notification:

- **Message text**: Uses the regular error colors (typically red foreground)
- **Title/annote**: Uses inverted colors (red background with black foreground)

If the base highlight has a transparent background,
the inverted version automatically
uses black for the foreground to
ensure the title text remains visible.

You can view notification history using the `:Notifications` command,
which works similarly to `:messages`.

You can also filter by log level:

```vim
:Notifications          " Show all notifications
:Notifications error    " Show only error notifications
:Notifications info     " Show only info notifications
:Notifications warn     " Show only warning notifications
:Notifications debug    " Show only debug notifications
```

The notification system also supports
the `title` parameter from `vim.notify()`:

```lua
vim.notify("Something went wrong", vim.log.levels.ERROR, { title = "Error" })
-- The title "Error" will be displayed with inverted error colors (red background)
```

### Testing Progress Notifications

You can simulate progress notifications for
testing using the `progress.handle.create()` API:

```lua
local progress = require("juu.progress")

-- Create a progress handle
local handle = progress.handle.create({
  title = "My Task",
  message = "Starting...",
  client = { name = "My Test-Client" },
  percentage = 0,
  cancellable = true,
})

-- Update progress over time
handle.message = "Processing..."
handle.percentage = 25

handle:report({
  message = "Halfway there...",
  percentage = 50,
})

-- Finish the task
handle:finish()
```

For a more complete example that simulates progress over time:

```lua
-- Simulate a 5-second progress task
local progress = require("juu.progress")
local handle = progress.handle.create({
  title = "Test Task",
  message = "Starting...",
  client = { name = "My Test-Client" },
  percentage = 0,
})

local timer = vim.loop.new_timer()
local step = 0
timer:start(0, 100, function()
  step = step + 1
  local percentage = math.min(100, step * 2)
  handle:report({
    message = string.format("Processing... (%d%%)", percentage),
    percentage = percentage,
  })
  
  if percentage >= 100 then
    timer:stop()
    timer:close()
    handle:finish()
  end
end)
```

There is also a demo file included with the plugin at
`lua/juu/demos/progress/loading.lua` that you can run with:

```vim
:lua require("juu.demos.progress.loading").simulate()
```


### LSP Progress Configuration

Juu.nvim automatically tracks and displays LSP progress messages.

You can disable LSP progress tracking by setting `modules.lsp = nil`:

```lua
require("juu").setup({
  progress = {
    modules = {
      lsp = nil,  -- Disable LSP progress tracking
    },
  },
})
```

Configure it like this:

```vim


```lua
require("juu").setup({
  progress = {
    -- General progress options
    -- Poll rate: 0 = immediate, >0 = Hz, false = disabled
    poll_rate = 0,

    -- Suppress new messages while in insert mode
    suppress_on_insert = false,

    -- Ignore new tasks that are already complete
    ignore_done_already = false,

    -- Ignore new tasks that don't contain a message
    ignore_empty_message = false,

    -- How to group progress messages (default: by client name)
    notification_group = function(msg)
      return msg.client.name
    end,

    -- List of clients to ignore
    ignore = {},

    -- Module-specific configuration
    modules = {
      -- LSP progress module configuration
      -- Set to `nil` to disable LSP progress tracking entirely
      lsp = {
        -- Configure the LSP progress ring buffer size
        progress_ringbuf_size = 0,

        -- Log $/progress handler invocations (for debugging)
        log_handler = false,
      },
    },

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



[badge-made-with-lua]: assets/badge-made-with-lua.svg
[badge-development-status]: assets/badge-development-status.svg
[badge-our-manifesto]: assets/badge-our-manifesto.svg
[badge-made-with-love]: assets/badge-made-with-love.svg
[badge-latest-release]: https://img.shields.io/github/v/release/mistweaverco/juu.nvim?style=for-the-badge
[screenshot-notify]: ./web/static/assets/screenshots/notify.png
[screenshot-progress]: ./web/static/assets/screenshots/progress.png
[our-manifesto]: https://mistweaverco.com/manifesto
[development-status]: https://github.com/orgs/mistweaverco/projects/5/views/1?filterQuery=repo%3Amistweaverco%2Fjuu.nvim
[contributors]: https://github.com/mistweaverco/juu.nvim/graphs/contributors
[logo]: assets/logo.svg
[swahili]: https://en.wikipedia.org/wiki/Swahili_language
[latest-release]: https://github.com/mistweaverco/juu.nvim/releases/latest
