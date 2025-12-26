-- Test script to simulate progress notifications
-- Usage: :lua require("juu.demos.progress.loading").simulate()

local M = {}
local NotifierModule = require("juu.notify")
local ProgressModule = require("juu.progress")

--- Simulate a progress notification that updates over time
---@param duration number Duration in seconds (default: 5)
---@param title string|nil Title of the progress (default: "Demo-Downlader")
function M.simulate(duration, title)
  duration = duration or 5
  title = title or "Demo-Downloader"

  -- Create a progress handle
  local handle = ProgressModule.handle.create({
    title = title,
    message = "Starting...",
    client = { name = title },
    percentage = 0,
    cancellable = true,
  })

  local start_time = vim.loop.now()
  local interval_ms = 100 -- Update every 100ms
  local total_steps = math.floor((duration * 1000) / interval_ms)
  local current_step = 0

  -- Update progress periodically
  local timer = vim.loop.new_timer()
  timer:start(0, interval_ms, function()
    current_step = current_step + 1
    local elapsed = (vim.loop.now() - start_time) / 1000
    local percentage = math.min(100, math.floor((current_step / total_steps) * 100))

    -- Update the progress message
    handle:report({
      message = string.format("Downloading... (%d%%) - %.1fs elapsed", percentage, elapsed),
      percentage = percentage,
    })

    -- Finish when done
    if current_step >= total_steps then
      timer:stop()
      timer:close()
      handle:finish()
      NotifierModule.notify("Download completed!", vim.log.levels.INFO, { title = title })
    end
  end)

  return handle, timer
end

--- Simulate multiple progress notifications at once
---@param count number Number of progress tasks to simulate (default: 3)
function M.simulate_multiple(count)
  count = count or 3

  local handles = {}
  local timers = {}

  for i = 1, count do
    local duration = 3 + (i * 2) -- Different durations for each task
    local handle, timer = M.simulate(duration, string.format("Task %d", i))
    table.insert(handles, handle)
    table.insert(timers, timer)
  end

  return handles, timers
end

return M
