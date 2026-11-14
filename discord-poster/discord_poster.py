#!/usr/bin/env python3
"""
Discord Poster - writes and sends a Discord message every 10 minutes.

Uses a Discord *webhook* (the officially supported way to post automated
messages into a channel). No third-party packages needed: standard library only.

Setup:
  1. In Discord: Server Settings -> Integrations -> Webhooks -> New Webhook.
     Pick the channel, then "Copy Webhook URL".
  2. Run:
       export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
       python3 discord_poster.py

Options:
  --interval MINUTES   minutes between messages (default 10)
  --messages FILE      text file with one message template per line
  --once               send a single message and exit (good for testing)
  --dry-run            print messages instead of sending them
"""

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime

DEFAULT_TEMPLATES = [
    "Hello from the bot! It's {time} on {weekday}. This is message #{count}.",
    "Ten-minute check-in #{count}: still running since {start}.",
    "Fun fact #{count}: {fact}",
    "Reminder: drink some water! ({time})",
    "Beep boop. Message #{count} delivered at {time}.",
]

FACTS = [
    "Honey never spoils.",
    "Octopuses have three hearts.",
    "Bananas are berries, but strawberries aren't.",
    "A day on Venus is longer than a year on Venus.",
    "The first computer bug was an actual moth.",
    "Python is named after Monty Python, not the snake.",
]


def load_templates(path):
    if not path:
        return DEFAULT_TEMPLATES
    with open(path, encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip() and not line.startswith("#")]
    if not lines:
        sys.exit(f"No messages found in {path}")
    return lines


def write_message(templates, count, start):
    """Build the next message by filling a random template with live values."""
    now = datetime.now()
    template = random.choice(templates)
    return template.format(
        count=count,
        time=now.strftime("%H:%M"),
        date=now.strftime("%Y-%m-%d"),
        weekday=now.strftime("%A"),
        start=start.strftime("%H:%M"),
        fact=random.choice(FACTS),
    )


def send_message(webhook_url, content, username="Ten-Minute Bot"):
    """POST a message to a Discord webhook. Retries once if rate limited."""
    payload = json.dumps({"content": content[:2000], "username": username}).encode()
    for attempt in range(2):
        req = urllib.request.Request(
            webhook_url,
            data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "DiscordPoster/1.0"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15):
                return True
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt == 0:
                retry_after = float(json.loads(e.read() or b"{}").get("retry_after", 5))
                print(f"Rate limited, retrying in {retry_after:.1f}s")
                time.sleep(retry_after)
                continue
            print(f"Discord returned HTTP {e.code}: {e.read().decode(errors='replace')}")
            return False
        except urllib.error.URLError as e:
            print(f"Network error: {e.reason}")
            return False
    return False


def main():
    parser = argparse.ArgumentParser(description="Send a Discord message on a timer.")
    parser.add_argument("--interval", type=float, default=10, help="minutes between messages")
    parser.add_argument("--messages", help="file with one message template per line")
    parser.add_argument("--once", action="store_true", help="send one message and exit")
    parser.add_argument("--dry-run", action="store_true", help="print instead of sending")
    args = parser.parse_args()

    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL", "")
    if not args.dry_run and not webhook_url.startswith("https://"):
        sys.exit("Set DISCORD_WEBHOOK_URL to your webhook URL (or use --dry-run).")

    templates = load_templates(args.messages)
    start = datetime.now()
    count = 0
    print(f"Posting every {args.interval:g} minute(s). Press Ctrl+C to stop.")

    try:
        while True:
            count += 1
            message = write_message(templates, count, start)
            stamp = datetime.now().strftime("%H:%M:%S")
            if args.dry_run:
                print(f"[{stamp}] (dry run) {message}")
            elif send_message(webhook_url, message):
                print(f"[{stamp}] Sent: {message}")
            else:
                print(f"[{stamp}] Failed to send; will try again next round.")
            if args.once:
                break
            time.sleep(args.interval * 60)
    except KeyboardInterrupt:
        print(f"\nStopped after {count} message(s).")


if __name__ == "__main__":
    main()
