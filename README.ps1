# README - Sistema SNMP para Impressoras
# 
# Este sistema coleta dados SNMP de impressoras e envia para API
#
# ARQUIVOS:
# - printers-config.yml: Configuracao de impressoras
# - snmp-collector.ps1: Script principal
# - snmp/: Pasta com executaveis Net-SNMP
#
# USO:
# 
# 1. MODO TESTE (nao envia para API):
#    pwsh -File snmp-collector.ps1 -TestMode
#
# 2. MODO PRODUCAO (envia para API):
#    pwsh -File snmp-collector.ps1
#
# 3. MODO PRODUCAO com endpoint customizado:
#    pwsh -File snmp-collector.ps1 -ApiEndpoint "https://sua-api.com/endpoint"
#
# DADOS COLETADOS:
# - Modelo da Impressora (sysDescr)
# - Numero de Serie
# - Total de Paginas Impressas
# - Nome do Sistema (sysName)
#
# FORMATO JSON ENVIADO PARA API:
# {
#   "model": "Brother NC-8300w, Firmware Ver.X ,MID 8C5-H27,FID 2",
#   "serialNumber": "U63885F9N733180", 
#   "totalPrintedPages": 298935
# }
#
# ADICIONAR NOVA IMPRESSORA:
# Edite printers-config.yml e adicione novo bloco:
#
# - model: "Nova Impressora"
#   description: "Descricao da impressora"
#   ip: "192.168.1.100"
#   community: "public"
#   oids:
#     paginasImpressas:
#       oid: "1.3.6.1.2.1.43.10.2.1.4.1.1"
#       description: "Contador de paginas impressas"
#     modeloImpressora:
#       oid: "1.3.6.1.2.1.1.1.0"
#       description: "Descricao do sistema/modelo"
#     numeroSerie:
#       oid: "1.3.6.1.2.1.43.5.1.1.17.1"
#       description: "Numero de serie"
#     nomeSistema:
#       oid: "1.3.6.1.2.1.1.5.0"
#       description: "Nome do sistema"
#
# DEPENDENCIAS:
# - PowerShell 5.1 ou superior
# - Modulo powershell-yaml (instalado automaticamente)
# - curl (para envio de dados para API)
# - Net-SNMP executaveis na pasta snmp/ (snmpget.exe)
#
# ENDPOINT API:
# POST https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer
# Content-Type: application/json
# Body: {"model": "string", "serialNumber": "string", "totalPrintedPages": 0}
#
# TROUBLESHOOTING:
# 1. Se SNMP nao responder, o sistema usa dados simulados
# 2. Verifique se a impressora tem SNMP habilitado
# 3. Teste conectividade de rede com a impressora
# 4. Verifique se a comunidade SNMP esta correta (geralmente "public")
# 5. Para testar sem enviar dados reais, use -TestMode

Write-Host "=== SISTEMA SNMP PARA IMPRESSORAS ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "Arquivos disponiveis:" -ForegroundColor Cyan
Write-Host "  - snmp-collector.ps1 (Script principal)" -ForegroundColor White
Write-Host "  - printers-config.yml (Configuracao)" -ForegroundColor White
Write-Host ""
Write-Host "Uso:" -ForegroundColor Cyan
Write-Host "  Modo teste:     pwsh -File snmp-collector.ps1 -TestMode" -ForegroundColor Yellow
Write-Host "  Modo producao:  pwsh -File snmp-collector.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "Para mais informacoes, leia este arquivo README.ps1" -ForegroundColor Gray
