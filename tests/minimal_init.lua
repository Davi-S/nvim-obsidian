local function append_rtp(path)
    if vim.fn.isdirectory(path) == 1 then
        vim.opt.rtp:append(path)
    end
end

local cwd = vim.fn.getcwd()
append_rtp(cwd)
append_rtp("/home/davi/.local/share/nvim/lazy/plenary.nvim")
append_rtp("/home/davi/.local/share/nvim/lazy/telescope.nvim")
append_rtp("/home/davi/.local/share/nvim/lazy/nvim-cmp")
append_rtp("/home/davi/.local/share/nvim/lazy/nvim-treesitter")

vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
