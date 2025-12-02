# Usar uma imagem base do Nginx e tentar uma abordagem alternativa
# Para POC, vamos usar uma solução mais simples: instrumentação via sidecar
# ou usar uma imagem que já tenha suporte

FROM nginx:latest

# Copiar configurações
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d /etc/nginx/conf.d

# Nota: O módulo OpenTelemetry do Nginx requer compilação específica
# Para produção, considere usar:
# - nginx/nginx-ingress (tem suporte nativo)
# - ou compilar o módulo manualmente
# - ou usar instrumentação via OpenTelemetry Collector sidecar
