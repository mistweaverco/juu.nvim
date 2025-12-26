---@mod juu.progress LSP progress subsystem
local progress = {}
progress.display = require("juu.progress.display")
progress.handle = require("juu.progress.handle")
local logger = require("juu.logger")
local notification = require("juu.notify")
local poll = require("juu.poll")

--- Default modules that are enabled by default if not explicitly disabled.
--- Add module names here to enable them automatically.
---@type string[]
local default_modules = { "lsp" }

--- Lazy loader for progress modules (only loaded when enabled)
---@param module_name string Name of the module (e.g., "lsp")
---@return table|nil
local function get_module(module_name)
  local module_key = module_name
  if progress[module_key] == nil then
    local ok, module = pcall(require, "juu.progress." .. module_name)
    if ok then
      progress[module_key] = module
    else
      logger.error("Failed to load progress module:", module_name)
      return nil
    end
  end
  return progress[module_key]
end

--- Table of progress-related autocmds, used to ensure setup() re-entrancy.
local autocmds = {}

--- Registry of detach handlers.
--- Each handler is called when a client/module detaches.
---
---@type table<string, fun(identifier: any): any>
local detach_handlers = {}

---@options progress [[
---@protected
--- Progress options
progress.options = {
  --- How and when to poll for progress messages
  ---
  --- Set to `0` to immediately poll on each progress event (e.g., |LspProgress|).
  ---
  --- Set to a positive number to poll for progress messages at the specified
  --- frequency (Hz, i.e., polls per second). Combining a slow `poll_rate`
  --- (e.g., `0.5`) with the `ignore_done_already` setting can be used to filter
  --- out short-lived progress tasks, de-cluttering notifications.
  ---
  --- Note that if too many progress messages are sent between polls,
  --- Neovim's progress ring buffer will overflow and messages will be
  --- overwritten (dropped), possibly causing stale progress notifications.
  --- Workarounds include using the |juu.option.progress.modules.lsp.progress_ringbuf_size|
  --- option, or manually calling |juu.notify.reset| (see #167).
  ---
  --- Set to `false` to disable polling altogether; you can still manually poll
  --- progress messages by calling |juu.progress.poll|.
  ---
  ---@type number|false
  poll_rate = 0,

  --- Suppress new messages while in insert mode
  ---
  --- Note that progress messages for new tasks will be dropped, but existing
  --- tasks will be processed to completion.
  ---
  ---@type boolean
  suppress_on_insert = false,

  --- Ignore new tasks that are already complete
  ---
  --- This is useful if you want to avoid excessively bouncy behavior, and only
  --- seeing notifications for long-running tasks. Works best when combined with
  --- a low `poll_rate`.
  ---
  ---@type boolean
  ignore_done_already = false,

  --- Ignore new tasks that don't contain a message
  ---
  --- Some servers may send empty messages for tasks that don't actually exist.
  --- And if those tasks are never completed, they will become stale in Fidget.
  --- This option tells Fidget to ignore such messages unless the LSP server has
  --- anything meaningful to say. (See #171)
  ---
  --- Note that progress messages for new empty tasks will be dropped, but
  --- existing tasks will be processed to completion.
  ---
  ---@type boolean
  ignore_empty_message = false,

  --- How to get a progress message's notification group key
  ---
  --- Set this to return a constant to group all progress messages together,
  --- e.g.,
  --->lua
  ---     notification_group = function(msg)
  ---       -- N.B. you may also want to configure this group key ("progress")
  ---       -- using progress.display.overrides or notification.configs
  ---       return "progress"
  ---     end
  ---<
  ---
  ---@type fun(msg: ProgressMessage): Key
  notification_group = function(msg)
    return msg.client.name
  end,

  --- List of filters to ignore progress messages
  ---
  --- Each filter is either a string or a function.
  ---
  --- If it is a string, then it is treated as the name of a client;
  --- messages from that client are ignored.
  ---
  --- If it is a function, then the progress message object is passed to the
  --- function. If the function returns a truthy value, then that message is
  --- ignored.
  ---
  --- Example:
  --->lua
  ---     ignore = {
  ---       "rust_analyzer",  -- Ignore all messages from rust-analyzer client
  ---       function(msg)     -- Ignore messages containing "ing"
  ---         return string.find(msg.title, "ing") ~= nil
  ---       end,
  ---     }
  ---<
  ---
  ---@type (string|fun(msg: ProgressMessage): any)[]
  ignore = {},

  --- Configuration for progress modules (e.g., LSP integration)
  ---
  --- Set `modules.lsp = nil` to disable LSP progress tracking.
  ---
  ---@type { lsp?: table|nil }
  modules = {
    lsp = nil, -- Lazy-loaded when enabled
  },

  display = progress.display,
}
---@options ]]

progress.client_ids = {}

require("juu.options").declare(progress, "progress", progress.options, function()
  -- Ensure setup() reentrancy
  for _, autocmd in pairs(autocmds) do
    vim.api.nvim_del_autocmd(autocmd)
  end
  autocmds = {}

  -- Set up modules if enabled
  -- Process default modules (enable by default if not explicitly set)
  for _, module_name in ipairs(default_modules) do
    local module_opts = progress.options.modules[module_name]
    if module_opts == nil then
      -- Not explicitly set, enable by default
      module_opts = {}
      progress.options.modules[module_name] = module_opts
    end

    if module_opts ~= false then
      -- Module is enabled
      local module = get_module(module_name)
      if module then
        if module_opts == module then
          -- It's the module itself, use its current options
          module.setup(module.options)
        elseif type(module_opts) == "table" and next(module_opts) == nil then
          -- Empty table means use default options
          module.setup(module.options)
        else
          -- It's a table of options
          module.setup(module_opts)
        end
        -- Set up module-specific progress tracking if the method exists
        if module.setup_progress_tracking then
          module.setup_progress_tracking(progress.options.poll_rate, progress.poller)
        end
      end
    elseif progress[module_name] ~= nil then
      -- Module was explicitly disabled, clean it up
      progress[module_name].setup(nil)
    end
  end

  -- Also handle any other modules that might be configured
  for module_name, module_opts in pairs(progress.options.modules) do
    -- Skip if we already processed it above
    local is_default = false
    for _, default_name in ipairs(default_modules) do
      if module_name == default_name then
        is_default = true
        break
      end
    end
    if not is_default and module_opts ~= nil and module_opts ~= false then
      local module = get_module(module_name)
      if module then
        if module_opts == module then
          module.setup(module.options)
        else
          module.setup(module_opts)
        end
        if module.setup_progress_tracking then
          module.setup_progress_tracking(progress.options.poll_rate, progress.poller)
        end
      end
    end
  end
end)

--- Whether progress message updates are suppressed.
local progress_suppressed = false

--- Cache of generated LSP notification group configs.
---
---@type { [Key]: Config }
local loaded_configs = {}

--- Lazily load the notification configuration for some progress message.
---
---@protected
---@param msg ProgressMessage
function progress.load_config(msg)
  local group = progress.options.notification_group(msg)
  if loaded_configs[group] then
    return
  end

  local config = progress.display.make_config(group)

  notification.set_config(group, config, false)
end

--- Format a progress message for vim.notify().
---
---@protected
---@param msg ProgressMessage
---@return string|nil message
---@return number     level
---@return Options    opts
function progress.format_progress(msg)
  local group = progress.options.notification_group(msg)
  local message = progress.options.display.format_message(msg)
  local annote = progress.options.display.format_annote(msg)

  local update_only = false
  if progress.options.ignore_done_already and msg.done then
    update_only = true
  elseif progress.options.ignore_empty_message and msg.message == nil then
    update_only = true
  elseif progress.options.suppress_on_insert and string.find(vim.fn.mode(), "i") then
    update_only = true
  end

  return message,
    vim.log.levels.INFO,
    {
      key = msg.token,
      group = group,
      annote = annote,
      update_only = update_only,
      ttl = msg.done and 0 or progress.display.options.progress_ttl, -- Use config default when done
      data = msg.done, -- use data to convey whether this task is done
    }
end

--- Poll for progress messages to feed to the juu notifications subsystem.
---@private
progress.poller = poll.Poller({
  name = "progress",
  poll = function()
    if progress_suppressed then
      return false
    end

    -- Poll all enabled modules for messages
    local all_messages = {}
    for module_name, module_opts in pairs(progress.options.modules) do
      if module_opts ~= nil and module_opts ~= false then
        local module = get_module(module_name)
        if module and module.poll_for_messages then
          local messages = module.poll_for_messages()
          for _, msg in ipairs(messages) do
            table.insert(all_messages, msg)
          end
        end
      end
    end

    if #all_messages == 0 then
      return false
    end

    local messages = all_messages
    if #messages == 0 then
      logger.info("No progress messages (that can be displayed)")
      return false
    end

    for _, msg in ipairs(messages) do
      -- Determine if we should ignore this message
      local ignore = false
      for _, filter in ipairs(progress.options.ignore) do
        if type(filter) == "string" then
          if msg.client.name == filter then
            ignore = true
            logger.info("Ignoring progress message by name from", filter, ":", msg)
            break
          end
        elseif type(filter) == "function" then
          if filter(msg) then
            ignore = true
            logger.info("Filtering out progress message", ":", msg)
            break
          end
        else
          logger.error("Unsupported filter type:", type(filter))
        end
      end
      if not ignore then
        logger.info("Notifying progress message from", msg.client.name, ":", msg.title, " | ", msg.message)
        progress.load_config(msg)
        notification.notify(progress.format_progress(msg))
      end
    end
    return true
  end,
})

--- Poll for progress messages once.
---
--- Potentially useful if you're planning on "driving" Juu yourself.
function progress.poll()
  progress.poller:poll_once()
end

--- Suppress consumption of progress messages.
---
--- Pass `false` as argument to turn off suppression.
---
--- If no argument is given, suppression state is toggled.
---@param suppress boolean|nil Whether to suppress or toggle suppression
function progress.suppress(suppress)
  if suppress == nil then
    progress_suppressed = not progress_suppressed
  else
    progress_suppressed = suppress
  end
end

--- Register a detach handler for a module.
---
--- When a client/module detaches, all registered handlers will be called with
--- the identifier provided to `on_detach`.
---
---@param name string Unique name for this handler (e.g., "lsp")
---@param handler fun(identifier: any): any Function to call when a client detaches
function progress.register_detach_handler(name, handler)
  detach_handlers[name] = handler
end

--- Unregister a detach handler.
---
---@param name string Name of the handler to remove
function progress.unregister_detach_handler(name)
  detach_handlers[name] = nil
end

--- Called when a client/module detaches.
---
--- This function calls all registered detach handlers with the provided identifier.
--- Modules should register their handlers using `register_detach_handler`.
---
---@param identifier any Identifier for the detaching client/module (e.g., client_id, client_name, etc.)
function progress.on_detach(identifier)
  for name, handler in pairs(detach_handlers) do
    local ok, err = pcall(handler, identifier)
    if not ok then
      logger.error("Error in detach handler '", name, "':", err)
    end
  end
end

return progress
