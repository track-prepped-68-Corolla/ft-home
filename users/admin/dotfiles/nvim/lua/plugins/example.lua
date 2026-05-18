-- since this is just an example spec, don't actually load anything here and return an empty spec
return {
  -- Add your custom plugin specs here
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "flake8",
      },
    },
  },
}
