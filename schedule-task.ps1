# Script para criar agendamento no Task Scheduler
# Executa o coletor SNMP automaticamente EM BACKGROUND (invisivel ao usuario)
# 
# Configuracoes de execucao oculta:
# - WindowStyle Hidden: PowerShell nao abre janela
# - LogonType S4U: Executa sem interacao com usuario
# - Hidden: Tarefa fica oculta no Task Scheduler

param(
    [string]$TaskName = "UPMS-SNMP-Collector",
    [string]$ScriptPath = $PSScriptRoot,
    [int]$IntervalHours = 1,
    [switch]$RemoveTask = $false
)

# Verifica se esta executando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Este script precisa ser executado como Administrador." -ForegroundColor Red
    Write-Host "Clique com botao direito no PowerShell e selecione 'Executar como administrador'" -ForegroundColor Yellow
    pause
    exit
}

$fullScriptPath = Join-Path $ScriptPath "snmp-collector.ps1"

if (-not (Test-Path $fullScriptPath)) {
    Write-Host "Script snmp-collector.ps1 nao encontrado em: $fullScriptPath" -ForegroundColor Red
    exit
}

if ($RemoveTask) {
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "Tarefa '$TaskName' removida com sucesso!" -ForegroundColor Green
    }
    catch {
        Write-Host "Erro ao remover tarefa: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit
}

Write-Host "=== Configurando Agendamento UPMS SNMP Collector ===" -ForegroundColor Cyan
Write-Host "Nome da tarefa: $TaskName" -ForegroundColor White
Write-Host "Script: $fullScriptPath" -ForegroundColor White
Write-Host "Intervalo: A cada $IntervalHours hora(s)" -ForegroundColor White

try {
    # Remove tarefa existente se houver
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch { }

    # Cria acao (execucao oculta - sem janela)
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$fullScriptPath`""

    # Cria gatilho (executa a cada X horas)
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)

    # Configuracoes da tarefa (execucao em background)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable -Hidden

    # Cria principal (executa em background sem interacao com usuario)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U

    # Registra a tarefa
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Coleta dados SNMP das impressoras e envia para API UPMS"

    Write-Host "`nTarefa criada com sucesso!" -ForegroundColor Green
    Write-Host "A tarefa ira executar a cada $IntervalHours hora(s)" -ForegroundColor Green
    Write-Host "EXECUCAO INVISIVEL: A tarefa rodara em background (sem janelas)" -ForegroundColor Magenta
    
    Write-Host "`nComandos uteis:" -ForegroundColor Yellow
    Write-Host "  Ver tarefas: Get-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host "  Ver tarefas ocultas: Get-ScheduledTask | Where-Object {`$_.Settings.Hidden}" -ForegroundColor Gray
    Write-Host "  Executar agora: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host "  Ver ultima execucao: Get-ScheduledTaskInfo -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host "  Remover: .\schedule-task.ps1 -RemoveTask" -ForegroundColor Gray
}
catch {
    Write-Host "Erro ao criar tarefa: $($_.Exception.Message)" -ForegroundColor Red
}
