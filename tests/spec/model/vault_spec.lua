local vault = require("nvim-obsidian.model.vault")
local fixtures = require("tests.spec.support.fixtures")

describe("vault preferred match", function()
    before_each(function()
        vault.reset()
    end)

    it("prefers explicit vault-relative path when duplicates exist", function()
        local cfg = fixtures.standard_cfg("/tmp/vault")
        local matches = {
            { filepath = "/tmp/vault/sub/My Note.md" },
            { filepath = "/tmp/vault/My Note.md" },
        }

        local preferred = vault.preferred_match("sub/My Note", matches, cfg)
        assert.is_truthy(preferred)
        assert.are.equal("/tmp/vault/sub/My Note.md", preferred.filepath)
    end)

    it("falls back to vault-root filename preference", function()
        local cfg = fixtures.standard_cfg("/tmp/vault")
        local matches = {
            { filepath = "/tmp/vault/sub/Target.md" },
            { filepath = "/tmp/vault/Target.md" },
        }

        local preferred = vault.preferred_match("Target", matches, cfg)
        assert.is_truthy(preferred)
        assert.are.equal("/tmp/vault/Target.md", preferred.filepath)
    end)
end)
