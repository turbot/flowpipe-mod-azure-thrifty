mod "azure_thrifty" {
  title         = "Azure Thrifty"
  description   = "Run pipelines to detect and correct Azure resources that are unused and underutilized."
  color         = "#0089D6"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/azure-thrifty.svg"
  categories    = ["azure", "cost", "public cloud", "standard", "thrifty"]

  opengraph {
    title       = "Azure Thrifty Mod for Flowpipe"
    description = "Run pipelines to detect and correct Azure resources that are unused and underutilized."
    image       = "/images/mods/turbot/azure-thrifty-social-graphic.png"
  }

  require {
    flowpipe {
      min_version = "1.0.0"
    }
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "^1"
    }
    mod "github.com/turbot/flowpipe-mod-azure" {
      version = "^1"
    }
  }
}
