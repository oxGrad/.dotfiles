return {
  {
    "oxGrad/knot.nvim",
    main = "knot", -- tells lazy.nvim to call require("knot").setup(opts)
    lazy = false, -- must load at startup so the devicon is registered before file trees render
    opts = {
      auto_configure_yamlls = true,
    },
  },
}
