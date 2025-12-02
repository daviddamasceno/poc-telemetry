# Guia: Adicionar Aplicação Java ao Docker Swarm na Stack de Observabilidade

Este guia explica como configurar a stack de observabilidade para coletar logs, traces e métricas de uma aplicação Java rodando no Docker Swarm como service (exemplo: `api-pix`).

## 📋 Pré-requisitos

- Stack de observabilidade rodando (OtelCollector, Jaeger, Loki, Prometheus, Grafana, Promtail)
- Aplicação Java já instrumentada com OpenTelemetry
- Acesso ao Docker Swarm onde a aplicação será deployada
- Acesso aos arquivos de configuração da stack de observabilidade

## 🔧 Passo a Passo

### 1. Configurar Promtail para Coletar Logs do Serviço Swarm

O Promtail precisa ser configurado para descobrir e coletar logs dos containers do serviço `api-pix` no Docker Swarm.

**Arquivo:** `observabilidade/promtail/promtail-config.yml`

Adicione o seguinte job na seção `scrape_configs`:

```yaml
scrape_configs:
  # ... configurações existentes ...

  # Coleta logs do serviço Java no Docker Swarm (api-pix)
  - job_name: api-pix-swarm
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      # Filtrar containers do serviço api-pix do Swarm
      # No Swarm, o nome do container segue o padrão: <service_name>.<task_id>.<replica_id>
      - source_labels: ['__meta_docker_container_name']
        regex: '/api-pix\..*'  # Match: api-pix.1.abc123def, api-pix.2.xyz789, etc.
        action: keep
      # Adicionar labels
      - source_labels: ['__meta_docker_container_name']
        regex: '/api-pix\.([^.]+)\.([^.]+)'
        target_label: 'container_name'
        replacement: 'api-pix'
      - source_labels: ['__meta_docker_container_name']
        regex: '/api-pix\.([^.]+)\.([^.]+)'
        target_label: 'task_id'
        replacement: '${1}'
      - source_labels: ['__meta_docker_container_name']
        regex: '/api-pix\.([^.]+)\.([^.]+)'
        target_label: 'replica_id'
        replacement: '${2}'
      - source_labels: ['__meta_docker_container_label_com_docker_swarm_service_name']
        target_label: 'swarm_service'
      - source_labels: ['__meta_docker_container_label_com_docker_swarm_task_name']
        target_label: 'swarm_task'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'log_stream'
```

**Após adicionar a configuração, reinicie o Promtail:**

```bash
docker-compose restart promtail
```

### 2. Configurar a Aplicação Java no Docker Swarm

A aplicação Java precisa estar configurada para enviar telemetria (traces, métricas e logs) para o OtelCollector.

#### Opção A: Usando Docker Stack File

Crie ou edite o arquivo `docker-stack-api-pix.yml`:

```yaml
version: '3.8'

services:
  api-pix:
    image: sua-imagem-java:tag
    environment:
      # OpenTelemetry - Configuração do OtelCollector
      - OTEL_SERVICE_NAME=api-pix
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
      
      # Resource Attributes
      - OTEL_RESOURCE_ATTRIBUTES=service.name=api-pix,service.version=1.0.0,deployment.environment=production
      
      # Exporters
      - OTEL_TRACES_EXPORTER=otlp
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_LOGS_EXPORTER=otlp
      
      # Configurações adicionais recomendadas
      - OTEL_PROPAGATORS=tracecontext,baggage
      - OTEL_TRACES_SAMPLER=always_on
      - OTEL_METRICS_EXPORT_INTERVAL=60000
      
    networks:
      - observability-network  # Mesma rede do OtelCollector
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      placement:
        constraints:
          - node.role == worker  # Ajuste conforme necessário

networks:
  observability-network:
    external: true  # Se a rede já existir
    # ou
    # driver: overlay
    # attachable: true
```

**Deploy do stack:**

```bash
docker stack deploy -c docker-stack-api-pix.yml api-pix-stack
```

#### Opção B: Usando Docker Service Create

```bash
docker service create \
  --name api-pix \
  --env OTEL_SERVICE_NAME=api-pix \
  --env OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317 \
  --env OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
  --env OTEL_RESOURCE_ATTRIBUTES="service.name=api-pix,service.version=1.0.0" \
  --env OTEL_TRACES_EXPORTER=otlp \
  --env OTEL_METRICS_EXPORTER=otlp \
  --env OTEL_LOGS_EXPORTER=otlp \
  --network observability-network \
  --replicas 2 \
  sua-imagem-java:tag
```

### 3. Configurar Networking

Para que o serviço `api-pix` acesse o OtelCollector, é necessário garantir que ambos estejam na mesma rede ou que o OtelCollector seja acessível.

#### Opção A: Mesma Rede Overlay (Recomendado)

Se a stack de observabilidade estiver no mesmo Swarm, configure a rede como overlay:

**No stack da observabilidade (`docker-stack-observability.yml`):**

```yaml
networks:
  observability-network:
    driver: overlay
    attachable: true  # IMPORTANTE: Permite que outros serviços se conectem
```

**No serviço api-pix:**

```yaml
networks:
  - observability-network
```

#### Opção B: OtelCollector Acessível via Host

Se o OtelCollector estiver em outro host ou fora do Swarm:

**No serviço api-pix, use o IP do host ou hostname:**

```yaml
environment:
  - OTEL_EXPORTER_OTLP_ENDPOINT=http://<IP_DO_HOST_OBSERVABILIDADE>:4317
```

**Ou se o OtelCollector estiver em um host específico:**

```yaml
environment:
  - OTEL_EXPORTER_OTLP_ENDPOINT=http://observability-host:4317
```

### 4. Configurar OtelCollector no Swarm (se necessário)

Se a stack de observabilidade também estiver no Swarm, configure assim:

**Arquivo:** `docker-stack-observability.yml`

```yaml
version: '3.8'

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./observabilidade/otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317"  # GRPC
      - "4318:4318"  # HTTP
      - "8889:8889"  # Prometheus metrics
    networks:
      - observability-network
    deploy:
      placement:
        constraints:
          - node.role == manager  # Ou worker, conforme necessário
      replicas: 1

networks:
  observability-network:
    driver: overlay
    attachable: true  # IMPORTANTE: Permite que outros serviços se conectem
```

## ✅ Verificação e Testes

### 1. Verificar se o Promtail está Coletando Logs

```bash
# Verificar logs do Promtail
docker logs promtail | grep api-pix

# Verificar labels no Loki via API
curl http://localhost:3100/loki/api/v1/label/container_name/values
# Deve retornar "api-pix" na lista JSON

# Ou via PowerShell
Invoke-WebRequest -Uri "http://localhost:3100/loki/api/v1/label/container_name/values" -UseBasicParsing | Select-Object -ExpandProperty Content
```

### 2. Verificar Traces no Jaeger

1. Acesse a UI do Jaeger: `http://localhost:16686`
2. No dropdown "Service", procure por `api-pix`
3. Selecione o serviço e clique em "Find Traces"
4. Deve aparecer traces da aplicação Java

### 3. Verificar Métricas no Grafana

1. Acesse o Grafana: `http://localhost:3000`
2. Vá para os dashboards existentes:
   - **POC Observability - Overview**
   - **Python Services - Detailed Metrics**
3. Os painéis devem mostrar métricas do serviço `api-pix` automaticamente
4. As métricas são geradas automaticamente pelo SpanMetrics Connector do OtelCollector

**Query Prometheus para testar:**

```promql
# Taxa de requisições do api-pix
sum(rate(traces_span_metrics_calls_total{service_name="api-pix"}[5m]))

# Duração P95 do api-pix
histogram_quantile(0.95, sum(rate(traces_span_metrics_duration_milliseconds_bucket{service_name="api-pix"}[5m])) by (le))
```

### 4. Verificar Logs no Grafana

1. Acesse o Grafana: `http://localhost:3000`
2. Vá para **Explore** (ícone de bússola)
3. Selecione o data source **Loki**
4. Use as seguintes queries LogQL:

```logql
# Logs do api-pix
{container_name="api-pix"}

# Logs do api-pix com filtro por nível
{container_name="api-pix"} |= "ERROR"

# Logs do api-pix por task específica
{container_name="api-pix", task_id="1"}

# Logs do api-pix por serviço Swarm
{swarm_service="api-pix"}
```

5. Os logs também aparecem automaticamente nos dashboards:
   - **POC Observability - Overview** → painel "Application Logs"
   - **Traces and Logs - Jaeger Integration** → painéis de logs

### 5. Verificar Status do Serviço no Swarm

```bash
# Listar serviços do Swarm
docker service ls

# Ver detalhes do serviço api-pix
docker service ps api-pix

# Ver logs do serviço
docker service logs api-pix

# Verificar se está na rede correta
docker service inspect api-pix | grep -A 10 Networks
```

## 🔍 Troubleshooting

### Problema: Logs não aparecem no Loki

**Soluções:**
1. Verifique se o Promtail está rodando: `docker ps | grep promtail`
2. Verifique os logs do Promtail: `docker logs promtail`
3. Verifique se o regex no `promtail-config.yml` está correto para o padrão de nomes do Swarm
4. Verifique se o container do serviço está sendo descoberto:
   ```bash
   docker ps --format "{{.Names}}" | grep api-pix
   ```

### Problema: Traces não aparecem no Jaeger

**Soluções:**
1. Verifique se as variáveis de ambiente OTEL estão configuradas corretamente no serviço
2. Verifique se o OtelCollector está acessível:
   ```bash
   # Do container do api-pix, teste a conectividade
   docker exec <container_id> ping otel-collector
   ```
3. Verifique os logs do OtelCollector: `docker logs otel-collector`
4. Verifique se o serviço está na mesma rede do OtelCollector
5. Teste a conectividade manualmente:
   ```bash
   # Se o OtelCollector estiver em outro host
   curl http://<IP_OTEL_COLLECTOR>:4318
   ```

### Problema: Métricas não aparecem no Grafana

**Soluções:**
1. Verifique se o SpanMetrics Connector está gerando métricas:
   ```bash
   curl http://localhost:8889/metrics | grep traces_span_metrics
   ```
2. Verifique se o Prometheus está coletando do OtelCollector:
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```
3. Aguarde alguns minutos após o deploy - as métricas são geradas a partir dos traces

### Problema: Rede não conectada

**Soluções:**
1. Verifique se a rede existe: `docker network ls | grep observability`
2. Verifique se a rede é overlay e attachable:
   ```bash
   docker network inspect observability-network
   ```
3. Se necessário, recrie a rede:
   ```bash
   docker network create --driver overlay --attachable observability-network
   ```
4. Reconecte o serviço:
   ```bash
   docker service update --network-add observability-network api-pix
   ```

## 📝 Variáveis de Ambiente OTEL - Referência Completa

```bash
# Identificação do Serviço
OTEL_SERVICE_NAME=api-pix

# Endpoint do OtelCollector
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc  # ou http

# Resource Attributes (metadados do serviço)
OTEL_RESOURCE_ATTRIBUTES=service.name=api-pix,service.version=1.0.0,deployment.environment=production

# Exporters
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp

# Propagadores de Contexto
OTEL_PROPAGATORS=tracecontext,baggage

# Sampling
OTEL_TRACES_SAMPLER=always_on  # ou parentbased_always_on, traceidratio, etc.

# Intervalo de exportação de métricas (ms)
OTEL_METRICS_EXPORT_INTERVAL=60000

# Timeout de exportação (ms)
OTEL_EXPORTER_OTLP_TIMEOUT=10000

# Headers customizados (se necessário)
OTEL_EXPORTER_OTLP_HEADERS=authorization=Bearer token123
```

## 🎯 Resumo Rápido

1. **Adicionar job no Promtail** (`observabilidade/promtail/promtail-config.yml`) para coletar logs
2. **Configurar variáveis OTEL** no serviço Docker Swarm
3. **Garantir networking** (mesma rede ou endpoint acessível)
4. **Deploy do serviço** no Swarm
5. **Verificar** logs, traces e métricas nos dashboards

## 📚 Recursos Adicionais

- [OpenTelemetry Java Instrumentation](https://opentelemetry.io/docs/instrumentation/java/)
- [Docker Swarm Networking](https://docs.docker.com/engine/swarm/networking/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/configuration/)
- [Grafana Loki LogQL](https://grafana.com/docs/loki/latest/logql/)

---

**Nota:** Este guia assume que a stack de observabilidade já está configurada e funcionando. Se encontrar problemas, consulte a seção de Troubleshooting ou os logs dos serviços.

