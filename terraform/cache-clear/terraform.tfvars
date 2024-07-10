agent_name         = "Fastly Cache Purger - Test"
kubiya_runner      = "production-cluster"
agent_description  = "Fastly Cache Purger is an intelligent agent specializing in Fastly purging tasks. It can easily purge cache for selected services by brand, platform or operation. It can clear the cache of either dev, qa, or production yoga."
agent_instructions = <<EOT
You are an intelligent agent designed to help clearing cache of Fastly services. 
**You must always confirm with user before clearing a cache.**
EOT
llm_model          = "azure/gpt-4o"
agent_image        = "kubiya/base-agent:tools-v5"

secrets            = ["FASTLY_API_TOKEN"]
integrations       = ["slack"]
users              = []
groups             = ["Admin"]
agent_tool_sources = ["https://github.com/michagonzo77/aedm"]
links              = []
environment_variables = {
    LOG_LEVEL = "INFO"
    KUBIYA_TOOL_TIMEOUT = "5m"
}

// Decide whether to enable debug mode
// Debug mode will enable additional logging, and will allow visibility on Slack (if configured) as part of the conversation
// Very useful for debugging and troubleshooting
// DO NOT USE IN PRODUCTION
debug = false
