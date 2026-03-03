#!/usr/bin/env python3
"""Manage OneDrive files via Microsoft Graph."""
import argparse
import json
from pathlib import Path

from utils import append_log, authorized_request, graph_url, cli_main


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Operações básicas no OneDrive pessoal via Graph")
    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list", help="Lista arquivos/pastas")
    p_list.add_argument("--path", default="/", help="Caminho (ex.: /Documentos)")
    p_list.add_argument("--top", type=int, default=50)

    p_upload = sub.add_parser("upload", help="Faz upload de arquivo")
    p_upload.add_argument("--local", required=True, type=Path)
    p_upload.add_argument("--remote", required=True, help="Destino em OneDrive (/Documentos/arquivo.ext)")

    p_download = sub.add_parser("download", help="Baixa arquivo")
    p_download.add_argument("--item-id", help="ID do item")
    p_download.add_argument("--remote", help="Caminho remoto se não tiver ID")
    p_download.add_argument("--local", type=Path, required=True)

    p_move = sub.add_parser("move", help="Move item para outra pasta")
    p_move.add_argument("item_id")
    p_move.add_argument("--dest", required=True, help="ID ou caminho da pasta destino")

    p_share = sub.add_parser("share", help="Gera link de compartilhamento")
    p_share.add_argument("item_id")
    p_share.add_argument("--scope", choices=["anonymous", "organization"], default="organization")
    p_share.add_argument("--type", choices=["view", "edit"], default="view")

    return parser


def list_items(path: str, top: int) -> None:
    encoded_path = path if path.startswith("/") else f"/{path}"
    url = graph_url(f"/me/drive/root:{encoded_path}:/children")
    resp = authorized_request("GET", url, params={"$top": top})
    data = resp.json()
    append_log({"action": "drive_list", "path": path, "count": len(data.get("value", []))})
    print(json.dumps(data, indent=2))


def upload_file(local: Path, remote: str) -> None:
    content = local.read_bytes()
    remote_path = remote if remote.startswith("/") else f"/{remote}"
    url = graph_url(f"/me/drive/root:{remote_path}:/content")
    resp = authorized_request("PUT", url, data=content, headers={"Content-Type": "application/octet-stream"})
    append_log({"action": "drive_upload", "name": local.name, "remote": remote})
    print(json.dumps(resp.json(), indent=2))


def resolve_item_path(remote: str) -> str:
    path = remote if remote.startswith("/") else f"/{remote}"
    resp = authorized_request("GET", graph_url(f"/me/drive/root:{path}"))
    return resp.json()["id"]


def download_file(item_id: str, remote: str, local: Path) -> None:
    if not item_id:
        if not remote:
            raise SystemExit("Informe --item-id ou --remote")
        item_id = resolve_item_path(remote)
    metadata = authorized_request("GET", graph_url(f"/me/drive/items/{item_id}"))
    download_url = metadata.json()["@microsoft.graph.downloadUrl"]
    resp = authorized_request("GET", download_url)
    local.write_bytes(resp.content)
    append_log({"action": "drive_download", "item": item_id, "local": str(local)})
    print(f"Arquivo salvo em {local}")


def move_item(item_id: str, dest: str) -> None:
    payload = {}
    if dest.startswith("/"):
        payload["parentReference"] = {"path": f"/drive/root:{dest}"}
    else:
        payload["parentReference"] = {"id": dest}
    resp = authorized_request("PATCH", graph_url(f"/me/drive/items/{item_id}"), json=payload)
    append_log({"action": "drive_move", "item": item_id, "dest": dest})
    print(json.dumps(resp.json(), indent=2))


def share_item(item_id: str, scope: str, link_type: str) -> None:
    resp = authorized_request(
        "POST",
        graph_url(f"/me/drive/items/{item_id}/createLink"),
        json={"type": link_type, "scope": scope},
    )
    append_log({"action": "drive_share", "item": item_id, "scope": scope, "type": link_type})
    print(json.dumps(resp.json(), indent=2))


def handler():
    parser = build_parser()
    args = parser.parse_args()
    if args.command == "list":
        list_items(args.path, args.top)
    elif args.command == "upload":
        upload_file(args.local, args.remote)
    elif args.command == "download":
        download_file(args.item_id, args.remote, args.local)
    elif args.command == "move":
        move_item(args.item_id, args.dest)
    elif args.command == "share":
        share_item(args.item_id, args.scope, args.type)


if __name__ == "__main__":
    cli_main(handler)
