return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "isort", "black" },
        go = { "gofumpt" },
        rust = { "rustfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        markdown = { "prettier" },
        yaml = { "prettier" },
        json = { "prettier" },
        css = { "prettier" },
        nix = { "nixfmt" },
      },
    },
  },
}