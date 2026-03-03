# Calendar Reference

## Listar eventos

```
python skills/graph-office-suite/scripts/calendar_sync.py list --start 2026-03-03T00:00Z --end 2026-03-05T00:00Z --top 20
```

Sem parâmetros, `list` cobre agora até +7 dias.

## Criar evento

```
python skills/graph-office-suite/scripts/calendar_sync.py create \
  --subject "Reunião com Danilo" \
  --start 2026-03-05T12:00 \
  --end 2026-03-05T13:00 \
  --tz America/Sao_Paulo \
  --body "Almoço no Sage" \
  --location "Sage" \
  --attendees danilo@example.com manuel@example.com \
  --online
```

## Atualizar evento

```
python skills/graph-office-suite/scripts/calendar_sync.py update <eventId> --start 2026-03-05T12:30 --end 2026-03-05T13:30
```

## Cancelar

```
python skills/graph-office-suite/scripts/calendar_sync.py cancel <eventId> --message "Precisamos remarcar."
```

### Notas
- Datas sempre em ISO 8601. Adicione `Z` para UTC explícito.
- `--online` marca meeting Teams; remova se for reunião presencial.
- Atualizações aceitam `--attendees` para sobrescrever a lista inteira.
