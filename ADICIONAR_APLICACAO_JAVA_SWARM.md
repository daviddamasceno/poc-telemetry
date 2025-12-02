# Guia: Adicionar Aplicação Java ao Docker Swarm na Stack de Observabilidade

Este guia explica passo a passo como configurar a stack de observabilidade para coletar **logs, traces e métricas** de uma aplicação Java rodando no **Docker Swarm** como service (exemplo: `api-pix`).

> **Nota**: Este guia assume que você já tem a stack de observabilidade rodando. Se não, consulte o [`README.md`](README.md) primeiro.

## 📋 Pré-requisitos

- ✅ Stack de observabilidade rodando (OtelCollector, Jaeger, Loki, Prometheus, Grafana, Promtail)
- ✅ Aplicação Java já instrumentada com OpenTelemetry
- ✅ Acesso ao Docker Swarm onde a aplicação será deployada
- ✅ Acesso aos arquivos de configuração da stack de observabilidade
- ✅ Rede Docker configurada para comunicação entre serviços

## 🔧 Passo a Passo

### 1. Configurar Promtail para Coletar Logs do Serviço Swarm

O Promtail precisa ser configurado para descobrir e coletar logs dos containers do serviço `api-pix` no Docker Swarm.

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
# Se a stack estiver em docker-compose
docker-compose restart promtail

# Se a stack estiver em Docker Swarm
docker service update --force observability-promtail
```

**Verificar se está funcionando:**

```bash
# Ver logs do Promtail procurando por "api-pix"
docker logs promtail | grep api-pix

# Ou se estiver em Swarm
docker service logs observability-promtail | grep api-pix
```

### 2. Configurar a Aplicação Java no Docker Swarm

A aplicação Java precisa estar configurada para enviar telemetria (traces, métricas e logs) para o OtelCollector através de variáveis de ambiente OpenTelemetry.

> **Importante**: A aplicação Java deve estar instrumentada com OpenTelemetry. Se não estiver, consulte a [documentação oficial](https://opentelemetry.io/docs/instrumentation/java/).

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

Para que o serviço `api-pix` acesse o OtelCollector, é necessário garantir que ambos estejam na mesma rede ou que o OtelCollector seja acessível via hostname/IP.

> **Nota**: No Docker Swarm, use redes do tipo `overlay` para comunicação entre serviços em diferentes nós.

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

Se a stack de observabilidade também estiver rodando no Docker Swarm (não apenas docker-compose), configure o OtelCollector como serviço do Swarm:

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

Após configurar tudo, siga estes passos para verificar se a telemetria está sendo coletada corretamente.

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

1. **Acesse a UI do Jaeger**: http://localhost:16686
2. **No dropdown "Service"**, procure por `api-pix`
3. **Selecione o serviço** e clique em **"Find Traces"**
4. **Deve aparecer traces** da aplicação Java

> **Dica**: Se não aparecer traces, aguarde alguns segundos e gere algumas requisições na aplicação Java.

### 3. Verificar Métricas no Grafana

1. **Acesse o Grafana**: http://localhost:3000
2. **Vá para os dashboards existentes**:
   - **POC Observability - Overview**: Métricas agregadas incluindo `api-pix`
   - **Python Services - Detailed Metrics**: Métricas detalhadas (pode ser adaptado para Java)
3. **Os painéis devem mostrar métricas** do serviço `api-pix` automaticamente
4. **As métricas são geradas automaticamente** pelo SpanMetrics Connector do OtelCollector

> **Nota**: As métricas são geradas a partir dos traces. Aguarde alguns minutos após gerar traces para as métricas aparecerem.

**Queries Prometheus para testar:**

```promql
# Taxa de requisições do api-pix
sum(rate(traces_spanmetrics_calls_total{service_name="api-pix"}[5m]))

# Duração P95 do api-pix
histogram_quantile(0.95, sum(rate(traces_spanmetrics_duration_milliseconds_bucket{service_name="api-pix"}[5m])) by (le))

# Taxa de erros
sum(rate(traces_spanmetrics_calls_total{service_name="api-pix", status_code="error"}[5m]))
```

### 4. Verificar Logs no Grafana

1. **Acesse o Grafana**: http://localhost:3000
2. **Vá para Explore** (ícone de bússola no menu lateral)
3. **Selecione o data source Loki** (já configurado)
4. **Use as seguintes queries LogQL**:

```logql
# Logs do api-pix
{container_name="api-pix"}

# Logs do api-pix com filtro por nível
{container_name="api-pix"} |= "ERROR"
{container_name="api-pix"} |= "WARNING"

# Logs do api-pix por task específica (Swarm)
{container_name="api-pix", task_id="1"}

# Logs do api-pix por serviço Swarm
{swarm_service="api-pix"}

# Buscar por texto específico
{container_name="api-pix"} |= "exception"
{container_name="api-pix"} |~ "error|exception|failed"
```

5. **Os logs também aparecem automaticamente** nos dashboards:
   - **POC Observability - Overview** → painel "Application Logs"
   - **Traces and Logs - Jaeger Integration** → painéis de logs

> 📖 Para mais detalhes sobre visualização de logs, consulte [`VIEW_LOGS.md`](VIEW_LOGS.md)

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

**Sintomas**: Logs do `api-pix` não aparecem no Grafana/Loki

**Soluções:**

1. **Verifique se o Promtail está rodando:**
   ```bash
   docker ps | grep promtail
   # Ou se estiver em Swarm
   docker service ps observability-promtail
   ```

2. **Verifique os logs do Promtail:**
   ```bash
   docker logs promtail
   # Procure por erros ou mensagens sobre api-pix
   ```

3. **Verifique se o regex no `promtail-config.yml` está correto:**
   - No Swarm, os nomes dos containers seguem o padrão: `<service_name>.<task_id>.<replica_id>`
   - Exemplo: `api-pix.1.abc123def`
   - O regex deve corresponder a este padrão

4. **Verifique se o container do serviço está sendo descoberto:**
   ```bash
   docker ps --format "{{.Names}}" | grep api-pix
   # Deve listar os containers do serviço
   ```

5. **Verifique labels disponíveis no Loki:**
   ```bash
   curl http://localhost:3100/loki/api/v1/label/container_name/values
   # Deve retornar "api-pix" na lista JSON
   ```

### Problema: Traces não aparecem no Jaeger

**Sintomas**: Traces do `api-pix` não aparecem na UI do Jaeger

**Soluções:**

1. **Verifique se as variáveis de ambiente OTEL estão configuradas corretamente:**
   ```bash
   docker service inspect api-pix | grep -A 20 "Env"
   # Ou
   docker exec <container_id> env | grep OTEL
   ```

2. **Verifique se o OtelCollector está acessível:**
   ```bash
   # Do container do api-pix, teste a conectividade
   docker exec <container_id> ping -c 3 otel-collector
   
   # Teste a porta gRPC
   docker exec <container_id> nc -zv otel-collector 4317
   ```

3. **Verifique os logs do OtelCollector:**
   ```bash
   docker logs otel-collector | grep -i "api-pix\|error"
   ```

4. **Verifique se o serviço está na mesma rede do OtelCollector:**
   ```bash
   docker network inspect observability-network
   # Verifique se api-pix e otel-collector estão na lista
   ```

5. **Teste a conectividade manualmente:**
   ```bash
   # Se o OtelCollector estiver em outro host
   curl http://<IP_OTEL_COLLECTOR>:4318
   ```

6. **Gere algumas requisições na aplicação** e aguarde alguns segundos

### Problema: Métricas não aparecem no Grafana

**Sintomas**: Métricas do `api-pix` não aparecem nos dashboards do Grafana

**Soluções:**

1. **Verifique se o SpanMetrics Connector está gerando métricas:**
   ```bash
   curl http://localhost:8889/metrics | grep traces_spanmetrics
   # Deve retornar métricas com service_name="api-pix"
   ```

2. **Verifique se o Prometheus está coletando do OtelCollector:**
   ```bash
   curl http://localhost:9090/api/v1/targets
   # Verifique se otel-collector está com status "up"
   ```

3. **Aguarde alguns minutos** após o deploy - as métricas são geradas a partir dos traces
   - Gere algumas requisições na aplicação
   - Aguarde 1-2 minutos para processamento

4. **Verifique no Prometheus diretamente:**
   ```bash
   # Acesse http://localhost:9090
   # Execute a query: traces_spanmetrics_calls_total{service_name="api-pix"}
   ```

### Problema: Rede não conectada

**Sintomas**: Serviço `api-pix` não consegue acessar o OtelCollector

**Soluções:**

1. **Verifique se a rede existe:**
   ```bash
   docker network ls | grep observability
   ```

2. **Verifique se a rede é overlay e attachable:**
   ```bash
   docker network inspect observability-network
   # Verifique: "Driver": "overlay", "Attachable": true
   ```

3. **Se necessário, recrie a rede:**
   ```bash
   # Remover rede antiga (cuidado: pode afetar outros serviços)
   docker network rm observability-network
   
   # Criar nova rede overlay attachable
   docker network create --driver overlay --attachable observability-network
   ```

4. **Reconecte o serviço:**
   ```bash
   docker service update --network-add observability-network api-pix
   ```

5. **Verifique se o serviço está na rede:**
   ```bash
   docker service inspect api-pix | grep -A 10 Networks
   ```

## 📝 Variáveis de Ambiente OTEL - Referência Completa

### Variáveis Essenciais

```bash
# Identificação do Serviço
OTEL_SERVICE_NAME=api-pix

# Endpoint do OtelCollector
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc  # ou http/protobuf

# Resource Attributes (metadados do serviço)
OTEL_RESOURCE_ATTRIBUTES=service.name=api-pix,service.version=1.0.0,deployment.environment=production

# Exporters
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
```

### Variáveis Opcionais (Recomendadas)

```bash
# Propagadores de Contexto
OTEL_PROPAGATORS=tracecontext,baggage

# Sampling
OTEL_TRACES_SAMPLER=always_on  # ou parentbased_always_on, traceidratio, etc.

# Intervalo de exportação de métricas (ms)
OTEL_METRICS_EXPORT_INTERVAL=60000

# Timeout de exportação (ms)
OTEL_EXPORTER_OTLP_TIMEOUT=10000

# Headers customizados (se necessário para autenticação)
OTEL_EXPORTER_OTLP_HEADERS=authorization=Bearer token123

# Instrumentação automática (Java)
OTEL_JAVAAGENT_ENABLED=true
```

> 📖 Para mais informações sobre variáveis OTEL, consulte a [documentação oficial](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)

## 🎯 Resumo Rápido

### Checklist de Configuração

- [ ] **1. Adicionar job no Promtail** (`observabilidade/promtail/promtail-config.yml`) para coletar logs
- [ ] **2. Configurar variáveis OTEL** no serviço Docker Swarm
- [ ] **3. Garantir networking** (mesma rede overlay attachable ou endpoint acessível)
- [ ] **4. Deploy do serviço** no Swarm
- [ ] **5. Verificar logs** no Grafana (Loki)
- [ ] **6. Verificar traces** no Jaeger
- [ ] **7. Verificar métricas** no Grafana/Prometheus

### Comandos Essenciais

```bash
# Reiniciar Promtail após configurar
docker-compose restart promtail  # ou docker service update --force observability-promtail

# Deploy do serviço Java
docker stack deploy -c docker-stack-api-pix.yml api-pix-stack

# Verificar status
docker service ps api-pix
docker service logs api-pix
```

## 📚 Recursos Adicionais

- [OpenTelemetry Java Instrumentation](https://opentelemetry.io/docs/instrumentation/java/)
- [OpenTelemetry Java Auto-Instrumentation](https://opentelemetry.io/docs/instrumentation/java/automatic/)
- [Docker Swarm Networking](https://docs.docker.com/engine/swarm/networking/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/configuration/)
- [Grafana Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Docker Swarm Services](https://docs.docker.com/engine/swarm/services/)

## 💡 Dicas Finais

- **Teste incrementalmente**: Configure logs primeiro, depois traces, depois métricas
- **Use labels consistentes**: Facilita queries e filtros no Grafana
- **Monitore recursos**: A coleta de telemetria consome recursos (CPU, memória, rede)
- **Configure retenção**: Ajuste retenção de dados no Loki e Prometheus conforme necessário
- **Documente customizações**: Mantenha documentação das configurações específicas do seu ambiente

---

> **Nota**: Este guia assume que a stack de observabilidade já está configurada e funcionando. Se encontrar problemas, consulte a seção de Troubleshooting, os logs dos serviços ou a documentação principal em [`README.md`](README.md).

