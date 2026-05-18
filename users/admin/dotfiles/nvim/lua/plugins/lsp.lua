return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {},
        gopls = {},
        rust_analyzer = {},
        clangd = {},
        marksman = {},
        yamlls = {},
        jsonls = {},
        lemminx = {},
        nixd = {},
        cssls = {},
      },
    },
  },
}