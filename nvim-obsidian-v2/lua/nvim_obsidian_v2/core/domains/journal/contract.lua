local M = {
    name = "journal",
    version = "phase3-contract",
    deterministic = true,
    side_effects = "none",
    api = {
        classify_input = {
            input = {
                raw = "string",
                now = "date_time",
            },
            output = {
                kind = "daily|weekly|monthly|yearly|none",
            },
        },
        build_title = {
            input = {
                kind = "daily|weekly|monthly|yearly",
                date = "date_time",
                locale = "string",
            },
            output = {
                title = "string",
            },
        },
        compute_adjacent = {
            input = {
                kind = "daily|weekly|monthly|yearly",
                date = "date_time",
                direction = "next|prev|current",
            },
            output = {
                target_date = "date_time",
            },
        },
    },
}

return M
