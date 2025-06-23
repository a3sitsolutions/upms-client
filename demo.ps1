# Script de Demonstração das Funcionalidades Implementadas
# UPMS Agent - Demonstração Completa

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "DEMONSTRACAO UPMS AGENT - FUNCIONALIDADES" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "`n1. VERIFICACAO DE DEPENDENCIAS" -ForegroundColor Yellow
Write-Host "   Executando pre-teste..." -ForegroundColor Gray
& .\pre-test.ps1

Write-Host "`n2. MODO TESTE (SEM ENVIO PARA API)" -ForegroundColor Yellow
Write-Host "   Teste da coleta SNMP + verificacao Git..." -ForegroundColor Gray
& powershell -ExecutionPolicy Bypass -File .\snmp-collector.ps1 -TestMode

Write-Host "`n3. MODO REENVIO (RETRY ONLY)" -ForegroundColor Yellow
Write-Host "   Teste do reenvio de dados salvos..." -ForegroundColor Gray
& powershell -ExecutionPolicy Bypass -File .\snmp-collector.ps1 -RetryOnly

Write-Host "`n4. VERIFICACAO DE AGENDAMENTO" -ForegroundColor Yellow
Write-Host "   Verificando se tarefa agendada existe..." -ForegroundColor Gray
$task = Get-ScheduledTask -TaskName "UPMS-SNMP-Collector" -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "   OK Tarefa agendada configurada" -ForegroundColor Green
    Write-Host "   Proxima execucao: $($task.NextRunTime)" -ForegroundColor Green
} else {
    Write-Host "   AVISO Tarefa agendada nao configurada" -ForegroundColor Yellow
    Write-Host "   Execute: .\schedule-task.ps1" -ForegroundColor Yellow
}

Write-Host "`n5. ESTRUTURA DE DADOS LOCAIS" -ForegroundColor Yellow
Write-Host "   Verificando estrutura local-data..." -ForegroundColor Gray
if (Test-Path ".\local-data\local-data.json") {
    $localData = Get-Content ".\local-data\local-data.json" | ConvertFrom-Json
    Write-Host "   OK Arquivo local-data.json existe" -ForegroundColor Green
    Write-Host "   INFO Registros salvos: $($localData.Count)" -ForegroundColor Cyan
} else {
    Write-Host "   INFO Nenhum dado local salvo ainda" -ForegroundColor Cyan
}

Write-Host "`n6. STATUS DO REPOSITORIO GIT" -ForegroundColor Yellow
Write-Host "   Verificando status Git..." -ForegroundColor Gray
$gitStatus = git status --porcelain 2>$null
if ($LASTEXITCODE -eq 0) {
    if ($gitStatus) {
        Write-Host "   AVISO Ha mudancas locais nao commitadas" -ForegroundColor Yellow
        Write-Host "   (Serao automaticamente gerenciadas pelo script)" -ForegroundColor Gray
    } else {
        Write-Host "   OK Repositorio limpo" -ForegroundColor Green
    }
    
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    Write-Host "   INFO Branch atual: $currentBranch" -ForegroundColor Cyan
} else {
    Write-Host "   AVISO Nao e um repositorio Git ou Git nao instalado" -ForegroundColor Yellow
}

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "RESUMO DAS FUNCIONALIDADES IMPLEMENTADAS:" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "OK Fallback local robusto (local-data.json unico)" -ForegroundColor Green
Write-Host "OK Reenvio automatico com retry" -ForegroundColor Green
Write-Host "OK Controle de envio diario (1 envio por impressora por dia)" -ForegroundColor Green
Write-Host "OK Marcacao de registros 404 como not_found" -ForegroundColor Green
Write-Host "OK Automacao via Task Scheduler" -ForegroundColor Green
Write-Host "OK Pre-teste de dependencias" -ForegroundColor Green
Write-Host "OK Investigacao de problemas de conectividade" -ForegroundColor Green
Write-Host "OK Verificacao e atualizacao automatica do Git" -ForegroundColor Green

Write-Host "`nSCRIPTS AUXILIARES DISPONIVEIS:" -ForegroundColor Yellow
Write-Host "• pre-test.ps1 - Teste de dependencias" -ForegroundColor Gray
Write-Host "• schedule-task.ps1 - Agendamento automatico" -ForegroundColor Gray
Write-Host "• migrate-local-data.ps1 - Migracao de dados antigos" -ForegroundColor Gray
Write-Host "• cleanup-old-data.ps1 - Limpeza de dados antigos" -ForegroundColor Gray
Write-Host "• test-api.ps1 - Teste direto da API" -ForegroundColor Gray

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "PRONTO PARA PRODUCAO!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
