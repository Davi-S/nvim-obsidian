local M = {}

function M.new()
    return {
        complete = function(_, _, callback)
            callback({ items = {}, isIncomplete = false })
        end,
    }
end

return M
