# Script para testar a API local com dados das impressoras
# Use este script para verificar se sua API está funcionando corretamente

param(
    [string]$ApiEndpoint = "http://localhost:8080/api/printer-history-public/by-printer",
    [string]$Model = "HP LaserJet Pro MFP M428fdw",
    [string]$SerialNumber = "VN83K12345",
    [int]$TotalPages = 24580,
    [string]$Date = $null
)

# Se nenhuma data for fornecida, usa a data atual
if (-not $Date) {
    $Date = Get-Date -Format "yyyy-MM-dd"
}

# Prepara dados de teste
$testData = @{
    model = $Model
    serialNumber = $SerialNumber
    totalPrintedPages = $TotalPages
    time = $Date
} | ConvertTo-Json -Compress

Write-Host "=== Teste da API UPMS ===" -ForegroundColor Cyan
Write-Host "Endpoint: $ApiEndpoint" -ForegroundColor White
Write-Host "Dados de teste:" -ForegroundColor Yellow
Write-Host $testData -ForegroundColor Gray

try {
    # Caminho para o executavel curl local
    $curlPath = Join-Path $PSScriptRoot "curl\curl.exe"
    
    if (-not (Test-Path $curlPath)) {
        Write-Host "Erro: curl.exe nao encontrado em: $curlPath" -ForegroundColor Red
        Write-Host "Tentando usar curl do sistema..." -ForegroundColor Yellow
        $curlPath = "curl"
    }
    
    # Cria arquivo temporario para o JSON
    $tempJsonFile = [System.IO.Path]::GetTempFileName()
    try {
        # Escreve o JSON no arquivo temporario
        $testData | Out-File -FilePath $tempJsonFile -Encoding UTF8 -NoNewline
        
        Write-Host "`nEnviando dados para API..." -ForegroundColor Cyan
        
        $curlArgs = @(
            '-X', 'POST',
            $ApiEndpoint,
            '-H', 'accept: application/json',
            '-H', 'Content-Type: application/json',
            '--data-binary', "@$tempJsonFile",
            '--verbose'
        )
        
        $response = & $curlPath @curlArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-Host "`nResposta da API:" -ForegroundColor Yellow
        Write-Host $response -ForegroundColor White
        
        if ($exitCode -eq 0) {
            Write-Host "`nSucesso! API respondeu corretamente." -ForegroundColor Green
        } else {
            Write-Host "`nErro no envio. Codigo de saida: $exitCode" -ForegroundColor Red
        }
    }
    finally {
        # Remove arquivo temporario
        if (Test-Path $tempJsonFile) {
            Remove-Item $tempJsonFile -Force
        }
    }
}
catch {
    Write-Host "Erro ao executar teste: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nComandos curl equivalentes para teste manual:" -ForegroundColor Yellow
Write-Host "curl -X 'POST' \\" -ForegroundColor Gray
Write-Host "  '$ApiEndpoint' \\" -ForegroundColor Gray
Write-Host "  -H 'accept: application/json' \\" -ForegroundColor Gray
Write-Host "  -H 'Content-Type: application/json' \\" -ForegroundColor Gray
Write-Host "  -d '$testData'" -ForegroundColor Gray
