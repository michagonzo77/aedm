agent_name         = "Create Pagerduty Incident"
kubiya_runner      = "production-cluster"
agent_description  = "Create Pagerduty Incident is an intelligent agent specializing in creating Pagerduty Sev 1 incidents. It creates a Teams bridge link, Freshservice ticket, and Pagerduty incident, then sends the Sev 1 information to a Slack channel."
agent_instructions = <<EOT
You are an intelligent agent designed to help creating Pagerduty Sev 1 incidents.
EOT
llm_model          = "azure/gpt-4o"
agent_image        = "kubiya/base-agent:tools-v4"

secrets            = ["FASTLY_API_TOKEN"]
integrations       = ["slack"]
users              = []
groups             = ["Admin"]
agent_tool_sources = ["https://github.com/michagonzo77/aedm"]
links              = []
environment_variables = {}

// Decide whether to enable debug mode
// Debug mode will enable additional logging, and will allow visibility on Slack (if configured) as part of the conversation
// Very useful for debugging and troubleshooting
// DO NOT USE IN PRODUCTION
debug = false
