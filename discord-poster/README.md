# Discord Poster

A small Python script that writes a message and sends it to a Discord channel every 10 minutes, using a Discord webhook. It only uses the Python standard library, so there's nothing to install.

## Setup

1. In Discord, open **Server Settings → Integrations → Webhooks → New Webhook**, choose a channel, and click **Copy Webhook URL**.
2. Set it as an environment variable. Keep this URL private, because anyone who has it can post to your channel.

   ```bash
   export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
   ```

## Usage

```bash
python3 discord_poster.py                         # every 10 minutes, built-in messages
python3 discord_poster.py --messages messages.txt # use your own message templates
python3 discord_poster.py --interval 5            # change the interval (minutes)
python3 discord_poster.py --once                  # send one message to test
python3 discord_poster.py --dry-run --interval 0.05  # preview without sending
```

## Writing messages

Each line in `messages.txt` is a template. The script picks one at random each round and fills in:

| Placeholder | Value |
|---|---|
| `{count}` | message number since the script started |
| `{time}` | current time (HH:MM) |
| `{date}` | current date |
| `{weekday}` | day of the week |
| `{start}` | time the script started |
| `{fact}` | a random fun fact |
