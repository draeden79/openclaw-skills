# Auth Reference

## Perfis de autenticação recomendados

### Conta pessoal Microsoft (`@outlook.com`, `@hotmail.com`, Microsoft 365 Family)

- **Client ID padrão desta skill**: `9e5f94bc-e8a4-4e73-b8be-63364c29d753`
- **Tenant padrão desta skill**: `consumers`
- **Quando usar**: contas pessoais Microsoft (MSA), sem Entra ID corporativo.

### Conta corporativa/escolar (Microsoft Entra ID / Azure AD)

- **Tenant recomendado**: `organizations` (ou GUID do tenant)
- **Client ID**: app registration da organização (ou outro app permitido pelo tenant)
- **Quando usar**: contas de trabalho/escola com políticas de tenant.
- **Scopes sugeridos**:
  - `Mail.ReadWrite`
  - `Mail.Send`
  - `Calendars.ReadWrite`
  - `Files.ReadWrite.All`
  - `Contacts.ReadWrite` *(remova se não precisar de contato)*
  - `offline_access` (necessário para refresh token)

## Fluxo Device Code (assistido)

1. Rodar (conta pessoal): `python graph-office-suite/scripts/graph_auth.py device-login --client-id 9e5f94bc-e8a4-4e73-b8be-63364c29d753 --tenant-id consumers --scopes Mail.ReadWrite Mail.Send Calendars.ReadWrite Files.ReadWrite.All Contacts.ReadWrite offline_access`
2. O script imprime **URL** e **código**. Copie ambos pro chat.
3. O humano abre `https://microsoft.com/devicelogin`, cola o código e autentica com `tar.alitar@outlook.com`.
4. Após consentir, o script grava `state/graph_auth.json` com `access_token`, `refresh_token`, horário de expiração e os escopos.
5. Tokens são renovados automaticamente antes de cada chamada. Para forçar: `python graph-office-suite/scripts/graph_auth.py refresh`.

## Estrutura do arquivo state/graph_auth.json

```json
{
  "client_id": "9e5f94bc-e8a4-4e73-b8be-63364c29d753",
  "tenant_id": "consumers",
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
| `AADSTS50059` no `/devicecode` | Tenant incompatível com o tipo de conta. Para conta pessoal, use `--tenant-id consumers`. |
| `AADSTS700016` no tenant `consumers` | `client_id` não é válido para Microsoft Account. Use app registration compatível com MSA. |
| 401 constantes | Rode `graph_auth.py refresh`; se persistir, limpe estado e refaça device login. |
| 403 (Access Denied) | Adicione o escopo correspondente e refaça consentimento. |
