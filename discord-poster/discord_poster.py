#!/usr/bin/env python3
"""
Discord Poster - writes and sends a Discord message every 10 minutes.

Two ways to send:

  Direct message (default): a bot account DMs one Discord user.
    1. https://discord.com/developers/applications -> New Application -> Bot
       -> Reset Token, copy the token.
    2. Invite the bot to a server the user is also in (OAuth2 -> URL Generator,
       scope "bot"). Bots can only DM people they share a server with.
    3. export DISCORD_BOT_TOKEN="..."
       python3 discord_poster.py

  Channel webhook: posts into one server channel.
    export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
    python3 discord_poster.py --webhook

No third-party packages needed: standard library only.

Options:
  --user-id ID         Discord user ID to DM (default: DEFAULT_USER_ID below)
  --webhook            post to a channel webhook instead of DMing a user
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

API = "https://discord.com/api/v10"

# The Discord user to DM, taken from https://discord.com/users/<this number>
DEFAULT_USER_ID = "1544316757685178475"

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


def post_json(url, payload, headers=None):
    """POST JSON to Discord and return the decoded response, or None on failure.
    Waits and retries once if Discord says we're being rate limited."""
    data = json.dumps(payload).encode()
    all_headers = {"Content-Type": "application/json", "User-Agent": "DiscordPoster/1.0"}
    all_headers.update(headers or {})
    for attempt in range(2):
        req = urllib.request.Request(url, data=data, headers=all_headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                body = resp.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as e:
            body = e.read()
            if e.code == 429 and attempt == 0:
                retry_after = float(json.loads(body or b"{}").get("retry_after", 5))
                print(f"Rate limited, retrying in {retry_after:.1f}s")
                time.sleep(retry_after)
                continue
            print(f"Discord returned HTTP {e.code}: {body.decode(errors='replace')}")
            return None
        except urllib.error.URLError as e:
            print(f"Network error: {e.reason}")
            return None
    return None


class WebhookSender:
    """Posts into the single channel a webhook belongs to."""

    def __init__(self, webhook_url, username="Ten-Minute Bot"):
        self.url = webhook_url
        self.username = username

    def send(self, content):
        payload = {"content": content[:2000], "username": self.username}
        return post_json(self.url, payload) is not None


class DMSender:
    """Sends direct messages to one user from a bot account."""

    def __init__(self, bot_token, user_id):
        self.headers = {"Authorization": f"Bot {bot_token}"}
        self.user_id = user_id
        self.channel_id = None

    def _open_dm(self):
        result = post_json(f"{API}/users/@me/channels", {"recipient_id": self.user_id}, self.headers)
        if result and "id" in result:
            self.channel_id = result["id"]
        else:
            print("Couldn't open a DM. Check the token, and that the bot shares a "
                  "server with the user and they allow DMs from server members.")
        return self.channel_id

    def send(self, content):
        if not self.channel_id and not self._open_dm():
            return False
        url = f"{API}/channels/{self.channel_id}/messages"
        return post_json(url, {"content": content[:2000]}, self.headers) is not None


def main():
    parser = argparse.ArgumentParser(description="Send a Discord message on a timer.")
    parser.add_argument("--user-id", default=DEFAULT_USER_ID, help="Discord user ID to DM")
    parser.add_argument("--webhook", action="store_true", help="post via channel webhook instead")
    parser.add_argument("--interval", type=float, default=10, help="minutes between messages")
    parser.add_argument("--messages", help="file with one message template per line")
    parser.add_argument("--once", action="store_true", help="send one message and exit")
    parser.add_argument("--dry-run", action="store_true", help="print instead of sending")
    args = parser.parse_args()

    sender = None
    if args.dry_run:
        pass
    elif args.webhook:
        webhook_url = os.environ.get("DISCORD_WEBHOOK_URL", "")
        if not webhook_url.startswith("https://"):
            sys.exit("Set DISCORD_WEBHOOK_URL to your webhook URL (or use --dry-run).")
        sender = WebhookSender(webhook_url)
    else:
        token = os.environ.get("DISCORD_BOT_TOKEN", "")
        if not token:
            sys.exit("Set DISCORD_BOT_TOKEN to your bot's token (or use --webhook / --dry-run).")
        if not args.user_id.isdigit():
            sys.exit(f"--user-id should be a number, got {args.user_id!r}")
        sender = DMSender(token, args.user_id)

    templates = load_templates(args.messages)
    start = datetime.now()
    count = 0
    target = "channel webhook" if args.webhook else f"user {args.user_id}"
    print(f"Sending to {target} every {args.interval:g} minute(s). Press Ctrl+C to stop.")

    try:
        while True:
            count += 1
            message = write_message(templates, count, start)
            stamp = datetime.now().strftime("%H:%M:%S")
            if args.dry_run:
                print(f"[{stamp}] (dry run) {message}")
            elif sender.send(message):
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
