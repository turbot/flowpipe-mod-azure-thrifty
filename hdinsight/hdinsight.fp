locals {
  hdinsight_common_tags = merge(local.azure_thrifty_common_tags, {
    service = "Azure/HDInsight"
  })
}
