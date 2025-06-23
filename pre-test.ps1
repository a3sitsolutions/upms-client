# Script de pré-teste para verificar dependências

Write-Host "=== Pré-teste de dependências ===" -ForegroundColor Cyan

# Verifica módulo powershell-yaml
Write-Host "Verificando módulo powershell-yaml..." -ForegroundColor White
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Módulo powershell-yaml não encontrado!" -ForegroundColor Red
    Write-Host "Execute o seguinte comando para instalar:" -ForegroundColor Yellow
    Write-Host "Install-Module -Name powershell-yaml -Force -Scope CurrentUser" -ForegroundColor Green
} else {
    Write-Host "Módulo powershell-yaml está instalado." -ForegroundColor Green
}

# Verifica executável curl.exe
Write-Host "Verificando executável curl.exe..." -ForegroundColor White
$curlPath = Join-Path $PSScriptRoot "curl\curl.exe"
if (-not (Test-Path $curlPath)) {
    Write-Host "Executável curl.exe não encontrado!" -ForegroundColor Red
    Write-Host "Certifique-se de que o arquivo esteja na pasta: $curlPath" -ForegroundColor Yellow
} else {
    Write-Host "Executável curl.exe está presente." -ForegroundColor Green
}

# Verifica executável snmpget.exe
Write-Host "Verificando executável snmpget.exe..." -ForegroundColor White
$snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
if (-not (Test-Path $snmpgetPath)) {
    Write-Host "Executável snmpget.exe não encontrado!" -ForegroundColor Red
    Write-Host "Certifique-se de que o arquivo esteja na pasta: $snmpgetPath" -ForegroundColor Yellow
} else {
    Write-Host "Executável snmpget.exe está presente." -ForegroundColor Green
}

# Adiciona teste de conectividade com servidor
Write-Host "Testando conectividade com servidor..." -ForegroundColor White
$serverTest = Test-NetConnection -ComputerName "upms-backend.maranguape.a3sitsolutions.com.br" -Port 443

if ($serverTest.TcpTestSucceeded) {
    Write-Host "Conexão com o servidor bem-sucedida!" -ForegroundColor Green
} else {
    Write-Host "Falha na conexão com o servidor!" -ForegroundColor Red
    Write-Host "Detalhes: $($serverTest)" -ForegroundColor Yellow
}

Write-Host "=== Pré-teste concluído ===" -ForegroundColor Cyan
