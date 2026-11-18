# Discord Poster

A small Python script that writes a message and sends it every 10 minutes. By default a bot account sends it as a direct message to Discord user `1544316757685178475` (set as `DEFAULT_USER_ID` in the script). It can also post into a server channel through a webhook. It only uses the Python standard library, so there's nothing to install.

## Setup: direct messages (default)

1. Go to <https://discord.com/developers/applications>, click **New Application**, open **Bot**, click **Reset Token** and copy the token. Keep it private, because anyone who has it controls the bot.
2. Under **OAuth2 → URL Generator**, tick the `bot` scope, open the generated link and add the bot to a server the user is also in. Bots can only DM people they share a server with, and the user's privacy settings have to allow DMs from members of that server.
3. Run:

   ```bash
   export DISCORD_BOT_TOKEN="your-bot-token"
   python3 discord_poster.py --once   # send one test DM
   python3 discord_poster.py          # DM every 10 minutes
   ```

Use `--user-id 123...` to DM someone else.

## Setup: channel webhook

In Discord, open **Server Settings → Integrations → Webhooks → New Webhook**, pick a channel and copy the URL. Then:

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
python3 discord_poster.py --webhook
```

## Other options

```bash
python3 discord_poster.py --messages messages.txt    # use your own message templates
python3 discord_poster.py --interval 5               # change the interval (minutes)
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
