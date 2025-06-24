# Teste de Prevenção de Duplicatas
# Este script simula múltiplas execuções do snmp-collector para verificar se duplicatas são evitadas

Write-Host "=== TESTE DE PREVENÇÃO DE DUPLICATAS ===" -ForegroundColor Cyan
Write-Host "Este teste simula várias execuções para verificar se apenas um registro por dia é criado" -ForegroundColor Yellow
Write-Host ""

# Remove dados locais existentes para começar limpo
$localDataFile = ".\local-data\local-data.json"
if (Test-Path $localDataFile) {
    Write-Host "Removendo dados locais existentes para teste limpo..." -ForegroundColor Gray
    Remove-Item $localDataFile -Force
}

Write-Host "EXECUÇÃO 1: Primeira execução (deve processar normalmente)" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray
.\snmp-collector.ps1 -TestMode

Write-Host "`n`nEXECUÇÃO 2: Segunda execução no mesmo dia (deve detectar duplicatas)" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Gray

# Simula dados já enviados criando um arquivo local-data.json
$localDataDir = ".\local-data"
if (-not (Test-Path $localDataDir)) {
    New-Item -ItemType Directory -Path $localDataDir | Out-Null
}

$currentDate = Get-Date -Format "yyyy-MM-dd"
$simulatedData = @(
    @{
        id = [System.Guid]::NewGuid().ToString()
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        printerIP = "192.168.15.106"
        model = "Brother NC-8300w, Firmware Ver.X  ,MID 8C5-H27,FID 2"
        serialNumber = "U63885F9N733180"
        totalPrintedPages = 298935
        time = $currentDate
        apiEndpoint = "https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer"
        status = "sent"
        sentTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
)

$simulatedData | ConvertTo-Json -Depth 3 | Set-Content $localDataFile -Encoding UTF8
Write-Host "Dados simulados criados (Brother já enviado hoje)" -ForegroundColor Cyan

# Segunda execução
.\snmp-collector.ps1 -TestMode

Write-Host "`n`nVERIFICAÇÃO DO ARQUIVO LOCAL:" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Gray

if (Test-Path $localDataFile) {
    $content = Get-Content $localDataFile | ConvertFrom-Json
    Write-Host "Total de registros no arquivo: $($content.Count)" -ForegroundColor White
    
    $todayRecords = $content | Where-Object { $_.time -eq $currentDate }
    Write-Host "Registros para hoje ($currentDate): $($todayRecords.Count)" -ForegroundColor White
    
    foreach ($record in $todayRecords) {
        Write-Host "  - IP: $($record.printerIP), Status: $($record.status), Modelo: $($record.model.Substring(0, [Math]::Min(30, $record.model.Length)))..." -ForegroundColor Gray
    }
} else {
    Write-Host "Arquivo local-data.json não encontrado" -ForegroundColor Red
}

Write-Host "`n=== RESULTADO DO TESTE ===" -ForegroundColor Green
Write-Host "Se a prevenção de duplicatas estiver funcionando:" -ForegroundColor Yellow
Write-Host "- A primeira execução deve processar normalmente" -ForegroundColor White
Write-Host "- A segunda execução deve pular impressoras já processadas" -ForegroundColor White
Write-Host "- Deve haver apenas 1 registro por impressora no arquivo local" -ForegroundColor White

Write-Host "`nTeste concluído!" -ForegroundColor Green
