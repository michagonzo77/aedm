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
  name         = "Fastly Realtime - TEST" // String
  runner       = "production-cluster"     // String
  description  = <<EOT
Fastly Realtime is an intelligent agent that helps you fetch only realtime stats for a specific Fastly service efficiently.
EOT
  instructions = <<EOT
You are an intelligent agent designed to retrieve realtime stats of Fastly services.
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
    KUBIYA_TOOL_TIMEOUT          = "60s"
    KUBIYA_TOOL_CONFIG_URLS      = "https://gist.githubusercontent.com/michagonzo77/16487f19ef8a7bfebd2ac9897ca56127/raw/a7cf76ed47ddfd53dfaa1b17f6f358aa8557359c/realtime-fastly.yaml"
    TOOLS_MANAGER_URL            = "http://localhost:3001"
    TOOLS_SERVER_URL             = "http://localhost:3001"
    TOOL_MANAGER_LOG_FILE        = "/tmp/tool-manager.log"
    TOOL_SERVER_URL              = "http://localhost:3001"
    KUBIYA_AGENT_STREAMING_DISABLED        = "1"
  }
    starters = [
    {
      name = "📈 RT Overview - Yoga Prod"
      command      = "Show me the real-time overview of the yoga service on production"
    },
    {
      name = "📈 RT Overview - Pulse Prod"
      command      = "Show me the real-time overview of the pulse service on production"
    },
        {
      name = "📈 RT Overview - Cplay Prod"
      command      = "Show me the real-time overview of the cplay service on production"
    },
    {
      name = "📈 RT Overview - Roku Prod"
      command      = "Show me the real-time overview of the roku service on production"
    },
    {
      name = "📈 RT Overview - Webcenter Prod"
      command      = "Show me the real-time overview of the webcenter service on production"
    }
  ]
}

output "agent" {
  value = kubiya_agent.agent
}
