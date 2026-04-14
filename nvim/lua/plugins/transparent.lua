return {
  {
    "xiyaowong/transparent.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd("TransparentEnable") -- Enables transparency
      -- You can also specify components to clear
      require("transparent").clear_prefix("NeoTree")
    end,
  },
}
