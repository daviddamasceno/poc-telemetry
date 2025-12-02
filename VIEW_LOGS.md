# Como Visualizar Logs das Aplicações

Este guia detalha todas as formas de visualizar e analisar logs das aplicações na POC de Observabilidade.

## 📋 Visão Geral

Os logs são coletados de duas formas:
1. **Via OpenTelemetry**: Logs das aplicações Python enviados diretamente para o OtelCollector
2. **Via Promtail**: Logs dos containers Docker coletados automaticamente

Ambos os métodos enviam os logs para o **Loki**, onde podem ser visualizados no **Grafana**.

---

## 1. Logs via Docker Compose (Terminal)

### Ver logs de um serviço específico
```bash
docker-compose logs <nome-do-servico>
```

Exemplos:
```bash
# Logs do Python1
docker-compose logs python1

# Logs do Python2
docker-compose logs python2

# Logs do Python3
docker-compose logs python3

# Logs do Nginx
docker-compose logs nginx

# Logs do OtelCollector
docker-compose logs otel-collector
```

### Ver logs em tempo real (follow)
```bash
docker-compose logs -f <nome-do-servico>
```

Exemplos:
```bash
# Acompanhar logs do Python1 em tempo real
docker-compose logs -f python1

# Acompanhar logs de múltiplos serviços
docker-compose logs -f python1 python2 python3
```

### Ver últimas linhas dos logs
```bash
docker-compose logs --tail=50 <nome-do-servico>
```

Exemplos:
```bash
# Últimas 50 linhas do Python1
docker-compose logs --tail=50 python1

# Últimas 100 linhas do Nginx
docker-compose logs --tail=100 nginx
```

### Ver logs de todos os serviços
```bash
docker-compose logs
```

### Filtrar logs por período
```bash
# Logs desde um tempo específico
docker-compose logs --since 10m python1

# Logs desde uma data/hora específica
docker-compose logs --since 2025-11-30T21:00:00 python1
```

---

## 2. Logs via Docker (Comandos Diretos)

### Ver logs de um container específico
```bash
docker logs <nome-do-container>
```

Exemplos:
```bash
docker logs python1
docker logs python2
docker logs python3
docker logs nginx
docker logs otel-collector
```

### Ver logs em tempo real
```bash
docker logs -f <nome-do-container>
```

### Ver últimas linhas
```bash
docker logs --tail=50 <nome-do-container>
```

---

## 3. Logs no Grafana (Visualização Gráfica)

Os logs são automaticamente coletados e disponibilizados no Grafana. O Loki já está configurado como data source (consulte [`GRAFANA_SETUP.md`](GRAFANA_SETUP.md)).

### Acessar Logs no Grafana

1. **Acesse o Grafana**: http://localhost:3000
   - Usuário: `admin`
   - Senha: `admin`

2. **Explore Logs**:
   - Vá em: **Explore** (ícone de bússola no menu lateral)
   - Selecione: **Loki** como data source (já configurado)

3. **Queries LogQL Úteis**:

   **Logs de um serviço específico:**
   ```logql
   {service_name="python1"}
   {service_name="python2"}
   {service_name="python3"}
   ```

   **Logs por container:**
   ```logql
   {container_name="python1"}
   {container_name="python2"}
   {container_name="python3"}
   ```

   **Filtrar por nível de log:**
   ```logql
   {service_name="python1"} |= "ERROR"
   {service_name="python1"} |= "WARNING"
   ```

   **Buscar por texto:**
   ```logql
   {service_name="python1"} |= "requisição"
   {service_name="python1"} |~ "error|exception"
   ```

   **Logs de múltiplos serviços:**
   ```logql
   {service_name=~"python1|python2|python3"}
   ```

4. **Usar Dashboards Provisionados**:
   - Os dashboards já incluem painéis de logs
   - Acesse: **Dashboards** → **Browse** → Pasta **"POC"**
   - Dashboard **"Traces and Logs - Jaeger Integration"** tem visualização integrada

---

## 4. Logs do Nginx

Os logs do Nginx são coletados pelo Promtail e enviados para o Loki.

### Logs de Acesso
```bash
# Via docker-compose
docker-compose exec nginx cat /var/log/nginx/access.log

# Via docker
docker exec nginx cat /var/log/nginx/access.log
```

### Logs de Erro
```bash
# Via docker-compose
docker-compose exec nginx cat /var/log/nginx/error.log

# Via docker
docker exec nginx cat /var/log/nginx/error.log
```

### Ver logs em tempo real
```bash
docker-compose exec nginx tail -f /var/log/nginx/access.log
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

---

## 5. Scripts e Comandos Úteis

### Ver logs de todas as aplicações Python
```bash
docker-compose logs python1 python2 python3
```

### Ver logs com timestamp
```bash
docker-compose logs -t python1
```

### Filtrar logs por palavra-chave
```bash
# No PowerShell
docker-compose logs python1 | Select-String "error"

# No Linux/Mac
docker-compose logs python1 | grep "error"
```

---

## 6. Logs dos Serviços de Observabilidade

### OtelCollector

Verificar se os traces e logs estão sendo coletados:
```bash
# Linux/Mac
docker-compose logs otel-collector | grep -i "trace\|error"

# Windows PowerShell
docker-compose logs otel-collector | Select-String "trace|error"
```

### Jaeger

Verificar o status do Jaeger:
```bash
docker-compose logs jaeger
```

### Promtail

Verificar se está coletando logs dos containers:
```bash
# Linux/Mac
docker-compose logs promtail | grep -i "error\|discovered"

# Windows PowerShell
docker-compose logs promtail | Select-String "error|discovered"
```

### Loki

Verificar se está recebendo logs:
```bash
docker-compose logs loki
```

### Prometheus

Verificar scraping de métricas:
```bash
docker-compose logs prometheus
```

### Grafana

Verificar erros de conexão com data sources:
```bash
# Linux/Mac
docker-compose logs grafana | grep -i "error\|datasource"

# Windows PowerShell
docker-compose logs grafana | Select-String "error|datasource"
```

---

## 💡 Dicas e Boas Práticas

### Comandos Docker Compose

- **Seguir logs em tempo real**: `docker-compose logs -f <servico>` (útil durante testes)
- **Últimas N linhas**: `docker-compose logs --tail=50 <servico>`
- **Múltiplos serviços**: `docker-compose logs -f python1 python2 python3`
- **Com timestamp**: `docker-compose logs -t <servico>`
- **Filtrar por período**: `docker-compose logs --since 10m <servico>`

### Filtros no Terminal

**Linux/Mac (grep):**
```bash
docker-compose logs python1 | grep -i "error"
docker-compose logs python1 | grep -E "error|exception|warning"
```

**Windows PowerShell (Select-String):**
```powershell
docker-compose logs python1 | Select-String "error"
docker-compose logs python1 | Select-String "error|exception|warning"
```

### Grafana

- **Configure alertas** para logs de erro
- **Use LogQL avançado** para análises complexas
- **Crie dashboards customizados** para visualizações específicas
- **Exporte logs** quando necessário para análise externa

### Performance

- **Evite seguir logs de todos os serviços** simultaneamente (pode ser lento)
- **Use intervalos de tempo** nas queries do Grafana para melhor performance
- **Configure retenção** no Loki para evitar acúmulo excessivo de dados

---

## 🔍 Troubleshooting

### Logs não aparecem no Grafana

1. **Verifique se o Promtail está coletando:**
   ```bash
   docker-compose logs promtail
   ```

2. **Verifique se o Loki está recebendo:**
   ```bash
   curl http://localhost:3100/ready
   ```

3. **Verifique labels disponíveis:**
   ```bash
   curl http://localhost:3100/loki/api/v1/labels
   ```

4. **Verifique se o Loki está configurado no Grafana:**
   - Configuration → Data Sources → Loki → Test

### Logs duplicados

- Verifique se há múltiplas fontes coletando os mesmos logs
- Ajuste a configuração do Promtail se necessário

### Logs muito antigos não aparecem

- Verifique a retenção configurada no Loki
- Ajuste o intervalo de tempo na query do Grafana

---

## 📚 Recursos Adicionais

- [LogQL (Loki Query Language)](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)
- [Docker Compose Logs](https://docs.docker.com/compose/reference/logs/)

