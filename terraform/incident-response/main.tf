terraform {
  required_providers {
    kubiya = {
      source = "kubiya-terraform/kubiya"
    }
  }
}

provider "kubiya" {
  // Your Kubiya API Key will be taken from the
  // environment variable KUBIYA_API_KEY
  // To set the key, please use export KUBIYA_API_KEY="YOUR_API_KEY"
}

resource "kubiya_agent" "agent" {
  // Mandatory Fields
  name         = "Fastly Cache Purger" // String
  runner       = "production-cluster"     // String
  description  = <<EOT
Fastly Cache Purger is an intelligent agent specializing in Fastly purging tasks. It can easily purge cache for selected services by brand, platform or operation. It can clear the cache of either dev, qa, or production yoga.
EOT
  instructions = <<EOT
You are an intelligent agent designed to help clearing cache of Fastly services. You must always confirm with user before clearing a cache.
EOT
  // Optional fields, String
  model = "azure/gpt-4o" // If not provided, Defaults to "azure/gpt-4"
  // If not provided, Defaults to "ghcr.io/kubiyabot/kubiya-agent:stable"
  image = "kubiya/base-agent:tools-v2"

  // Optional Fields:
  // Arrays
  secrets      = ["FASTLY_API_TOKEN"]
  integrations = ["slack"]
  users        = []
  groups       = ["Admin"]
  links = []
  environment_variables = {
    DEBUG                        = "1"
    LOG_LEVEL                    = "INFO"
    KUBIYA_TOOL_CONFIG_URLS      = "https://gist.githubusercontent.com/michagonzo77/0d432d4b668f6c6acb8708de3bb015d1/raw/a3c35dee12f4fc52b2073b7c13df47eed2ebd8f0/cache-clear.yaml"
    TOOLS_MANAGER_URL            = "http://localhost:3001"
    TOOLS_SERVER_URL             = "http://localhost:3001"
    TOOL_MANAGER_LOG_FILE        = "/tmp/tool-manager.log"
    TOOL_SERVER_URL              = "http://localhost:3001"
  }
}

output "agent" {
  value = kubiya_agent.agent
}
