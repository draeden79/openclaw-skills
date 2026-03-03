# Auth Reference

## Public client (Thunderbird)

- **Client ID**: `871c010d-c5f5-44c4-a880-0f22c62b742a` (Mozilla Thunderbird)
- **Tenant**: use `organizations` unless a dedicated tenant ID is required
- **Scopes sugeridos**:
  - `Mail.ReadWrite`
  - `Mail.Send`
  - `Calendars.ReadWrite`
  - `Files.ReadWrite.All`
  - `Contacts.ReadWrite` *(remova se não precisar de contato)*
  - `offline_access` (necessário para refresh token)

## Fluxo Device Code (assistido)

1. Rodar: `python skills/graph-office-suite/scripts/graph_auth.py device-login --scopes Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All Contacts.ReadWrite offline_access`
2. O script imprime **URL** e **código**. Copie ambos pro chat.
3. O humano abre `https://microsoft.com/devicelogin`, cola o código e autentica com `tar.alitar@outlook.com`.
4. Após consentir, o script grava `state/graph_auth.json` com `access_token`, `refresh_token`, horário de expiração e os escopos.
5. Tokens são renovados automaticamente antes de cada chamada. Para forçar: `python skills/graph-office-suite/scripts/graph_auth.py refresh`.

## Estrutura do arquivo state/graph_auth.json

```json
{
  "client_id": "871c010d-c5f5-44c4-a880-0f22c62b742a",
  "tenant_id": "organizations",
  "scopes": ["Mail.ReadWrite", "Mail.Send", ...],
  "token": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_at": 1234567890
  }
}
```

Nunca versionar esse arquivo (`.gitignore`).

## Erros comuns

| Sintoma | Solução |
| --- | --- |
| `authorization_pending` | Aguarde — o usuário ainda não autorizou. |
| `interaction_required` | O usuário precisa repetir o fluxo (token inválido/consent removido). |
| 401 constantes | Rode `graph_auth.py refresh`; se persistir, limpe estado e refaça device login. |
| 403 (Access Denied) | Adicione o escopo correspondente e refaça consentimento. |
