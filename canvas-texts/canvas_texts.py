#!/usr/bin/env python3
"""Get phone notifications (or texts) about your upcoming Canvas assignments.

Settings come from environment variables (GitHub Secrets when it runs on GitHub):

  Where assignments come from (set one):
    CANVAS_ICS_URL    Your Canvas calendar feed link (Calendar -> Calendar Feed)
    CANVAS_DOMAIN +   e.g. "myschool.instructure.com" plus a token from
    CANVAS_TOKEN      Account -> Settings -> New Access Token. With these set,
                      assignments you've already turned in are left out.

  Where it goes:
    SEND_VIA          "ntfy" (default, free), "textbelt" or "twilio" (paid texts)
    NTFY_TOPIC        Your ntfy topic name (needed for ntfy). Make it hard to guess!
    NTFY_SERVER       Default https://ntfy.sh
    PHONE_NUMBER      Your cell number, e.g. +15551234567 (texts only)
    TEXTBELT_KEY      Your Textbelt key (needed for textbelt)
    TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM   (needed for twilio)

  Optional:
    TIMEZONE          Default America/Los_Angeles (Pacific; daylight saving handled)
    SEND_HOURS        Default "8,11,13,15,18,20,22,23" (24-hour clock, your time)
    DAYS_AHEAD        How far ahead to look, in days. Default 3
    MAX_ITEMS         Most assignments listed in one text. Default 6
    FORCE=1           Send right now, whatever the time
    DRY_RUN=1         Print the text instead of sending it
"""

import base64
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

TZ = ZoneInfo(os.environ.get("TIMEZONE") or "America/Los_Angeles")
SEND_HOURS = {int(h) for h in (os.environ.get("SEND_HOURS") or "8,11,13,15,18,20,22,23").split(",")}
DAYS_AHEAD = int(os.environ.get("DAYS_AHEAD") or 3)
MAX_ITEMS = int(os.environ.get("MAX_ITEMS") or 6)


def env(name):
    return (os.environ.get(name) or "").strip()


def http(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    req.add_header("User-Agent", "canvas-texts")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8"), resp.headers


# ---------- Source 1: the Canvas calendar feed (.ics) ----------

def parse_ics_time(prop, value):
    """Turn an ICS DTSTART into an aware datetime."""
    if "VALUE=DATE" in prop and "T" not in value:  # all-day: treat as due 11:59pm
        d = datetime.strptime(value[:8], "%Y%m%d")
        return d.replace(hour=23, minute=59, tzinfo=TZ)
    if value.endswith("Z"):
        return datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    m = re.search(r"TZID=([^;:]+)", prop)
    tz = ZoneInfo(m.group(1)) if m else TZ
    return datetime.strptime(value[:15], "%Y%m%dT%H%M%S").replace(tzinfo=tz)


def unescape(text):
    return (text.replace("\\n", " ").replace("\\N", " ").replace("\\,", ",")
                .replace("\\;", ";").replace("\\\\", "\\").strip())


def from_ics(url):
    url = url.replace("webcal://", "https://", 1)
    raw, _ = http(url)
    raw = re.sub(r"\r?\n[ \t]", "", raw)  # unfold continued lines
    items = []
    for block in raw.split("BEGIN:VEVENT")[1:]:
        fields = {}
        for line in block.splitlines():
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            fields[key.split(";")[0]] = (key, value)
        uid = fields.get("UID", ("", ""))[1]
        if "assignment" not in uid:  # skip ordinary calendar events
            continue
        if "DTSTART" not in fields or "SUMMARY" not in fields:
            continue
        prop, value = fields["DTSTART"]
        items.append({"title": unescape(fields["SUMMARY"][1]), "due": parse_ics_time(prop, value)})
    return items


# ---------- Source 2: the Canvas API (also skips work you've turned in) ----------

def from_api(domain, token):
    domain = re.sub(r"^https?://", "", domain).rstrip("/")
    now = datetime.now(timezone.utc)
    params = urllib.parse.urlencode({
        "start_date": now.isoformat(),
        "end_date": (now + timedelta(days=DAYS_AHEAD + 1)).isoformat(),
        "per_page": 100,
    })
    url = f"https://{domain}/api/v1/planner/items?{params}"
    items = []
    while url:
        body, headers = http(url, headers={"Authorization": f"Bearer {token}"})
        for it in json.loads(body):
            if it.get("plannable_type") not in ("assignment", "quiz", "discussion_topic", "sub_assignment"):
                continue
            subs = it.get("submissions") or {}
            if subs.get("submitted") or subs.get("excused"):
                continue
            if (it.get("planner_override") or {}).get("marked_complete"):
                continue
            due = it.get("plannable_date")
            if not due:
                continue
            course = it.get("context_name") or ""
            title = (it.get("plannable") or {}).get("title") or "Untitled"
            items.append({
                "title": f"{title} [{course}]" if course else title,
                "due": datetime.fromisoformat(due.replace("Z", "+00:00")),
            })
        m = re.search(r'<([^>]+)>;\s*rel="next"', headers.get("Link", ""))
        url = m.group(1) if m else None
    return items


# ---------- Building the text ----------

def when(due, now):
    local = due.astimezone(TZ)
    t = local.strftime("%I:%M%p").lstrip("0").lower().replace(":00", "")
    days = (local.date() - now.date()).days
    if days == 0:
        return f"TODAY {t}"
    if days == 1:
        return f"tmrw {t}"
    return f"{local.strftime('%a')} {t}"


def build_message(items, now):
    end = now + timedelta(days=DAYS_AHEAD)
    upcoming = sorted((i for i in items if now <= i["due"] <= end), key=lambda i: i["due"])
    if not upcoming:
        return "Nothing due 🎉", f"Nothing due in the next {DAYS_AHEAD} days."
    title = f"{len(upcoming)} due soon"
    lines = []
    for i in upcoming[:MAX_ITEMS]:
        name = i["title"]
        if len(name) > 45:
            name = name[:44] + "…"
        lines.append(f"- {name}: {when(i['due'], now)}")
    if len(upcoming) > MAX_ITEMS:
        lines.append(f"+{len(upcoming) - MAX_ITEMS} more")
    return title, "\n".join(lines)


# ---------- Sending it ----------

def send_ntfy(title, body):
    topic = env("NTFY_TOPIC")
    if not topic:
        sys.exit("Set NTFY_TOPIC.")
    server = (env("NTFY_SERVER") or "https://ntfy.sh").rstrip("/")
    payload = {"topic": topic, "title": title, "message": body, "tags": ["books"]}
    if title.startswith("Nothing"):
        payload["priority"] = 2  # quiet when there's nothing due
    http(server, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    print("Sent with ntfy.")


def send_textbelt(phone, message):
    data = urllib.parse.urlencode({"phone": phone, "message": message, "key": env("TEXTBELT_KEY")}).encode()
    body, _ = http("https://textbelt.com/text", data=data)
    result = json.loads(body)
    if not result.get("success"):
        sys.exit(f"Textbelt didn't send it: {result.get('error') or result}")
    print(f"Sent. Texts left on your Textbelt key: {result.get('quotaRemaining')}")


def send_twilio(phone, message):
    sid, auth = env("TWILIO_ACCOUNT_SID"), env("TWILIO_AUTH_TOKEN")
    data = urllib.parse.urlencode({"To": phone, "From": env("TWILIO_FROM"), "Body": message}).encode()
    basic = base64.b64encode(f"{sid}:{auth}".encode()).decode()
    http(f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json",
         data=data, headers={"Authorization": f"Basic {basic}"})
    print("Sent with Twilio.")


def main():
    now = datetime.now(TZ)
    force = env("FORCE") == "1"
    if not force and now.hour not in SEND_HOURS:
        print(f"It's {now:%-I:%M%p} Pacific, which isn't a send time. Skipping.")
        return

    if env("CANVAS_DOMAIN") and env("CANVAS_TOKEN"):
        items = from_api(env("CANVAS_DOMAIN"), env("CANVAS_TOKEN"))
    elif env("CANVAS_ICS_URL"):
        items = from_ics(env("CANVAS_ICS_URL"))
    else:
        sys.exit("Set CANVAS_ICS_URL, or CANVAS_DOMAIN and CANVAS_TOKEN.")

    title, body = build_message(items, now)
    print(f"{title}\n{body}")
    if env("DRY_RUN") == "1":
        print("(Dry run, so nothing was sent.)")
        return

    via = (env("SEND_VIA") or "ntfy").lower()
    if via == "ntfy":
        send_ntfy(title, body)
        return
    phone = env("PHONE_NUMBER")
    if not phone:
        sys.exit("Set PHONE_NUMBER.")
    message = f"Canvas: {title}\n{body}"
    if via == "twilio":
        send_twilio(phone, message)
    else:
        send_textbelt(phone, message)


if __name__ == "__main__":
    main()
