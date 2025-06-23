# Demonstração do Scanner de OIDs - Instruções de Uso

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "SCANNER DE OIDS PARA IMPRESSORAS - GUIA DE USO" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "`n1. SCAN RAPIDO (Recomendado):" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100 -QuickScan" -ForegroundColor White

Write-Host "`n2. SCAN COMPLETO:" -ForegroundColor Green  
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100" -ForegroundColor White

Write-Host "`n3. SCAN COM DESCOBERTA:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100 -FullScan" -ForegroundColor White

Write-Host "`n4. EXPORTAR RESULTADOS:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100 -ExportConfig" -ForegroundColor White

Write-Host "`n===============================================" -ForegroundColor Yellow
Write-Host "OIDS PRINCIPAIS TESTADOS:" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

Write-Host "`nSISTEMA:" -ForegroundColor Cyan
Write-Host "  1.3.6.1.2.1.1.1.0 - Descricao do Sistema" -ForegroundColor Gray
Write-Host "  1.3.6.1.2.1.1.5.0 - Nome do Sistema" -ForegroundColor Gray

Write-Host "`nPAGINAS IMPRESSAS:" -ForegroundColor Cyan
Write-Host "  1.3.6.1.2.1.43.10.2.1.4.1.1 - Contador padrao" -ForegroundColor Gray
Write-Host "  1.3.6.1.4.1.1347.43.10.1.1.12.1.1 - Brother" -ForegroundColor Gray
Write-Host "  1.3.6.1.4.1.11.2.3.9.4.2.1.1.16.3.1.1 - HP" -ForegroundColor Gray

Write-Host "`nNUMERO DE SERIE:" -ForegroundColor Cyan  
Write-Host "  1.3.6.1.2.1.43.5.1.1.17.1 - Padrao MIB-II" -ForegroundColor Gray
Write-Host "  1.3.6.1.4.1.1602.1.2.1.4.1.1.3.1 - Canon" -ForegroundColor Gray
Write-Host "  1.3.6.1.4.1.1347.42.2.1.1.1.4.1 - Brother" -ForegroundColor Gray

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "EXEMPLO DE SAIDA ESPERADA:" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "OK SNMP funcionando!" -ForegroundColor Green
Write-Host "Descricao do sistema: Brother NC-8300w, Firmware Ver.X" -ForegroundColor White
Write-Host ""
Write-Host "Categoria: Essenciais" -ForegroundColor Magenta
Write-Host "  OK 1.3.6.1.2.1.43.10.2.1.4.1.1" -ForegroundColor Green
Write-Host "     Valor: 298935" -ForegroundColor White
Write-Host "     Tipo: Counter/Pages" -ForegroundColor Cyan
Write-Host ""
Write-Host "CONFIGURACAO RECOMENDADA:" -ForegroundColor Green
Write-Host "  - model: 'Brother Printer'" -ForegroundColor White
Write-Host "    ip: '192.168.1.100'" -ForegroundColor White
Write-Host "    oids:" -ForegroundColor White
Write-Host "      paginasImpressas:" -ForegroundColor White
Write-Host "        oid: '1.3.6.1.2.1.43.10.2.1.4.1.1'" -ForegroundColor White

Write-Host "`n===============================================" -ForegroundColor Yellow
Write-Host "PROXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

Write-Host "1. Execute o scan na sua impressora" -ForegroundColor White
Write-Host "2. Copie a configuracao YAML gerada" -ForegroundColor White  
Write-Host "3. Cole no arquivo printers-config.yml" -ForegroundColor White
Write-Host "4. Teste com: .\snmp-collector.ps1 -TestMode" -ForegroundColor White
Write-Host "5. Execute em producao: .\snmp-collector.ps1" -ForegroundColor White

Write-Host "`nPRONTO PARA USAR!" -ForegroundColor Green -BackgroundColor Black
