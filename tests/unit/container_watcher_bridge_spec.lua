---@diagnostic disable: undefined-global

local container_builder = require("nvim_obsidian.app.container")

describe("container watcher bridge", function()
    local vault_root
    local container

    local function write_file(path, content)
        local file = assert(io.open(path, "w"))
        file:write(content or "")
        file:close()
    end

    before_each(function()
        vault_root = "/tmp/nvim_obsidian_watcher_bridge_test"
        os.execute("rm -rf " .. vault_root)
        os.execute("mkdir -p " .. vault_root)

        container = container_builder.build({
            vault_root = vault_root,
        })

        if container.vault_catalog and type(container.vault_catalog._reset_for_tests) == "function" then
            container.vault_catalog._reset_for_tests()
        end
    end)

    after_each(function()
        if container and container.vault_catalog and type(container.vault_catalog._reset_for_tests) == "function" then
            container.vault_catalog._reset_for_tests()
        end
        os.execute("rm -rf " .. vault_root)
    end)

    it("upserts markdown note on create event", function()
        local note_path = vault_root .. "/watch-created.md"
        write_file(note_path, "# from watcher")

        container.on_fs_event({ kind = "create", path = note_path })

        local lookup = container.vault_catalog.find_by_identity_token("watch-created")
        assert.is_table(lookup)
        assert.equals(1, #lookup.matches)
        assert.equals(note_path, lookup.matches[1].path)
    end)

    it("removes indexed note on delete event", function()
        local note_path = vault_root .. "/watch-deleted.md"
        write_file(note_path, "# delete me")

        container.on_fs_event({ kind = "create", path = note_path })
        os.remove(note_path)
        container.on_fs_event({ kind = "delete", path = note_path })

        local lookup = container.vault_catalog.find_by_identity_token("watch-deleted")
        assert.is_table(lookup)
        assert.equals(0, #lookup.matches)
    end)

    it("ignores non-markdown watcher events", function()
        local txt_path = vault_root .. "/ignore.txt"
        write_file(txt_path, "hello")

        container.on_fs_event({ kind = "create", path = txt_path })

        local notes = container.vault_catalog.list_notes()
        assert.is_table(notes)
        assert.equals(0, #notes)
    end)

    it("triggers manual reindex on rescan event", function()
        local calls = {}
        local original_execute = container.reindex_sync.execute

        container.reindex_sync.execute = function(_ctx, input)
            table.insert(calls, input)
            return { ok = true, stats = { mode = input.mode } }
        end

        container.on_fs_event({ kind = "rescan", path = vault_root })

        container.reindex_sync.execute = original_execute

        assert.equals(1, #calls)
        assert.equals("manual", calls[1].mode)
    end)
end)
