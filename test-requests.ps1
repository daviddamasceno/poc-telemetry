# Script PowerShell de teste para as aplicações da POC
# Testa requisições para python1, python2 e python3 através do Nginx

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teste de Requisições - POC Observabilidade" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Função para fazer requisição e exibir resultado
function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Description
    )
    
    Write-Host "Testando: $Description" -ForegroundColor Blue
    Write-Host "URL: $Url"
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
        Write-Host "✓ Status: $($response.StatusCode)" -ForegroundColor Green
        
        if ($response.Content) {
            Write-Host "Resposta:"
            try {
                $json = $response.Content | ConvertFrom-Json
                $json | ConvertTo-Json -Depth 10
            } catch {
                Write-Host $response.Content
            }
        }
    } catch {
        Write-Host "✗ Erro: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "1. Testando Health Checks" -ForegroundColor Yellow
Write-Host "-------------------------"
Test-Endpoint "http://localhost/health" "Health Check do Nginx"
Test-Endpoint "http://localhost:8001/health" "Health Check Python1 (direto)"
Test-Endpoint "http://localhost:8002/health" "Health Check Python2 (direto)"
Test-Endpoint "http://localhost:8003/health" "Health Check Python3 (direto)"
Test-Endpoint "http://localhost/api/python1/health" "Health Check Python1 via Nginx"
Test-Endpoint "http://localhost/api/python2/health" "Health Check Python2 via Nginx"
Test-Endpoint "http://localhost/api/python3/health" "Health Check Python3 via Nginx"

Write-Host ""
Write-Host "2. Testando Endpoints Raiz" -ForegroundColor Yellow
Write-Host "-------------------------"
Test-Endpoint "http://localhost/api/python1/" "Endpoint raiz Python1"
Test-Endpoint "http://localhost/api/python2/" "Endpoint raiz Python2"
Test-Endpoint "http://localhost/api/python3/" "Endpoint raiz Python3"

Write-Host ""
Write-Host "3. Testando Endpoint /api/receive" -ForegroundColor Yellow
Write-Host "--------------------------------"
Test-Endpoint "http://localhost/api/python1/api/receive" "Receive Python1"
Test-Endpoint "http://localhost/api/python2/api/receive" "Receive Python2"
Test-Endpoint "http://localhost/api/python3/api/receive" "Receive Python3"

Write-Host ""
Write-Host "4. Testando Cadeia de Requisições (/api/start)" -ForegroundColor Yellow
Write-Host "----------------------------------------------"
Write-Host "Python1 → Python2 → Python3" -ForegroundColor Yellow
Test-Endpoint "http://localhost/api/python1/api/start" "Python1 inicia cadeia (→ Python2)"

Write-Host ""
Write-Host "5. Testando Requisições POST" -ForegroundColor Yellow
Write-Host "----------------------------"
Write-Host "Enviando POST para /api/receive" -ForegroundColor Blue
try {
    $body = @{
        test = "data"
        message = "Hello from test script"
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest -Uri "http://localhost/api/python1/api/receive" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body `
        -UseBasicParsing `
        -ErrorAction Stop
    
    Write-Host "✓ Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Resposta:"
    try {
        $json = $response.Content | ConvertFrom-Json
        $json | ConvertTo-Json -Depth 10
    } catch {
        Write-Host $response.Content
    }
} catch {
    Write-Host "✗ Erro: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Write-Host ""
Write-Host "6. Testando Múltiplas Requisições (Gerar Traces)" -ForegroundColor Yellow
Write-Host "------------------------------------------------"
Write-Host "Executando 5 requisições para gerar traces..." -ForegroundColor Yellow
for ($i = 1; $i -le 5; $i++) {
    Write-Host -NoNewline "Requisição $i/5... "
    try {
        $null = Invoke-WebRequest -Uri "http://localhost/api/python1/api/start" -UseBasicParsing -ErrorAction Stop
        Write-Host "✓" -ForegroundColor Green
    } catch {
        Write-Host "✗" -ForegroundColor Red
    }
    Start-Sleep -Seconds 1
}
Write-Host ""

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Testes concluídos!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Próximos passos:"
Write-Host "1. Visualize os traces no Jaeger: http://localhost:16686"
Write-Host "2. Verifique as métricas no Prometheus: http://localhost:9090"
Write-Host "3. Acesse o Grafana: http://localhost:3000"
Write-Host ""

