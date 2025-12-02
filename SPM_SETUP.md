# Service Performance Monitoring (SPM) - Configuração

## Status Atual

A configuração básica para SPM foi implementada:

✅ **Prometheus** - Adicionado ao docker-compose  
✅ **SpanMetrics Connector** - Configurado no OtelCollector  
✅ **Métricas exportadas** - OtelCollector exporta métricas RED para Prometheus na porta 8889

⚠️ **Jaeger all-in-one** - Tem limitações para configuração de SPM via arquivo YAML

## O que foi configurado

### 1. Prometheus
- Container: `prometheus`
- Porta: `9090`
- Configuração: `prometheus/prometheus.yml`
- Scraping: Coleta métricas do OtelCollector na porta 8889

### 2. OtelCollector com SpanMetrics Connector
- Imagem: `otel/opentelemetry-collector-contrib:latest` (contém o connector)
- Configuração: `otel-collector-config.yaml`
- SpanMetrics Connector: Gera métricas RED (Request, Error, Duration) dos spans
- Exporta métricas para Prometheus na porta 8889

### 3. Jaeger
- O Jaeger all-in-one não suporta configuração completa de SPM via arquivo YAML
- Para habilitar o SPM completamente, seria necessário usar o Jaeger distribuído

## Como verificar se está funcionando

### 1. Verificar métricas no Prometheus

Acesse: http://localhost:9090

Execute a query:
```promql
traces_spanmetrics_calls_total
```

Ou:
```promql
traces_spanmetrics_duration_milliseconds_bucket
```

### 2. Verificar métricas do OtelCollector

Acesse: http://localhost:8889/metrics

Você deve ver métricas como:
- `traces_spanmetrics_calls_total`
- `traces_spanmetrics_duration_milliseconds_bucket`

### 3. Habilitar SPM no Jaeger (Limitação do all-in-one)

O Jaeger all-in-one não suporta configuração completa de SPM via arquivo. Para habilitar completamente:

**Opção 1: Usar Jaeger Distribuído** (Recomendado para produção)
- Substituir `jaegertracing/all-in-one` por componentes individuais
- Configurar `jaeger-query` com suporte a Prometheus
- Habilitar `monitor.menuEnabled=true` na UI

**Opção 2: Usar UI customizada**
- Modificar a UI do Jaeger para habilitar o menu Monitor
- Configurar via variáveis de ambiente (se suportado)

## Arquivos de Configuração

### `otel-collector-config.yaml`
- Configura o SpanMetrics Connector
- Exporta métricas para Prometheus

### `prometheus/prometheus.yml`
- Configura scraping do OtelCollector
- Configura scraping do Jaeger (telemetria interna)

### `jaeger-config.yaml`
- Tentativa de configuração do SPM (pode não funcionar com all-in-one)

## Próximos Passos

Para habilitar completamente o SPM:

1. **Substituir Jaeger all-in-one por componentes distribuídos:**
   - `jaegertracing/jaeger-query`
   - `jaegertracing/jaeger-collector`
   - `jaegertracing/jaeger-agent`

2. **Configurar jaeger-query com:**
   ```yaml
   query:
     metrics-storage-type: prometheus
     prometheus:
       server-url: http://prometheus:9090
   ```

3. **Habilitar menu na UI:**
   - Configurar `monitor.menuEnabled=true`

## Referências

- [Documentação SPM do Jaeger](https://www.jaegertracing.io/docs/2.12/architecture/spm/)
- [SpanMetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)

