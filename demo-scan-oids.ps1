# Script de demonstração do scanner de OIDs
# Simula uma impressora respondendo para mostrar as funcionalidades

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "DEMONSTRACAO DO SCANNER DE OIDS" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "`nEste script demonstra como usar o scanner de OIDs:" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. SCAN RAPIDO (QuickScan):" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100 -QuickScan" -ForegroundColor Gray
Write-Host "   • Testa apenas OIDs essenciais" -ForegroundColor Gray
Write-Host "   • Rapido e eficiente" -ForegroundColor Gray
Write-Host ""

Write-Host "2. SCAN COMPLETO:" -ForegroundColor Green  
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100" -ForegroundColor Gray
Write-Host "   • Testa todos os OIDs conhecidos" -ForegroundColor Gray
Write-Host "   • Mais detalhado" -ForegroundColor Gray
Write-Host ""

Write-Host "3. SCAN COMPLETO COM WALK:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100 -FullScan" -ForegroundColor Gray
Write-Host "   • Inclui SNMP walk para descobrir novos OIDs" -ForegroundColor Gray
Write-Host "   • Pode demorar varios minutos" -ForegroundColor Gray
Write-Host ""

Write-Host "4. EXPORTAR CONFIGURACAO:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100 -ExportConfig" -ForegroundColor Gray
Write-Host "   • Salva os resultados em arquivo JSON" -ForegroundColor Gray
Write-Host "   • Útil para documentacao" -ForegroundColor Gray
Write-Host ""

Write-Host "EXEMPLO DE SAIDA ESPERADA:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray

$simulatedOutput = @"
OK SNMP funcionando!
Descricao do sistema: Brother NC-8300w, Firmware Ver.X

Categoria: Essenciais
─────────────────────────────
  OK 1.3.6.1.2.1.1.1.0
     Descrição: Descrição do Sistema
     Valor: Brother NC-8300w, Firmware Ver.X
     Tipo: Model/Description

  OK 1.3.6.1.2.1.43.10.2.1.4.1.1  
     Descrição: Contador de páginas
     Valor: 298935
     Tipo: Counter/Pages

  OK 1.3.6.1.2.1.43.5.1.1.17.1
     Descrição: Número de série
     Valor: U63885F9N733180
     Tipo: Serial Number

CONFIGURACAO RECOMENDADA PARA PRINTERS-CONFIG.YML:
  - model: "Brother Printer"
    description: "Impressora Brother - IP 192.168.1.100"
    ip: "192.168.1.100"
    community: "public"
    oids:
      paginasImpressas:
        oid: "1.3.6.1.2.1.43.10.2.1.4.1.1"
        description: "Contador de páginas"
        type: "Counter32"
      numeroSerie:
        oid: "1.3.6.1.2.1.43.5.1.1.17.1"
        description: "Número de série"
        type: "String"
      modeloImpressora:
        oid: "1.3.6.1.2.1.1.1.0"
        description: "Descrição do Sistema"
        type: "String"
"@

Write-Host $simulatedOutput -ForegroundColor White

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "OIDS TESTADOS POR CATEGORIA:" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "`nSISTEMA:" -ForegroundColor Yellow
Write-Host "• 1.3.6.1.2.1.1.1.0 - Descrição do Sistema" -ForegroundColor Gray
Write-Host "• 1.3.6.1.2.1.1.5.0 - Nome do Sistema" -ForegroundColor Gray
Write-Host "• 1.3.6.1.2.1.1.6.0 - Localização" -ForegroundColor Gray

Write-Host "`nPAGINAS IMPRESSAS:" -ForegroundColor Yellow
Write-Host "• 1.3.6.1.2.1.43.10.2.1.4.1.1 - Contador padrão" -ForegroundColor Gray
Write-Host "• 1.3.6.1.4.1.1347.43.10.1.1.12.1.1 - Brother" -ForegroundColor Gray
Write-Host "• 1.3.6.1.4.1.11.2.3.9.4.2.1.1.16.3.1.1 - HP" -ForegroundColor Gray
Write-Host "• 1.3.6.1.4.1.1602.1.2.1.4.1.1.1.1 - Canon" -ForegroundColor Gray

Write-Host "`nNUMERO DE SERIE:" -ForegroundColor Yellow  
Write-Host "• 1.3.6.1.2.1.43.5.1.1.17.1 - Padrão MIB-II" -ForegroundColor Gray
Write-Host "• 1.3.6.1.4.1.1602.1.2.1.4.1.1.3.1 - Canon" -ForegroundColor Gray
Write-Host "• 1.3.6.1.4.1.11.2.3.9.4.2.1.1.3.3.0 - HP" -ForegroundColor Gray
Write-Host "• 1.3.6.1.4.1.1347.42.2.1.1.1.4.1 - Brother" -ForegroundColor Gray

Write-Host "`nSTATUS E SUPRIMENTOS:" -ForegroundColor Yellow
Write-Host "• 1.3.6.1.2.1.43.11.1.1.9.1.1 - Nível de toner" -ForegroundColor Gray
Write-Host "• 1.3.6.1.2.1.43.8.2.1.10.1.1 - Status da impressora" -ForegroundColor Gray

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "COMO USAR OS RESULTADOS:" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

Write-Host "1. Execute o scan na sua impressora" -ForegroundColor White
Write-Host "2. Copie a configuracao YAML gerada" -ForegroundColor White  
Write-Host "3. Cole no arquivo printers-config.yml" -ForegroundColor White
Write-Host "4. Ajuste modelo e descricao se necessario" -ForegroundColor White
Write-Host "5. Teste com: .\snmp-collector.ps1 -TestMode" -ForegroundColor White
Write-Host "6. Execute em producao: .\snmp-collector.ps1" -ForegroundColor White

Write-Host "`nPRONTO PARA USAR!" -ForegroundColor Green
