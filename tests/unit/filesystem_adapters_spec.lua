---@diagnostic disable: undefined-global

local io_adapter = require("nvim_obsidian.adapters.filesystem.io")
local watcher = require("nvim_obsidian.adapters.filesystem.watcher")

describe("filesystem adapters", function()
    local original_vim
    local temp_root

    before_each(function()
        original_vim = _G.vim
        temp_root = "/tmp/nvim_obsidian_fs_adapter_test"
        os.execute("mkdir -p " .. temp_root)
    end)

    after_each(function()
        _G.vim = original_vim
        watcher.stop()
        os.execute("rm -rf " .. temp_root)
    end)

    describe("filesystem io adapter", function()
        it("should export read/write/list functions", function()
            assert.is_function(io_adapter.read_file)
            assert.is_function(io_adapter.write_file)
            assert.is_function(io_adapter.list_markdown_files)
        end)

        it("should read file contents", function()
            local path = temp_root .. "/note.md"
            local fh = assert(io.open(path, "w"))
            fh:write("hello\nworld")
            fh:close()

            local content, err = io_adapter.read_file(path)
            assert.is_nil(err)
            assert.equals("hello\nworld", content)
        end)

        it("should return error for missing file", function()
            local content, err = io_adapter.read_file(temp_root .. "/missing.md")
            assert.is_nil(content)
            assert.is_string(err)
        end)

        it("should write file contents and create parent directories", function()
            local path = temp_root .. "/nested/dir/new.md"
            local ok, err = io_adapter.write_file(path, "payload")
            assert.is_true(ok)
            assert.is_nil(err)

            local verify = assert(io.open(path, "r"))
            local text = verify:read("*a")
            verify:close()
            assert.equals("payload", text)
        end)

        it("should list markdown files recursively", function()
            os.execute("mkdir -p " .. temp_root .. "/a/b")
            local f1 = assert(io.open(temp_root .. "/root.md", "w"))
            f1:write("root")
            f1:close()
            local f2 = assert(io.open(temp_root .. "/a/b/nested.md", "w"))
            f2:write("nested")
            f2:close()
            local f3 = assert(io.open(temp_root .. "/a/b/skip.txt", "w"))
            f3:write("txt")
            f3:close()

            local files, err = io_adapter.list_markdown_files(temp_root)
            assert.is_nil(err)
            assert.is_table(files)
            assert.equals(2, #files)
        end)
    end)

    describe("filesystem watcher adapter", function()
        local function make_vim_loop(mocks)
            local handle = {
                _started = false,
                _closed = false,
                start = function(self, path, opts, cb)
                    if mocks.start_error then
                        return nil, "start-error"
                    end
                    self._started = true
                    self._path = path
                    self._opts = opts
                    self._cb = cb
                    return true
                end,
                stop = function(self)
                    self._started = false
                    return true
                end,
                close = function(self)
                    self._closed = true
                end,
            }

            return {
                loop = {
                    new_fs_event = function()
                        if mocks.new_error then
                            return nil
                        end
                        return handle
                    end,
                },
                _handle = handle,
            }
        end

        it("should export start and stop", function()
            assert.is_function(watcher.start)
            assert.is_function(watcher.stop)
        end)

        it("should start watcher with recursive mode", function()
            local vm = make_vim_loop({})
            _G.vim = { loop = vm.loop }

            local started, err = watcher.start({
                config = { vault_root = temp_root },
            })

            assert.is_true(started)
            assert.is_nil(err)
            assert.is_true(vm._handle._started)
            assert.equals(temp_root, vm._handle._path)
        end)

        it("should fail start when root is missing", function()
            _G.vim = { loop = make_vim_loop({}).loop }
            local started, err = watcher.start({ config = {} })

            assert.is_false(started)
            assert.is_string(err)
        end)

        it("should fail when fs event handle cannot be created", function()
            local vm = make_vim_loop({ new_error = true })
            _G.vim = { loop = vm.loop }

            local started, err = watcher.start({ config = { vault_root = temp_root } })
            assert.is_false(started)
            assert.is_string(err)
        end)

        it("should emit mapped events to callback", function()
            local vm = make_vim_loop({})
            _G.vim = { loop = vm.loop }
            local emitted = {}

            local started = watcher.start({
                config = { vault_root = temp_root },
                on_fs_event = function(event)
                    table.insert(emitted, event)
                end,
            })
            assert.is_true(started)

            vm._handle._cb(nil, "note.md", { rename = false, change = true })
            vm._handle._cb(nil, "renamed.md", { rename = true, change = false })

            assert.equals(2, #emitted)
            assert.equals("modify", emitted[1].kind)
            assert.equals("rename", emitted[2].kind)
        end)

        it("should stop and close active watcher", function()
            local vm = make_vim_loop({})
            _G.vim = { loop = vm.loop }
            watcher.start({ config = { vault_root = temp_root } })

            local stopped = watcher.stop()
            assert.is_true(stopped)
            assert.is_true(vm._handle._closed)
        end)
    end)
end)
