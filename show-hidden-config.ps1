# Demonstracao das configuracoes para execucao invisivel
# Este script mostra exatamente como a tarefa sera configurada

Write-Host "=== Configuracoes para Execucao Invisivel ===" -ForegroundColor Cyan

Write-Host "`n1. ANTES (execucao visivel):" -ForegroundColor Red
Write-Host "   Acao: powershell.exe -ExecutionPolicy Bypass -File script.ps1" -ForegroundColor Gray
Write-Host "   Principal: LogonType = Interactive" -ForegroundColor Gray
Write-Host "   Settings: Hidden = False" -ForegroundColor Gray
Write-Host "   Resultado: Abre janela do PowerShell visivel ao usuario" -ForegroundColor Red

Write-Host "`n2. DEPOIS (execucao invisivel):" -ForegroundColor Green
Write-Host "   Acao: powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File script.ps1" -ForegroundColor Gray
Write-Host "   Principal: LogonType = S4U" -ForegroundColor Gray
Write-Host "   Settings: Hidden = True" -ForegroundColor Gray
Write-Host "   Resultado: Executa completamente em background" -ForegroundColor Green

Write-Host "`n3. MUDANCAS IMPLEMENTADAS:" -ForegroundColor Yellow
Write-Host "   ✓ Adicionado -WindowStyle Hidden ao PowerShell" -ForegroundColor Green
Write-Host "   ✓ Alterado LogonType de Interactive para S4U" -ForegroundColor Green
Write-Host "   ✓ Adicionado -Hidden nas configuracoes da tarefa" -ForegroundColor Green

Write-Host "`n4. SIGNIFICADO DAS CONFIGURACOES:" -ForegroundColor Yellow
Write-Host "   -WindowStyle Hidden:" -ForegroundColor White
Write-Host "     Impede que o PowerShell abra uma janela visivel" -ForegroundColor Gray
Write-Host "   LogonType S4U:" -ForegroundColor White
Write-Host "     'Service for User' - executa sem interacao com desktop" -ForegroundColor Gray
Write-Host "   Settings Hidden:" -ForegroundColor White
Write-Host "     Tarefa fica oculta na interface do Task Scheduler" -ForegroundColor Gray

Write-Host "`n5. PARA APLICAR AS MUDANCAS:" -ForegroundColor Cyan
Write-Host "   1. Abra PowerShell como Administrador" -ForegroundColor White
Write-Host "      (Botao direito no PowerShell > 'Executar como administrador')" -ForegroundColor Gray
Write-Host "   2. Execute: .\schedule-task.ps1" -ForegroundColor White
Write-Host "   3. Teste com: .\test-hidden-execution.ps1" -ForegroundColor White

Write-Host "`n6. VERIFICACAO RAPIDA:" -ForegroundColor Yellow
Write-Host "   Apos recriar a tarefa, execute:" -ForegroundColor White
Write-Host "   Get-ScheduledTask -TaskName 'UPMS-SNMP-Collector' | Select-Object TaskName, @{n='Hidden';e={`$_.Settings.Hidden}}, @{n='LogonType';e={`$_.Principal.LogonType}}" -ForegroundColor Gray

Write-Host "`nOBS: As mudancas garantem que o snmp-collector.ps1 execute" -ForegroundColor Magenta
Write-Host "     de forma completamente invisivel ao usuario!" -ForegroundColor Magenta
