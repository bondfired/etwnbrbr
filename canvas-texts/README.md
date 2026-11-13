# Canvas assignment reminders

Sends a free notification to your phone with your upcoming Canvas assignments at
**8am, 11am, 1pm, 3pm, 6pm, 8pm, 10pm and 11pm Pacific**. It switches between standard and daylight time on its own.
It runs on GitHub Actions, so nothing has to stay running on your phone or computer.

It looks like this on your lock screen:

```
📚 3 due soon
- Essay Draft [ENG 101]: TODAY 11:59pm
- Lab 4 [CHEM 1A]: tmrw 5pm
- Quiz 6 [MATH 3]: Sat 11:59pm
```

## Setup (about 10 minutes)

### 1. Install ntfy and pick a topic
1. Install **ntfy** from the App Store or Google Play. It's free and you don't need an account.
2. Tap **+**, then subscribe to a topic name you make up. Make it long and random, like `canvas-k7q2m9xw4p`.
   Anyone who knows the name can see your notifications, so treat it like a password.
3. *iPhone:* allow notifications when it asks.

### 2. Get your Canvas link
In Canvas, open **Calendar** and click **Calendar Feed** (bottom right). Copy the link.

*Optional:* to leave out assignments you've already turned in, go to **Account → Settings → New Access Token** and create a token.
Use the token plus your school's Canvas address (for example `myschool.instructure.com`) in place of the feed link.

### 3. Add two secrets to GitHub
In the GitHub repo, go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret | Value |
|---|---|
| `NTFY_TOPIC` | Your topic name from step 1 |
| `CANVAS_ICS_URL` | The calendar feed link from step 2 *(or `CANVAS_DOMAIN` + `CANVAS_TOKEN` instead)* |

### 4. Merge into main and test
GitHub only runs schedules from the **main** branch, so merge this in first.
Then go to **Actions → Canvas assignment reminders → Run workflow**. You should get a notification within a minute.
After that, it sends on its own schedule.

## Changing things
These are set in `.github/workflows/canvas-texts.yml`, under `env:`:
- `SEND_HOURS`: which hours to send, e.g. `"8,13,18,22"`. If you add an hour, also add it to the `cron` line.
- `DAYS_AHEAD`: how many days ahead to look (default 3).
- `MAX_ITEMS`: the most assignments listed at once (default 6).

## Real texts instead (costs money)
If you'd rather get SMS texts, add a `SEND_VIA` secret set to `textbelt` (about $0.06 per text) or `twilio` (cheaper, but needs a
verification form). Also add `PHONE_NUMBER`, plus `TEXTBELT_KEY` or `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM`.

## Notes
- GitHub sometimes starts scheduled runs a few minutes late. That's normal.
- The workflow keeps its own schedule switched on. Otherwise GitHub would turn it off after 60 days with no repo activity.
- Your Canvas feed link and token are like passwords. Keep them in GitHub Secrets and never put them in the code.
