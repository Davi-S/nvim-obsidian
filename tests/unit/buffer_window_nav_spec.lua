---@diagnostic disable: undefined-global

local buffer_window_nav = require("nvim_obsidian.adapters.nav.buffer_window_nav")

describe("buffer/window navigation adapter", function()
    local function base_ctx(overrides)
        local ctx = {
            vim = {
                api = {
                    nvim_get_current_buf = function()
                        return 1
                    end,
                    nvim_get_current_win = function()
                        return 1000
                    end,
                    nvim_win_get_buf = function(win_id)
                        if not win_id then return nil end
                        return 1
                    end,
                    nvim_buf_get_name = function(buf_id)
                        if buf_id == 1 then return "/vault/notes/foo.md" end
                        if buf_id == 2 then return "/vault/notes/bar.md" end
                        return ""
                    end,
                    nvim_buf_get_lines = function(buf_id, start, end_, strict)
                        if buf_id == 1 then
                            return {
                                "# Foo",
                                "Some content",
                                "More content",
                            }
                        end
                        return {}
                    end,
                    nvim_win_get_cursor = function(win_id)
                        return { 1, 0 }
                    end,
                    nvim_win_set_cursor = function(win_id, pos)
                        -- Mock success
                    end,
                    nvim_set_current_buf = function(buf_id)
                        -- Mock success
                    end,
                    nvim_set_current_win = function(win_id)
                        -- Mock success
                    end,
                    nvim_open_win = function(buf_id, enter, config)
                        return 1001
                    end,
                    nvim_win_close = function(win_id, force)
                        -- Mock success
                    end,
                    nvim_create_buf = function(listed, scratch)
                        return 2
                    end,
                    nvim_buf_set_lines = function(buf_id, start, end_, strict, lines)
                        -- Mock success
                    end,
                    nvim_command = function(cmd)
                        -- Mock success
                    end,
                },
                fn = {
                    bufloaded = function(buf_ref)
                        return 1
                    end,
                    buflisted = function(buf_ref)
                        return 1
                    end,
                    bufwinnr = function(buf_ref)
                        return 1000
                    end,
                    expand = function(word)
                        return "/vault/notes/foo.md"
                    end,
                },
            },
        }

        if type(overrides) == "table" then
            for key, value in pairs(overrides) do
                if type(ctx[key]) == "table" and type(value) == "table" then
                    for subkey, subvalue in pairs(value) do
                        if type(ctx[key][subkey]) == "table" and type(subvalue) == "table" then
                            for subsubkey, subsubvalue in pairs(subvalue) do
                                ctx[key][subkey][subsubkey] = subsubvalue
                            end
                        else
                            ctx[key][subkey] = subvalue
                        end
                    end
                else
                    ctx[key] = value
                end
            end
        end

        return ctx
    end

    describe("adapter structure", function()
        it("should export create_navigator function", function()
            assert.is_function(buffer_window_nav.create_navigator)
        end)

        it("should export buffer functions", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.is_function(nav.get_current_buffer)
            assert.is_function(nav.open_file)
            assert.is_function(nav.list_buffers)
        end)

        it("should export window functions", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.is_function(nav.get_current_window)
            assert.is_function(nav.navigate_to_line)
            assert.is_function(nav.get_cursor_position)
        end)

        it("should export cursor functions", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.is_function(nav.set_cursor_position)
            assert.is_function(nav.jump_to_buffer)
        end)
    end)

    describe("create_navigator", function()
        it("should return navigator object", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.is_table(nav)
        end)

        it("should handle nil context gracefully", function()
            local nav = buffer_window_nav.create_navigator(nil)
            assert.is_table(nav)
        end)

        it("should store context reference", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.is_table(nav._ctx)
        end)
    end)

    describe("buffer operations", function()
        it("should get current buffer ID", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local buf = nav.get_current_buffer()
            assert.equals(1, buf)
        end)

        it("should handle missing vim.api gracefully", function()
            -- Create a completely fresh context without vim.api
            local ctx = {
                vim = {
                    fn = {},
                },
            }
            local nav = buffer_window_nav.create_navigator(ctx)
            local buf = nav.get_current_buffer()
            assert.is_nil(buf)
        end)

        it("should open file and return buffer ID", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local buf = nav.open_file("/vault/notes/test.md")
            assert.is_number(buf)
        end)

        it("should handle open_file with nil path", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.open_file(nil)
            end)
        end)

        it("should get buffer lines", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local lines = nav.get_buffer_lines(1)
            assert.is_table(lines)
            assert.equals(3, #lines)
        end)

        it("should get specific line range", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local lines = nav.get_buffer_lines(1, 1, 2)
            assert.is_table(lines)
        end)

        it("should list buffers", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local bufs = nav.list_buffers()
            assert.is_table(bufs)
        end)

        it("should return empty buffer list on error", function()
            local ctx = base_ctx({ vim = { fn = { buflisted = function() error("broken") end } } })
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.list_buffers()
            end)
        end)

        it("should get buffer name", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local name = nav.get_buffer_name(1)
            assert.equals("/vault/notes/foo.md", name)
        end)

        it("should set buffer text", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.set_buffer_text(1, 0, 0, "new text")
            end)
        end)
    end)

    describe("window operations", function()
        it("should get current window ID", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local win = nav.get_current_window()
            assert.equals(1000, win)
        end)

        it("should handle missing window API", function()
            -- Create context without vim.api
            local ctx = {
                vim = {
                    fn = {},
                },
            }
            local nav = buffer_window_nav.create_navigator(ctx)
            local win = nav.get_current_window()
            assert.is_nil(win)
        end)

        it("should navigate to line", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.navigate_to_line(1, 2)
            end)
        end)

        it("should handle navigate_to_line with invalid buffer", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.navigate_to_line(nil, 2)
            end)
        end)

        it("should navigate to position", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.navigate_to_position(1, 2, 5)
            end)
        end)

        it("should close window", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.close_window()
            end)
        end)

        it("should handle close_window errors gracefully", function()
            local close_called = false
            local ctx = base_ctx({
                vim = {
                    api = {
                        nvim_win_close = function()
                            close_called = true
                            error("window is invalid")
                        end,
                    },
                },
            })
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.close_window()
            end)
            assert.is_true(close_called)
        end)
    end)

    describe("cursor operations", function()
        it("should get cursor position", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local pos = nav.get_cursor_position()
            assert.is_table(pos)
            assert.equals(1, pos.line)
            assert.equals(0, pos.col)
        end)

        it("should set cursor position", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.set_cursor_position(5, 10)
            end)
        end)

        it("should set cursor position with defaults", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.set_cursor_position()
            end)
        end)

        it("should handle set_cursor_position errors gracefully", function()
            local ctx = base_ctx({
                vim = {
                    api = {
                        nvim_win_set_cursor = function()
                            error("invalid position")
                        end,
                    },
                },
            })
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.set_cursor_position(5, 10)
            end)
        end)

        it("should center cursor on screen", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.center_cursor_on_screen()
            end)
        end)
    end)

    describe("buffer navigation", function()
        it("should jump to buffer", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.jump_to_buffer(1)
            end)
        end)

        it("should handle nil buffer in jump_to_buffer", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.jump_to_buffer(nil)
            end)
        end)

        it("should switch to window showing buffer", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.switch_to_buffer_window(1)
            end)
        end)

        it("should get buffer for window", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local buf = nav.get_window_buffer(1000)
            assert.equals(1, buf)
        end)

        it("should handle get_window_buffer with invalid window", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local buf = nav.get_window_buffer(nil)
            assert.is_nil(buf)
        end)
    end)

    describe("split operations", function()
        it("should open split", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            local win = nav.open_split("vertical")
            assert.is_number(win)
        end)

        it("should open split with size", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.open_split("horizontal", 20)
            end)
        end)

        it("should handle split errors gracefully", function()
            local ctx = base_ctx({
                vim = {
                    api = {
                        nvim_open_win = function()
                            error("cannot open window")
                        end,
                    },
                },
            })
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.open_split("vertical")
            end)
        end)
    end)

    describe("error handling", function()
        it("should handle missing vim completely", function()
            local nav = buffer_window_nav.create_navigator({})
            assert.is_table(nav)
            assert.has_no.errors(function()
                nav.get_current_buffer()
            end)
        end)

        it("should handle API call errors gracefully", function()
            local ctx = base_ctx({
                vim = {
                    api = {
                        nvim_get_current_buf = function()
                            error("API error")
                        end,
                    },
                },
            })
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.get_current_buffer()
            end)
        end)

        it("should handle nested API errors", function()
            local ctx = base_ctx({
                vim = {
                    api = {
                        nvim_buf_get_lines = function()
                            error("cannot read buffer")
                        end,
                    },
                },
            })
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.get_buffer_lines(1)
            end)
        end)

        it("should return sensible defaults on error", function()
            local ctx = base_ctx({
                vim = {
                    api = {
                        nvim_get_current_buf = function()
                            error("error")
                        end,
                    },
                },
            })
            local nav = buffer_window_nav.create_navigator(ctx)
            local buf = nav.get_current_buffer()
            assert.is_nil(buf)
        end)
    end)

    describe("integration scenarios", function()
        it("should support opening file and navigating to line", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                local buf = nav.open_file("/vault/notes/test.md")
                if buf then
                    nav.navigate_to_line(buf, 5)
                end
            end)
        end)

        it("should support jumping to position within buffer", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                nav.jump_to_buffer(1)
                nav.set_cursor_position(3, 5)
            end)
        end)

        it("should support reading content at position", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                local lines = nav.get_buffer_lines(1, 1, 3)
                if lines and #lines > 0 then
                    nav.set_cursor_position(1, 0)
                end
            end)
        end)

        it("should support multi-window navigation", function()
            local ctx = base_ctx()
            local nav = buffer_window_nav.create_navigator(ctx)
            assert.has_no.errors(function()
                local buf = nav.get_current_buffer()
                local win = nav.open_split("vertical")
                if win then
                    nav.set_cursor_position(5, 10)
                    nav.close_window()
                end
            end)
        end)
    end)
end)
