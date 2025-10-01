# Daily Metrics Storage

Este directorio almacena las métricas diarias generadas por el sistema de testing automático.

## 📊 Estructura de Archivos

```
daily-metrics/
├── daily_metrics_20251001.json
├── daily_metrics_20251002.json
├── daily_metrics_20251003.json
└── ...
```

## 📝 Formato de Archivo

Cada archivo sigue el patrón: `daily_metrics_YYYYMMDD.json`

Ejemplo: `daily_metrics_20251001.json`

## 🔒 Git Ignore

Los archivos `.json` en este directorio están excluidos del control de versiones (.gitignore) para evitar commits innecesarios de datos temporales.

## 📈 Uso

Las métricas son:
- **Generadas**: Por `daily-testing-runner.ps1`
- **Leídas**: Por `generate-daily-report.ps1`
- **Analizadas**: Para reportes y tendencias históricas

## 🗑️ Limpieza

Se recomienda mantener solo los últimos 90 días de métricas para no acumular archivos innecesarios:

```powershell
# Eliminar métricas mayores a 90 días
Get-ChildItem -Path daily-metrics -Filter "daily_metrics_*.json" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } |
    Remove-Item
```

## 📍 Ubicación

`tests/automation/daily-metrics/`
