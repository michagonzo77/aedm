import os
import sys
import requests
import json
import time
import sqlite3
from datetime import datetime, timedelta
from fuzzywuzzy import process, fuzz
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
from pprint import pprint

VALID_ENVIRONMENTS = ['production', 'dev', 'qa']
API_TOKEN = os.getenv("FASTLY_API_TOKEN")
SLACK_API_TOKEN = os.getenv("SLACK_API_TOKEN")
SLACK_CHANNEL_ID = os.getenv("SLACK_CHANNEL_ID")
SLACK_THREAD_TS = os.getenv("SLACK_THREAD_TS")
CACHE_DB = "/sqlite_data/services_cache.db"
CACHE_EXPIRY_HOURS = 24
FUZZY_MATCH_THRESHOLD = 80
REAL_TIME_BASE_URL = "https://rt.fastly.com"
BASE_URL = "https://api.fastly.com"
DEFAULT_STREAM_DURATION = 60
DEFAULT_WAIT_INTERVAL = 1
FASTLY_DASHBOARD_HISTORICAL_URL = "https://manage.fastly.com/observability/dashboard/system/overview/historic/{service_id}?range={range}&region=all"
FASTLY_DASHBOARD_REALTIME_URL = "https://manage.fastly.com/observability/dashboard/system/overview/realtime/{service_id}?range={range}"
COMMON_FIELDS = ["status_5xx", "requests", "hits", "miss", "all_pass_requests"]

def debug_print(message):
    if os.getenv("KUBIYA_DEBUG"):
        print(message)

def load_cache():
    try:
        conn = sqlite3.connect(CACHE_DB)
        c = conn.cursor()
        c.execute('''CREATE TABLE IF NOT EXISTS services_cache
                    (timestamp text, services text)''')
        c.execute("SELECT * FROM services_cache")
        row = c.fetchone()
        if row:
            cache_timestamp = datetime.fromisoformat(row[0])
            if datetime.utcnow() - cache_timestamp < timedelta(hours=CACHE_EXPIRY_HOURS):
                services = json.loads(row[1])
                conn.close()
                return services
        conn.close()
    except Exception as e:
        print(f"Error loading cache from database: {e}")
    return None

def save_cache(services):
    try:
        conn = sqlite3.connect(CACHE_DB)
        c = conn.cursor()
        c.execute("DELETE FROM services_cache")
        cache_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'services': json.dumps(services)
        }
        c.execute("INSERT INTO services_cache (timestamp, services) VALUES (?, ?)", 
                (cache_data['timestamp'], cache_data['services']))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Error saving cache to database: {e}")

def list_services():
    cached_services = load_cache()
    if cached_services:
        debug_print("Loaded services from cache.")
        return cached_services

    url = f"{BASE_URL}/service"
    headers = {
        "Fastly-Key": API_TOKEN,
        "Accept": "application/json"
    }
    params = {
        "direction": "ascend",
        "page": 1,
        "per_page": 20,
        "sort": "created"
    }
    
    all_services = {}
    
    try:
        while True:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            services = response.json()
            if not services:
                break
            for service in services:
                all_services[service['name']] = service['id']
            params["page"] += 1
    except requests.exceptions.RequestException as e:
        print(f"Error fetching services from Fastly API: {e}")
    
    save_cache(all_services)
    return all_services

def construct_service_prefix(service_name, environment):
    if environment == 'production':
        return service_name
    return f"{environment}-{service_name}"

def get_environment(env_name):
    if not env_name:
        return None
    env_name = env_name.lower()
    if env_name in VALID_ENVIRONMENTS:
        return env_name
    return None

def get_real_time_data(api_token, service_id, duration_seconds=5):
    url = f"{REAL_TIME_BASE_URL}/v1/channel/{service_id}/ts/0"
    debug_print(f"Real-Time API URL: {url}")
    headers = {
        "Fastly-Key": api_token,
        "Accept": "application/json"
    }
    
    try:
        debug_print("Retrieving real-time data...")
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        real_time_data = response.json()
        return real_time_data['Data']
    except requests.exceptions.RequestException as e:
        print(f"Error retrieving real-time data from Fastly API: {e}")
        return None

def get_best_match(prefix, services):
    results = process.extract(prefix, services, scorer=fuzz.WRatio)
    filtered_results = [result for result in results if result[0].startswith(prefix)]
    if not filtered_results:
        best_match = max(results, key=lambda x: x[1])
    else:
        best_match = max(filtered_results, key=lambda x: x[1])
    return best_match[0] if best_match else None

def format_value(value):
    try:
        value = float(value)
        if value >= 1000:
            return f"{value / 1000:.1f}K ({int(value)})"
        return str(int(value))
    except (ValueError, TypeError):
        return str(value)

def send_slack_message(channel, thread_ts, blocks, text="Message from script"):
    client = WebClient(token=SLACK_API_TOKEN)
    try:
        response = client.chat_postMessage(channel=channel, thread_ts=thread_ts, blocks=blocks, text=text)
        return response["channel"], response["ts"]
    except SlackApiError as e:
        print(f"Error sending message to Slack: {e.response['error']}")
        return None

def update_slack_message(channel, ts, blocks, text="Updated message from script", thread_ts=None):
    client = WebClient(token=SLACK_API_TOKEN)
    try:
        if thread_ts:
            client.chat_update(channel=channel, ts=ts, thread_ts=thread_ts, blocks=blocks, text=text)
        else:
            client.chat_update(channel=channel, ts=ts, blocks=blocks, text=text)
    except SlackApiError as e:
        print(f"Error updating message on Slack: {e.response['error']}")

def delete_slack_message(channel, ts):
    client = WebClient(token=SLACK_API_TOKEN)
    try:
        client.chat_delete(channel=channel, ts=ts)
    except SlackApiError as e:
        print(f"Error deleting message on Slack: {e.response['error']}")

def generate_dashboard_url(service_id, range_str):
    return FASTLY_DASHBOARD_REALTIME_URL.format(service_id=service_id, range=range_str)

def generate_slack_blocks(summary, interval_summary, service_name, environment, service_id, previous_interval_summary=None):
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": ":bar_chart: Real-Time Data Summary"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*Service Name:*\n<{generate_dashboard_url(service_id, '1m')}|{service_name}>"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Environment:*\n{environment.title()}"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Update Frequency:*\nEvery 1 second"
                }
            ]
        },
        {"type": "divider"}
    ]

    for field, value in summary.items():
        interval_value = interval_summary.get(field, 0)
        previous_value = previous_interval_summary.get(field, 0) if previous_interval_summary else 0
        change_emoji = ""
        if interval_value > previous_value:
            change_emoji = " :arrow_up:"
        elif interval_value < previous_value:
            change_emoji = " :small_red_triangle_down:"

        blocks.append({
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*{field.replace('_', ' ').title()}*\n*Last Interval:* `{format_value(interval_value)}` {change_emoji}"
                }
            ]
        })

    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": "_You can stop the stream by clicking on the 'Stop' button on this thread._"
        }
    })

    return blocks

def generate_final_slack_blocks_with_intervals(summary, interval_summary, service_name, environment, service_id):
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": ":bar_chart: Final Real-Time Data Summary"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*Service Name:*\n<{generate_dashboard_url(service_id, '1m')}|{service_name}>"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Environment:*\n{environment.title()}"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Update Frequency:*\nEvery 1 second"
                }
            ]
        },
        {"type": "divider"}
    ]

    for field, value in summary.items():
        interval_value = interval_summary.get(field, 0)
        blocks.append({
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*{field.replace('_', ' ').title()}*\n*Last Interval:* `{format_value(interval_value)}`"
                }
            ]
        })

    return blocks

def stream_real_time_data(api_token, service_name, environment, service_id, slack_channel=None, thread_ts=None):
    print(f"Streaming real-time data for {DEFAULT_STREAM_DURATION} seconds with a wait interval of {DEFAULT_WAIT_INTERVAL} seconds...")
    end_time = datetime.utcnow() + timedelta(seconds=DEFAULT_STREAM_DURATION)
    total_stats = {field: 0 for field in COMMON_FIELDS}
    previous_stats = {field: 0 for field in COMMON_FIELDS}

    slack_ts = None
    if slack_channel:
        blocks = generate_slack_blocks(total_stats, {}, service_name, environment, service_id)
        channel, slack_ts = send_slack_message(slack_channel, thread_ts, blocks)
    
    try:
        while datetime.utcnow() < end_time:
            time.sleep(DEFAULT_WAIT_INTERVAL)
            stats_data = get_real_time_data(api_token, service_id, duration_seconds=DEFAULT_WAIT_INTERVAL)
            if not stats_data:
                print("Unable to retrieve real-time data.")
                return

            interval_stats = {field: 0 for field in COMMON_FIELDS}
            for data_point in stats_data:
                for common_field in COMMON_FIELDS:
                    if common_field in data_point['aggregated']:
                        interval_stats[common_field] += data_point['aggregated'][common_field]

            for field in COMMON_FIELDS:
                total_stats[field] += interval_stats[field]

            if slack_channel:
                blocks = generate_slack_blocks(total_stats, interval_stats, service_name, environment, service_id, previous_interval_summary=previous_stats)
                update_slack_message(channel, slack_ts, blocks, thread_ts)
                previous_stats = interval_stats.copy()
            else:
                print(f"\nReal-Time Data Summary (Last {DEFAULT_WAIT_INTERVAL} seconds):")
                for field, value in interval_stats.items():
                    print(f"{field}: {format_value(value)}")
                print("\n---\n")

        if not slack_channel:
            print("\nTotal Real-Time Data Summary:")
            for field, value in total_stats.items():
                print(f"{field}: {format_value(value)}")
            print("\n---\n")
    finally:
        if slack_channel and slack_ts:
            final_blocks = generate_final_slack_blocks_with_intervals(total_stats, previous_stats, service_name, environment, service_id)
            update_slack_message(slack_channel, slack_ts, final_blocks)

def main(environment=None, service_name=None):
    try:
        if not environment:
            print("No environment specified. Please provide one of the following environments:")
            for env in VALID_ENVIRONMENTS:
                print(f"  - {env}")
            return

        environment = get_environment(environment)
        if not environment:
            print(f"No matching environment found for '{environment}'. Available environments: {VALID_ENVIRONMENTS}")
            return

        if not service_name:
            print("No service name specified. Please provide a service name.")
            return

        service_prefix = construct_service_prefix(service_name, environment)
        debug_print(f"Constructed service prefix: {service_prefix}")

        debug_print("Fetching list of services...")
        services = list_services()
        
        if not services:
            print("No services found.")
            return

        best_match = get_best_match(service_prefix, list(services.keys()))
        if not best_match:
            print(f"No matching service found for '{service_prefix}'.")
            return

        service_id = services[best_match]
        debug_print(f"Best matching service: {best_match}")

        stream_real_time_data(API_TOKEN, best_match, environment, service_id, slack_channel=SLACK_CHANNEL_ID, thread_ts=SLACK_THREAD_TS)
        print(f"View more details in the Fastly dashboard: {generate_dashboard_url(service_id, f'{DEFAULT_STREAM_DURATION}s')}")
        
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Realtime stats for Fastly service.')
    parser.add_argument('--environment', type=str, choices=['production', 'dev', 'qa'], help='The environment to monitor (production, dev, qa)')
    parser.add_argument('--service_name', type=str, help='The name of the Fastly service to monitor')

    args = parser.parse_args()
    
    main(environment=args.environment, service_name=args.service_name)
