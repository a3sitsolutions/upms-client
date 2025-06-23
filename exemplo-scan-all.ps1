# Exemplos de uso do scan-printer-oids.ps1 para varrer todos os IPs

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "EXEMPLOS DE VARREDURA DE TODOS OS IPs" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "`n1. VARREDURA AUTOMÁTICA DE TODA A REDE LOCAL:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -ScanAll" -ForegroundColor White
Write-Host "   → Detecta a rede local automaticamente e varre todos os IPs" -ForegroundColor Gray
Write-Host "   → Automaticamente varre todas as impressoras encontradas" -ForegroundColor Gray

Write-Host "`n2. VARREDURA DE REDE ESPECÍFICA (TODOS OS IPs):" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -NetworkRange '192.168.1.*' -ScanAll" -ForegroundColor White
Write-Host "   → Varre todos os IPs de 192.168.1.1 a 192.168.1.254" -ForegroundColor Gray
Write-Host "   → Automaticamente varre todas as impressoras encontradas" -ForegroundColor Gray

Write-Host "`n3. VARREDURA CIDR (TODOS OS IPs):" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -NetworkRange '10.0.0.0/24' -ScanAll" -ForegroundColor White
Write-Host "   → Varre toda a rede 10.0.0.0/24" -ForegroundColor Gray
Write-Host "   → Automaticamente varre todas as impressoras encontradas" -ForegroundColor Gray

Write-Host "`n4. VARREDURA COM RANGE ESPECÍFICO (TODOS OS IPs):" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -NetworkRange '172.16.1.1-172.16.1.100' -ScanAll" -ForegroundColor White
Write-Host "   → Varre IPs de 172.16.1.1 até 172.16.1.100" -ForegroundColor Gray
Write-Host "   → Automaticamente varre todas as impressoras encontradas" -ForegroundColor Gray

Write-Host "`n5. VARREDURA COMPLETA COM EXPORTAÇÃO:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -ScanAll -ExportConfig" -ForegroundColor White
Write-Host "   → Varre toda a rede local" -ForegroundColor Gray
Write-Host "   → Varre todas as impressoras encontradas" -ForegroundColor Gray
Write-Host "   → Exporta configuração para arquivo JSON" -ForegroundColor Gray

Write-Host "`n6. VARREDURA RÁPIDA DE TODOS OS IPs:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -ScanAll -QuickScan" -ForegroundColor White
Write-Host "   → Varre toda a rede local" -ForegroundColor Gray
Write-Host "   → Varre todas as impressoras com OIDs essenciais apenas" -ForegroundColor Gray

Write-Host "`n7. VARREDURA COMPLETA E PROFUNDA:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -ScanAll -FullScan -ExportConfig" -ForegroundColor White
Write-Host "   → Varre toda a rede local" -ForegroundColor Gray
Write-Host "   → Varre todas as impressoras com SNMP Walk completo" -ForegroundColor Gray
Write-Host "   → Exporta configuração detalhada" -ForegroundColor Gray

Write-Host "`n===============================================" -ForegroundColor Yellow
Write-Host "DIFERENÇAS ENTRE OS MODOS:" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

Write-Host "`n• SEM -ScanAll:" -ForegroundColor Cyan
Write-Host "  - Você escolhe qual impressora varrer" -ForegroundColor White
Write-Host "  - Interativo: pergunta qual impressora selecionar" -ForegroundColor White

Write-Host "`n• COM -ScanAll:" -ForegroundColor Cyan
Write-Host "  - Varre TODAS as impressoras encontradas automaticamente" -ForegroundColor White
Write-Host "  - Não interativo: processa todas sem perguntar" -ForegroundColor White

Write-Host "`n===============================================" -ForegroundColor Magenta
Write-Host "EXEMPLO PRÁTICO - EXECUTAR AGORA:" -ForegroundColor Magenta
Write-Host "===============================================" -ForegroundColor Magenta

$response = Read-Host "`nDeseja executar um teste de varredura automática da rede local? (S/N)"

if ($response -eq 'S' -or $response -eq 's') {
    Write-Host "`nExecutando: .\scan-printer-oids.ps1 -ScanAll -QuickScan" -ForegroundColor Green
    Write-Host "Aguarde..." -ForegroundColor Yellow
    
    try {
        & ".\scan-printer-oids.ps1" -ScanAll -QuickScan
    } catch {
        Write-Host "Erro ao executar: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nTeste cancelado. Use os comandos acima quando quiser testar!" -ForegroundColor Yellow
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "RESUMO DOS NOVOS RECURSOS" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "OK Parametro -ScanAll adicionado" -ForegroundColor Green
Write-Host "OK Deteccao automatica da rede local" -ForegroundColor Green
Write-Host "OK Varredura automatica de todas as impressoras" -ForegroundColor Green
Write-Host "OK Suporte a multiplos formatos de rede" -ForegroundColor Green
Write-Host "OK Modo nao-interativo para automacao" -ForegroundColor Green
