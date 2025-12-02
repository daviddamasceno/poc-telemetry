# Service Performance Monitoring (SPM) - Configuração

Este documento descreve a configuração do Service Performance Monitoring (SPM) na POC de Observabilidade, que gera automaticamente métricas **RED** (Request, Error, Duration) a partir dos traces coletados.

## ✅ Status Atual

A configuração básica para SPM foi implementada e está funcionando:

| Componente | Status | Descrição |
|------------|--------|-----------|
| **Prometheus** | ✅ Configurado | Armazena métricas RED |
| **SpanMetrics Connector** | ✅ Configurado | Gera métricas a partir dos spans |
| **Métricas RED** | ✅ Funcionando | Exportadas para Prometheus na porta 8889 |
| **Dashboards Grafana** | ✅ Provisionados | Visualização automática das métricas |
| **Jaeger all-in-one** | ⚠️ Limitado | Não suporta SPM completo via UI (métricas disponíveis no Grafana) |

## 🔧 O que foi Configurado

### 1. Prometheus

- **Container**: `prometheus`
- **Porta**: `9090`
- **Configuração**: `observabilidade/prometheus/prometheus.yml`
- **Scraping**: Coleta métricas do OtelCollector na porta 8889
- **Armazenamento**: Volume persistente para histórico de métricas

### 2. OtelCollector com SpanMetrics Connector

- **Imagem**: `otel/opentelemetry-collector-contrib:latest` (inclui o connector)
- **Configuração**: `observabilidade/otel-collector-config.yaml`
- **SpanMetrics Connector**: 
  - Processa spans recebidos
  - Gera métricas RED automaticamente:
    - **R**equests: Contador de requisições (`traces_spanmetrics_calls_total`)
    - **E**rrors: Taxa de erros (`traces_spanmetrics_calls_total{status_code="error"}`)
    - **D**uration: Histograma de duração (`traces_spanmetrics_duration_milliseconds_bucket`)
- **Exportação**: Métricas expostas na porta 8889 para scraping do Prometheus

### 3. Jaeger

- **Status**: Jaeger all-in-one não suporta configuração completa de SPM via arquivo YAML
- **Alternativa**: Métricas estão disponíveis no Grafana e Prometheus
- **Para SPM Completo**: Seria necessário usar Jaeger distribuído (veja seção abaixo)

## 🔍 Como Verificar se Está Funcionando

### 1. Verificar Métricas no Prometheus

1. **Acesse**: http://localhost:9090

2. **Execute queries de exemplo**:

   **Contador de requisições por serviço:**
   ```promql
   traces_spanmetrics_calls_total
   ```

   **Taxa de requisições (requests por segundo):**
   ```promql
   sum(rate(traces_spanmetrics_calls_total[5m])) by (service_name)
   ```

   **Taxa de erros:**
   ```promql
   sum(rate(traces_spanmetrics_calls_total{status_code="error"}[5m])) by (service_name)
   ```

   **Latência P95 (percentil 95):**
   ```promql
   histogram_quantile(0.95, sum(rate(traces_spanmetrics_duration_milliseconds_bucket[5m])) by (le, service_name))
   ```

   **Latência P99:**
   ```promql
   histogram_quantile(0.99, sum(rate(traces_spanmetrics_duration_milliseconds_bucket[5m])) by (le, service_name))
   ```

### 2. Verificar Métricas do OtelCollector

1. **Acesse**: http://localhost:8889/metrics

2. **Procure por métricas** começando com `traces_spanmetrics_`:
   - `traces_spanmetrics_calls_total` - Contador de chamadas
   - `traces_spanmetrics_duration_milliseconds_bucket` - Histograma de duração
   - `traces_spanmetrics_calls_total{status_code="error"}` - Chamadas com erro

### 3. Verificar no Grafana

1. **Acesse**: http://localhost:3000
2. **Abra os dashboards provisionados**:
   - **POC Observability - Overview**: Métricas agregadas
   - **Python Services - Detailed Metrics**: Métricas detalhadas por serviço
3. **Verifique se os gráficos estão sendo atualizados** após gerar algumas requisições

### 4. Gerar Dados para Teste

Para gerar traces e consequentemente métricas:

```bash
# Fazer algumas requisições
curl http://localhost/api/python1/api/start

# Ou usar o script de teste
./scripts/test-requests.sh  # Linux/Mac
.\scripts\test-requests.ps1  # Windows
```

Aguarde alguns segundos para as métricas serem processadas e aparecerem no Prometheus/Grafana.

### 3. Habilitar SPM no Jaeger (Limitação do all-in-one)

O Jaeger all-in-one não suporta configuração completa de SPM via arquivo. As métricas estão disponíveis no Grafana e Prometheus, mas a aba "Monitor" no Jaeger UI não está habilitada.

**Opção 1: Usar Jaeger Distribuído** (Recomendado para produção)

Substituir `jaegertracing/all-in-one` por componentes individuais:

```yaml
services:
  jaeger-collector:
    image: jaegertracing/jaeger-collector:latest
    environment:
      - SPAN_STORAGE_TYPE=memory
      - METRICS_STORAGE_TYPE=prometheus
      - PROMETHEUS_SERVER_URL=http://prometheus:9090
    networks:
      - observability-network

  jaeger-query:
    image: jaegertracing/jaeger-query:latest
    environment:
      - SPAN_STORAGE_TYPE=memory
      - METRICS_STORAGE_TYPE=prometheus
      - PROMETHEUS_SERVER_URL=http://prometheus:9090
      - QUERY_BASE_PATH=/
    ports:
      - "16686:16686"
    networks:
      - observability-network
```

**Opção 2: Usar Grafana** (Recomendado para esta POC)

- As métricas já estão disponíveis nos dashboards do Grafana
- Visualização mais rica e customizável
- Integração com logs e traces

## 📁 Arquivos de Configuração

### `observabilidade/otel-collector-config.yaml`

Configuração principal do OtelCollector incluindo:

- **Receivers**: OTLP (gRPC e HTTP) para receber traces
- **Processors**: 
  - `spanmetrics`: Gera métricas RED dos spans
  - `batch`: Agrupa dados para melhor performance
- **Exporters**:
  - `jaeger`: Envia traces para Jaeger
  - `prometheus`: Expõe métricas na porta 8889
  - `loki`: Envia logs para Loki

### `observabilidade/prometheus/prometheus.yml`

Configuração do Prometheus:

- **Scrape Configs**:
  - `otel-collector`: Coleta métricas do OtelCollector (porta 8889)
  - `jaeger`: Coleta telemetria interna do Jaeger (opcional)

### `jaeger-config.yaml` (se existir)

- Tentativa de configuração do SPM (pode não funcionar com all-in-one)
- Não é necessário para o funcionamento básico

## 🚀 Próximos Passos

### Para Melhorar o SPM

1. **Configurar Alertas no Grafana**
   - Alertas para taxa de erros alta
   - Alertas para latência elevada
   - Alertas para queda de requisições

2. **Adicionar Métricas Customizadas**
   - Instrumentar aplicações com métricas de negócio
   - Adicionar atributos customizados aos spans

3. **Migrar para Jaeger Distribuído** (se necessário)
   - Substituir `jaegertracing/all-in-one` por componentes individuais
   - Configurar `jaeger-query` com suporte a Prometheus
   - Habilitar `monitor.menuEnabled=true` na UI

4. **Otimizar Retenção de Dados**
   - Configurar retenção no Prometheus
   - Configurar políticas de retenção no Loki

## 📊 Métricas Disponíveis

### Métricas RED Geradas Automaticamente

| Métrica | Tipo | Descrição |
|---------|------|-----------|
| `traces_spanmetrics_calls_total` | Counter | Total de requisições por serviço |
| `traces_spanmetrics_duration_milliseconds_bucket` | Histogram | Distribuição de latência |
| `traces_spanmetrics_calls_total{status_code="error"}` | Counter | Total de erros |

### Labels Disponíveis

- `service_name`: Nome do serviço (python1, python2, python3)
- `status_code`: Status da requisição (ok, error)
- `span_kind`: Tipo do span (server, client, etc.)

## 📚 Referências

- [Documentação SPM do Jaeger](https://www.jaegertracing.io/docs/2.12/architecture/spm/)
- [SpanMetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)
- [Prometheus Query Language (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)

## 💡 Dicas

- **Aguarde alguns minutos** após gerar traces para as métricas aparecerem
- **Use intervalos de tempo adequados** nas queries (5m, 15m, 1h)
- **Combine métricas** com logs e traces para análise completa
- **Configure alertas** para monitoramento proativo

