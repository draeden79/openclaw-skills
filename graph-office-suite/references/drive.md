# OneDrive Reference

## Listar itens

```
python skills/graph-office-suite/scripts/drive_ops.py list --path /Documentos --top 20
```

## Upload

```
python skills/graph-office-suite/scripts/drive_ops.py upload --local arquivos/briefing.docx --remote /Clientes/briefing.docx
```

## Download

```
python skills/graph-office-suite/scripts/drive_ops.py download --remote /Clientes/briefing.docx --local /tmp/briefing.docx
```

## Mover

```
python skills/graph-office-suite/scripts/drive_ops.py move <itemId> --dest /Arquivo/Processado
```

## Compartilhar link

```
python skills/graph-office-suite/scripts/drive_ops.py share <itemId> --scope organization --type view
```

### Dicas
- Caminhos remotos sempre começam com `/`.
- Para descobrir `item_id`, rode `list` e copie o campo `id`.
- Upload chunked ainda não implementado; arquivos maiores que 4 MB exigem melhoria futura.
