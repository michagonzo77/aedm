#!/usr/bin/env bash

# Function to create a service ticket
create_ticket() {
    local url="https://aenetworks-fs-sandbox.freshservice.com/api/v2/tickets"
    local description="$1"
    local servicename="$2"
    local title="$3"
    local incident_url="$4"
    local slackincidentcommander="$5"
    local slackdetectionmethod="$6"
    local slackbusinessimpact="$7"
    local incident_id="$8"
    local payload="{\"description\": \"$description</br><strong>Incident Commander:</strong>$slackincidentcommander</br><strong>Detection Method:</strong>$slackdetectionmethod</br><strong>Business Impact:</strong>$slackbusinessimpact</br><strong>Ticket Link:</strong>$incident_url\", \"subject\": \"TESTING $servicename - $title\", \"email\": \"devsecops@aenetworks.com\", \"priority\": 1, \"status\": 2, \"source\": 8, \"category\": \"DevOps\", \"sub_category\": \"Pageout\", \"tags\": [\"PDID_$incident_id\"]}"
    curl -u $FSAPI_SANDBOX:X -H "Content-Type: application/json" -X POST -d "$payload" -o response.json "$url"
}

# Function to extract ticket ID from response
extract_ticket_id() {
    local ticket_id=$(jq -r '.ticket.id' response.json)
    echo "$ticket_id"
}

# Function to send a message to Slack
send_slack_message() {
    local channel="$1"
    local message="$2"
    curl -X POST -H 'Content-type: application/json' --data "{\"channel\":\"$channel\",\"text\":\"$message\"}" "https://slack.com/api/chat.postMessage" -H "Authorization: Bearer $SLACK_API_TOKEN"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --description) description="$2"; shift ;;
        --servicename) servicename="$2"; shift ;;
        --title) title="$2"; shift ;;
        --incident_url) incident_url="$2"; shift ;;
        --slackincidentcommander) slackincidentcommander="$2"; shift ;;
        --slackdetectionmethod) slackdetectionmethod="$2"; shift ;;
        --slackbusinessimpact) slackbusinessimpact="$2"; shift ;;
        --incident_id) incident_id="$2"; shift ;;
        --bridge_url) bridge_url="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check for required arguments
if [ -z "${description}" ] || [ -z "${servicename}" ] || [ -z "${title}" ] || [ -z "${incident_url}" ] || [ -z "${slackincidentcommander}" ] || [ -z "${slackdetectionmethod}" ] || [ -z "${slackbusinessimpact}" ] || [ -z "${incident_id}" ] || [ -z "${bridge_url}" ]; then
    echo "Usage: $0 --description <description> --servicename <servicename> --title <title> --incident_url <incident_url> --slackincidentcommander <slackincidentcommander> --slackdetectionmethod <slackdetectionmethod> --slackbusinessimpact <slackbusinessimpact> --incident_id <incident_id> --bridge_url <bridge_url>"
    exit 1
fi

# Create service ticket
create_ticket "$description" "$servicename" "$title" "$incident_url" "$slackincidentcommander" "$slackdetectionmethod" "$slackbusinessimpact" "$incident_id"

# Extract ticket ID
TICKET_ID=$(extract_ticket_id)

# Export TICKET_ID as an environment variable
export TICKET_ID

# Generate ticket URL
TICKET_URL="https://aenetworks-fs-sandbox.freshservice.com/a/tickets/$TICKET_ID"

# Format the message
MESSAGE=$(cat <<EOF
************** SEV 1 ****************
<@U074TSUMZEJ>
Incident Commander: $slackincidentcommander
Detection Method: $slackdetectionmethod
Business Impact: $slackbusinessimpact
Bridge Link: <$bridge_url|Bridge Link>
Pagerduty Incident URL: $incident_url
FS Ticket URL: $TICKET_URL
We will keep everyone posted on this channel as we assess the issue further.
EOF
)

# Export MESSAGE as an environment variable
export MESSAGE

# Send the message to the Slack channel using the Slack API
send_slack_message "#kubiya-michaelg-test" "$MESSAGE"
