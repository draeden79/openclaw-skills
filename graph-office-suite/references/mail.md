# Mail Reference

## Listagem

```
python skills/graph-office-suite/scripts/mail_fetch.py --folder Inbox --top 10 --unread
```

- `--filter` aceita expressões OData (`contains(subject,'Thais')`).
- `--id <messageId>` busca mensagem específica.
- `--include-body` traz corpo completo (HTML + texto).
- `--mark-read` e `--move-to <folderId>` atuam sobre a mensagem carregada com `--id`.

## Envio

```
python skills/graph-office-suite/scripts/mail_send.py \
  --to thais@example.com \
  --subject "Follow-up" \
  --body-file drafts/reply.html --html \
  --cc manuel@example.com \
  --attachment docs/proposta.pdf
```

- `saveToSentItems` é `True` por padrão. Use `--no-save-copy` se quiser desabilitar.
- Anexos são convertidos para fileAttachment e limitados a 3 MB nesse endpoint; para maiores, usar upload session (futuro).

## IDs de pasta úteis

Liste pastas com:
```
curl -H "Authorization: Bearer $(python -m scripts.print_token)" \
  https://graph.microsoft.com/v1.0/me/mailFolders
```
Ou adapte `mail_fetch.py --folder 'SentItems'`.

## Desduplicação / watch

Use `state/email_watch.json` como base para armazenar o `receivedDateTime` e ID da última mensagem processada.
