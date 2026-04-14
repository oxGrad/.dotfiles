-- disabled
if true then
  return {}
end

return {
  "olimorris/codecompanion.nvim",
  version = "^18.0.0",
  opts = {
    adapters = {
      http = {},
      acp = {
        gemini_cli = function()
          return require("codecompanion.adapters").extend("gemini_cli", {
            defaults = {
              auth_method = "oauth-personal", -- "oauth-personal"|"gemini-api-key"|"vertex-ai"
            },
            env = {
              GEMINI_API_KEY = "cmd:op read op://personal/Gemini_API/credential --no-newline",
            },
          })
        end,
      },
    },
    interactions = {
      chat = {
        adapter = "ollama",
        model = "qwen2.5-coder-7b",
      },
      inline = {
        adapter = "ollama",
        model = "qwen2.5-coder-7b",
      },
      cmd = {
        adapter = "ollama",
        model = "qwen2.5-coder-7b",
      },
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
}
