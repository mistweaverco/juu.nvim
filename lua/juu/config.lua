---@class JuuNotifyWindowConfig
---@field normal_hl string Base highlight group in the notification window
---@field winblend number Background color opacity (0-100)
---@field border "none"|"single"|"double"|"rounded"|"solid"|"shadow"|string[] Border around the notification window
---@field border_hl string Highlight group for notification window border
---@field zindex number Stacking priority of the notification window
---@field max_width number Maximum width (0 = no limit, or fraction like 0.5 for 50% of editor width)
---@field max_height integer Maximum height (0 = no limit)
---@field x_padding integer Padding from right edge
---@field y_padding integer Padding from bottom edge
---@field align "top"|"bottom"|"avoid_cursor" How to align the notification window
---@field relative "editor"|"win" What the notification window position is relative to
---@field tabstop integer Width of each tab character
---@field avoid string[] Filetypes to avoid when positioning window

---@class JuuNotifyViewConfig
---@field stack_upwards boolean Display notification items from bottom to top
---@field align "message"|"annote" How to indent messages longer than a single line
---@field reflow "hard"|"hyphenate"|"ellipsis"|false Reflow (wrap) messages wider than notification window
---@field icon_separator string Separator between group name and icon
---@field group_separator string|false Separator between notification groups (set to false to omit)
---@field group_separator_hl string|false Highlight group for group separator
---@field line_margin integer Spaces to pad both sides of each non-empty line
---@field render_message fun(msg: string, cnt: number): (string|false|nil) How to render notification messages with counts

---@alias JuuNotifyDisplay string|false|fun(now: number, items: table[]): (string|false|nil) Something that can be displayed (string, false, or function)

---@class JuuNotifyGroupConfig
---@field name JuuNotifyDisplay|nil Name of the group
---@field icon JuuNotifyDisplay|nil Icon of the group
---@field icon_on_left boolean|nil If true, icon is rendered on the left instead of right
---@field annote_separator string|nil Separator between message from annote; defaults to " "
---@field ttl number|nil How long a notification item should exist; defaults to 5
---@field render_limit number|nil How many notification items to show at once
---@field group_style string|nil Style used to highlight group name; defaults to "Title"
---@field icon_style string|nil Style used to highlight icon; if nil, use group_style
---@field annote_style string|nil Default style used to highlight item annotes; defaults to "Question"
---@field debug_style string|nil Style used to highlight debug item annotes
---@field info_style string|nil Style used to highlight info item annotes
---@field warn_style string|nil Style used to highlight warn item annotes
---@field error_style string|nil Style used to highlight error item annotes
---@field debug_annote string|nil Default annotation for debug items
---@field info_annote string|nil Default annotation for info items
---@field warn_annote string|nil Default annotation for warn items
---@field error_annote string|nil Default annotation for error items
---@field priority number|nil Order in which group should be displayed; defaults to 50
---@field skip_history boolean|nil Whether messages should be preserved in history
---@field update_hook fun(item: table)|false|nil Called when an item is updated; defaults to false
---@field color_messages boolean|nil Whether to apply log level colors to message text (defaults to true)
---@field borders boolean|nil Whether to display borders around notification items (defaults to true)

---@class JuuNotifyConfig
---@field enabled boolean|nil Set to false to disable the notification system
---@field poll_rate number How frequently to update and render notifications (Hz)
---@field filter 0|1|2|3|4|5 Minimum notification level to display
---@field history_size number Number of removed messages to retain in history
---@field override_vim_notify boolean Automatically override vim.notify() with Juu
---@field window JuuNotifyWindowConfig Window configuration
---@field view JuuNotifyViewConfig View/rendering configuration
---@field configs table<string, JuuNotifyGroupConfig> Notification group configurations
---@field redirect false|fun(msg: string|nil, level: number|string|nil, opts: table|nil): (boolean|nil)|nil Conditionally redirect notifications to another backend

---@class JuuNotifyUserConfig
---@field enabled boolean|nil Set to false to disable the notification system
---@field poll_rate number|nil How frequently to update and render notifications (Hz)
---@field filter 0|1|2|3|4|5|nil Minimum notification level to display
---@field history_size number|nil Number of removed messages to retain in history
---@field override_vim_notify boolean|nil Automatically override vim.notify() with Juu
---@field window JuuNotifyWindowConfig|nil Window configuration
---@field view JuuNotifyViewConfig|nil View/rendering configuration
---@field configs table<string, JuuNotifyGroupConfig>|nil Notification group configurations
---@field redirect false|fun(msg: string|nil, level: number|string|nil, opts: table|nil): (boolean|nil)|nil Conditionally redirect notifications to another backend

---@class JuuDefaultConfig
---@field input table Configuration for vim.ui.input
---@field select table Configuration for vim.ui.select
---@field notify JuuNotifyConfig|false Configuration for notifications (set to false to disable)

---@class JuuUserConfig
---@field input table|nil Configuration for vim.ui.input
---@field select table|nil Configuration for vim.ui.select
---@field notify JuuNotifyUserConfig|false|nil Configuration for notifications (set to false to disable)

local default_config = {
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
  notify = {
    -- Set to false to disable the notification system
    enabled = true,

    -- How frequently to update and render notifications (Hz)
    poll_rate = 10,

    -- Minimum notification level to display
    -- Set to vim.log.levels.OFF to filter out all notifications with a numeric level
    -- Set to vim.log.levels.TRACE to turn off filtering
    filter = vim.log.levels.INFO,

    -- Number of removed messages to retain in history
    -- Set to 0 to keep history indefinitely (until cleared)
    history_size = 128,

    -- Automatically override vim.notify() with Juu
    override_vim_notify = true,

    -- Window configuration
    window = {
      -- Base highlight group in the notification window
      normal_hl = "Comment",

      -- Background color opacity (0-100)
      winblend = 100,

      -- Border around the notification window
      border = "none",

      -- Highlight group for notification window border
      -- Set to empty string to use theme's default FloatBorder
      border_hl = "",

      -- Stacking priority of the notification window
      zindex = 45,

      -- Maximum width (0 = no limit, or fraction like 0.5 for 50% of editor width)
      max_width = 0,

      -- Maximum height (0 = no limit)
      max_height = 0,

      -- Padding from right edge
      x_padding = 1,

      -- Padding from bottom edge
      y_padding = 0,

      -- How to align the notification window
      align = "bottom",

      -- What the notification window position is relative to
      relative = "editor",

      -- Width of each tab character
      tabstop = 8,

      -- Filetypes to avoid when positioning window
      avoid = {},
    },

    -- View/rendering configuration
    view = {
      -- Display notification items from bottom to top
      stack_upwards = true,

      -- How to indent messages longer than a single line
      align = "message",

      -- Reflow (wrap) messages wider than notification window
      -- Options: "hard", "hyphenate", "ellipsis", or false
      reflow = false,

      -- Separator between group name and icon
      icon_separator = " ",

      -- Separator between notification groups (set to false to omit)
      group_separator = "--",

      -- Highlight group for group separator
      group_separator_hl = "Comment",

      -- Spaces to pad both sides of each non-empty line
      line_margin = 1,

      -- How to render notification messages with counts
      render_message = function(msg, cnt)
        return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg)
      end,
    },

    -- Notification group configurations
    -- A configuration with the key "default" should always be specified
    configs = {
      default = {
        -- Group name
        name = "Notifications",

        -- Group icon
        icon = "❰❰",

        -- How long a notification item should exist (seconds)
        ttl = 5,

        -- Highlight styles
        group_style = "Title",
        icon_style = "Special",
        annote_style = "Question",
        debug_style = "Comment",
        info_style = "Question",
        warn_style = "WarningMsg",
        error_style = "ErrorMsg",

        -- Default annotations for log levels
        debug_annote = "DEBUG",
        info_annote = "INFO",
        warn_annote = "WARN",
        error_annote = "ERROR",

        -- Enable colored message text based on log level
        color_messages = true,

        -- Enable borders around notification items
        borders = true,

        -- Separator between message and annote
        annote_separator = " ",

        -- How many notification items to show at once
        render_limit = nil,

        -- Priority for ordering groups
        priority = 50,
      },
    },

    -- Conditionally redirect notifications to another backend
    -- Useful for delegating to backends that support features Juu doesn't
    redirect = false,
  },
}

local M = vim.deepcopy(default_config)

-- Apply shims for backwards compatibility
---@param key string
---@param opts? table
---@return table?
M.apply_shim = function(key, opts)
  -- Support start_in_insert for backwards compatibility.
  if key == "input" and opts ~= nil and opts.start_in_insert ~= nil then
    opts.start_mode = opts.start_in_insert and "insert" or "normal"
  end

  return opts
end

M.update = function(opts)
  local newconf = vim.tbl_deep_extend("force", default_config, opts or {})

  for k, v in pairs(newconf) do
    M[k] = M.apply_shim(k, v)
  end
end

-- Used to get the effective config value for a module.
-- Use like: config.get_mod_config('input')
M.get_mod_config = function(key, ...)
  if not M[key].get_config then
    return M[key]
  end

  local conf = M[key].get_config(...)
  conf = M.apply_shim(key, conf)

  if conf then
    return vim.tbl_deep_extend("force", M[key], conf)
  else
    return M[key]
  end
end

return M
