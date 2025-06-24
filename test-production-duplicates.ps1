# Teste de Duplicatas em Modo Produção (sem servidor)
# Simula execuções em modo produção quando servidor não está disponível

Write-Host "=== TESTE DE DUPLICATAS - MODO PRODUÇÃO ===" -ForegroundColor Cyan
Write-Host "Testando prevenção de duplicatas quando servidor está indisponível" -ForegroundColor Yellow
Write-Host ""

# Remove dados locais existentes
$localDataFile = ".\local-data\local-data.json"
if (Test-Path $localDataFile) {
    Write-Host "Removendo dados locais existentes..." -ForegroundColor Gray
    Remove-Item $localDataFile -Force
}

Write-Host "EXECUÇÃO 1: Primeira execução em modo produção" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray
# Usar endpoint inválido para simular servidor indisponível
.\snmp-collector.ps1 -ApiEndpoint "https://servidor-inexistente.com/api/test"

Write-Host "`n`nEXECUÇÃO 2: Segunda execução (deve detectar registros já salvos)" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Gray
.\snmp-collector.ps1 -ApiEndpoint "https://servidor-inexistente.com/api/test"

Write-Host "`n`nEXECUÇÃO 3: Terceira execução (deve continuar detectando)" -ForegroundColor Red
Write-Host "=" * 60 -ForegroundColor Gray
.\snmp-collector.ps1 -ApiEndpoint "https://servidor-inexistente.com/api/test"

Write-Host "`n`nVERIFICAÇÃO FINAL DO ARQUIVO:" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Gray

if (Test-Path $localDataFile) {
    $content = Get-Content $localDataFile | ConvertFrom-Json
    Write-Host "Total de registros: $($content.Count)" -ForegroundColor White
    
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    $todayRecords = $content | Where-Object { $_.time -eq $currentDate }
    Write-Host "Registros para hoje: $($todayRecords.Count)" -ForegroundColor White
    
    # Agrupa por IP e status
    $recordsByIP = $todayRecords | Group-Object printerIP
    foreach ($group in $recordsByIP) {
        $statuses = $group.Group | Group-Object status
        Write-Host "  📍 IP: $($group.Name)" -ForegroundColor Cyan
        foreach ($statusGroup in $statuses) {
            Write-Host "    ⚡ Status '$($statusGroup.Name)': $($statusGroup.Count) registro(s)" -ForegroundColor White
        }
    }
} else {
    Write-Host "❌ Arquivo local-data.json não encontrado" -ForegroundColor Red
}

Write-Host "`n=== ANÁLISE DO RESULTADO ===" -ForegroundColor Green
Write-Host "✅ Resultado esperado: Apenas 1 registro 'pending' por impressora" -ForegroundColor Yellow
Write-Host "❌ Problema se houver: Múltiplos registros para a mesma impressora/dia" -ForegroundColor Red
