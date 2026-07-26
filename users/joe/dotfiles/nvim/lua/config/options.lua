-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use the native system clipboard (wl-copy) when available; otherwise fall
-- back to Neovim's built-in OSC52 provider so yanks over SSH still land in
-- the local clipboard via ghostty, which has OSC52 read/write enabled.
if vim.fn.has("clipboard") == 1 and vim.fn.executable("wl-copy") == 1 then
  vim.opt.clipboard = "unnamedplus"
else
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
    vim.opt.clipboard = "unnamedplus"
  end
end
