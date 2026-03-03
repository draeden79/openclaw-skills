#!/usr/bin/env python3
"""Send email via Microsoft Graph."""
import argparse
import json
from pathlib import Path

from utils import append_log, authorized_request, encode_attachment, graph_url, parse_recipients, cli_main


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Envio de emails via Graph.")
    parser.add_argument("--to", nargs="+", required=True, help="Destinatários principais.")
    parser.add_argument("--subject", required=True)
    body_group = parser.add_mutually_exclusive_group(required=True)
    body_group.add_argument("--body", help="Conteúdo direto em texto.")
    body_group.add_argument("--body-file", type=Path, help="Arquivo com o corpo.")
    parser.add_argument("--html", action="store_true", help="Interpreta corpo como HTML.")
    parser.add_argument("--cc", nargs="*", default=[], help="Destinatários em cópia.")
    parser.add_argument("--bcc", nargs="*", default=[], help="Cópia oculta.")
    parser.add_argument("--attachment", nargs="*", default=[], help="Arquivos para anexar.")
    parser.add_argument("--importance", choices=["Low", "Normal", "High"], default="Normal")
    parser.add_argument("--no-save-copy", dest="save_copy", action="store_false", help="Não gravar em Sent Items.")
    parser.set_defaults(save_copy=True)
    return parser


def load_body(args: argparse.Namespace) -> str:
    if args.body_file:
        return args.body_file.read_text(encoding="utf-8")
    return args.body


def handler():
    parser = build_parser()
    args = parser.parse_args()
    body_content = load_body(args)
    attachments = [encode_attachment(Path(path)) for path in args.attachment]
    message = {
        "subject": args.subject,
        "importance": args.importance,
        "body": {"contentType": "HTML" if args.html else "Text", "content": body_content},
        "toRecipients": list(parse_recipients(args.to)),
    }
    if args.cc:
        message["ccRecipients"] = list(parse_recipients(args.cc))
    if args.bcc:
        message["bccRecipients"] = list(parse_recipients(args.bcc))
    if attachments:
        message["attachments"] = attachments
    payload = {"message": message, "saveToSentItems": args.save_copy}
    resp = authorized_request("POST", graph_url("/me/sendMail"), json=payload)
    if resp.status_code == 202:
        status = "queued"
    else:
        status = "sent"
    append_log({
        "action": "mail_send",
        "status": status,
        "subject": args.subject,
        "to": args.to,
        "cc": args.cc,
        "attachments": [Path(p).name for p in args.attachment],
    })
    print("Email enviado com sucesso.")


if __name__ == "__main__":
    cli_main(handler)
