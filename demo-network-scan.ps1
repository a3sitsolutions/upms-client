# Demonstração do Scanner de Rede e OIDs - Guia Completo

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "SCANNER DE REDE E OIDS - GUIA COMPLETO DE USO" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Write-Host "`nNOVAS FUNCIONALIDADES:" -ForegroundColor Green
Write-Host "• Varredura automática de rede procurando impressoras" -ForegroundColor White
Write-Host "• Identificação automática de modelos" -ForegroundColor White
Write-Host "• Seleção interativa de impressoras" -ForegroundColor White
Write-Host "• Varredura de múltiplas impressoras" -ForegroundColor White

Write-Host "`n========================================================" -ForegroundColor Yellow
Write-Host "MODOS DE USO:" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow

Write-Host "`n1. VARREDURA AUTOMATICA DE REDE:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -NetworkScan" -ForegroundColor White
Write-Host "   • Detecta rede local automaticamente" -ForegroundColor Gray
Write-Host "   • Procura todas as impressoras na rede" -ForegroundColor Gray
Write-Host "   • Permite selecionar qual escanear" -ForegroundColor Gray

Write-Host "`n2. VARREDURA DE REDE ESPECIFICA:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -NetworkRange '192.168.1.*'" -ForegroundColor White
Write-Host "   .\scan-printer-oids.ps1 -NetworkRange '192.168.1.1-254'" -ForegroundColor White
Write-Host "   .\scan-printer-oids.ps1 -NetworkRange '192.168.1.0/24'" -ForegroundColor White
Write-Host "   • Especifica range de rede para varrer" -ForegroundColor Gray
Write-Host "   • Suporte a multiplos formatos" -ForegroundColor Gray

Write-Host "`n3. VARREDURA DE IP ESPECIFICO (modo original):" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100" -ForegroundColor White
Write-Host "   • Escaneamento direto de uma impressora" -ForegroundColor Gray

Write-Host "`n4. COMBINACOES UTEIS:" -ForegroundColor Green
Write-Host "   .\scan-printer-oids.ps1 -NetworkScan -QuickScan" -ForegroundColor White
Write-Host "   .\scan-printer-oids.ps1 -NetworkRange '192.168.1.*' -FullScan" -ForegroundColor White
Write-Host "   .\scan-printer-oids.ps1 -NetworkScan -ExportConfig" -ForegroundColor White

Write-Host "`n========================================================" -ForegroundColor Magenta
Write-Host "EXEMPLO DE FLUXO COMPLETO:" -ForegroundColor Magenta
Write-Host "========================================================" -ForegroundColor Magenta

Write-Host "`nPasso 1: Executar varredura de rede" -ForegroundColor Yellow
Write-Host ".\scan-printer-oids.ps1 -NetworkScan" -ForegroundColor White

Write-Host "`nSaida esperada:" -ForegroundColor Cyan
Write-Host "Detectando rede local..." -ForegroundColor Gray
Write-Host "Rede detectada: 192.168.1.*" -ForegroundColor Gray
Write-Host "Total de IPs para verificar: 254" -ForegroundColor Gray
Write-Host "Progresso: 50/254 (19.7%) - Verificando 192.168.1.50" -ForegroundColor Gray
Write-Host "IMPRESSORA ENCONTRADA: 192.168.1.106 - Brother NC-8300w" -ForegroundColor Green
Write-Host "IMPRESSORA ENCONTRADA: 192.168.1.200 - HP LaserJet Pro M404n" -ForegroundColor Green

Write-Host "`nPasso 2: Resultado da varredura" -ForegroundColor Yellow
Write-Host "Total de dispositivos SNMP encontrados: 5" -ForegroundColor Gray
Write-Host "Total de impressoras identificadas: 2" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPRESSORAS ENCONTRADAS:" -ForegroundColor Gray
Write-Host "1. IP: 192.168.1.106" -ForegroundColor Gray
Write-Host "   Modelo: Brother NC-8300w" -ForegroundColor Gray
Write-Host "2. IP: 192.168.1.200" -ForegroundColor Gray
Write-Host "   Modelo: HP LaserJet Pro M404n" -ForegroundColor Gray

Write-Host "`nPasso 3: Selecao de impressora" -ForegroundColor Yellow
Write-Host "Multiplas impressoras encontradas. Selecione uma:" -ForegroundColor Gray
Write-Host "1. 192.168.1.106 - Brother NC-8300w" -ForegroundColor Gray
Write-Host "2. 192.168.1.200 - HP LaserJet Pro M404n" -ForegroundColor Gray
Write-Host "3. Escanear todas as impressoras" -ForegroundColor Gray
Write-Host "0. Cancelar" -ForegroundColor Gray
Write-Host "Digite o numero da opcao: 1" -ForegroundColor White

Write-Host "`nPasso 4: Varredura de OIDs" -ForegroundColor Yellow
Write-Host "Iniciando varredura de OIDs para impressora 192.168.1.106..." -ForegroundColor Gray
Write-Host "OK SNMP funcionando!" -ForegroundColor Green
Write-Host "  OK 1.3.6.1.2.1.43.10.2.1.4.1.1" -ForegroundColor Green
Write-Host "     Valor: 298935" -ForegroundColor Gray
Write-Host "     Tipo: Counter/Pages" -ForegroundColor Gray

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "FORMATOS DE REDE SUPORTADOS:" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green

Write-Host "`nFORMATO 1 - Asterisco:" -ForegroundColor Yellow
Write-Host "  192.168.1.*" -ForegroundColor White
Write-Host "  • Varre de 192.168.1.1 a 192.168.1.254" -ForegroundColor Gray

Write-Host "`nFORMATO 2 - Range:" -ForegroundColor Yellow
Write-Host "  192.168.1.100-200" -ForegroundColor White
Write-Host "  • Varre de 192.168.1.100 a 192.168.1.200" -ForegroundColor Gray

Write-Host "`nFORMATO 3 - CIDR:" -ForegroundColor Yellow
Write-Host "  192.168.1.0/24" -ForegroundColor White
Write-Host "  • Varre toda a rede /24 (256 IPs)" -ForegroundColor Gray

Write-Host "`n========================================================" -ForegroundColor Yellow
Write-Host "MARCAS DE IMPRESSORAS SUPORTADAS:" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow

Write-Host "• Brother (NC-8300w, MFC, DCP, HL series)" -ForegroundColor White
Write-Host "• HP (LaserJet, DeskJet, OfficeJet)" -ForegroundColor White
Write-Host "• Canon (imageRUNNER, PIXMA, imageCLASS)" -ForegroundColor White
Write-Host "• Xerox (WorkCentre, Phaser)" -ForegroundColor White
Write-Host "• Lexmark (Enterprise, Corporate)" -ForegroundColor White
Write-Host "• Epson (WorkForce, EcoTank)" -ForegroundColor White
Write-Host "• Kyocera (TASKalfa, ECOSYS)" -ForegroundColor White

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "BENEFICIOS DO NOVO SISTEMA:" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Write-Host "✓ Descoberta automatica de impressoras na rede" -ForegroundColor Green
Write-Host "✓ Identificacao inteligente de modelos" -ForegroundColor Green
Write-Host "✓ Suporte a multiplas impressoras simultaneas" -ForegroundColor Green
Write-Host "✓ Deteccao automatica da rede local" -ForegroundColor Green
Write-Host "✓ Configuracao YAML pronta para uso" -ForegroundColor Green
Write-Host "✓ Exportacao de resultados em JSON" -ForegroundColor Green

Write-Host "`nPRONTO PARA DESCOBRIR SUAS IMPRESSORAS!" -ForegroundColor Green -BackgroundColor Black
