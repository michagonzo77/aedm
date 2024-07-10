agent_name         = "Fastly Realtime - TEST"
kubiya_runner      = "dev-eks-sandbox"
agent_description  = "Fastly Realtime is an intelligent agent that helps you fetch only realtime stats for a specific Fastly service efficiently."
agent_instructions = <<EOT
You are an intelligent agent designed to retrieve realtime stats of Fastly services.
EOT
llm_model          = "azure/gpt-4o"
agent_image        = "kubiya/base-agent:tools-v5"

secrets            = ["FASTLY_API_TOKEN"]
integrations       = ["slack"]
users              = []
groups             = ["Admin"]
agent_tool_sources = ["https://github.com/michagonzo77/aedm"]
links              = []
log_level = "INFO"
environment_variables = {}
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

// Decide whether to enable debug mode
// Debug mode will enable additional logging, and will allow visibility on Slack (if configured) as part of the conversation
// Very useful for debugging and troubleshooting
// DO NOT USE IN PRODUCTION
debug = true
