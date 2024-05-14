mod "azure_thrifty" {
  title         = "Azure Thrifty"
  description   = "Run pipelines to detect and correct Azure resources that are unused and underutilized."
  color         = "#0089D6"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/azure-thrifty.svg"
  categories    = ["azure", "cost", "thrifty", "public cloud"]

  opengraph {
    title       = "Azure Thrifty Mod for Flowpipe"
    description = "Run pipelines to detect and correct Azure resources that are unused and underutilized."
    image       = "/images/mods/turbot/azure-thrifty-social-graphic.png"
  }

  require {
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "*"
    }
    mod "github.com/turbot/flowpipe-mod-azure" {
      version = "*"
    }
  }
}