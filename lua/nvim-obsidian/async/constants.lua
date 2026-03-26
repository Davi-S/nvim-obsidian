-- Async operation timing constants
local M = {}

-- Omni picker: throttle query input changes to avoid excessive vault scans
M.OMNI_QUERY_THROTTLE_MS = 60

-- Scanner: debounce filesystem watcher events into a single full rebuild
M.RECONCILE_DEBOUNCE_MS = 200

-- Scanner: delay before restarting filesystem watchers after batch of events
M.WATCHER_RESTART_DELAY_MS = 350

-- Scanner: number of markdown files to process per async chunk during warmup/reindex
M.SCANNER_BATCH_SIZE = 40

-- Scanner: delay between chunks to keep Neovim responsive
M.SCANNER_BATCH_DELAY_MS = 1

return M
