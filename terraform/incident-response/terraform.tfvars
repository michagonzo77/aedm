agent_name         = "Incident Response - TEST"
kubiya_runner      = "dev-eks-sandbox"
agent_description  = "This agent is triggered by a pagerduty webhook and will create FreshService SEV 1 incidents."
agent_instructions = <<EOT
You are an intelligent agent targeted for incident response management.
EOT
llm_model          = "azure/gpt-4o"
agent_image        = "kubiya/base-agent:tools-v5"

secrets            = ["FSAPI_SANDBOX"]
integrations       = ["slack"]
users              = []
groups             = ["Admin", "Users"]
agent_tool_sources = ["https://github.com/michagonzo77/aedm"]
links              = []
environment_variables = {}

// Decide whether to enable debug mode
// Debug mode will enable additional logging, and will allow visibility on Slack (if configured) as part of the conversation
// Very useful for debugging and troubleshooting
// DO NOT USE IN PRODUCTION
debug = false
