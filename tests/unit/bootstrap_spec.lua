---@diagnostic disable: undefined-global

describe("app bootstrap", function()
    local saved_container
    local saved_dependencies
    local saved_bootstrap
    local saved_schedule

    before_each(function()
        saved_container = package.loaded["nvim_obsidian.app.container"]
        saved_dependencies = package.loaded["nvim_obsidian.app.dependencies"]
        saved_bootstrap = package.loaded["nvim_obsidian.app.bootstrap"]
        saved_schedule = vim.schedule
    end)

    after_each(function()
        package.loaded["nvim_obsidian.app.container"] = saved_container
        package.loaded["nvim_obsidian.app.dependencies"] = saved_dependencies
        package.loaded["nvim_obsidian.app.bootstrap"] = saved_bootstrap
        vim.schedule = saved_schedule
    end)

    it("returns before startup reindex executes by scheduling it", function()
        local verify_calls = 0
        local register_calls = 0
        local reindex_calls = 0
        local ready_notifications = 0
        local scheduled = nil

        package.loaded["nvim_obsidian.app.dependencies"] = {
            verify_required_dependencies = function()
                verify_calls = verify_calls + 1
            end,
        }

        local container = {
            adapters = {
                commands = {
                    register = function()
                        register_calls = register_calls + 1
                    end,
                },
            },
            use_cases = {
                reindex_sync = {
                    execute = function(_, payload)
                        reindex_calls = reindex_calls + 1
                        assert.same({ mode = "startup" }, payload)
                        return { ok = true }
                    end,
                },
            },
            notifications = {
                info = function(msg)
                    if msg == "nvim-obsidian: vault cache ready" then
                        ready_notifications = ready_notifications + 1
                    end
                end,
                error = function() end,
            },
        }

        package.loaded["nvim_obsidian.app.container"] = {
            build = function()
                return container
            end,
        }

        vim.schedule = function(fn)
            scheduled = fn
        end

        package.loaded["nvim_obsidian.app.bootstrap"] = nil
        local bootstrap = require("nvim_obsidian.app.bootstrap")
        local out = bootstrap.start({ vault_root = "/tmp/nvim_obsidian_bootstrap_vault" })

        assert.equals(container, out)
        assert.equals(1, verify_calls)
        assert.equals(1, register_calls)
        assert.equals(0, reindex_calls)
        assert.is_function(scheduled)

        scheduled()

        assert.equals(1, reindex_calls)
        assert.equals(1, ready_notifications)
    end)

    it("notifies error when scheduled startup reindex fails", function()
        local error_message = nil
        local scheduled = nil

        package.loaded["nvim_obsidian.app.dependencies"] = {
            verify_required_dependencies = function() end,
        }

        package.loaded["nvim_obsidian.app.container"] = {
            build = function()
                return {
                    adapters = {
                        commands = {
                            register = function() end,
                        },
                    },
                    use_cases = {
                        reindex_sync = {
                            execute = function()
                                return {
                                    ok = false,
                                    error = { message = "failed to replace vault catalog" },
                                }
                            end,
                        },
                    },
                    notifications = {
                        info = function() end,
                        error = function(msg)
                            error_message = msg
                        end,
                    },
                }
            end,
        }

        vim.schedule = function(fn)
            scheduled = fn
        end

        package.loaded["nvim_obsidian.app.bootstrap"] = nil
        local bootstrap = require("nvim_obsidian.app.bootstrap")
        bootstrap.start({ vault_root = "/tmp/nvim_obsidian_bootstrap_vault" })

        assert.is_function(scheduled)
        scheduled()

        assert.equals("nvim-obsidian: failed to replace vault catalog", error_message)
    end)
end)
