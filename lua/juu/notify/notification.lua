---@mod juu.notify Notification subsystem
local notification = {}
notification.model = require("juu.notify.notification.model")
notification.window = require("juu.notify.notification.window")
notification.view = require("juu.notify.notification.view")
local logger = require("juu.logger")
local poll = require("juu.poll")

--- Used to determine the identity of notification items and groups.
---@alias Key any

--- Second (level) parameter passed to |juu.notify.notify|.
---
--- `string` indicates highlight group name; otherwise, `number` indicates
--- the |vim.log.levels| value (that will resolve to a highlight group as
--- determined by the |juu.notify.Config|).
---@alias Level number|string

--- Third (opts) parameter passed to |juu.notify.notify|.
---@class Options
---@field key           Key|nil       Replace existing notification item of the same key
---@field group         Key|nil       Group that this notification item belongs to
---@field annote        string|nil    Optional single-line title that accompanies the message
---@field title         string|nil    Optional title (alias for annote, for vim.notify compatibility)
---@field hidden        boolean|nil   Whether this item should be shown
---@field ttl           number|nil    How long after a notification item should exist; pass 0 to use default value
---@field update_only   boolean|nil   If true, don't create new notification items
---@field skip_history  boolean|nil   If true, don't include in notifications history
---@field data          any|nil       Arbitrary data attached to notification item

--- Something that can be displayed in a |juu.notify.Group|.
---
--- If false, this content is not rendered.
---
--- If a callable `function`, it is invoked every render cycle with the items
--- list; useful for rendering animations and other dynamic content.
---@alias Display string|false|fun(now: number, items: Item[]): (string|false|nil)

--- Used to configure the behavior of notification groups.
---
--- If both name and icon are nil, then no group header is rendered.
---
--- The `update_hook` function can be used to dynamically adjust fields of
--- a |juu.notify.Item|, e.g., to set the `hidden` field according to
--- the message. If set to `false`, nothing is done when an item is updated.
---
--- Note that the actual |juu.notify.default_config| defines a few
--- more defaults than what is documented here, which pertain to the fallback
--- used if the corresponding field in the `default` config table is `nil`.
---
---@class Config
---@field name              Display|nil   Name of the group
---@field icon              Display|nil   Icon of the group
---@field icon_on_left      boolean|nil   If `true`, icon is rendered on the left instead of right
---@field annote_separator  string|nil    Separator between message from annote; defaults to `" "`
---@field ttl               number|nil    How long a notification item should exist; defaults to `5`
---@field render_limit      number|nil    How many notification items to show at once
---@field group_style       string|nil    Style used to highlight group name; defaults to `"Title"`
---@field icon_style        string|nil    Style used to highlight icon; if nil, use `group_style`
---@field annote_style      string|nil    Default style used to highlight item annotes; defaults to `"Question"`
---@field debug_style       string|nil    Style used to highlight debug item annotes
---@field info_style        string|nil    Style used to highlight info item annotes
---@field warn_style        string|nil    Style used to highlight warn item annotes
---@field error_style       string|nil    Style used to highlight error item annotes
---@field debug_annote      string|nil    Default annotation for debug items
---@field info_annote       string|nil    Default annotation for info items
---@field warn_annote       string|nil    Default annotation for warn items
---@field error_annote      string|nil    Default annotation for error items
---@field priority          number|nil    Order in which group should be displayed; defaults to `50`
---@field skip_history      boolean|nil   Whether messages should be preserved in history
---@field update_hook       fun(item: Item)|false|nil   Called when an item is updated; defaults to `false`
---@field color_messages    boolean|nil   Whether to apply log level colors to message text (defaults to `true`)
---@field borders           boolean|nil   Whether to display borders around notification items (defaults to `true`)

--- Notification element containing a message and optional annotation.
---
---@class Item
---@field key           Key         Identity of this item (for in-place updates)
---@field content_key   Key         What to deduplicate items by (do not deduplicate if `nil`)
---@field message       string      Displayed message for the item
---@field annote        string|nil  Optional title that accompanies the message
---@field style         string      Style used to render the message text, if any
---@field annote_style  string|nil  Style used to render the annote/title (with inverted colors), if any
---@field hidden        boolean     Whether this item should be shown
---@field expires_at    number      What time this item should be removed; math.huge means never
---@field last_updated  number      What time this item was last updated
---@field skip_history  boolean     Whether this item should be included in history
---@field data          any|nil     Arbitrary data attached to notification item

--- A notification element in the notifications history.
---
---@class HistoryItem : Item
---@field removed       boolean     Whether this item is deleted
---@field group_key     Key         Key of the group this item belongs to
---@field group_name    string|nil  Title of the group this item belongs to
---@field group_icon    string|nil  Icon of the group this item belongs to
---@field last_updated  number      What time this item was last updated, in seconds since Jan 1, 1970

--- Filter options when querying for notifications history.
---
--- Note that filters are conjunctive; all specified predicates need to be true.
---
---@class HistoryFilter
---@field group_key       Key|nil     Items from this group
---@field level           number|string|nil  Filter by log level (number like vim.log.levels.INFO, or string like "info", "error", etc.)
---@field before          number|nil  Only items last updated at least this long ago
---@field since           number|nil  Only items last updated at most this long ago
---@field include_removed boolean|nil Include items that have been removed (default: true)
---@field include_active  boolean|nil Include items that have not been removed (default: true)

--- The "model" (abstract state) of notifications.
---@type State
local state = {
  groups = {},
  view_suppressed = false,
  removed = {},
  removed_cap = 128,
  removed_first = 1,
}

--- Default notification configuration.
---
--- Exposed publicly because it might be useful for users to integrate for when
--- they are adding their own configs.
---
--- To see the default values, run:
---
--->vim
--- :lua print(vim.inspect(require("juu.notify").default_config))
---<
---
--- Note that the default `update_hook` function performs a few book-keeping
--- tasks, e.g., calling |juu.notify.set_content_key| to keep its
--- `content_key` up to date. You may want to do the same if writing your own;
--- check the source code to see what it's doing.
---
--- See also:~
---     |juu.notify.Config|
---
---@type Config
notification.default_config = {
  name = "Notifications",
  icon = "❰❰",
  ttl = 5,
  group_style = "Title",
  icon_style = "Special",
  annote_style = "Question",
  debug_style = "Comment",
  info_style = "Question",
  warn_style = "WarningMsg",
  error_style = "ErrorMsg",
  debug_annote = "DEBUG",
  info_annote = "INFO",
  warn_annote = "WARN",
  error_annote = "ERROR",
  color_messages = true,
  borders = true,
  update_hook = function(item)
    notification.set_content_key(item)
  end,
}

--- Create inverted highlight groups for annotes (bg becomes fg, fg becomes bg)
---@param base_style string The base highlight group name
---@return string|nil inverted_style_name The name of the inverted highlight group, or nil if base doesn't exist
local function create_inverted_annote_style(base_style)
  if not base_style then
    return nil
  end
  local base_hl, theme_hl, ok

  local inverted_name = "JuuNotifyAnnote" .. base_style
  ok, base_hl = pcall(vim.api.nvim_get_hl, 0, { name = base_style })

  if not ok or not base_hl then
    -- If base highlight doesn't exist, try to link to a default inverted style
    return nil
  end

  ok, theme_hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal" })

  -- Get foreground and background colors
  -- nvim_get_hl returns fg/bg as numbers, we need to convert them
  local fg = base_hl.fg
  local bg = base_hl.bg

  -- If both fg and bg are nil, try to get them from the linked highlight
  if not fg and not bg and base_hl.link then
    local linked_ok, linked_hl = pcall(vim.api.nvim_get_hl, 0, { name = base_hl.link })
    if linked_ok and linked_hl then
      fg = linked_hl.fg
      bg = linked_hl.bg
    end
  end

  -- Create inverted highlight: swap fg and bg
  -- If we don't have colors, use reverse attribute
  local hl_opts = {
    bold = base_hl.bold,
    italic = base_hl.italic,
    underline = base_hl.underline,
    undercurl = base_hl.undercurl,
    strikethrough = base_hl.strikethrough,
  }

  if fg or bg then
    hl_opts.fg = bg
    hl_opts.bg = fg
  else
    -- Fallback: use reverse attribute
    hl_opts.reverse = true
  end

  hl_opts.fg = theme_hl.bg or hl_opts.fg

  vim.api.nvim_set_hl(0, inverted_name, hl_opts)

  return inverted_name
end

--- Initialize inverted highlight groups for annotes
---@param config Config
function notification._init_annote_styles(config)
  if not config then
    return
  end

  -- Create inverted styles for each log level
  if config.debug_style then
    create_inverted_annote_style(config.debug_style)
  end
  if config.info_style then
    create_inverted_annote_style(config.info_style)
  end
  if config.warn_style then
    create_inverted_annote_style(config.warn_style)
  end
  if config.error_style then
    create_inverted_annote_style(config.error_style)
  end
  if config.annote_style then
    create_inverted_annote_style(config.annote_style)
  end
end

--- Sets a |juu.notify.Item|'s `content_key`, for deduplication.
---
--- This default implementation sets an item's `content_key` to its `message`,
--- appended with its `annote` (or a null byte if it has no `annote`), a rough
--- "hash" of its contents. You can write your own `update_hook` that "hashes"
--- the message differently, e.g., only considering the `message`, or taking the
--- `data` or style fields into account.
---
--- If you would like to disable message deduplication, don't call this
--- function, leaving the `content_key` field as `nil`. Assuming you're not
--- using the `update_hook` for anything else, you can achieve this by simply
--- the option to `false`, e.g.:
---
--->lua
--- { -- In options table
---   notification = {
---     configs = {
---       -- Opt out of deduplication by default, i.e., in default config
---       default = vim.tbl_extend("force", require('juu.notify').default_config, {
---         update_hook = false,
---       },
---     },
---   },
--- }
---<
---
---@param item Item
function notification.set_content_key(item)
  item.content_key = item.message .. " " .. (item.annote and item.annote or string.char(0))
end

---@options notification [[
---@protected
--- Notification options
notification.options = {
  --- How frequently to update and render notifications
  ---
  --- Measured in Hertz (frames per second).
  ---
  ---@type number
  poll_rate = 10,

  --- Minimum notifications level
  ---
  --- Note that this filter only applies to notifications with an explicit
  --- numeric level (i.e., `vim.log.levels`).
  ---
  --- Set to `vim.log.levels.OFF` to filter out all notifications with an
  --- numeric level, or `vim.log.levels.TRACE` to turn off filtering.
  ---
  ---@type 0|1|2|3|4|5
  filter = vim.log.levels.INFO,

  --- Number of removed messages to retain in history
  ---
  --- Set to 0 to keep around history indefinitely (until cleared).
  ---
  ---@type number
  history_size = 128,

  --- Automatically override vim.notify() with Juu
  ---
  --- Equivalent to the following:
  --->lua
  ---     juu.setup({ --[[ options ]] })
  ---     vim.notify = juu.notify
  ---<
  ---
  ---@type boolean
  override_vim_notify = true,

  --- How to configure notification groups when instantiated
  ---
  --- A configuration with the key `"default"` should always be specified, and
  --- is used as the fallback for notifications lacking a group key.
  ---
  --- To see the default config, run:
  --->vim
  ---     :lua print(vim.inspect(require("juu.notify").default_config))
  ---<
  ---
  ---@type table<Key, Config>
  configs = { default = notification.default_config },

  --- Conditionally redirect notifications to another backend
  ---
  --- This option is useful for delegating notifications to another backend that
  --- supports features Juu has not (yet) implemented.
  ---
  --- For instance, Juu uses a single, shared buffer and window for rendering
  --- all notifications, so it lacks a per-notification `on_open` callback that
  --- can be used to, e.g., set the |filetype| for a specific notification.
  --- For such notifications, you can set up a custom redirect function to delegate
  --- to another notification backend (e.g., nvim-notify) if available.
  ---
  ---@type false|fun(msg: string|nil, level: Level|nil, opts: table|nil): (boolean|nil)
  redirect = false,

  view = notification.view,
  window = notification.window,
}
---@options ]]

require("juu.options").declare(notification, "notification", notification.options, function()
  -- Need to ensure that there is some sane default config.
  if not notification.options.configs.default then
    logger.warn("no default notification config specified; using default")
    notification.options.configs.default = notification.default_config
  end
  -- Initialize inverted highlight groups for annotes
  for _, config in pairs(notification.options.configs) do
    notification._init_annote_styles(config)
  end
  state.removed_cap = notification.options.history_size
  notification.reset()
end)

--- Send a notification to the Juu notifications subsystem.
---
--- Can be used to override `vim.notify()`, e.g.,
--->lua
---     vim.notify = require("juu.notify").notify
---<
---
---@param msg     string|nil  Content of the notification to show to the user.
---@param level   Level|nil   How to format the notification.
---@param opts    Options|nil Optional parameters (see |juu.notify.Options|).
function notification.notify(msg, level, opts)
  if notification.options.redirect and notification.options.redirect(msg, level, opts) then
    logger.info(string.format("Redirected notification: %s", msg))
    return
  end

  if msg ~= nil and type(msg) ~= "string" then
    error("message: expected string, got " .. type(msg))
  end

  if level ~= nil and type(level) ~= "number" and type(level) ~= "string" then
    error("level: expected number | string, got " .. type(level))
  end

  if opts ~= nil and type(opts) ~= "table" then
    error("opts: expected table, got " .. type(opts))
  end

  if type(level) == "number" and level < notification.options.filter then
    logger.info(string.format("Filtered out notification (%s): %s", logger.fmt_level(level), msg))
    return
  end

  local now = poll.get_time()
  notification.model.update(now, notification.options.configs, state, msg, level, opts)
  notification.poller:start_polling(notification.options.poll_rate)
end

--- Close the notification window.
---
--- Note that it the window will pop open again as soon as there is any reason
--- to (e.g., if another notification or LSP progress message is received).
---
--- To temporarily stop the window from opening, see |juu.notify.suppress|.
---
---@return boolean closed_successfully Whether the window closed successfully.
function notification.close()
  return notification.window.guard(function()
    notification.window.close()
  end)
end

--- Clear active notifications.
---
--- If the given `group_key` is `nil`, then all groups are cleared. Otherwise,
--- only that notification group is cleared.
---
---@param group_key Key|nil  Which group to clear
function notification.clear(group_key)
  notification.model.clear(state, poll.get_time(), group_key)
  if #state.groups == 0 then
    notification.window.guard(notification.window.close)
  end
end

--- Clear notifications history, according to the specified filter.
---
---@param filter HistoryFilter|Key|nil  What to clear
function notification.clear_history(filter)
  if filter == nil then
    filter = {}
  elseif type(filter) ~= "table" then
    filter = { group_key = filter }
  end
  notification.model.clear_history(state, poll.get_time(), filter)
end

--- Reset notification subsystem state.
---
--- Note that this function does not set any Juu notification window state,
--- in particular, the `x_offset`.
function notification.reset()
  notification.clear()
  notification.clear_history()
  notification.poller:reset_error() -- Clear error if previously encountered one
end

--- The poller for the notification subsystem.
---@protected
notification.poller = poll.Poller({
  name = "notification",
  poll = function(self)
    notification.model.tick(self:now(), state)

    -- TODO: if not modified, don't re-render
    local lines, width, item_boundaries = notification.view.render(self:now(), state.groups)

    if #lines > 0 then
      if state.view_suppressed then
        return true
      end

      notification.window.guard(function()
        notification.window.set_lines(lines, width, item_boundaries)
      end)
      return true
    else
      if state.view_suppressed then
        return false
      end

      -- If we could not close the window, keep polling, i.e., keep trying to close the window.
      return not notification.close()
    end
  end,
})

--- Dynamically add, overwrite, or delete a notification configuration.
---
--- Inherits missing keys from the default config.
---
---@param key       Key         Which config to set.
---@param config    Config|nil  What to set as config.
---@param overwrite boolean     Whether to overwrite existing config, if any.
---
---@see juu.notify.Config
function notification.set_config(key, config, overwrite)
  if overwrite or not notification.options.configs[key] then
    notification.options.configs[key] = vim.tbl_extend("keep", config, notification.options.configs.default)
  end
end

--- Suppress whether the notification window is shown.
---
--- Pass `true` as argument to turn on suppression, or `false` to turn it off.
---
--- If no argument is given, suppression state is toggled.
---
---@param suppress boolean|nil Whether to suppress or toggle suppression
function notification.suppress(suppress)
  if suppress == nil then
    state.view_suppressed = not state.view_suppressed
  else
    state.view_suppressed = suppress
  end

  if state.view_suppressed then
    notification.close()
  end
end

--- Remove an item from a particular group.
---
---@param group_key Key
---@param item_key Key
---@return boolean successfully_removed
function notification.remove(group_key, item_key)
  return notification.model.remove(state, poll.get_time(), group_key, item_key)
end

--- Query notifications history, according to an optional filter.
---
--- Note that this function may return more than |juu.options.history_size|
--- items, since it will also include current notifications, unless
--- `filter.include_active` is set to `false`.
---
---@param filter  HistoryFilter|Key|nil  options or group_key for filtering history
---@return        HistoryItem[] history
function notification.get_history(filter)
  if filter == nil then
    filter = {}
  elseif type(filter) ~= "table" then
    filter = { group_key = filter }
  end
  return notification.model.make_history(state, poll.get_time(), filter)
end

--- Show the notifications history in the |nvim_echo()| buffer.
---
---@param filter  HistoryFilter|Key|nil  options or group_key for filtering history
function notification.show_history(filter)
  local history = notification.get_history(filter)
  notification.view.echo_history(history)
end

--- Get list of active notification group keys.
---
---@return Key[] keys
function notification.group_keys()
  return vim.tbl_map(function(group)
    return group.key
  end, state.groups)
end

return notification
