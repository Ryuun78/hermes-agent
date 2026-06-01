import importlib.util
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[2] / "scripts" / "hermes_calendar_event_v2.py"


def load_module():
    spec = importlib.util.spec_from_file_location("hermes_calendar_event_v2", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class FakeResponse:
    def __init__(self, payload=None, status_code=200):
        self._payload = payload or {}
        self.status_code = status_code
        self.text = "{}"
        self.url = "https://www.googleapis.com/test"

    def json(self):
        return self._payload

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")


class FakeSession:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []

    def request(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs))
        return self.responses.pop(0)


def test_list_events_uses_calendar_googleapis_without_discovery():
    mod = load_module()
    session = FakeSession([FakeResponse({"items": []})])

    events = mod.list_events(
        session,
        "primary",
        "2026-06-15T00:00:00+09:00",
        "2026-06-16T00:00:00+09:00",
        20,
    )

    assert events == []
    method, url, kwargs = session.calls[0]
    assert method == "GET"
    assert url == "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    assert kwargs["params"]["timeMin"] == "2026-06-15T00:00:00+09:00"
    assert kwargs["params"]["singleEvents"] is True


def test_create_event_skips_exact_duplicate():
    mod = load_module()
    session = FakeSession(
        [
            FakeResponse(
                {
                    "items": [
                        {
                            "id": "existing-id",
                            "summary": "[개인] 주은숙과 점심식사 - 담당 관장",
                            "start": {"dateTime": "2026-06-15T12:00:00+09:00"},
                            "end": {"dateTime": "2026-06-15T13:00:00+09:00"},
                            "status": "confirmed",
                        }
                    ]
                }
            )
        ]
    )

    result = mod.create_event(
        session,
        calendar_id="primary",
        title="[개인] 주은숙과 점심식사 - 담당 관장",
        start="2026-06-15T12:00:00+09:00",
        end="2026-06-15T13:00:00+09:00",
        description="",
        timezone="Asia/Seoul",
    )

    assert result["status"] == "exists"
    assert result["event"]["id"] == "existing-id"
    assert len(session.calls) == 1


def test_delete_event_calls_calendar_endpoint():
    mod = load_module()
    session = FakeSession([FakeResponse({})])

    result = mod.delete_event(session, "primary", "event-123")

    assert result == {"status": "deleted", "event_id": "event-123"}
    method, url, kwargs = session.calls[0]
    assert method == "DELETE"
    assert url == "https://www.googleapis.com/calendar/v3/calendars/primary/events/event-123"
    assert kwargs["params"] == {}


def test_list_calendars_uses_calendar_list_endpoint():
    mod = load_module()
    session = FakeSession(
        [
            FakeResponse(
                {
                    "items": [
                        {
                            "id": "ryuun.jyp@gmail.com",
                            "summary": "박진영",
                            "primary": True,
                            "accessRole": "owner",
                        }
                    ]
                }
            )
        ]
    )

    calendars = mod.list_calendars(session)

    assert calendars == [
        {
            "id": "ryuun.jyp@gmail.com",
            "summary": "박진영",
            "primary": True,
            "accessRole": "owner",
        }
    ]
    method, url, kwargs = session.calls[0]
    assert method == "GET"
    assert url == "https://www.googleapis.com/calendar/v3/users/me/calendarList"
    assert kwargs["params"]["maxResults"] == 100
