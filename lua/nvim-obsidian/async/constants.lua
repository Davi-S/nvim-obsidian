-- Async operation timing constants
local M = {}

-- Omni picker: throttle query input changes to avoid excessive vault scans
M.OMNI_QUERY_THROTTLE_MS = 60

-- Scanner: debounce filesystem watcher events into a single full rebuild
M.RECONCILE_DEBOUNCE_MS = 200

-- Scanner: delay before restarting filesystem watchers after batch of events
M.WATCHER_RESTART_DELAY_MS = 350

return M
