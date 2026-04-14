local conform = require("conform")

conform.formatters.prettier = {
  condition = function(ctx)
    local filename = ctx.filename
    local exclude_patterns = {
      "azure%-pipeline%.yml$",
      ".*%.pipelines%.yml$",
      ".*/pipelines/.*%.pipelines%.yml$",
    }
    for _, pattern in ipairs(exclude_patterns) do
      if filename:match(pattern) then
        return false
      end
    end
    return true
  end,
}
