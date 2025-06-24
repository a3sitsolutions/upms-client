# Script para testar se a execucao agendada esta realmente oculta
# Executa: .\test-hidden-execution.ps1

param(
    [string]$TaskName = "UPMS-SNMP-Collector"
)

Write-Host "=== Teste de Execucao Oculta ===" -ForegroundColor Cyan

# 1. Verifica se a tarefa existe e esta configurada corretamente
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    Write-Host "`n1. Tarefa encontrada: $($task.TaskName)" -ForegroundColor Green
    
    # Verifica configuracoes de execucao oculta
    Write-Host "`n2. Verificando configuracoes de execucao oculta:" -ForegroundColor Yellow
    
    # Verifica se a tarefa esta marcada como oculta
    if ($task.Settings.Hidden) {
        Write-Host "   ✓ Tarefa marcada como oculta (Hidden = True)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Tarefa NAO esta oculta (Hidden = False)" -ForegroundColor Red
    }
    
    # Verifica o LogonType
    $principal = $task.Principal
    Write-Host "   LogonType: $($principal.LogonType)" -ForegroundColor White
    if ($principal.LogonType -eq "S4U") {
        Write-Host "   ✓ LogonType correto para execucao em background (S4U)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ LogonType pode causar interacao com usuario ($($principal.LogonType))" -ForegroundColor Red
    }
    
    # Verifica os argumentos do PowerShell
    $action = $task.Actions[0]
    Write-Host "   Argumentos: $($action.Arguments)" -ForegroundColor White
    if ($action.Arguments -like "*-WindowStyle Hidden*") {
        Write-Host "   ✓ PowerShell configurado para execucao oculta (-WindowStyle Hidden)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ PowerShell pode abrir janela (falta -WindowStyle Hidden)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`n1. Tarefa nao encontrada: $TaskName" -ForegroundColor Red
    Write-Host "   Execute primeiro: .\schedule-task.ps1" -ForegroundColor Yellow
    exit
}

# 2. Executa a tarefa manualmente para teste
Write-Host "`n3. Executando tarefa para teste..." -ForegroundColor Yellow
try {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "   ✓ Tarefa iniciada" -ForegroundColor Green
    
    # Aguarda um pouco para a tarefa processar
    Start-Sleep -Seconds 5
    
    # Verifica o status da ultima execucao
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Host "`n4. Status da ultima execucao:" -ForegroundColor Yellow
    Write-Host "   Ultima execucao: $($taskInfo.LastRunTime)" -ForegroundColor White
    Write-Host "   Resultado: $($taskInfo.LastTaskResult)" -ForegroundColor White
    
    if ($taskInfo.LastTaskResult -eq 0) {
        Write-Host "   ✓ Tarefa executada com sucesso (codigo 0)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Tarefa com erro (codigo $($taskInfo.LastTaskResult))" -ForegroundColor Red
    }
    
} catch {
    Write-Host "   ✗ Erro ao executar tarefa: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Verifica se algum processo PowerShell visivel foi criado
Write-Host "`n5. Verificando processos PowerShell visiveis..." -ForegroundColor Yellow
$visiblePS = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }
if ($visiblePS) {
    Write-Host "   ⚠ Encontrados processos PowerShell com janela visivel:" -ForegroundColor Yellow
    $visiblePS | ForEach-Object { Write-Host "     PID: $($_.Id) - Titulo: $($_.MainWindowTitle)" -ForegroundColor Gray }
} else {
    Write-Host "   ✓ Nenhum processo PowerShell visivel encontrado" -ForegroundColor Green
}

Write-Host "`n=== Resumo ===" -ForegroundColor Cyan
Write-Host "Se todas as verificacoes estao com ✓, a tarefa executara de forma invisivel." -ForegroundColor White
Write-Host "Monitore os logs em local-data/ para confirmar que a coleta esta funcionando." -ForegroundColor White

Write-Host "`nComandos para monitoramento:" -ForegroundColor Yellow
Write-Host "  Ver info da tarefa: Get-ScheduledTaskInfo -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "  Ver logs locais: Get-ChildItem local-data/*.json | Sort-Object LastWriteTime -Descending" -ForegroundColor Gray
