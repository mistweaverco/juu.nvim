---Juu notification abstract state (internal)
---
--- Type definitions and helper methods for the notifications model
--- (i.e., its abstract state).
---
--- Note that this model exists separately from the view for several reasons:
--- (1) to make debugging and testing easier;
--- (2) to accumulate repeated, asynchronous in-place-updating notifications,
---     and avoid building strings for no reason; and
--- (3) to enable fine-grained cacheing of rendered elements.
---
--- Types and functions defined in this module are considered private, and won't
--- be added to code documentation.
local M = {}
local logger = require("juu.logger")
local poll = require("juu.poll")

--- The abstract state of the notifications subsystem.
---@class State
---@field groups          Group[]         active notification groups
---@field view_suppressed boolean         whether the notification window is suppressed
---@field removed         HistoryItem[]   ring buffer of removed notifications, kept around for history
---@field removed_cap     number          capacity of removed ring buffer
---@field removed_first   number          index of first item in removed ring buffer (1-indexed)

--- A collection of notification Items.
---@class Group
---@field key           Key     used to distinguish this group from others
---@field config        Config  configuration for this group
---@field items         Item[]  items displayed in the group

---@class HistoryExtra
---@field removed   boolean
---@field group_key Key
---@field group_name string|nil
---@field group_icon string|nil

--- Get the notification group indexed by group_key; create one if none exists.
---
---@param   configs     table<Key, Config>
---@param   groups      Group[]
---@param   group_key   Key
---@return              Group      group
---@return              number|nil new_index
local function get_group(configs, groups, group_key)
  for _, group in ipairs(groups) do
    if group.key == group_key then
      return group, nil
    end
  end

  -- Group not found; create it and insert it into list of active groups.

  ---@type Group
  local group = {
    key = group_key,
    items = {},
    config = configs[group_key] or configs.default,
  }
  table.insert(groups, group)
  return group, #groups
end

--- Add item to the removed history
---
---@param state State
---@param now   number
---@param group Group
---@param item  Item
local function add_removed(state, now, group, item)
  if not item.skip_history then
    local group_name = group.config.name
    if type(group_name) == "function" then
      group_name = group_name(now, group.items)
    end

    local group_icon = group.config.icon
    if type(group_icon) == "function" then
      group_icon = group_icon(now, group.items)
    end

    ---@cast item HistoryItem
    item.last_updated = poll.unix_time(now)
    item.removed = true
    item.group_key = group.key
    item.group_name = group_name
    item.group_icon = group_icon

    state.removed[state.removed_first] = item
    state.removed_first = (state.removed_first % state.removed_cap) + 1
  end
end

--- Promote an item to a history item.
---
---@param item    Item
---@param extra   HistoryExtra
---@return        HistoryItem
local function item_to_history(item, extra)
  ---@type HistoryItem
  item = vim.tbl_extend("force", item, extra)
  item.last_updated = poll.unix_time(item.last_updated)
  return item
end

--- Convert level string to number
---
---@param level_str string|nil
---@return number|nil
function M.level_str_to_num(level_str)
  if not level_str then
    return nil
  end
  level_str = string.lower(level_str)
  if level_str == "debug" then
    return vim.log.levels.DEBUG
  elseif level_str == "info" then
    return vim.log.levels.INFO
  elseif level_str == "warn" then
    return vim.log.levels.WARN
  elseif level_str == "error" then
    return vim.log.levels.ERROR
  end
  return nil
end

--- Infer log level from item annote
---
---@param item Item
---@return number|nil
local function infer_level_from_item(item)
  if not item.annote then
    return nil
  end
  local annote_upper = string.upper(item.annote)
  if annote_upper == "DEBUG" then
    return vim.log.levels.DEBUG
  elseif annote_upper == "INFO" then
    return vim.log.levels.INFO
  elseif annote_upper == "WARN" then
    return vim.log.levels.WARN
  elseif annote_upper == "ERROR" then
    return vim.log.levels.ERROR
  end
  return nil
end

--- Whether an item matches the filter.
---
---@param filter HistoryFilter
---@param now number
---@param item Item
---@return boolean
local function matches_filter(filter, now, item)
  if filter.since and now - filter.since < item.last_updated then
    return false
  end

  if filter.before and now - filter.before > item.last_updated then
    return false
  end

  if filter.level ~= nil then
    local filter_level = type(filter.level) == "string" and M.level_str_to_num(filter.level) or filter.level
    if filter_level ~= nil then
      local item_level = infer_level_from_item(item)
      if item_level ~= filter_level then
        return false
      end
    end
  end

  return true
end

--- Search for an item with the given key among a notification group.
---
---@param group Group
---@param key Key
---@return Item|nil
local function find_item(group, key)
  if key == nil then
    return nil
  end

  for _, item in ipairs(group.items) do
    if item.key == key then
      return item
    end
  end

  -- No item with key was found
  return nil
end

--- Obtain the style specified by the level parameter of a .update(),
--- reading from config if necessary.
---
---@param config  Config
---@param level   number|string|nil
---@return        string|nil
local function style_from_level(config, level)
  if type(level) == "number" then
    if level == vim.log.levels.INFO and config.info_style then
      return config.info_style
    elseif level == vim.log.levels.WARN and config.warn_style then
      return config.warn_style
    elseif level == vim.log.levels.ERROR and config.error_style then
      return config.error_style
    elseif level == vim.log.levels.DEBUG and config.debug_style then
      return config.debug_style
    end
  elseif type(level) == "string" then
    -- Convert string level to number first, then look up the style
    local level_num = M.level_str_to_num(level)
    if level_num then
      return style_from_level(config, level_num)
    end
    -- If it's not a recognized level string, treat it as a style name directly
    return level
  end
  return nil
end

--- Resolve highlight group to get actual colors
---@param hl_name string
---@return table|nil highlight definition with resolved colors
local function resolve_highlight(hl_name, depth)
  depth = (depth or 10) - 1
  if depth < 0 then
    return nil
  end

  -- Get highlight definition with link=false to automatically resolve link chains
  -- This should return the final highlight definition with actual colors
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = hl_name, link = false })
  if not ok or not hl then
    return nil
  end

  -- If link=false returned an empty table, try getting it with link=true to see if there's a link
  if not next(hl) then
    local ok_with_link, hl_with_link = pcall(vim.api.nvim_get_hl, 0, { name = hl_name })
    if ok_with_link and hl_with_link and hl_with_link.link then
      -- There's a link, follow it recursively
      return resolve_highlight(hl_with_link.link, depth)
    end
    -- No link and no colors, can't resolve
    return nil
  end

  -- Check if we have colors (fg/bg) - if not, we can't create an inverted style
  -- Attributes alone aren't enough for inversion
  local has_fg = hl.fg or hl.foreground
  local has_bg = hl.bg or hl.background

  -- If we have a link property but no colors, try following the link
  if hl.link and not has_fg and not has_bg then
    return resolve_highlight(hl.link, depth)
  end

  -- If we still don't have colors after following links, return nil
  if not has_fg and not has_bg then
    return nil
  end

  return hl
end

--- Obtain the inverted annote style for the given base style
---@param base_style string|nil
---@return string|nil
function M.annote_style_from_base(base_style)
  if not base_style then
    return nil
  end

  local inverted_name = "JuuNotifyAnnote" .. base_style

  -- Check if the inverted highlight group already exists and has explicit colors
  -- This check works even in fast event contexts, so we can use existing inverted styles
  -- First try with default (link=true) to see if highlight exists at all
  local ok_default, existing_default = pcall(vim.api.nvim_get_hl, 0, { name = inverted_name })

  -- Ensure existing_default is a table (nvim_get_hl should return a table, but be defensive)
  local is_table = type(existing_default) == "table"
  local has_content = is_table and next(existing_default) ~= nil
  local is_link = is_table and existing_default.link ~= nil

  logger.debug(
    "Checking for existing inverted style:",
    inverted_name,
    "ok:",
    ok_default,
    "exists:",
    existing_default ~= nil,
    "is_table:",
    is_table,
    "has_content:",
    has_content,
    "is_link:",
    is_link,
    "fast_event:",
    vim.in_fast_event()
  )

  -- If highlight exists, is a table, is not empty, and is not just a link, it was properly created
  -- In fast event contexts, we trust that if it exists and isn't a link, it has colors
  if ok_default and is_table and has_content and not is_link then
    logger.debug("Found existing inverted style, using it:", inverted_name)
    if vim.in_fast_event() then
      -- In fast event, trust that existing non-link highlights have colors
      return inverted_name
    end

    -- Not in fast event, verify it has colors
    local ok, existing = pcall(vim.api.nvim_get_hl, 0, { name = inverted_name, link = false })
    if ok and existing and next(existing) then
      local has_fg = existing.fg or existing.foreground
      local has_bg = existing.bg or existing.background
      -- Only return if both colors are set (meaning it was properly created)
      if has_fg and has_bg then
        return inverted_name
      end
    end
  end

  -- Resolve the base highlight, following links recursively
  -- Keep resolving until we get actual colors or hit max depth
  -- If we're in a fast event context, defer creating new inverted styles
  local base_hl
  if vim.in_fast_event() then
    -- In fast event context, defer highlight resolution for creating new inverted styles
    -- But if the inverted style already exists (checked above), we would have returned early
    -- So if we get here, the inverted style doesn't exist yet, and we can't create it in fast event
    logger.debug("Deferring highlight resolution for", base_style, "in fast event context")
    return base_style
  else
    base_hl = resolve_highlight(base_style)
    if not base_hl then
      -- If we can't resolve the base highlight at all, we can't create an inverted style
      logger.warn("Could not resolve highlight:", base_style)
      return base_style
    end
  end

  -- Get foreground and background colors (try both ID and RGB)
  local fg = base_hl.fg or base_hl.foreground
  local bg = base_hl.bg or base_hl.background

  logger.debug("Resolved highlight:", base_style, "fg:", fg, "bg:", bg, "hl:", vim.inspect(base_hl))

  -- Convert color IDs (numbers) to hex strings if needed
  local function color_to_hex(color)
    if not color then
      return nil
    end
    if type(color) == "string" then
      -- Already a hex string
      return color
    elseif type(color) == "number" then
      -- Convert color ID to hex string
      return string.format("#%06x", color)
    end
    return nil
  end

  -- Convert colors to hex strings
  fg = color_to_hex(fg)
  bg = color_to_hex(bg)

  -- Create inverted highlight: swap fg and bg, but handle transparent backgrounds
  local hl_opts = {}

  -- Copy text attributes
  if base_hl.bold ~= nil then
    hl_opts.bold = base_hl.bold
  end
  if base_hl.italic ~= nil then
    hl_opts.italic = base_hl.italic
  end
  if base_hl.underline ~= nil then
    hl_opts.underline = base_hl.underline
  end
  if base_hl.undercurl ~= nil then
    hl_opts.undercurl = base_hl.undercurl
  end
  if base_hl.strikethrough ~= nil then
    hl_opts.strikethrough = base_hl.strikethrough
  end

  -- Swap colors: bg becomes fg, fg becomes bg
  -- But handle transparent backgrounds: if bg is nil/transparent, use black for inverted bg
  if fg or bg then
    -- If we have a foreground color, use it as the inverted background
    if fg then
      hl_opts.bg = fg
    end
    -- If we have a background color, use it as the inverted foreground
    -- If background is transparent (nil), use black for good contrast
    if bg then
      hl_opts.fg = bg
    else
      -- No background in base highlight -> transparent bg becomes black fg for visibility
      hl_opts.fg = "#000000" -- Black foreground for good contrast
    end
  else
    -- If no colors found at all, we can't create a proper inverted style
    -- Return the base style name so it at least uses the original highlight
    return base_style
  end

  -- Create the inverted highlight group
  vim.api.nvim_set_hl(0, inverted_name, hl_opts)

  return inverted_name
end

--- Obtain the annotation from the specified level of an .update() call.
---
---@param config Config
---@param level  number|string|nil
---@return string|nil
local function annote_from_level(config, level)
  if type(level) == "number" then
    if level == vim.log.levels.INFO then
      return config.info_annote or "INFO"
    elseif level == vim.log.levels.WARN then
      return config.warn_annote or "WARN"
    elseif level == vim.log.levels.ERROR then
      return config.error_annote or "ERROR"
    elseif level == vim.log.levels.DEBUG then
      return config.debug_annote or "DEBUG"
    end
  else
    return nil
  end
end

--- Compute the expiry time based on the given TTL (from notify() options) and the default TTL (from config).
---@param ttl         number|nil
---@param default_ttl number|nil
---@return            number expiry_time
local function compute_expiry(now, ttl, default_ttl)
  if not ttl or ttl == 0 then
    return now + (default_ttl or 3)
  else
    return now + ttl
  end
end

--- Update the state of the notifications model.
---
--- The API of this function is based on that of vim.notify().
---
---@protected
---@param now     number
---@param configs table<string, Config>
---@param state   State
---@param msg     string|nil
---@param level   Level|nil
---@param opts    Options|nil
function M.update(now, configs, state, msg, level, opts)
  opts = opts or {}
  -- Support opts.title as an alias for opts.annote (for vim.notify compatibility)
  -- Title takes precedence over annote if both are provided
  if opts.title ~= nil then
    opts.annote = opts.title
  end
  local group_key = opts.group ~= nil and opts.group or "default"
  local group, new_index = get_group(configs, state.groups, group_key)
  local item = find_item(group, opts.key)

  if item == nil then
    -- Item doesn't yet exist; create new item and to insert into the group
    if msg == nil or opts.update_only then
      if new_index then
        table.remove(state.groups, new_index)
      end
      return
    end

    local skip_history = false
    if group.config.skip_history ~= nil then
      skip_history = group.config.skip_history
    end
    if opts.skip_history ~= nil then
      skip_history = opts.skip_history
    end
    ---@cast skip_history boolean

    local base_style = style_from_level(group.config, level) or group.config.annote_style or "Question"
    -- Try to create inverted style, but don't fail if we're in a fast event context
    -- It will be created lazily during rendering if needed
    local annote_style = M.annote_style_from_base(base_style)
    -- If we couldn't create it (e.g., in fast event context), set to nil
    -- The renderer will create it lazily
    if annote_style == base_style and vim.in_fast_event() then
      annote_style = nil -- Will be created lazily during rendering
    elseif not annote_style then
      annote_style = base_style
    end

    ---@type Item
    local new_item = {
      key = opts.key,
      group_key = group_key,
      message = msg,
      annote = (opts.annote ~= nil) and opts.annote or annote_from_level(group.config, level),
      style = base_style,
      annote_style = annote_style,
      hidden = opts.hidden or false,
      expires_at = compute_expiry(now, opts.ttl, group.config.ttl),
      skip_history = skip_history,
      removed = false,
      last_updated = now,
      data = opts.data,
    }
    if group.config.update_hook then
      group.config.update_hook(new_item)
    end
    table.insert(group.items, new_item)
  else
    -- Item with the same key already exists; update it in place
    item.message = msg or item.message
    local base_style = style_from_level(group.config, level) or item.style
    item.style = base_style
    -- Try to create inverted style, but don't fail if we're in a fast event context
    -- It will be created lazily during rendering if needed
    local annote_style = M.annote_style_from_base(base_style)
    -- If we couldn't create it (e.g., in fast event context), set to nil
    -- The renderer will create it lazily
    if annote_style == base_style and vim.in_fast_event() then
      item.annote_style = nil -- Will be created lazily during rendering
    else
      item.annote_style = annote_style or base_style
    end
    -- If opts.annote is explicitly provided (including from title), use it; otherwise fall back to level-based or existing
    if opts.annote ~= nil then
      item.annote = opts.annote
    elseif level ~= nil then
      item.annote = annote_from_level(group.config, level) or item.annote
    end
    item.hidden = opts.hidden or item.hidden
    item.expires_at = opts.ttl and compute_expiry(now, opts.ttl, group.config.ttl) or item.expires_at
    item.skip_history = opts.skip_history or item.skip_history
    item.last_updated = now
    item.data = opts.data ~= nil and opts.data or item.data
    if group.config.update_hook then
      group.config.update_hook(item)
    end
  end

  if new_index then
    -- Sort groups by priority (stable sort using table.sort)
    table.sort(state.groups, function(a, b)
      return (a.config.priority or 50) < (b.config.priority or 50)
    end)
  end
end

--- Remove an item from a particular group.
---
---@param state     State
---@param now       number
---@param group_key Key
---@param item_key  Key
---@return boolean successfully_removed
function M.remove(state, now, group_key, item_key)
  for g, group in ipairs(state.groups) do
    if group.key == group_key then
      for i, item in ipairs(group.items) do
        if item.key == item_key then
          -- Note that it should be safe to perform destructive updates to the
          -- arrays here since we're no longer iterating.
          table.remove(group.items, i)
          add_removed(state, now, group, item)
          if #group.items == 0 then
            table.remove(state.groups, g)
          end
          return true
        end
      end
      return false -- Found group, but didn't find item
    end
  end
  return false -- Did not find group
end

--- Clear active notifications.
---
--- If the given `group_key` is `nil`, then all groups are cleared. Otherwise,
--- only that notification group is cleared.
---
---@param state     State
---@param now       number
---@param group_key Key|nil
function M.clear(state, now, group_key)
  if group_key == nil then
    for _, group in ipairs(state.groups) do
      for _, item in ipairs(group.items) do
        add_removed(state, now, group, item)
      end
    end
    state.groups = {}
  else
    for idx, group in ipairs(state.groups) do
      if group.key == group_key then
        for _, item in ipairs(group.items) do
          add_removed(state, now, group, item)
        end
        table.remove(state.groups, idx)
        -- We assume group keys are unique
        break
      end
    end
  end
end

--- Prune out all items (and groups) for which the ttl has elapsed.
---
---@protected
---@param now number timestamp of current frame.
---@param state  State
function M.tick(now, state)
  local new_groups = {}
  for _, group in ipairs(state.groups) do
    local new_items = {}
    for _, item in ipairs(group.items) do
      if item.expires_at > now then
        table.insert(new_items, item)
      else
        add_removed(state, now, group, item)
      end
    end
    if #group.items > 0 then
      group.items = new_items
      table.insert(new_groups, group)
    else
    end
  end
  state.groups = new_groups
end

--- Generate a notifications history according to the provided filter.
---
--- The results are not sorted.
---
---@param state   State
---@param filter  HistoryFilter
---@param now     number
---@return        HistoryItem[] history
function M.make_history(state, now, filter)
  ---@type Item[]
  local history = {}

  if filter.include_active ~= false then
    for _, group in ipairs(state.groups) do
      if filter.group_key == nil or group.key == filter.group_key then
        for _, item in ipairs(group.items) do
          if not item.skip_history and matches_filter(filter, now, item) then
            local group_name = group.config.name
            if type(group_name) == "function" then
              group_name = group_name(now, group.items)
            end

            local group_icon = group.config.icon
            if type(group_icon) == "function" then
              group_icon = group_icon(now, group.items)
            end

            table.insert(
              history,
              item_to_history(item, {
                removed = false,
                group_key = group.key,
                group_name = group_name,
                group_icon = "",
              })
            )
          end
        end
        if filter.group_key ~= nil then
          -- No need to search other groups, we assume keys are unique
          break
        end
      end
    end
  end

  if filter.include_removed ~= false then
    for _, item in ipairs(state.removed) do
      if matches_filter(filter, now, item) then
        -- NOTE: we aren't deep-copying here---not sure it's necessary.
        table.insert(history, item)
      end
    end
  end

  return history
end

--- Clear notifications history, according to the specified filter.
---
--- Removes items that match the filter; equivalently, preserves items that do
--- not match the filter.
---
---@param state   State
---@param now     number
---@param filter  HistoryFilter
function M.clear_history(state, now, filter)
  if filter.include_removed == false then
    logger.warn("filter does not make any sense for clearing history:", vim.inspect(filter))
    return
  end

  local new_removed = {}

  if state.removed[state.removed_first] ~= nil then
    -- History has already wrapped around
    for i = state.removed_first, state.removed_cap do
      local item = state.removed[i]
      if not matches_filter(filter, now, item) then
        table.insert(new_removed, item)
      end
    end
  end

  for i = 1, state.removed_first - 1 do
    local item = state.removed[i]
    if item == nil then
      -- Reached end of ring buffer
      break
    end
    if not matches_filter(filter, now, item) then
      table.insert(new_removed, item)
    end
  end

  state.removed = new_removed
  state.removed_first = #new_removed + 1
end

return M
