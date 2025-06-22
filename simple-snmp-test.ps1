# Script SNMP simples para Windows - Sem dependências externas
# Lê mibs.yml e tenta conectar via SNMP usando PowerShell puro

# Função para ler YAML simples (sem módulo)
function Read-SimpleYaml {
    param([string]$FilePath)
    
    $yaml = @{}
    $mibs = @()
    $content = Get-Content $FilePath
    
    foreach ($line in $content) {
        $line = $line.Trim()
        if ($line -match '^printerIp:\s*(.+)$') {
            $yaml.printerIp = $matches[1]
        }
        elseif ($line -match '^\s*-\s*name:\s*(.+)$') {
            $mib = @{ name = $matches[1] }
            $mibs += $mib
        }
        elseif ($line -match '^\s*oid:\s*(.+)$' -and $mibs.Count -gt 0) {
            $mibs[-1].oid = $matches[1]
        }
    }
    
    $yaml.mibs = $mibs
    return $yaml
}

# Função para testar conectividade SNMP básica
function Test-SNMPConnectivity {
    param(
        [string]$IpAddress,
        [int]$Port = 161,
        [int]$TimeoutMs = 3000
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($IpAddress, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    }
    catch {
        return $false
    }
}

# Função para simular consulta SNMP com dados mock
function Get-MockSNMPValue {
    param(
        [string]$IpAddress,
        [string]$OID
    )    # Dados simulados baseados nos OIDs reais da impressora Brother
    $mockData = @{
        "1.3.6.1.2.1.43.10.2.1.4.1.1" = "298935"                           # Páginas Impressas
        "1.3.6.1.2.1.1.5.0" = "BRW105BAD6F5F7A"                           # Nome do Sistema
        "1.3.6.1.2.1.1.1.0" = "Brother NC-8300w, Firmware Ver.X ,MID 8C5-H27,FID 2"  # Descrição do Sistema
        "1.3.6.1.2.1.43.5.1.1.17.1" = "U63885F9N733180"                   # Número de Série
    }
    
    if ($mockData.ContainsKey($OID)) {
        return $mockData[$OID]
    }
    
    return "Valor não encontrado para OID: $OID"
}

# Função principal
function Main {
    Write-Host "=== SNMP Reader Simples ===" -ForegroundColor Magenta
    
    # Verifica se arquivo existe
    $yamlPath = Join-Path $PSScriptRoot "mibs.yml"
    if (-not (Test-Path $yamlPath)) {
        Write-Error "Arquivo mibs.yml não encontrado em: $yamlPath"
        return
    }
    
    # Lê configuração
    Write-Host "Lendo configuração..." -ForegroundColor Green
    $config = Read-SimpleYaml -FilePath $yamlPath
    
    Write-Host "`n=== Configuração ===" -ForegroundColor Cyan
    Write-Host "IP: $($config.printerIp)" -ForegroundColor White
    Write-Host "MIBs: $($config.mibs.Count) configuradas" -ForegroundColor White
    
    # Lista MIBs
    Write-Host "`n=== MIBs Configuradas ===" -ForegroundColor Cyan
    foreach ($mib in $config.mibs) {
        Write-Host "- $($mib.name): $($mib.oid)" -ForegroundColor Gray
    }
    
    # Testa conectividade
    Write-Host "`n=== Testando Conectividade ===" -ForegroundColor Cyan
    $connected = Test-SNMPConnectivity -IpAddress $config.printerIp -Port 161
    
    if ($connected) {
        Write-Host "✓ Porta 161 acessível em $($config.printerIp)" -ForegroundColor Green
    } else {
        Write-Host "✗ Não foi possível conectar na porta 161" -ForegroundColor Red
        Write-Host "  Possíveis causas:" -ForegroundColor Yellow
        Write-Host "  - Impressora desligada ou fora da rede" -ForegroundColor Yellow
        Write-Host "  - SNMP desabilitado na impressora" -ForegroundColor Yellow
        Write-Host "  - Firewall bloqueando a conexão" -ForegroundColor Yellow
    }
    
    # Consulta valores (usando dados simulados se não conseguir conectar)
    Write-Host "`n=== Consultando Valores ===" -ForegroundColor Cyan
    
    foreach ($mib in $config.mibs) {
        Write-Host "`n$($mib.name) ($($mib.oid)):" -ForegroundColor Yellow
        
        if ($connected) {
            Write-Host "  Status: Conectado, mas sem cliente SNMP instalado" -ForegroundColor Orange
            Write-Host "  Para consultas reais, instale:" -ForegroundColor White
            Write-Host "  1. Net-SNMP tools" -ForegroundColor White
            Write-Host "  2. OU módulo Posh-SNMP: Install-Module Posh-SNMP" -ForegroundColor White
        }
        
        # Mostra valor simulado
        $mockValue = Get-MockSNMPValue -IpAddress $config.printerIp -OID $mib.oid
        Write-Host "  Valor simulado: $mockValue" -ForegroundColor Cyan
    }
    
    Write-Host "`n=== Instruções para SNMP Real ===" -ForegroundColor Magenta
    Write-Host "1. Para instalar Net-SNMP:" -ForegroundColor White
    Write-Host "   - Baixe de: http://www.net-snmp.org/download.html" -ForegroundColor Gray
    Write-Host "   - Execute o instalador como administrador" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Para usar módulo PowerShell:" -ForegroundColor White
    Write-Host "   Install-Module -Name Posh-SNMP -Scope CurrentUser" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Teste manual com snmpget:" -ForegroundColor White
    Write-Host "   snmpget -v2c -c public $($config.printerIp) 1.3.6.1.2.1.43.5.1.1.16" -ForegroundColor Gray
    
    Write-Host "`n=== Finalizado ===" -ForegroundColor Magenta
}

# Executa
Main
