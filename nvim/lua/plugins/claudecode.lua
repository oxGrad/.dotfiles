local claude_account = "personal" -- ponytail: module-level toggle, add a picker if a 3rd account shows up

local function toggle_claude(account, env)
  return function()
    if claude_account ~= account then
      require("claudecode.terminal").close()
      require("claudecode.terminal").setup(nil, nil, env)
      claude_account = account
    end
    require("claudecode.terminal").simple_toggle({})
  end
end

return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = true,
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", toggle_claude("personal", {}), desc = "Toggle Claude" },
    {
      "<leader>aw",
      toggle_claude("work", { CLAUDE_CONFIG_DIR = vim.fn.expand("~/.claude-work") }),
      desc = "Toggle Claude (work)",
    },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
    },
    -- Diff management
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  },
}
