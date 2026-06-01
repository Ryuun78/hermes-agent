#!/usr/bin/env python3
"""Hermes local Google Calendar helper v2.

This tool is intentionally separate from ``~/.hermes/scripts/hermes_calendar_event.py``.
It avoids ``googleapiclient.discovery`` and calls Calendar REST endpoints
directly so calendar operations do not depend on the discovery service.
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import sys
from pathlib import Path
from urllib.parse import quote


DEFAULT_CALENDAR_BASE_URL = "https://www.googleapis.com/calendar/v3"
TOKEN_FILE = "google_token.json"
CLIENT_SECRET_FILE = "google_client_secret.json"
SCOPES = ["https://www.googleapis.com/auth/calendar"]


class CalendarApiError(RuntimeError):
    """Calendar API failure with a compact response body for operator diagnosis."""

    def __init__(self, status_code: int, url: str, body: str):
        self.status_code = status_code
        self.url = url
        self.body = body[:1000]
        super().__init__(f"HTTP {status_code} for {url}: {self.body}")


def get_hermes_home() -> Path:
    value = os.environ.get("HERMES_HOME", "").strip()
    return Path(value) if value else Path.home() / ".hermes"


def token_candidates() -> list[Path]:
    candidates: list[Path] = []
    override = os.environ.get("HERMES_GOOGLE_TOKEN_PATH", "").strip()
    if override:
        candidates.append(Path(override).expanduser())
    candidates.append(get_hermes_home() / TOKEN_FILE)
    default_home = Path.home() / ".hermes" / TOKEN_FILE
    if default_home not in candidates:
        candidates.append(default_home)
    return candidates


def client_secret_candidates() -> list[Path]:
    candidates: list[Path] = []
    override = os.environ.get("HERMES_GOOGLE_CLIENT_SECRET_PATH", "").strip()
    if override:
        candidates.append(Path(override).expanduser())
    candidates.append(get_hermes_home() / CLIENT_SECRET_FILE)
    default_home = Path.home() / ".hermes" / CLIENT_SECRET_FILE
    if default_home not in candidates:
        candidates.append(default_home)
    return candidates


def first_existing(paths: list[Path]) -> Path | None:
    for path in paths:
        if path.exists():
            return path
    return None


def safe_error_payload(exc: Exception) -> dict:
    message = str(exc)
    lowered = message.lower()
    if (
        "failed to resolve" in lowered
        or "nodename nor servname" in lowered
        or "servernotfound" in lowered
        or "could not resolve" in lowered
        or "name or service not known" in lowered
    ):
        category = "dns_or_network"
        summary = "Google OAuth/Calendar endpoint DNS lookup failed"
    elif "invalid_grant" in lowered or "reauth" in lowered or "oauth" in lowered:
        category = "oauth_refresh"
        summary = "Google OAuth token refresh failed"
    elif "permission" in lowered or "insufficient" in lowered or "forbidden" in lowered:
        category = "permission"
        summary = "Google Calendar permission failure"
    elif isinstance(exc, CalendarApiError):
        category = "calendar_api"
        summary = f"Google Calendar API HTTP {exc.status_code}"
    else:
        category = "calendar_tool_error"
        summary = exc.__class__.__name__
    return {
        "status": "error",
        "tool": "hermes_calendar_event_v2.py",
        "category": category,
        "summary": summary,
        "message": message.splitlines()[0][:500],
        "operator_note": (
            "Telegram 일정 처리는 Codex/ChatGPT 커넥터 승인창으로 우회하지 말고 "
            "Hermes 로컬 Google Calendar v2 도구 경로를 복구해야 합니다."
        ),
    }


def resolve_host(host: str, port: int = 443) -> dict:
    try:
        infos = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
        return {
            "host": host,
            "ok": True,
            "addresses": sorted({info[4][0] for info in infos})[:10],
        }
    except Exception as exc:
        return {"host": host, "ok": False, "error": repr(exc)}


def load_credentials():
    token_path = first_existing(token_candidates())
    if not token_path:
        raise RuntimeError(
            "Not authenticated. Missing google_token.json in: "
            + ", ".join(str(path) for path in token_candidates())
        )

    from google.auth.transport.requests import AuthorizedSession, Request
    from google.oauth2.credentials import Credentials

    creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
        token_path.write_text(json.dumps(json.loads(creds.to_json()), indent=2) + "\n")
    if not creds.valid:
        raise RuntimeError("Token is invalid. Re-run local Google Workspace setup.")
    return AuthorizedSession(creds), token_path


def event_url(calendar_id: str, event_id: str | None = None) -> str:
    base = os.environ.get("HERMES_CALENDAR_API_BASE", DEFAULT_CALENDAR_BASE_URL).rstrip("/")
    encoded_calendar = quote(calendar_id, safe="")
    url = f"{base}/calendars/{encoded_calendar}/events"
    if event_id:
        url += f"/{quote(event_id, safe='')}"
    return url


def calendar_list_url() -> str:
    base = os.environ.get("HERMES_CALENDAR_API_BASE", DEFAULT_CALENDAR_BASE_URL).rstrip("/")
    return f"{base}/users/me/calendarList"


def request_json(session, method: str, url: str, *, params: dict | None = None, body: dict | None = None):
    response = session.request(
        method,
        url,
        params=params or {},
        json=body,
        timeout=20,
    )
    if response.status_code >= 400:
        raise CalendarApiError(response.status_code, response.url, response.text)
    if response.status_code == 204:
        return {}
    return response.json()


def format_event(event: dict) -> dict:
    return {
        "id": event.get("id"),
        "summary": event.get("summary"),
        "start": event.get("start", {}).get("dateTime", event.get("start", {}).get("date", "")),
        "end": event.get("end", {}).get("dateTime", event.get("end", {}).get("date", "")),
        "status": event.get("status"),
        "htmlLink": event.get("htmlLink"),
        "description": event.get("description", ""),
    }


def list_events(session, calendar_id: str, start: str, end: str, max_results: int = 25) -> list[dict]:
    payload = request_json(
        session,
        "GET",
        event_url(calendar_id),
        params={
            "timeMin": start,
            "timeMax": end,
            "maxResults": max_results,
            "singleEvents": True,
            "orderBy": "startTime",
        },
    )
    return [format_event(event) for event in payload.get("items", [])]


def list_calendars(session, max_results: int = 100) -> list[dict]:
    payload = request_json(
        session,
        "GET",
        calendar_list_url(),
        params={"maxResults": max_results},
    )
    calendars = []
    for item in payload.get("items", []):
        calendars.append(
            {
                "id": item.get("id", ""),
                "summary": item.get("summary", ""),
                "primary": bool(item.get("primary")),
                "accessRole": item.get("accessRole", ""),
            }
        )
    return calendars


def event_time(value: str, timezone: str) -> dict:
    payload = {"dateTime": value}
    if timezone:
        payload["timeZone"] = timezone
    return payload


def create_event(
    session,
    *,
    calendar_id: str,
    title: str,
    start: str,
    end: str,
    description: str = "",
    timezone: str = "Asia/Seoul",
    location: str = "",
    attendees: str = "",
    no_duplicate_check: bool = False,
) -> dict:
    if not no_duplicate_check:
        for event in list_events(session, calendar_id, start, end, 50):
            if event.get("summary") == title and event.get("start") == start and event.get("end") == end:
                return {"status": "exists", "message": "duplicate skipped", "event": event}

    body = {
        "summary": title,
        "start": event_time(start, timezone),
        "end": event_time(end, timezone),
        "description": description or "",
        "visibility": "private",
        "transparency": "opaque",
        "reminders": {"useDefault": True},
    }
    if location:
        body["location"] = location
    if attendees:
        body["attendees"] = [
            {"email": email.strip()}
            for email in attendees.split(",")
            if email.strip()
        ]

    created = request_json(session, "POST", event_url(calendar_id), body=body)
    return {"status": "created", "event": format_event(created)}


def delete_event(session, calendar_id: str, event_id: str) -> dict:
    request_json(session, "DELETE", event_url(calendar_id, event_id))
    return {"status": "deleted", "event_id": event_id}


def cmd_probe(_args: argparse.Namespace) -> None:
    session = None
    token_path = None
    auth_ok = False
    auth_error = ""
    try:
        session, token_path = load_credentials()
        auth_ok = True
    except Exception as exc:
        auth_error = str(exc)
    payload = {
        "status": "ok" if auth_ok else "error",
        "hermes_home": str(get_hermes_home()),
        "token_path": str(token_path) if token_path else None,
        "token_candidates": [str(path) for path in token_candidates()],
        "client_secret_candidates": [str(path) for path in client_secret_candidates()],
        "auth_ok": auth_ok,
        "auth_error": auth_error,
        "dns": [
            resolve_host("oauth2.googleapis.com"),
            resolve_host("calendar.googleapis.com"),
            resolve_host("www.googleapis.com"),
        ],
    }
    if session:
        session.close()
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def cmd_list(args: argparse.Namespace) -> None:
    session, _token_path = load_credentials()
    try:
        events = list_events(session, args.calendar, args.start, args.end, args.max)
    finally:
        session.close()
    print(json.dumps(events, ensure_ascii=False, indent=2))


def cmd_calendars(args: argparse.Namespace) -> None:
    session, token_path = load_credentials()
    try:
        calendars = list_calendars(session, args.max)
    finally:
        session.close()
    print(
        json.dumps(
            {
                "status": "ok",
                "token_path": str(token_path),
                "calendars": calendars,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


def cmd_create(args: argparse.Namespace) -> None:
    session, _token_path = load_credentials()
    try:
        result = create_event(
            session,
            calendar_id=args.calendar,
            title=args.title,
            start=args.start,
            end=args.end,
            description=args.description,
            timezone=args.timezone,
            location=args.location,
            attendees=args.attendees,
            no_duplicate_check=args.no_duplicate_check,
        )
    finally:
        session.close()
    print(json.dumps(result, ensure_ascii=False, indent=2))


def cmd_delete(args: argparse.Namespace) -> None:
    session, _token_path = load_credentials()
    try:
        result = delete_event(session, args.calendar, args.event_id)
    finally:
        session.close()
    print(json.dumps(result, ensure_ascii=False, indent=2))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Hermes local Google Calendar helper v2")
    sub = parser.add_subparsers(dest="command", required=True)

    probe_p = sub.add_parser("probe")
    probe_p.set_defaults(func=cmd_probe)

    list_p = sub.add_parser("list")
    list_p.add_argument("--start", required=True, help="ISO datetime with timezone")
    list_p.add_argument("--end", required=True, help="ISO datetime with timezone")
    list_p.add_argument("--calendar", default="primary")
    list_p.add_argument("--max", type=int, default=25)
    list_p.set_defaults(func=cmd_list)

    calendars_p = sub.add_parser("calendars")
    calendars_p.add_argument("--max", type=int, default=100)
    calendars_p.set_defaults(func=cmd_calendars)

    create_p = sub.add_parser("create")
    create_p.add_argument("--title", required=True)
    create_p.add_argument("--start", required=True, help="ISO datetime with timezone")
    create_p.add_argument("--end", required=True, help="ISO datetime with timezone")
    create_p.add_argument("--description", default="")
    create_p.add_argument("--location", default="")
    create_p.add_argument("--attendees", default="")
    create_p.add_argument("--calendar", default="primary")
    create_p.add_argument("--timezone", default="Asia/Seoul")
    create_p.add_argument("--no-duplicate-check", action="store_true")
    create_p.set_defaults(func=cmd_create)

    delete_p = sub.add_parser("delete")
    delete_p.add_argument("event_id")
    delete_p.add_argument("--calendar", default="primary")
    delete_p.set_defaults(func=cmd_delete)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        args.func(args)
        return 0
    except Exception as exc:
        print(json.dumps(safe_error_payload(exc), ensure_ascii=False, indent=2))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
