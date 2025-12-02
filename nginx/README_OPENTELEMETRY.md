# Configuração do OpenTelemetry no Nginx

## Opções para Exportar Traces do Nginx

O Nginx pode exportar traces para o OpenTelemetry Collector, mas requer a instalação do módulo OpenTelemetry. Existem algumas abordagens:

### Opção 1: Usar Módulo OpenTelemetry do Nginx (Recomendado para Produção)

1. **Instalar o módulo**: O módulo `ngx_http_opentelemetry_module` precisa ser compilado ou instalado.

2. **Configuração no nginx.conf**:
```nginx
load_module modules/ngx_http_opentelemetry_module.so;

http {
    opentelemetry_config /etc/nginx/opentelemetry_config.yaml;
    # ... resto da configuração
}
```

3. **Arquivo opentelemetry_config.yaml**:
```yaml
service_name: nginx
sampler:
  type: always_on
  ratio: 1.0
exporter:
  otlp:
    endpoint: http://otel-collector:4317
    protocol: grpc
    insecure: true
```

### Opção 2: Usar Nginx Ingress Controller (Mais Fácil)

O Nginx Ingress Controller já tem suporte nativo ao OpenTelemetry:
- Imagem: `nginx/nginx-ingress`
- Configuração via annotations ou ConfigMap

### Opção 3: Instrumentação via OpenTelemetry Collector Sidecar

Usar o OpenTelemetry Collector como sidecar para coletar logs do Nginx e gerar traces:
- Coletar logs de acesso do Nginx
- Parsear logs e gerar spans
- Enviar para o Jaeger

### Opção 4: Usar Imagem Pré-compilada

Buscar imagens Docker que já tenham o módulo instalado:
- `otel/nginx` (se disponível)
- Imagens customizadas da comunidade

## Status Atual

Atualmente, a POC está configurada sem o módulo OpenTelemetry do Nginx ativo, mas a estrutura está pronta para ser habilitada quando o módulo for instalado.

Os traces das aplicações Python já estão sendo coletados corretamente pelo OtelCollector.

