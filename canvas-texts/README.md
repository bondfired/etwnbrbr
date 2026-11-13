# Canvas assignment texts

Texts you your upcoming Canvas assignments at **8am, 11am, 1pm, 3pm, 6pm, 8pm, 10pm and 11pm Pacific**.
It switches between standard and daylight time on its own. It runs free on GitHub Actions, so nothing has to stay running on your phone or computer.

A text looks like this:

```
Canvas: 3 due soon
- Essay Draft [ENG 101]: TODAY 11:59pm
- Lab 4 [CHEM 1A]: tmrw 5pm
- Quiz 6 [MATH 3]: Sat 11:59pm
```

## Setup (about 10 minutes)

### 1. Get your Canvas link
In Canvas, open **Calendar** and click **Calendar Feed** (bottom right). Copy the link.

*Optional:* to leave out assignments you've already turned in, go to **Account → Settings → New Access Token** and create a token.
Use the token plus your school's Canvas address (for example `myschool.instructure.com`) in place of the feed link.

### 2. Choose how the texts get sent
GitHub can't send texts by itself, so you need a texting service. Both options cost money:

| | **Textbelt** (easiest) | **Twilio** (cheaper per text) |
|---|---|---|
| Setup | Buy a key at textbelt.com. That's it. | Make an account, buy a toll-free number, then submit a "toll-free verification" form and wait for approval (can take days) |
| Cost | Roughly $0.06 per text. That's about **$14 a month** at 8 texts a day | Roughly $1–3 a month for messages plus about $2 a month for the number |

To get the cost down, cut the number of daily texts with the `SEND_HOURS` setting (see below).

### 3. Add your secrets to GitHub
In the GitHub repo, go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret | Value |
|---|---|
| `CANVAS_ICS_URL` | The calendar feed link from step 1 *(or `CANVAS_DOMAIN` + `CANVAS_TOKEN` instead)* |
| `PHONE_NUMBER` | Your cell number, like `+15551234567` |
| `TEXTBELT_KEY` | Your Textbelt key |

If you use Twilio, also add `SMS_PROVIDER` = `twilio`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM` (your Twilio number).

### 4. Test it
Go to **Actions → Canvas assignment texts → Run workflow**. You should get a text within a minute.
After that, it sends on its own schedule.

> GitHub only runs schedules from the repo's **main** branch, so this has to be merged into `main`.

## Changing things
These are set in `.github/workflows/canvas-texts.yml`, under `env:`:
- `SEND_HOURS`: which hours to text, e.g. `"8,13,18,22"`. If you add an hour, also add it to the `cron` line.
- `DAYS_AHEAD`: how many days ahead to look (default 3).
- `MAX_ITEMS`: the most assignments listed in one text (default 6).

## Notes
- GitHub sometimes starts scheduled runs a few minutes late. That's normal.
- The workflow keeps its own schedule switched on. Otherwise GitHub would turn it off after 60 days with no repo activity.
- Your feed link and token are like passwords. Keep them in GitHub Secrets and never put them in the code.
