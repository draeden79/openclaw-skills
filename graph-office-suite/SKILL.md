---
name: graph-office-suite
description: Operar Outlook (e-mail), Calendário e OneDrive via Microsoft Graph usando o app público do Thunderbird. Inclui OAuth assistido (device code), envio/consulta de emails, gestão de eventos e arquivos. Use quando precisar ler ou enviar mensagens, atualizar agenda ou manipular arquivos diretamente pelo Graph.
---

# Graph Office Suite Skill

## 1. Pré-requisitos rápidos
1. Python 3 com `requests` instalado (já presente neste ambiente).
2. Variáveis padrão:
   - Client ID (Thunderbird): `871c010d-c5f5-44c4-a880-0f22c62b742a`
   - Tenant: `organizations` (ajuste se quiser restringir a um tenant específico)
   - Escopos default: `Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All Contacts.ReadWrite offline_access`
3. Tokens ficam em `state/graph_auth.json` (automaticamente gitignored).

## 2. Fluxo OAuth assistido (Device Code)
1. Rode o script:  
   ```bash
   python skills/graph-office-suite/scripts/graph_auth.py device-login \
     --scopes Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All Contacts.ReadWrite offline_access
   ```
2. Ele imprime **URL** e **código**. Cole ambos no chat para o Manuel autorizar.
3. Assim que ele confirmar em `https://microsoft.com/devicelogin`, o token+refresh token serão salvos.
4. Para acompanhar ou renovar manualmente:  
   - `python skills/graph-office-suite/scripts/graph_auth.py status`  
   - `python skills/graph-office-suite/scripts/graph_auth.py refresh`  
   - `python skills/graph-office-suite/scripts/graph_auth.py clear`
5. Os demais scripts chamam `utils.get_access_token()` que renova automaticamente ao detectar expiração.

> Referência detalhada em [`references/auth.md`](references/auth.md).

## 3. Operações de e-mail
- **Listar/filtrar**: `python skills/graph-office-suite/scripts/mail_fetch.py --folder Inbox --top 20 --unread`
- **Buscar mensagem específica**: `... --id <messageId> --include-body --mark-read`
- **Mover**: adicionar `--move-to <folderId>` no comando acima.
- **Enviar** (sempre com `saveToSentItems` ativado):
  ```bash
  python skills/graph-office-suite/scripts/mail_send.py \
    --to thais@example.com \
    --subject "Atualização" \
    --body-file replies/thais.html --html \
    --cc manuel@example.com \
    --attachment docs/proposta.pdf
  ```
- Use `--no-save-copy` somente se houver motivo para não registrar em Sent.

Mais exemplos e filtros em [`references/mail.md`](references/mail.md).

## 4. Calendário
- **Listar janela personalizada**:
  ```bash
  python skills/graph-office-suite/scripts/calendar_sync.py list \
    --start 2026-03-03T00:00Z --end 2026-03-05T23:59Z --top 50
  ```
- **Criar evento Teams/presencial**: usar subcomando `create` com `--online` quando quiser link Teams.
- **Atualizar/cancelar** eventos pelo `event_id` retornado no JSON.

Modelos completos em [`references/calendar.md`](references/calendar.md).

## 5. OneDrive / Arquivos
- **Listar pastas**: `python skills/graph-office-suite/scripts/drive_ops.py list --path /Documentos`
- **Upload**: `... upload --local notas/briefing.docx --remote /Clientes/briefing.docx`
- **Download**: `... download --remote /Clientes/briefing.docx --local /tmp/briefing.docx`
- **Mover** ou **gerar link** com os subcomandos `move` e `share`.

Detalhes adicionais em [`references/drive.md`](references/drive.md).

## 6. Contatos (opcional)
Os escopos incluem `Contacts.ReadWrite`. Para operações pontuais, use o endpoint `/me/contacts`. Exemplos mínimos:
```bash
curl -H "Authorization: Bearer $(python - <<<'from skills.graph-office-suite.scripts.utils import get_access_token; print(get_access_token())')" \
  https://graph.microsoft.com/v1.0/me/contacts
```
(Adicione scripts dedicados quando surgir demanda.)

## 7. Convenções e logging
- Cada script registra uma linha JSON em `state/graph_ops.log` contendo timestamp, ação e parâmetros relevantes.
- Tokens e logs nunca devem ser versionados.
- Pastas/scripts assumem execução a partir da raiz do workspace (`/home/ubuntu/.openclaw/workspace`). Ajuste caminhos se rodar de outro diretório.

## 8. Solução de problemas
| Sintoma | Ação |
| --- | --- |
| 401/invalid_grant | Rode `graph_auth.py refresh`; se falhar, execute `clear` e refaça o fluxo device code. |
| 403/AccessDenied | Escopo faltando ou licença inadequada. Repita device login com o escopo solicitado. |
| 429/Throttled | Scripts já fazem retry básico; espere alguns segundos e tente novamente. |
| `requests.exceptions.SSLError` | Verifique hora/data do sistema. |

Com isso, o skill cobre leitura/escrita de e-mails, agenda e arquivos pelo Graph partindo de um único fluxo OAuth autorizado pelo Manuel.
