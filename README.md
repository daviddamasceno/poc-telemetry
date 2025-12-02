# POC - Observabilidade com Nginx e OpenTelemetry

Esta é uma Proof of Concept (POC) que demonstra a coleta de telemetria (traces, logs e métricas) de aplicações Python através de um Nginx usando Docker Compose.

## Arquitetura

A POC consiste em 7 aplicações Docker:

### Aplicações de Negócio
- **python1, python2, python3**: Três aplicações Python idênticas que se comunicam entre si
- **nginx**: Camada de proxy reverso que roteia requisições entre as aplicações Python

### Stack de Observabilidade
- **otel-collector**: Coletor OpenTelemetry que recebe traces, logs e métricas
- **jaeger**: Backend para visualização de traces distribuídos
- **loki**: Agregador de logs
- **grafana**: Dashboard para visualização de métricas e logs

## Fluxo de Comunicação

```
Cliente → Nginx → Python1 → Nginx → Python2 → Nginx → Python3
                ↓                                    ↓
         OtelCollector ← ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
                ↓
    ┌───────────┼───────────┐
    ↓           ↓           ↓
  Jaeger     Loki      Grafana
```

## Estrutura do Projeto

```
poc/
├── docker-compose.yml          # Orquestração de todos os serviços
├── otel-collector-config.yaml   # Configuração do OpenTelemetry Collector
├── .env.example                 # Exemplo de variáveis de ambiente
├── python-app/
│   ├── Dockerfile              # Dockerfile para aplicações Python
│   ├── app.py                  # Aplicação Python (usada por python1, python2, python3)
│   └── requirements.txt        # Dependências Python
└── nginx/
    ├── nginx.conf              # Configuração principal do Nginx
    └── conf.d/
        └── default.conf        # Configuração de roteamento
```

## Pré-requisitos

- Docker
- Docker Compose

## Como Executar

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

4. **Verifique se todos os containers estão rodando**
   ```bash
   docker-compose ps
   ```

## Endpoints Disponíveis

### Aplicações Python

Cada aplicação Python (python1, python2, python3) expõe os seguintes endpoints:

- `GET /` - Informações sobre a aplicação e endpoints disponíveis
- `GET /health` - Health check da aplicação
- `GET /api/start` - Dispara uma requisição GET para o `TARGET_URL` configurado
- `GET|POST /api/receive` - Recebe requisições

### Nginx

- `http://localhost/api/python1` - Roteia para python1
- `http://localhost/api/python2` - Roteia para python2
- `http://localhost/api/python3` - Roteia para python3
- `http://localhost/health` - Health check do Nginx

### Stack de Observabilidade

- **Jaeger UI**: http://localhost:16686
- **Grafana**: http://localhost:3000
  - Usuário padrão: `admin`
  - Senha padrão: `admin`
- **Loki**: http://localhost:3100

## Variáveis de Ambiente

As principais variáveis de ambiente configuráveis estão no arquivo `.env.example`:

### Portas
- `NGINX_PORT`: Porta do Nginx (padrão: 80)
- `PYTHON1_PORT`, `PYTHON2_PORT`, `PYTHON3_PORT`: Portas das aplicações Python
- `JAEGER_UI_PORT`, `GRAFANA_PORT`, `LOKI_PORT`: Portas dos serviços de observabilidade

### URLs de Destino
- `PYTHON1_TARGET_URL`: URL que python1 chamará quando `/api/start` for acionado
- `PYTHON2_TARGET_URL`: URL que python2 chamará quando `/api/start` for acionado
- `PYTHON3_TARGET_URL`: URL que python3 chamará quando `/api/start` for acionado

### Credenciais
- `GRAFANA_USER`: Usuário do Grafana (padrão: admin)
- `GRAFANA_PASSWORD`: Senha do Grafana (padrão: admin)

## Scripts de Teste

Foram criados scripts para facilitar os testes das aplicações:

- **`test-requests.sh`** - Script bash para Linux/Mac
- **`test-requests.ps1`** - Script PowerShell para Windows

### Executar os Scripts

**Linux/Mac:**
```bash
./test-requests.sh
```

**Windows (PowerShell):**
```powershell
.\test-requests.ps1
```

Os scripts testam:
- Health checks de todos os serviços
- Endpoints raiz das aplicações
- Endpoint `/api/receive`
- Cadeia de requisições via `/api/start`
- Requisições POST
- Múltiplas requisições para gerar traces

## Testando a POC

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

### 3. Testar Cadeia de Requisições

```bash
# Disparar requisição de python1 para python2
curl http://localhost/api/python1/api/start

# Isso fará python1 chamar python2, que por sua vez chamará python3
```

### 4. Visualizar Traces no Jaeger

1. Acesse http://localhost:16686
2. Selecione o serviço desejado (python1, python2, python3)
3. Clique em "Find Traces"
4. Você verá os traces das requisições distribuídas

### 5. Visualizar Logs

**Via Terminal (Docker Compose):**
```bash
# Ver logs de um serviço específico
docker-compose logs python1

# Ver logs em tempo real
docker-compose logs -f python1

# Ver últimas 50 linhas
docker-compose logs --tail=50 python1

# Ver logs de múltiplos serviços
docker-compose logs python1 python2 python3
```

**Via Grafana (Visualização Gráfica):**
1. Acesse http://localhost:3000
2. Faça login com as credenciais padrão
3. Configure o Loki como fonte de dados:
   - URL: `http://loki:3100`
4. Crie queries para visualizar os logs coletados

Para mais detalhes sobre visualização de logs, consulte `VIEW_LOGS.md`.

## Coleta de Telemetria

### Traces
- As aplicações Python estão instrumentadas com OpenTelemetry
- Os traces são enviados para o OtelCollector via gRPC (porta 4317)
- O OtelCollector encaminha os traces para o Jaeger
- **Nginx**: A estrutura para exportar traces do Nginx está configurada, mas requer a instalação do módulo OpenTelemetry. Veja a seção "OpenTelemetry no Nginx" abaixo.

### Logs
- Logs das aplicações Python são enviados via OpenTelemetry
- Logs do Nginx são coletados via filelog receiver do OtelCollector (quando configurado)
- Todos os logs são enviados para o Loki

### Métricas
- As métricas podem ser coletadas através do OpenTelemetry (configuração adicional necessária)

## OpenTelemetry no Nginx

O Nginx **pode** exportar traces para o OtelCollector, mas requer a instalação do módulo OpenTelemetry. A estrutura já está preparada nos arquivos de configuração:

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

### Arquivos de Configuração
- `nginx/opentelemetry_config.yaml`: Configuração do exportador OTLP
- `nginx/nginx.conf`: Configuração principal com diretivas do módulo (comentadas)
- `nginx/conf.d/default.conf`: Configuração de locations com opentelemetry (comentado)

Para mais detalhes, consulte `nginx/README_OPENTELEMETRY.md`.

## Parar os Serviços

```bash
docker-compose down
```

Para remover também os volumes:

```bash
docker-compose down -v
```

## Troubleshooting

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

## Service Performance Monitoring (SPM)

O Jaeger inclui uma funcionalidade chamada Service Performance Monitoring (SPM) que permite visualizar métricas RED (Request, Error, Duration) na aba "Monitor".

### Status da Configuração SPM

✅ **Prometheus** - Configurado e rodando  
✅ **SpanMetrics Connector** - Configurado no OtelCollector  
✅ **Métricas RED** - Sendo geradas e exportadas para Prometheus

⚠️ **Jaeger all-in-one** - Tem limitações para configuração completa de SPM

### Como Acessar

1. **Prometheus**: http://localhost:9090
   - Verifique as métricas: `traces_spanmetrics_calls_total`

2. **Métricas do OtelCollector**: http://localhost:8889/metrics

3. **Jaeger UI**: http://localhost:16686
   - A aba "Monitor" pode não estar visível devido às limitações do all-in-one

Para mais detalhes sobre a configuração do SPM, consulte `SPM_SETUP.md`.

## Próximos Passos

Para expandir esta POC, você pode:

1. ✅ Adicionar coleta de métricas (Prometheus) - **Implementado**
2. Configurar dashboards no Grafana
3. Adicionar mais aplicações Python
4. Implementar autenticação/autorização
5. Adicionar rate limiting no Nginx
6. Configurar alertas no Grafana
7. Habilitar SPM completo no Jaeger (usando componentes distribuídos)

## Licença

Este projeto é uma POC educacional.

