# POC - Observabilidade com Nginx e OpenTelemetry

Esta é uma Proof of Concept (POC) que demonstra a coleta completa de telemetria (traces, logs e métricas) de aplicações Python através de um Nginx usando Docker Compose. A stack implementa uma solução completa de observabilidade baseada em OpenTelemetry, permitindo monitoramento, rastreamento distribuído e análise de logs.

## 🏗️ Arquitetura

A POC consiste em **11 serviços Docker** organizados em duas redes:

### Aplicações de Negócio
- **python1, python2, python3**: Três aplicações Python idênticas que se comunicam entre si, instrumentadas com OpenTelemetry
- **nginx**: Camada de proxy reverso que roteia requisições entre as aplicações Python

### Stack de Observabilidade
- **otel-collector**: Coletor OpenTelemetry que recebe, processa e exporta traces, logs e métricas
- **jaeger**: Backend para visualização de traces distribuídos
- **loki**: Agregador de logs
- **promtail**: Coletor de logs dos containers Docker
- **prometheus**: Armazenamento de métricas
- **grafana**: Dashboard unificado para visualização de métricas, logs e traces

## 🔄 Fluxo de Comunicação e Telemetria

```
Cliente → Nginx → Python1 → Nginx → Python2 → Nginx → Python3
                ↓                                    ↓
         OtelCollector ← ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
                ↓
    ┌───────────┼───────────┬───────────┐
    ↓           ↓           ↓           ↓
  Jaeger     Loki      Prometheus   Grafana
    ↑           ↑           ↑           ↑
    └───────────┴───────────┴───────────┘
         (Visualização Unificada)
```

### Fluxo de Dados

1. **Traces**: Aplicações Python → OtelCollector (gRPC:4317) → Jaeger → Grafana
2. **Logs**: Aplicações Python → OtelCollector → Loki ← Promtail (coleta de containers)
3. **Métricas**: OtelCollector (SpanMetrics) → Prometheus → Grafana

## 📁 Estrutura do Projeto

```
poc-telemetry/
├── docker-compose.yml                    # Orquestração de todos os serviços
├── README.md                             # Este arquivo
├── GRAFANA_SETUP.md                      # Configuração do Grafana
├── SPM_SETUP.md                          # Service Performance Monitoring
├── VIEW_LOGS.md                          # Guia de visualização de logs
├── ADICIONAR_APLICACAO_JAVA_SWARM.md     # Guia para adicionar apps Java
├── .env.example                          # Exemplo de variáveis de ambiente
├── python-app/
│   ├── Dockerfile                        # Dockerfile para aplicações Python
│   ├── app.py                            # Aplicação Python (usada por python1, python2, python3)
│   └── requirements.txt                  # Dependências Python
├── nginx/
│   ├── Dockerfile
│   ├── nginx.conf                        # Configuração principal do Nginx
│   └── conf.d/
│       └── default.conf                  # Configuração de roteamento
└── observabilidade/
    ├── otel-collector-config.yaml        # Configuração do OpenTelemetry Collector
    ├── prometheus/
    │   └── prometheus.yml                # Configuração do Prometheus
    ├── promtail/
    │   └── promtail-config.yml           # Configuração do Promtail
    └── grafana/
        └── provisioning/                 # Provisionamento automático do Grafana
            ├── datasources/
            │   └── datasources.yml
            └── dashboards/
                └── dashboard.yml
```

## 📋 Pré-requisitos

- **Docker** (versão 20.10 ou superior)
- **Docker Compose** (versão 2.0 ou superior)
- **Portas disponíveis**: 80, 3000, 3100, 4317, 4318, 8001-8003, 9090, 16686
- **Memória**: Mínimo 4GB RAM recomendado

## 🚀 Como Executar

### Início Rápido

1. **Clone ou copie os arquivos do projeto**

2. **Configure as variáveis de ambiente (opcional)**
   ```bash
   cp .env.example .env
   # Edite o arquivo .env conforme necessário
   ```

3. **Inicie todos os serviços**
   ```bash
   docker-compose up -d
   ```

4. **Aguarde a inicialização completa** (aproximadamente 30-60 segundos)
   ```bash
   # Verifique o status dos containers
   docker-compose ps
   
   # Verifique os logs para garantir que tudo iniciou corretamente
   docker-compose logs -f
   ```

5. **Acesse os serviços**:
   - **Grafana**: http://localhost:3000 (admin/admin)
   - **Jaeger**: http://localhost:16686
   - **Prometheus**: http://localhost:9090
   - **Aplicação**: http://localhost

## 🌐 Endpoints Disponíveis

### Aplicações Python

Cada aplicação Python (python1, python2, python3) expõe os seguintes endpoints:

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/` | GET | Informações sobre a aplicação e endpoints disponíveis |
| `/health` | GET | Health check da aplicação |
| `/api/start` | GET | Dispara uma requisição GET para o `TARGET_URL` configurado |
| `/api/receive` | GET/POST | Recebe requisições |

**Acesso direto** (bypass Nginx):
- `http://localhost:8001` - python1
- `http://localhost:8002` - python2
- `http://localhost:8003` - python3

### Nginx (Proxy Reverso)

| Endpoint | Descrição |
|----------|-----------|
| `http://localhost/api/python1` | Roteia para python1 |
| `http://localhost/api/python2` | Roteia para python2 |
| `http://localhost/api/python3` | Roteia para python3 |
| `http://localhost/health` | Health check do Nginx |

### Stack de Observabilidade

| Serviço | URL | Credenciais | Descrição |
|---------|-----|-------------|-----------|
| **Grafana** | http://localhost:3000 | admin/admin | Dashboard unificado (métricas, logs, traces) |
| **Jaeger UI** | http://localhost:16686 | - | Visualização de traces distribuídos |
| **Prometheus** | http://localhost:9090 | - | Armazenamento e consulta de métricas |
| **Loki** | http://localhost:3100 | - | API de logs (usado pelo Grafana) |
| **OtelCollector Metrics** | http://localhost:8889/metrics | - | Métricas expostas pelo coletor |

## ⚙️ Variáveis de Ambiente

As principais variáveis de ambiente configuráveis estão no arquivo `.env.example`:

### Portas
| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `NGINX_PORT` | 80 | Porta do Nginx |
| `PYTHON1_PORT`, `PYTHON2_PORT`, `PYTHON3_PORT` | 8001, 8002, 8003 | Portas das aplicações Python |
| `JAEGER_UI_PORT` | 16686 | Porta da UI do Jaeger |
| `GRAFANA_PORT` | 3000 | Porta do Grafana |
| `LOKI_PORT` | 3100 | Porta do Loki |
| `PROMETHEUS_PORT` | 9090 | Porta do Prometheus |
| `OTEL_HTTP_PORT`, `OTEL_GRPC_PORT` | 4318, 4317 | Portas do OtelCollector |

### URLs de Destino (Cadeia de Requisições)
| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `PYTHON1_TARGET_URL` | `http://nginx:80/api/python2/api/start` | URL que python1 chamará |
| `PYTHON2_TARGET_URL` | `http://nginx:80/api/python3` | URL que python2 chamará |
| `PYTHON3_TARGET_URL` | `http://nginx:80/api/python1` | URL que python3 chamará |

### Credenciais
| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `GRAFANA_USER` | admin | Usuário do Grafana |
| `GRAFANA_PASSWORD` | admin | Senha do Grafana |

## 🧪 Scripts de Teste

Scripts para facilitar os testes das aplicações estão disponíveis em `scripts/`:

- **`test-requests.sh`** - Script bash para Linux/Mac
- **`test-requests.ps1`** - Script PowerShell para Windows

### Executar os Scripts

**Linux/Mac:**
```bash
chmod +x scripts/test-requests.sh
./scripts/test-requests.sh
```

**Windows (PowerShell):**
```powershell
.\scripts\test-requests.ps1
```

Os scripts testam automaticamente:
- ✅ Health checks de todos os serviços
- ✅ Endpoints raiz das aplicações
- ✅ Endpoint `/api/receive`
- ✅ Cadeia de requisições via `/api/start`
- ✅ Requisições POST
- ✅ Múltiplas requisições para gerar traces

## 🧪 Testando a POC

### 1. Testar Health Check

```bash
# Health check do Nginx
curl http://localhost/health

# Health check das aplicações Python diretamente
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
```

### 2. Testar Roteamento via Nginx

```bash
# Acessar python1 via Nginx
curl http://localhost/api/python1/

# Acessar python2 via Nginx
curl http://localhost/api/python2/

# Acessar python3 via Nginx
curl http://localhost/api/python3/
```

### 3. Testar Cadeia de Requisições (Gerar Traces)

```bash
# Disparar requisição de python1 para python2
curl http://localhost/api/python1/api/start

# Isso fará python1 chamar python2, que por sua vez chamará python3
# Gerando um trace distribuído completo
```

### 4. Visualizar Telemetria

#### Traces no Jaeger
1. Acesse http://localhost:16686
2. Selecione o serviço desejado (python1, python2, python3)
3. Clique em "Find Traces"
4. Visualize o trace completo da requisição distribuída

#### Métricas no Grafana
1. Acesse http://localhost:3000 (admin/admin)
2. Os dashboards são provisionados automaticamente:
   - **POC Observability - Overview**: Visão geral do sistema
   - **Python Services - Detailed Metrics**: Métricas detalhadas por serviço
   - **Traces and Logs - Jaeger Integration**: Integração de traces e logs
3. As métricas são geradas automaticamente pelo SpanMetrics Connector

#### Logs
- **Via Terminal**: Consulte `VIEW_LOGS.md` para comandos detalhados
- **Via Grafana**: Acesse Explore → Selecione Loki → Use queries LogQL como `{service_name="python1"}`

> 📖 Para mais detalhes sobre visualização de logs, consulte [`VIEW_LOGS.md`](VIEW_LOGS.md)

## 📊 Coleta de Telemetria

### Traces (Rastreamento Distribuído)
- ✅ **Aplicações Python**: Instrumentadas com OpenTelemetry Python SDK
- ✅ **Envio**: Traces enviados para OtelCollector via gRPC (porta 4317)
- ✅ **Processamento**: OtelCollector processa e encaminha para Jaeger
- ✅ **Visualização**: Jaeger UI e Grafana (via integração)
- ⚠️ **Nginx**: Estrutura preparada, mas requer módulo OpenTelemetry (veja seção abaixo)

### Logs
- ✅ **Aplicações Python**: Logs enviados via OpenTelemetry OTLP
- ✅ **Containers Docker**: Coletados pelo Promtail via Docker socket
- ✅ **Nginx**: Logs de acesso e erro coletados via Promtail
- ✅ **Armazenamento**: Todos os logs enviados para Loki
- ✅ **Visualização**: Grafana com queries LogQL

### Métricas (Service Performance Monitoring)
- ✅ **Geração**: SpanMetrics Connector no OtelCollector gera métricas RED automaticamente
  - **R**equests: Taxa de requisições
  - **E**rrors: Taxa de erros
  - **D**uration: Duração das requisições (latência)
- ✅ **Armazenamento**: Métricas exportadas para Prometheus
- ✅ **Visualização**: Dashboards no Grafana
- ⚠️ **SPM no Jaeger**: Limitado no modo all-in-one (veja [`SPM_SETUP.md`](SPM_SETUP.md))

## 🔧 OpenTelemetry no Nginx

O Nginx **pode** exportar traces para o OtelCollector, mas requer a instalação do módulo OpenTelemetry. A estrutura já está preparada nos arquivos de configuração.

### Status Atual
- ✅ Estrutura de configuração criada
- ✅ Arquivo `opentelemetry_config.yaml` preparado
- ⚠️ Módulo OpenTelemetry não instalado (configurações comentadas)

### Para Habilitar Traces do Nginx

1. **Instalar o módulo OpenTelemetry**:
   - Opção 1: Usar uma imagem Docker que já tenha o módulo
   - Opção 2: Compilar o módulo manualmente
   - Opção 3: Usar Nginx Plus (versão comercial com módulo oficial)

2. **Descomentar as configurações**:
   - Em `nginx/nginx.conf`: descomente `load_module modules/ngx_http_opentelemetry_module.so;`
   - Em `nginx/nginx.conf`: descomente `opentelemetry_config /etc/nginx/opentelemetry_config.yaml;`
   - Em `nginx/conf.d/default.conf`: descomente `opentelemetry on;` nas locations desejadas

3. **Reiniciar o Nginx**:
   ```bash
   docker-compose restart nginx
   ```

> 💡 **Nota**: Atualmente, os logs do Nginx são coletados via Promtail, mas os traces requerem o módulo adicional.

## 🛑 Parar os Serviços

```bash
# Parar todos os serviços
docker-compose down

# Parar e remover volumes (⚠️ apaga dados do Grafana, Prometheus, etc.)
docker-compose down -v
```

## 🔍 Troubleshooting

### Ver logs de um serviço específico
```bash
docker-compose logs -f <nome-do-servico>
# Exemplo: docker-compose logs -f python1
```

### Reiniciar um serviço específico
```bash
docker-compose restart <nome-do-servico>
```

### Reconstruir as imagens
```bash
docker-compose build --no-cache
docker-compose up -d
```

### Verificar conectividade entre serviços
```bash
# Testar se python1 consegue acessar otel-collector
docker-compose exec python1 ping -c 3 otel-collector

# Verificar se os serviços estão na mesma rede
docker network inspect poc-telemetry_observability-network
```

### Problemas Comuns

**Grafana não mostra dashboards:**
- Verifique se os arquivos JSON estão em `observabilidade/grafana/provisioning/dashboards/`
- Reinicie o Grafana: `docker-compose restart grafana`
- Consulte [`GRAFANA_SETUP.md`](GRAFANA_SETUP.md)

**Traces não aparecem no Jaeger:**
- Verifique se o OtelCollector está recebendo dados: `docker-compose logs otel-collector`
- Verifique as variáveis OTEL nas aplicações Python
- Teste a conectividade: `docker-compose exec python1 curl http://otel-collector:4318`

**Métricas não aparecem:**
- Aguarde alguns minutos após gerar traces (métricas são derivadas dos spans)
- Verifique Prometheus: http://localhost:9090 → Query: `traces_spanmetrics_calls_total`
- Consulte [`SPM_SETUP.md`](SPM_SETUP.md)

## 📈 Service Performance Monitoring (SPM)

O sistema gera automaticamente métricas **RED** (Request, Error, Duration) através do SpanMetrics Connector do OtelCollector.

### Status da Configuração SPM

✅ **Prometheus** - Configurado e rodando  
✅ **SpanMetrics Connector** - Configurado no OtelCollector  
✅ **Métricas RED** - Sendo geradas e exportadas para Prometheus  
✅ **Dashboards Grafana** - Visualização automática das métricas

⚠️ **Jaeger all-in-one** - Tem limitações para configuração completa de SPM na UI

### Como Acessar

1. **Grafana**: http://localhost:3000
   - Dashboards provisionados automaticamente mostram métricas RED
   - Métricas são atualizadas em tempo real

2. **Prometheus**: http://localhost:9090
   - Query exemplo: `traces_spanmetrics_calls_total`
   - Query exemplo: `histogram_quantile(0.95, traces_spanmetrics_duration_milliseconds_bucket)`

3. **Métricas do OtelCollector**: http://localhost:8889/metrics

> 📖 Para mais detalhes sobre a configuração do SPM, consulte [`SPM_SETUP.md`](SPM_SETUP.md)

## 🚀 Próximos Passos

Para expandir esta POC, você pode:

1. ✅ Adicionar coleta de métricas (Prometheus) - **Implementado**
2. ✅ Configurar dashboards no Grafana - **Implementado**
3. ✅ Habilitar SPM (métricas RED) - **Implementado**
4. Adicionar mais aplicações (Python, Java, Node.js, etc.)
   - Consulte [`ADICIONAR_APLICACAO_JAVA_SWARM.md`](ADICIONAR_APLICACAO_JAVA_SWARM.md) para exemplo com Java
5. Implementar autenticação/autorização nos serviços
6. Adicionar rate limiting no Nginx
7. Configurar alertas no Grafana
8. Habilitar traces do Nginx (instalar módulo OpenTelemetry)
9. Migrar para Jaeger distribuído para SPM completo
10. Adicionar exemplos de instrumentação manual (custom spans, attributes)

## 📚 Documentação Adicional

- [`GRAFANA_SETUP.md`](GRAFANA_SETUP.md) - Configuração e troubleshooting do Grafana
- [`SPM_SETUP.md`](SPM_SETUP.md) - Service Performance Monitoring detalhado
- [`VIEW_LOGS.md`](VIEW_LOGS.md) - Guia completo de visualização de logs
- [`ADICIONAR_APLICACAO_JAVA_SWARM.md`](ADICIONAR_APLICACAO_JAVA_SWARM.md) - Adicionar aplicações Java ao Docker Swarm

## 📄 Licença

Este projeto é uma POC educacional.

