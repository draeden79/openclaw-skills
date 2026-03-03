# OneDrive Reference

## Listar itens

```
python graph-office-suite/scripts/drive_ops.py list --path / --top 20
python graph-office-suite/scripts/drive_ops.py list --path /Documentos --top 20
python graph-office-suite/scripts/drive_ops.py list --path /Documents --top 20
```

## Upload

```
python graph-office-suite/scripts/drive_ops.py upload --local arquivos/briefing.docx --remote /Clientes/briefing.docx
```

## Download

```
python graph-office-suite/scripts/drive_ops.py download --remote /Clientes/briefing.docx --local /tmp/briefing.docx
```

## Mover

```
python graph-office-suite/scripts/drive_ops.py move <itemId> --dest /Arquivo/Processado
```

## Compartilhar link

```
python graph-office-suite/scripts/drive_ops.py share <itemId> --scope organization --type view
```

### Dicas
- Caminhos remotos sempre começam com `/`.
- O script resolve pastas especiais por nome local e por alias global (ex.: `Documents` ou `Documentos` para documentos).
- Para caminhos no root, `--path /` usa endpoint dedicado da raiz.
- Para descobrir `item_id`, rode `list` e copie o campo `id`.
- Upload chunked ainda não implementado; arquivos maiores que 4 MB exigem melhoria futura.
