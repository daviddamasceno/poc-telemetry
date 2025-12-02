#!/bin/bash

# Script de teste para as aplicações da POC
# Testa requisições para python1, python2 e python3 através do Nginx

echo "=========================================="
echo "Teste de Requisições - POC Observabilidade"
echo "=========================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Função para fazer requisição e exibir resultado
test_endpoint() {
    local url=$1
    local description=$2
    
    echo -e "${BLUE}Testando: ${description}${NC}"
    echo "URL: $url"
    
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$url")
    http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_CODE/d')
    
    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓ Status: $http_code${NC}"
        echo "Resposta:"
        echo "$body" | jq . 2>/dev/null || echo "$body"
    else
        echo -e "${RED}✗ Status: $http_code${NC}"
        echo "Resposta: $body"
    fi
    echo ""
}

# Verificar se curl está instalado
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Erro: curl não está instalado${NC}"
    exit 1
fi

# Verificar se jq está instalado (opcional, para formatação JSON)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Aviso: jq não está instalado. As respostas JSON não serão formatadas.${NC}"
    echo ""
fi

echo "1. Testando Health Checks"
echo "-------------------------"
test_endpoint "http://localhost/health" "Health Check do Nginx"
test_endpoint "http://localhost:8001/health" "Health Check Python1 (direto)"
test_endpoint "http://localhost:8002/health" "Health Check Python2 (direto)"
test_endpoint "http://localhost:8003/health" "Health Check Python3 (direto)"
test_endpoint "http://localhost/api/python1/health" "Health Check Python1 via Nginx"
test_endpoint "http://localhost/api/python2/health" "Health Check Python2 via Nginx"
test_endpoint "http://localhost/api/python3/health" "Health Check Python3 via Nginx"

echo ""
echo "2. Testando Endpoints Raiz"
echo "-------------------------"
test_endpoint "http://localhost/api/python1/" "Endpoint raiz Python1"
test_endpoint "http://localhost/api/python2/" "Endpoint raiz Python2"
test_endpoint "http://localhost/api/python3/" "Endpoint raiz Python3"

echo ""
echo "3. Testando Endpoint /api/receive"
echo "--------------------------------"
test_endpoint "http://localhost/api/python1/api/receive" "Receive Python1"
test_endpoint "http://localhost/api/python2/api/receive" "Receive Python2"
test_endpoint "http://localhost/api/python3/api/receive" "Receive Python3"

echo ""
echo "4. Testando Cadeia de Requisições (/api/start)"
echo "----------------------------------------------"
echo -e "${YELLOW}Python1 → Python2 → Python3${NC}"
test_endpoint "http://localhost/api/python1/api/start" "Python1 inicia cadeia (→ Python2)"

echo ""
echo "5. Testando Requisições POST"
echo "----------------------------"
echo -e "${BLUE}Enviando POST para /api/receive${NC}"
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"test": "data", "message": "Hello from test script"}' \
    "http://localhost/api/python1/api/receive")
http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_CODE/d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Status: $http_code${NC}"
    echo "Resposta:"
    echo "$body" | jq . 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Status: $http_code${NC}"
    echo "Resposta: $body"
fi
echo ""

echo ""
echo "6. Testando Múltiplas Requisições (Gerar Traces)"
echo "------------------------------------------------"
echo -e "${YELLOW}Executando 5 requisições para gerar traces...${NC}"
for i in {1..5}; do
    echo -n "Requisição $i/5... "
    curl -s "http://localhost/api/python1/api/start" > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    sleep 1
done
echo ""

echo ""
echo "=========================================="
echo -e "${GREEN}Testes concluídos!${NC}"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo "1. Visualize os traces no Jaeger: http://localhost:16686"
echo "2. Verifique as métricas no Prometheus: http://localhost:9090"
echo "3. Acesse o Grafana: http://localhost:3000"
echo ""

