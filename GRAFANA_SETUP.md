# Configuração Automática do Grafana

## Status da Configuração

✅ **Data Sources Provisionados Automaticamente:**
- Loki (http://loki:3100) - Para logs
- Prometheus (http://prometheus:9090) - Para métricas
- Jaeger (http://jaeger:16686) - Para traces

✅ **Dashboards Provisionados:**
- POC Observability - Overview
- Python Services - Detailed Metrics
- Traces and Logs - Jaeger Integration

## Estrutura de Arquivos

```
grafana/
├── provisioning/
│   ├── datasources/
│   │   └── datasources.yml      # Configuração dos data sources
│   └── dashboards/
│       └── dashboard.yml       # Configuração de provisioning dos dashboards
└── dashboards/                  # (arquivos movidos para provisioning/dashboards)
    ├── poc-overview.json
    ├── python-services.json
    └── traces-and-logs.json
```

## Como Verificar

1. **Acesse o Grafana**: http://localhost:3000
   - Login: `admin` / Senha: `admin`

2. **Verifique Data Sources**:
   - Vá em: Configuration → Data Sources
   - Você deve ver: Loki, Prometheus e Jaeger já configurados

3. **Verifique Dashboards**:
   - Vá em: Dashboards → Browse
   - Procure pela pasta "POC"
   - Você deve ver os 3 dashboards:
     - POC Observability - Overview
     - Python Services - Detailed Metrics
     - Traces and Logs - Jaeger Integration

## Troubleshooting

### Dashboards não aparecem

1. Verifique se os arquivos JSON estão no container:
   ```bash
   docker-compose exec grafana ls -la /etc/grafana/provisioning/dashboards/
   ```

2. Verifique se o arquivo dashboard.yml está correto:
   ```bash
   docker-compose exec grafana cat /etc/grafana/provisioning/dashboards/dashboard.yml
   ```

3. Verifique os logs do Grafana:
   ```bash
   docker-compose logs grafana | grep -i dashboard
   ```

4. Reinicie o Grafana:
   ```bash
   docker-compose restart grafana
   ```

### Data Sources não aparecem

1. Verifique o arquivo de configuração:
   ```bash
   docker-compose exec grafana cat /etc/grafana/provisioning/datasources/datasources.yml
   ```

2. Verifique se os serviços estão acessíveis:
   - Loki: http://localhost:3100
   - Prometheus: http://localhost:9090
   - Jaeger: http://localhost:16686

## Notas

- Os dashboards são provisionados automaticamente quando o Grafana inicia
- Alterações nos arquivos JSON serão refletidas após reiniciar o Grafana
- Os dashboards podem ser editados na UI do Grafana (allowUiUpdates: true)

