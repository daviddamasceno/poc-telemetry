# Configuração Automática do Grafana

Este documento descreve a configuração automática do Grafana na POC de Observabilidade, incluindo data sources e dashboards provisionados.

## ✅ Status da Configuração

### Data Sources Provisionados Automaticamente

| Data Source | URL | Tipo | Descrição |
|-------------|-----|------|-----------|
| **Loki** | http://loki:3100 | Logs | Agregador de logs das aplicações |
| **Prometheus** | http://prometheus:9090 | Métricas | Armazenamento de métricas RED |
| **Jaeger** | http://jaeger:16686 | Traces | Visualização de traces distribuídos |

### Dashboards Provisionados

Os seguintes dashboards são criados automaticamente na pasta "POC":

1. **POC Observability - Overview**
   - Visão geral do sistema
   - Métricas agregadas de todos os serviços
   - Logs recentes
   - Status dos serviços

2. **Python Services - Detailed Metrics**
   - Métricas detalhadas por serviço (python1, python2, python3)
   - Taxa de requisições, erros e latência
   - Gráficos de tendência temporal

3. **Traces and Logs - Jaeger Integration**
   - Integração entre traces e logs
   - Correlação de dados de telemetria
   - Visualização de requisições distribuídas

## 📁 Estrutura de Arquivos

```
observabilidade/
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── datasources.yml          # Configuração dos data sources
        └── dashboards/
            ├── dashboard.yml            # Configuração de provisioning dos dashboards
            ├── poc-overview.json        # Dashboard: Overview
            ├── python-services.json     # Dashboard: Métricas detalhadas
            └── traces-and-logs.json     # Dashboard: Traces e Logs
```

> **Nota**: Os arquivos JSON dos dashboards devem estar no diretório especificado em `dashboard.yml` (geralmente `provisioning/dashboards/`).

## 🔍 Como Verificar a Configuração

### 1. Acessar o Grafana

1. Acesse: http://localhost:3000
2. Faça login com as credenciais padrão:
   - **Usuário**: `admin`
   - **Senha**: `admin`
3. Na primeira execução, você pode ser solicitado a alterar a senha (opcional)

### 2. Verificar Data Sources

1. Navegue para: **Configuration** → **Data Sources**
2. Você deve ver os seguintes data sources já configurados:
   - ✅ **Loki** (Status: OK)
   - ✅ **Prometheus** (Status: OK)
   - ✅ **Jaeger** (Status: OK)

3. Para testar cada data source:
   - Clique no nome do data source
   - Clique em **Save & Test**
   - Deve aparecer a mensagem "Data source is working"

### 3. Verificar Dashboards

1. Navegue para: **Dashboards** → **Browse**
2. Procure pela pasta **"POC"**
3. Você deve ver os 3 dashboards:
   - ✅ **POC Observability - Overview**
   - ✅ **Python Services - Detailed Metrics**
   - ✅ **Traces and Logs - Jaeger Integration**

4. Abra qualquer dashboard para visualizar os dados

## 🔧 Troubleshooting

### Problema: Dashboards não aparecem

**Sintomas**: Ao acessar Dashboards → Browse, não há dashboards na pasta "POC"

**Soluções**:

1. **Verificar se os arquivos JSON estão no container:**
   ```bash
   docker-compose exec grafana ls -la /etc/grafana/provisioning/dashboards/
   ```
   Deve listar os arquivos `.json` dos dashboards

2. **Verificar o arquivo de configuração `dashboard.yml`:**
   ```bash
   docker-compose exec grafana cat /etc/grafana/provisioning/dashboards/dashboard.yml
   ```
   Verifique se o caminho `path` está correto

3. **Verificar os logs do Grafana:**
   ```bash
   docker-compose logs grafana | grep -i dashboard
   ```
   Procure por erros de carregamento

4. **Reiniciar o Grafana:**
   ```bash
   docker-compose restart grafana
   ```
   Aguarde alguns segundos e verifique novamente

5. **Verificar permissões dos arquivos:**
   ```bash
   ls -la observabilidade/grafana/provisioning/dashboards/
   ```

### Problema: Data Sources não aparecem

**Sintomas**: Em Configuration → Data Sources, não há data sources configurados

**Soluções**:

1. **Verificar o arquivo de configuração:**
   ```bash
   docker-compose exec grafana cat /etc/grafana/provisioning/datasources/datasources.yml
   ```
   Verifique se as URLs estão corretas

2. **Verificar se os serviços estão acessíveis:**
   ```bash
   # Testar conectividade do Grafana para os serviços
   docker-compose exec grafana ping -c 3 loki
   docker-compose exec grafana ping -c 3 prometheus
   docker-compose exec grafana ping -c 3 jaeger
   ```

3. **Verificar se os serviços estão rodando:**
   ```bash
   docker-compose ps
   ```
   Todos os serviços devem estar com status "Up"

4. **Verificar logs do Grafana:**
   ```bash
   docker-compose logs grafana | grep -i datasource
   ```

5. **Reiniciar o Grafana:**
   ```bash
   docker-compose restart grafana
   ```

### Problema: Data Source mostra erro "Connection refused"

**Soluções**:

1. **Verificar se o serviço está na mesma rede:**
   ```bash
   docker network inspect poc-telemetry_observability-network
   ```
   Todos os serviços devem estar listados

2. **Testar acesso direto aos serviços:**
   - Loki: http://localhost:3100/ready
   - Prometheus: http://localhost:9090/-/healthy
   - Jaeger: http://localhost:16686

3. **Verificar variáveis de ambiente no docker-compose.yml:**
   Certifique-se de que as portas estão corretas

## 📝 Notas Importantes

- ✅ **Provisionamento Automático**: Os dashboards e data sources são provisionados automaticamente quando o Grafana inicia
- ✅ **Edição Permitida**: Os dashboards podem ser editados na UI do Grafana (`allowUiUpdates: true`)
- ⚠️ **Alterações em Arquivos**: Alterações nos arquivos JSON serão refletidas após reiniciar o Grafana
- ⚠️ **Edições na UI**: Edições feitas na UI do Grafana não são salvas nos arquivos JSON (apenas no banco do Grafana)
- 💡 **Backup**: Para manter alterações, exporte os dashboards editados e substitua os arquivos JSON

## 🎯 Próximos Passos

Após verificar que tudo está funcionando:

1. **Explorar os Dashboards**: Abra cada dashboard e familiarize-se com as métricas
2. **Criar Alertas**: Configure alertas no Grafana para monitoramento proativo
3. **Personalizar Dashboards**: Edite os dashboards conforme suas necessidades
4. **Adicionar Queries Customizadas**: Crie painéis adicionais com queries específicas

## 📚 Recursos Adicionais

- [Documentação do Grafana](https://grafana.com/docs/grafana/latest/)
- [LogQL (Loki Query Language)](https://grafana.com/docs/loki/latest/logql/)
- [PromQL (Prometheus Query Language)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Jaeger Integration no Grafana](https://grafana.com/docs/grafana/latest/datasources/jaeger/)

