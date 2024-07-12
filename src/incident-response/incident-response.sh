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

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --event_file) event_file="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check for required arguments
if [ -z "${event_file}" ]; then
    echo "Usage: $0 --event_file <event_file>"
    exit 1
fi

# Main code
# Check if a file is provided as an argument
if [ -z "$event_file" ]; then
    echo "Usage: $0 --event_file <event_file>"
    exit 1
fi

# Read JSON input from the file
event_data=$(< "$event_file")

# Ensure the event_data is valid JSON
if ! jq empty <<< "$event_data"; then
    echo "Invalid JSON data in $event_file"
    exit 1
fi

# Extract necessary fields from the JSON data
description=$(jq -r '.slackdescription' <<< "$event_data")
servicename=$(jq -r '.servicename' <<< "$event_data")
title=$(jq -r '.title' <<< "$event_data")
incident_url=$(jq -r '.incident_url' <<< "$event_data")
slackincidentcommander=$(jq -r '.slackincidentcommander' <<< "$event_data")
slackdetectionmethod=$(jq -r '.slackdetectionmethod' <<< "$event_data")
slackbusinessimpact=$(jq -r '.slackbusinessimpact' <<< "$event_data")
incident_id=$(jq -r '.incident_id' <<< "$event_data")
bridge_url=$(jq -r '.bridge_url' <<< "$event_data")

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
@U074TSUMZEJ
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

# Send the message to the Slack channel
slack send-message '#kubiya-michaelg-test' "$MESSAGE"
