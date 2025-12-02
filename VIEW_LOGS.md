# Como Visualizar Logs das Aplicações

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

## 3. Logs no Grafana (Visualização Gráfica)

Os logs das aplicações Python são enviados para o Loki via OpenTelemetry.

### Configurar Loki no Grafana

1. **Acesse o Grafana**: http://localhost:3000
   - Usuário: `admin`
   - Senha: `admin`

2. **Adicione Loki como Data Source**:
   - Vá em: Configuration → Data Sources → Add data source
   - Selecione: Loki
   - URL: `http://loki:3100`
   - Clique em: Save & Test

3. **Crie uma Query de Logs**:
   - Vá em: Explore (ícone de bússola)
   - Selecione: Loki como data source
   - Use queries como:
     ```
     {service_name="python1"}
     {service_name="python2"}
     {service_name="python3"}
     ```

4. **Crie um Dashboard**:
   - Vá em: Dashboards → New Dashboard
   - Adicione painéis com queries de log
   - Configure visualizações adequadas

## 4. Logs do Nginx

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

## 5. Scripts Úteis

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

## 6. Logs do OtelCollector

Para verificar se os traces estão sendo coletados:
```bash
docker-compose logs otel-collector | Select-String "trace"
```

## 7. Logs do Jaeger

Para verificar o status do Jaeger:
```bash
docker-compose logs jaeger
```

## Dicas

- Use `-f` para seguir logs em tempo real (útil durante testes)
- Use `--tail=N` para ver apenas as últimas N linhas
- Combine múltiplos serviços: `docker-compose logs -f python1 python2`
- Use filtros do terminal (grep/Select-String) para buscar por palavras-chave
- Configure o Grafana para visualização gráfica e alertas

