--- Helper methods used to render notification model elements into views.
---
--- TODO: partial/in-place rendering, to avoid building new strings.
local M = {}

local window = require("juu.notify.notification.window")

--- A list of highlighted tokens.
---@class NotificationLine : NotificationToken[]

--- A tuple consisting of some text and a stack of highlights.
---@class NotificationToken : {[1]: string, [2]: string[]}

---@options notification.view [[
---@protected
--- Notifications rendering options
M.options = {
  --- Display notification items from bottom to top
  ---
  --- Setting this to true tends to lead to more stable animations when the
  --- window is bottom-aligned.
  ---
  ---@type boolean
  stack_upwards = true,

  --- Indent messages longer than a single line
  ---
  --- Example: ~
  --->
  ---   align message style INFO
  ---       looks like this
  ---         when reflowed
  ---
  ---    align annote style INFO
  ---       looks like this when
  ---                   reflowed
  ---<
  ---
  ---@type "message"|"annote"
  align = "message",

  --- Reflow (wrap) messages wider than notification window
  ---
  --- The various options determine how wrapping is handled mid-word.
  ---
  --- Example: ~
  --->
  ---       "hard" is reflo INFO
  ---         wed like this
  ---
  ---   "hyphenate" is ref- INFO
  ---       lowed like this
  ---
  ---   "ellipsis" is refl… INFO
  ---       …owed like this
  ---<
  ---
  --- If this option is set to false, long lines will simply be truncated.
  ---
  --- This option has no effect if |juu.option.notification.window.max_width|
  --- is `0` (i.e., infinite).
  ---
  --- Annotes longer than this width on their own will not be wrapped.
  ---
  ---@type "hard"|"hyphenate"|"ellipsis"|false
  reflow = false,

  --- Separator between group name and icon
  ---
  --- Must not contain any newlines. Set to `""` to remove the gap between names
  --- and icons in all notification groups.
  ---
  ---@type string
  icon_separator = " ",

  --- Separator between notification groups
  ---
  --- Must not contain any newlines. Set to `false` to omit separator entirely.
  ---
  ---@type string|false
  group_separator = "--",

  --- Highlight group used for group separator
  ---
  ---@type string|false
  group_separator_hl = "Comment",

  --- Spaces to pad both sides of each non-empty line
  ---
  --- Useful for adding a visual gap between notification text and any buffer it
  --- may overlap with.
  ---
  ---@type integer
  line_margin = 1,

  --- How to render notification messages
  ---
  --- Messages that appear multiple times (have the same `content_key`) will
  --- only be rendered once, with a `cnt` greater than 1. This hook provides an
  --- opportunity to customize how such messages should appear.
  ---
  --- If this returns false or nil, the notification will not be rendered.
  ---
  --- See also:~
  ---     |juu.notify.Config|
  ---     |juu.notify.default_config|
  ---     |juu.notify.set_content_key|
  ---
  ---@type fun(msg: string, cnt: number): (string|false|nil)
  render_message = function(msg, cnt)
    return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg)
  end,
}
---@options ]]

require("juu.options").declare(M, "notification.view", M.options)

--- True when using GUI clients like neovide. Set before each render() phase.
---@type boolean
local is_multigrid_ui = false

---@return boolean is_multigrid_ui
function M.check_multigrid_ui()
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.ext_multigrid then
      return true
    end
  end
  return false
end

---  Whether nr is a codepoint representing whitespace.
---
---@param s string
---@param index integer
---@return boolean
local function whitespace(s, index)
  -- Same heuristic as vim.fn.trim(): <= 32 includes all ASCII whitespace
  -- (as well as other control chars, which we don't care about).
  -- Note that 160 is the unicode no-break space but we don't want to break on
  -- that anyway.
  return vim.fn.strgetchar(s, index) <= 32
end

--- The displayed width of some strings.
---
--- A simple wrapper around vim.fn.strwidth(), accounting for tab characters
--- manually.
---
--- We call this instead of vim.fn.strdisplaywidth() because that depends on
--- the state and size of the current window and buffer, which could be
--- anywhere.
---@param ... string
---@return integer len
local function strwidth(...)
  local w = 0
  for _, s in ipairs({ ... }) do
    w = w + vim.fn.strwidth(s) + vim.fn.count(s, "\t") * math.max(0, window.options.tabstop - 1)
  end
  return w
end

---@return integer len
local function line_margin()
  return 2 * M.options.line_margin
end

--- The displayed width of some strings, accounting for line_margin.
---@param ... string
---@return integer len
local function line_width(...)
  local w = strwidth(...)
  return w == 0 and w or w + line_margin()
end

---@param text string the text in this token
---@param ... string  highlights to apply to text
---@return NotificationToken
local function Token(text, ...)
  if is_multigrid_ui then
    return { text, { ... } }
  end
  return { text, { window.no_blend_hl, ... } }
end

---@param ... NotificationToken
---@return NotificationLine
local function Line(...)
  if select("#", ...) == 0 then
    return {}
  end
  local margin = Token(string.rep(" ", M.options.line_margin))
  -- ... only expands to all args in last position of table
  local line = { margin, ... }
  line[#line + 1] = margin
  return line
end

---@return NotificationLine[]|nil lines
---@return integer                width
function M.render_group_separator()
  local line = M.options.group_separator
  if not line then
    return nil, 0
  end
  return { Line(Token(line, M.options.group_separator_hl)) }, line_width(line)
  -- TODO: cache the return value, this never changes
end

---@class JuuNotifyViewBorderStyle
---@field border_left_char string Vertical line for left border on content lines
---@field border_right_char string Vertical line for right border on content lines
---@field border_top_char string Horizontal line for top border
---@field border_bottom_char string Horizontal line for bottom border
---@field border_top_left_char string Corner character for top-left
---@field border_top_right_char string Corner character for top-right
---@field border_bottom_left_char string Corner character for bottom-left
---@field border_bottom_right_char string Corner character for bottom-right
---@field base_style string Highlight group to use for border

--- Get border styling information based on style or level and config.
---@param config Config
---@param style string|nil The highlight group name to use for borders
---@param level number|string|nil Optional level (used if style is not provided)
---@return JuuNotifyViewBorderStyle border_style
function M.get_styled_with_border(config, style, level)
  local border_left_char = "│"
  local border_top_left_char = "╭"
  local border_top_right_char = "╮"
  local border_bottom_left_char = "╰"
  local border_bottom_right_char = "╯"
  local border_right_char = "│"
  local border_top_char = "─"
  local border_bottom_char = "─"
  -- Use style directly if provided, otherwise resolve from level
  local base_style = style
  if not base_style then
    -- Get style from level, similar to how it's done in model.lua
    if type(level) == "number" then
      if level == vim.log.levels.INFO and config.info_style then
        base_style = config.info_style
      elseif level == vim.log.levels.WARN and config.warn_style then
        base_style = config.warn_style
      elseif level == vim.log.levels.ERROR and config.error_style then
        base_style = config.error_style
      elseif level == vim.log.levels.DEBUG and config.debug_style then
        base_style = config.debug_style
      end
    elseif type(level) == "string" then
      base_style = level
    end
  end

  -- Fallback to annote_style or Question
  base_style = base_style or config.annote_style or "Question"

  return {
    border_left_char = border_left_char,
    border_right_char = border_right_char,
    border_top_char = border_top_char,
    border_bottom_char = border_bottom_char,
    border_top_left_char = border_top_left_char,
    border_top_right_char = border_top_right_char,
    border_bottom_left_char = border_bottom_left_char,
    border_bottom_right_char = border_bottom_right_char,
    base_style = base_style,
  }
end

--- Render the header of a group, containing group name and icon.
---
---@param   now   number    timestamp of current render frame
---@param   group Group     group whose header we should render
---@return  NotificationLine[]|nil group_header
---@return  integer                width
function M.render_group_header(now, group)
  local group_name = group.config.name
  if type(group_name) == "function" then
    group_name = group_name(now, group.items)
  end

  local group_icon = group.config.icon
  if type(group_icon) == "function" then
    group_icon = group_icon(now, group.items)
  end

  local name_tok = group_name and Token(group_name, group.config.group_style or "Title")
  local icon_tok = group_icon and Token(group_icon, group.config.icon_style or group.config.group_style or "Title")

  if name_tok and icon_tok then
    ---@cast group_name string
    ---@cast group_icon string
    local sep_tok = Token(M.options.icon_separator) -- TODO: cache this
    local width = line_width(group_name, group_icon, M.options.icon_separator)
    if group.config.icon_on_left then
      return { Line(icon_tok, sep_tok, name_tok) }, width
    else
      return { Line(name_tok, sep_tok, icon_tok) }, width
    end
  elseif name_tok then
    ---@cast group_name string
    return { Line(name_tok) }, line_width(group_name)
  elseif icon_tok then
    ---@cast group_icon string
    return { Line(icon_tok) }, line_width(group_icon)
  else
    -- No group header to render
    return nil, 0
  end
end

---@param items Item[]
---@return Item[] deduped
---@return table<any, integer> counts
function M.dedup_items(items)
  local deduped, counts = {}, {}
  for _, item in ipairs(items) do
    local key = item.content_key or item
    if counts[key] then
      counts[key] = counts[key] + 1
    else
      counts[key] = 1
      table.insert(deduped, item)
    end
  end
  return deduped, counts
end

--- Render a notification item, containing message and annote.
---
---@param item   Item
---@param config Config
---@param count  number
---@return NotificationLine[]|nil lines
---@return integer                max_width
function M.render_item(item, config, count)
  if item.hidden then
    return nil, 0
  end

  local msg = M.options.render_message(item.message, count)
  if not msg then
    -- Don't render any lines for nil messages
    return nil, 0
  end

  local lines, item_width = {}, 0

  -- Use annote_style if available (inverted colors), otherwise fall back to style
  -- If annote_style is nil, try to create it lazily (e.g., if it wasn't created in fast event context)
  local annote_hl = item.annote_style
  if not annote_hl and item.style then
    -- Lazy creation of inverted style (renderer is not in fast event context)
    local model = require("juu.notify.notification.model")
    if model and model.annote_style_from_base then
      annote_hl = model.annote_style_from_base(item.style) or item.style
      -- Cache it for next time
      item.annote_style = annote_hl
    else
      annote_hl = item.style
    end
  end
  annote_hl = annote_hl or item.style
  local ann_tok = item.annote and Token(item.annote, annote_hl)
  local sep_tok = Token(config.annote_separator or " ")

  -- How much space is available to message lines
  local msg_width = window.max_width()
    - line_margin() -- adjusted for line margin
    - 1 -- adjusted for ext_mark margin

  local presplit_char, postsplit_char = nil, nil
  if M.options.reflow == "hyphenate" then
    presplit_char = "-"
  elseif M.options.reflow == "ellipsis" then
    presplit_char = "…"
    postsplit_char = "…"
  end

  if ann_tok and msg_width ~= math.huge and M.options.reflow then
    -- If we need annote, adjust remaining available width for message line(s)
    local ann_width = strwidth(sep_tok[1], ann_tok[1])
    if ann_width > msg_width then
      -- No room for annote + item line. Put annote on line of its own.
      table.insert(lines, Line(ann_tok))
      item_width = line_width(ann_tok[1])
      -- Pretend there was no annote to begin with.
      ann_tok = nil
    else
      -- Reduce available space for message line(s); that will get printed next
      -- to annote and sep in first iteration of loop below.
      msg_width = msg_width - ann_width
    end
  end

  -- Determine message style: use item.style if color_messages is enabled, otherwise nil (default)
  local msg_style = (config.color_messages and item.style) or nil

  local function insert(line)
    if ann_tok then
      -- Need to emite annote token in this line
      table.insert(lines, Line(line, sep_tok, ann_tok))
      item_width = math.max(item_width, line_width(line[1], sep_tok[1], ann_tok[1]))

      if M.options.align == "annote" then
        -- Refund available msg_width with length of annote + sepeparator
        msg_width, ann_tok = msg_width + strwidth(sep_tok[1], ann_tok[1]), nil
      else -- M.options.align == "message"
        -- Replace annote token with equivalent width of space
        ann_tok = Token(string.rep(" ", strwidth(ann_tok[1])))
      end
    else
      table.insert(lines, Line(line))
      item_width = math.max(item_width, line_width(line[1]))
    end
  end

  for whole_line in vim.gsplit(msg, "\n", { plain = true, trimempty = true }) do
    local lwidth = strwidth(whole_line)
    if msg_width >= lwidth then
      -- The entire line fits into the available space; insert it as is.
      -- Note that we do not trim it either.
      insert(Token(whole_line, msg_style))
    elseif not M.options.reflow then
      -- If the message is wider than available space but we are explicitly
      -- asked not to reflow, then just truncate it.
      insert(Token(vim.fn.strcharpart(whole_line, 0, msg_width, true), msg_style))
    else
      local split_begin, postsplit = 0, nil
      whole_line = vim.fn.trim(whole_line)
      while lwidth > 0 do
        local split_len, presplit = msg_width, nil
        if postsplit then
          split_len = split_len - 1
        end

        if
          lwidth > split_len
          and not whitespace(whole_line, split_begin + split_len)
          and not whitespace(whole_line, split_begin + split_len - 1)
        then
          if whitespace(whole_line, split_begin + split_len - 2) then
            -- Avoid "split w/ord"
            split_len = split_len - 1
          elseif presplit_char then
            if whitespace(whole_line, split_begin + split_len - 3) then
              -- Avoid "split w-/ord"
              split_len = split_len - 2
            else
              split_len = split_len - 1
              presplit = presplit_char
            end
          end
        end

        local line = vim.fn.strcharpart(whole_line, split_begin, split_len, true)
        line = vim.fn.trim(line)
        if postsplit then
          line = postsplit .. line
        end
        if presplit then
          line = line .. presplit
          postsplit = postsplit_char
        else
          postsplit = nil
        end
        insert(Token(line, msg_style))
        split_begin = split_begin + split_len
        lwidth = lwidth - split_len
      end
    end
  end

  if #lines == 0 then
    if ann_tok then
      -- The message is an empty string, but there's an annotation to render.
      return { Line(ann_tok) }, line_width(item.annote)
    else
      -- Don't render empty messages
      return nil, 0
    end
  else
    return lines, item_width
  end
end

--- Render notifications into lines and highlights.
---
---@param now number timestamp of current render frame
---@param groups Group[]
---@return NotificationLine[] lines
---@return integer width
---@return table item_boundaries Metadata about which lines belong to which items for border rendering
function M.render(now, groups)
  is_multigrid_ui = M.check_multigrid_ui()

  ---@type NotificationLine[][]
  local chunks = {}
  ---@type table[] Metadata for each chunk: {type: "item"|"header"|"separator", item?: Item, config?: Config}
  local chunk_metadata = {}
  local max_width = 0

  for idx, group in ipairs(groups) do
    if idx ~= 1 then
      local sep, sep_width = M.render_group_separator()
      if sep then
        table.insert(chunks, sep)
        table.insert(chunk_metadata, { type = "separator" })
        max_width = math.max(max_width, sep_width)
      end
    end

    local hdr, hdr_width = M.render_group_header(now, group)
    if hdr then
      table.insert(chunks, hdr)
      table.insert(chunk_metadata, { type = "header" })
      max_width = math.max(max_width, hdr_width)
    end

    local items, counts = M.dedup_items(group.items)
    for i, item in ipairs(items) do
      if group.config.render_limit and i > group.config.render_limit then
        -- Don't bother rendering the rest (though they still exist)
        break
      end

      local it, it_width = M.render_item(item, group.config, counts[item.content_key or item])
      if it then
        table.insert(chunks, it)
        -- Store the item's style directly - it's already the correct highlight group
        table.insert(chunk_metadata, { type = "item", item = item, config = group.config, style = item.style })
        max_width = math.max(max_width, it_width)
      end
    end
  end

  local start, stop, step
  if M.options.stack_upwards then
    start, stop, step = #chunks, 1, -1
  else
    start, stop, step = 1, #chunks, 1
  end

  local lines = {}
  local item_boundaries = {} -- {first_line_index, last_line_index, config, level}[]
  local current_line_index = 0

  for i = start, stop, step do
    local chunk = chunks[i]
    local metadata = chunk_metadata[i]
    local first_line = current_line_index + 1

    for _, line in ipairs(chunk) do
      table.insert(lines, line)
      current_line_index = current_line_index + 1
    end

    local last_line = current_line_index

    -- Track item boundaries for border rendering
    if metadata.type == "item" and metadata.item and metadata.config then
      table.insert(item_boundaries, {
        first_line = first_line,
        last_line = last_line,
        config = metadata.config,
        style = metadata.style,
        width = max_width,
      })
    end
  end

  return lines, max_width, item_boundaries
end

--- Display notification items in Neovim messages.
---
--- TODO(j-hui): this is not very configurable, but I'm not sure what options to
--- expose to strike a balance between flexibility and simplicity. Then again,
--- nothing done here is "special"; the user can easily (and is encouraged to)
--- write a custom `echo_history()` by consuming the results of `get_history()`.
---
---@param items HistoryItem[]
function M.echo_history(items)
  for _, item in ipairs(items) do
    local is_multiline_msg = string.find(item.message, "\n") ~= nil

    local chunks = {}

    table.insert(chunks, { vim.fn.strftime("%c", item.last_updated), "Comment" })

    -- if item.group_icon and #item.group_icon > 0 then
    --   table.insert(chunks, { " ", "MsgArea" })
    --   table.insert(chunks, { item.group_icon, "Special" })
    -- end

    if item.group_name and #item.group_name > 0 then
      table.insert(chunks, { " ", "MsgArea" })
      table.insert(chunks, { item.group_name, "Special" })
    end

    table.insert(chunks, { " | ", "Comment" })

    if item.annote and #item.annote > 0 then
      -- Use annote_style if available (inverted colors), otherwise fall back to style
      local annote_hl = item.annote_style or item.style or "Comment"
      table.insert(chunks, { item.annote, annote_hl })
    end

    if is_multiline_msg then
      table.insert(chunks, { "\n", "MsgArea" })
    else
      table.insert(chunks, { " ", "MsgArea" })
    end

    -- Use item.style for message if available, otherwise use MsgArea
    table.insert(chunks, { item.message, item.style or "MsgArea" })

    if is_multiline_msg then
      table.insert(chunks, { "\n", "MsgArea" })
    end

    vim.api.nvim_echo(chunks, false, {})
  end
end

return M
