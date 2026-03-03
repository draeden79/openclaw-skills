#!/usr/bin/env python3
"""Manage calendar events via Microsoft Graph."""
import argparse
import json
from datetime import datetime, timezone, timedelta
from typing import List, Optional

from utils import append_log, authorized_request, graph_url, cli_main

ISO_FORMAT = "%Y-%m-%dT%H:%M"


def parse_dt(dt_str: str, tz: str) -> dict:
    if dt_str.endswith("Z"):
        dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
        timezone_name = "UTC"
    else:
        dt = datetime.fromisoformat(dt_str)
        timezone_name = tz
    return {"dateTime": dt.strftime("%Y-%m-%dT%H:%M:%S"), "timeZone": timezone_name}


def attendees_list(addresses: Optional[List[str]] = None) -> List[dict]:
    result = []
    for addr in addresses or []:
        addr = addr.strip()
        if not addr:
            continue
        result.append({"emailAddress": {"address": addr}})
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Gerencia eventos do calendário via Graph.")
    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list", help="Lista próximos eventos")
    p_list.add_argument("--start", help="Início (ISO). Default agora.")
    p_list.add_argument("--end", help="Fim (ISO). Default +7d.")
    p_list.add_argument("--top", type=int, default=20)
    p_list.add_argument("--tz", default="UTC")

    p_create = sub.add_parser("create", help="Cria evento")
    p_create.add_argument("--subject", required=True)
    p_create.add_argument("--start", required=True, help="YYYY-MM-DDTHH:MM")
    p_create.add_argument("--end", required=True, help="YYYY-MM-DDTHH:MM")
    p_create.add_argument("--tz", default="UTC")
    p_create.add_argument("--body")
    p_create.add_argument("--location")
    p_create.add_argument("--attendees", nargs="*")
    p_create.add_argument("--online", action="store_true", help="marca como reunião online")

    p_update = sub.add_parser("update", help="Atualiza evento existente")
    p_update.add_argument("event_id", help="ID do evento")
    p_update.add_argument("--subject")
    p_update.add_argument("--start")
    p_update.add_argument("--end")
    p_update.add_argument("--tz", default="UTC")
    p_update.add_argument("--body")
    p_update.add_argument("--location")
    p_update.add_argument("--attendees", nargs="*")

    p_cancel = sub.add_parser("cancel", help="Cancela evento e notifica")
    p_cancel.add_argument("event_id")
    p_cancel.add_argument("--message", default="Evento cancelado.")

    return parser


def handle_list(args: argparse.Namespace) -> None:
    now = datetime.now(timezone.utc)
    start = args.start or now.isoformat()
    end = args.end or (now.replace(microsecond=0) + timedelta(days=7)).isoformat()
    params = {"$top": args.top, "startDateTime": start, "endDateTime": end}
    resp = authorized_request("GET", graph_url("/me/calendarView"), params=params)
    data = resp.json()
    append_log({"action": "cal_list", "count": len(data.get("value", []))})
    print(json.dumps(data, indent=2))


def handle_create(args: argparse.Namespace) -> None:
    event = {
        "subject": args.subject,
        "body": {"contentType": "Text", "content": args.body or ""},
        "start": parse_dt(args.start, args.tz),
        "end": parse_dt(args.end, args.tz),
    }
    if args.location:
        event["location"] = {"displayName": args.location}
    atts = attendees_list(args.attendees)
    if atts:
        event["attendees"] = atts
    if args.online:
        event["isOnlineMeeting"] = True
        event["onlineMeetingProvider"] = "teamsForBusiness"
    resp = authorized_request("POST", graph_url("/me/events"), json=event)
    append_log({"action": "cal_create", "subject": args.subject, "id": resp.json().get("id")})
    print(json.dumps(resp.json(), indent=2))


def handle_update(args: argparse.Namespace) -> None:
    patch = {}
    if args.subject:
        patch["subject"] = args.subject
    if args.body:
        patch["body"] = {"contentType": "Text", "content": args.body}
    if args.start:
        patch["start"] = parse_dt(args.start, args.tz)
    if args.end:
        patch["end"] = parse_dt(args.end, args.tz)
    if args.location:
        patch["location"] = {"displayName": args.location}
    if args.attendees is not None:
        patch["attendees"] = attendees_list(args.attendees)
    if not patch:
        raise SystemExit("Nada para atualizar.")
    authorized_request("PATCH", graph_url(f"/me/events/{args.event_id}"), json=patch)
    append_log({"action": "cal_update", "id": args.event_id, "fields": list(patch.keys())})
    print("Evento atualizado.")


def handle_cancel(args: argparse.Namespace) -> None:
    authorized_request(
        "POST",
        graph_url(f"/me/events/{args.event_id}/cancel"),
        json={"Comment": args.message},
    )
    append_log({"action": "cal_cancel", "id": args.event_id})
    print("Evento cancelado.")


def handler():
    parser = build_parser()
    args = parser.parse_args()
    if args.command == "list":
        handle_list(args)
    elif args.command == "create":
        handle_create(args)
    elif args.command == "update":
        handle_update(args)
    elif args.command == "cancel":
        handle_cancel(args)


if __name__ == "__main__":
    cli_main(handler)
