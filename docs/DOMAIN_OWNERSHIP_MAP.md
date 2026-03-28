# Domain Ownership Map

Version: 1.1
Status: Phase 0 Specification (Revised)
Date: March 28, 2026

This document maps each feature to an owning domain/service/adapter.
Ownership is exclusive at the rule level.
Document role: Canonical source for responsibility ownership only.
Policy authority: Product rules are canonical in docs/PRODUCT_CONTRACT.md.

---

## Vault Management

| Feature                            | Owner                             | Notes                                       |
| ---------------------------------- | --------------------------------- | ------------------------------------------- |
| Startup vault scan                 | Sync Service + Filesystem Adapter | Orchestrated scan; adapter performs IO      |
| Watch event handling               | Sync Service + Filesystem Adapter | Create/modify/delete/rename flow            |
| Manual full reindex command        | Sync Service + Neovim Adapter     | No periodic reconcile loop                  |
| Path/title/alias index maintenance | Vault Catalog                     | Core index consistency rules                |
| Canonical identity case policy     | Vault Catalog                     | Identity case-sensitive                     |
| Search fallback case policy        | Search Ranking + Vault Catalog    | Matching case-insensitive                   |
| Frontmatter parsing robustness     | Parser Adapter                    | Supports inline/multiline/quoted YAML lists |

---

## Journal

| Feature                            | Owner                                   | Notes                                |
| ---------------------------------- | --------------------------------------- | ------------------------------------ |
| Date classification                | Journal Domain                          | daily/weekly/monthly/yearly          |
| Title generation from placeholders | Journal Domain                          | Uses registered journal placeholders |
| Journal directory routing          | Journal Domain + App Config             | One subdir per note type             |
| Time travel calc (next/prev/today) | Journal Domain                          | Pure date logic                      |
| Open/create journal notes          | Note Lifecycle Service + Neovim Adapter | Command workflow                     |

---

## Wiki Link

| Feature                    | Owner                            | Notes                                                           |
| -------------------------- | -------------------------------- | --------------------------------------------------------------- |
| Wikilink parsing           | Wiki Link Domain                 | [[Title]], anchors, block IDs                                   |
| Link resolution            | Wiki Link Domain + Vault Catalog | Uses target token only (left side), case-sensitive              |
| Display alias handling     | Wiki Link Domain                 | [[target \| alias]] alias is non-resolving display text         |
| Ambiguity detection        | Wiki Link Domain                 | Multiple canonical matches for same case-sensitive target token |
| Follow command dispatch    | Neovim Adapter                   | Cursor extraction and jump/open                                 |
| Missing note on valid link | Note Lifecycle Service           | Create and open target note                                     |
| Missing heading/block      | Neovim Adapter + Parser Adapter  | Open note and warn                                              |
| Invalid text at cursor     | Neovim Adapter                   | No-op                                                           |

---

## Backlinks

| Feature            | Owner                            | Notes                            |
| ------------------ | -------------------------------- | -------------------------------- |
| Backlink discovery | Wiki Link Domain + Vault Catalog | Match current title OR any alias |
| Backlink picker UI | Neovim Adapter                   | Telescope presentation           |

---

## Omni and Search

| Feature                       | Owner                                   | Notes                                                            |
| ----------------------------- | --------------------------------------- | ---------------------------------------------------------------- |
| Omni ranking                  | Search Ranking Domain                   | Fuzzy matching on ordered corpus: title, aliases, relpath        |
| Omni create flow              | Note Lifecycle Service                  | Create from partial/no match via explicit create action          |
| Omni force-create keybinding  | Neovim Adapter + Note Lifecycle Service | Allowed in partial/no-match state                                |
| Omni full-match handling      | Neovim Adapter                          | Full match opens existing note; no create action                 |
| Omni create routing           | Journal Domain + Note Lifecycle Service | Journal classifier first, else standard new_notes_subdir         |
| Omni display policy           | Neovim Adapter + Search Ranking Domain  | title->relpath default, matched_alias->relpath on alias-only hit |
| Omni display separator config | App Config + Neovim Adapter             | Configurable separator token (default ->)                        |
| Omni picker behavior          | Neovim Adapter                          | Preserve Telescope default open actions                          |
| Vault text search             | Neovim Adapter                          | :ObsidianSearch live-grep style                                  |

---

## Templates

| Feature                    | Owner                                   | Notes                         |
| -------------------------- | --------------------------------------- | ----------------------------- |
| Placeholder registration   | Template Domain                         | User-registered only          |
| Template render            | Template Domain                         | No built-in placeholder set   |
| Insert template command    | Neovim Adapter + Note Lifecycle Service | :ObsidianInsertTemplate [type | path] |
| Optional picker bypass arg | Neovim Adapter                          | Arg path/type bypasses picker |
| Template inheritance       | Not supported                           | Explicitly out of scope       |

---

## Dataview

| Feature                              | Owner                | Notes                                        |
| ------------------------------------ | -------------------- | -------------------------------------------- |
| Query parsing/execution              | Dataview Domain      | TASK/TABLE                                   |
| Render trigger orchestration         | Query Render Service | on_open/on_save/on_buf_enter configurable    |
| Render placement and buffer mutation | Neovim Adapter       | Marked insertion                             |
| Render config surface                | App Config           | placement/scope/patterns/messages/highlights |

---

## Completion

| Feature                 | Owner                                             | Notes                                         |
| ----------------------- | ------------------------------------------------- | --------------------------------------------- |
| cmp source registration | Neovim Adapter                                    | nvim-cmp integration                          |
| Candidate supply        | Wiki Link Domain + Vault Catalog + Parser Adapter | titles, aliases, headings (#), block IDs (#^) |
| Insert behavior         | Neovim Adapter                                    | Correct wikilink output                       |

---

## Command Set Ownership

| Command                              | Owner                                                    |
| ------------------------------------ | -------------------------------------------------------- |
| :ObsidianOmni                        | Neovim Adapter + Search Ranking + Note Lifecycle Service |
| :ObsidianToday                       | Neovim Adapter + Journal + Note Lifecycle Service        |
| :ObsidianNext                        | Neovim Adapter + Journal + Note Lifecycle Service        |
| :ObsidianPrev                        | Neovim Adapter + Journal + Note Lifecycle Service        |
| :ObsidianFollow                      | Neovim Adapter + Wiki Link + Note Lifecycle Service      |
| :ObsidianBacklinks                   | Neovim Adapter + Wiki Link                               |
| :ObsidianSearch                      | Neovim Adapter                                           |
| :ObsidianReindex                     | Neovim Adapter + Sync Service                            |
| :ObsidianInsertTemplate [type\|path] | Neovim Adapter + Template + Note Lifecycle Service       |
| :ObsidianRenderDataview              | Neovim Adapter + Query Render Service                    |

Command scope authority:
- See docs/PRODUCT_CONTRACT.md for canonical in-scope vs out-of-primary-workflow command policy.

---

## Contract Checks

- [ ] No periodic reconcile ownership exists in V2.0 baseline.
- [ ] Journal layout requires per-type directories.
- [ ] No template inheritance responsibility exists.
- [ ] Omni creation path is explicit.
- [ ] Backlink matching uses title OR aliases.

---

Last Updated: March 28, 2026
