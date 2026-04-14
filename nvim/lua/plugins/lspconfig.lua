return {
  require("lspconfig").yamlls.setup({
    settings = {
      yaml = {
        editor = {
          maxLineLength = -1,
        },
      },
    },
  }),
  require("lspconfig")["azure_pipelines_ls"].setup({
    settings = {
      yaml = {
        schemas = {
          ["https://raw.githubusercontent.com/microsoft/azure-pipelines-vscode/master/service-schema.json"] = {
            "/azure-pipeline*.y*l",
            "/*.azure*",
            "Azure-Pipelines/**/*.y*l",
            "Pipelines/*.y*l",
            "*.pipelines.yml",
            "pipelines/*.pipelines.yml",
          },
        },
      },
    },
  }),
  require("lspconfig").jsonls.setup({
    settings = {
      json = {
        format = {
          enable = true,
          trailingCommas = false,
        },
        validate = {
          enable = true,
        },
      },
    },
  }),
}
