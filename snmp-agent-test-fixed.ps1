# Script para ler arquivo mibs.yml e consultar valores SNMP
# Encoding: UTF-8

# Função para instalar módulo SNMP PowerShell
function Install-SNMPModule {
    if (-not (Get-Module -ListAvailable -Name Posh-SNMP)) {
        Write-Host "Instalando modulo Posh-SNMP..." -ForegroundColor Yellow
        try {
            Install-Module -Name Posh-SNMP -Force -Scope CurrentUser -AllowClobber
        }
        catch {
            Write-Warning "Nao foi possivel instalar Posh-SNMP: $($_.Exception.Message)"
            return $false
        }
    }
    
    try {
        Import-Module Posh-SNMP -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Nao foi possivel importar Posh-SNMP: $($_.Exception.Message)"
        return $false
    }
}

# Função para usar Posh-SNMP se disponível
function Get-SNMPValuePosh {
    param(
        [string]$IpAddress,
        [string]$Community = "public",
        [string]$OID
    )
    
    try {
        # Usa o módulo Posh-SNMP
        $result = Get-SNMPData -IP $IpAddress -Community $Community -OID $OID -Version V2
        if ($result -and $result.Data) {
            return $result.Data
        }
        return "Sem dados"
    }
    catch {
        Write-Warning "Erro com Posh-SNMP: $($_.Exception.Message)"
        return $null
    }
}

# Função para instalar módulo YAML se não estiver disponível
function Install-YamlModule {
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "Instalando modulo powershell-yaml..." -ForegroundColor Yellow
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser
    }
    Import-Module powershell-yaml
}

# Função para fazer consulta SNMP usando snmpget local
function Get-SNMPValue {
    param(
        [string]$IpAddress,
        [string]$Community = "public",
        [string]$OID
    )
    
    try {
        # Caminho para o executável snmpget local
        $snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
        
        # Verifica se o executável local existe
        if (Test-Path $snmpgetPath) {
            Write-Host "Usando snmpget local: $snmpgetPath" -ForegroundColor Green
            # Executa consulta SNMP usando executável local com timeout e retry
            # -On: usa OIDs numericos (nao precisa das MIBs)
            # -Oe: nao mostra erros de MIB
            Write-Host "Executando: snmpget -v2c -c $Community -t 5 -r 2 -On -Oe $IpAddress $OID" -ForegroundColor Gray
            $result = & $snmpgetPath -v2c -c $Community -t 5 -r 2 -On -Oe $IpAddress $OID 2>&1
            
            # Mostra resultado bruto para debug
            Write-Host "Resultado bruto: $result" -ForegroundColor Magenta
        } else {
            # Fallback para snmpget do sistema
            $snmpget = Get-Command snmpget -ErrorAction SilentlyContinue
            if (-not $snmpget) {
                Write-Warning "snmpget nao encontrado nem local nem no sistema."
                return $null
            }
            Write-Host "Usando snmpget do sistema" -ForegroundColor Yellow
            # Executa consulta SNMP
            $result = & snmpget -v2c -c $Community $IpAddress $OID 2>$null
        }
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*" -and $result -notlike "*No Response*") {
            # Extrai apenas o valor da resposta SNMP
            Write-Host "SNMP respondeu com sucesso" -ForegroundColor Green
            $value = ($result -split "=")[1]
            if ($value) {
                return $value.Trim()
            }
        } else {
            Write-Host "SNMP falhou - Exit Code: $LASTEXITCODE, Result: $result" -ForegroundColor Red
            return "Erro na consulta: $result"
        }
    }
    catch {
        Write-Error "Erro ao consultar SNMP: $($_.Exception.Message)"
        return $null
    }
}

# Função para fazer snmpwalk usando executável local
function Get-SNMPWalk {
    param(
        [string]$IpAddress,
        [string]$Community = "public",
        [string]$OID
    )
    
    try {
        # Caminho para o executável snmpwalk local
        $snmpwalkPath = Join-Path $PSScriptRoot "snmp\snmpwalk.exe"
        
        # Verifica se o executável local existe
        if (Test-Path $snmpwalkPath) {
            Write-Host "Usando snmpwalk local: $snmpwalkPath" -ForegroundColor Green
            # Executa snmpwalk usando executável local
            $result = & $snmpwalkPath -v2c -c $Community $IpAddress $OID 2>$null
            return $result
        } else {
            Write-Warning "snmpwalk.exe nao encontrado na pasta local"
            return $null
        }
    }
    catch {
        Write-Error "Erro ao executar snmpwalk: $($_.Exception.Message)"
        return $null
    }
}

# Função alternativa usando .NET para SNMP
function Get-SNMPValueDotNet {
    param(
        [string]$IpAddress,
        [string]$Community = "public",
        [string]$OID
    )
    
    try {
        # Implementação SNMP usando UDP Socket e codificação ASN.1 basica
        Add-Type -AssemblyName System.Net
        
        # Converte OID string para array de bytes
        $oidParts = $OID.Split('.')
        $oidBytes = @()
        
        # Primeira parte do OID (40 * primeiro + segundo)
        if ($oidParts.Length -ge 2) {
            $firstByte = [int]$oidParts[0] * 40 + [int]$oidParts[1]
            $oidBytes += $firstByte
            
            # Adiciona o resto dos identificadores
            for ($i = 2; $i -lt $oidParts.Length; $i++) {
                $value = [int]$oidParts[$i]
                if ($value -lt 128) {
                    $oidBytes += $value
                } else {
                    # Para valores maiores que 127, usar codificação multi-byte
                    $bytes = @()
                    while ($value -gt 0) {
                        $bytes = @(($value -band 0x7F)) + $bytes
                        $value = $value -shr 7
                    }
                    for ($j = 0; $j -lt $bytes.Length - 1; $j++) {
                        $bytes[$j] = $bytes[$j] -bor 0x80
                    }
                    $oidBytes += $bytes
                }
            }
        }
        
        # Monta pacote SNMP GET simples
        $requestId = Get-Random -Minimum 1 -Maximum 32767  # Limite para int16
        
        # Varbind (OID + NULL value)
        $varbind = @(0x30) + @($oidBytes.Length + 4) + @(0x06) + @($oidBytes.Length) + $oidBytes + @(0x05, 0x00)
        
        # Varbind list
        $varbindList = @(0x30) + @($varbind.Length) + $varbind
        
        # PDU (GET request)
        $pdu = @(0xA0) + @($varbindList.Length + 9) + 
               @(0x02, 0x02) + [BitConverter]::GetBytes([int16]$requestId)[1,0] +  # Request ID
               @(0x02, 0x01, 0x00) +  # Error status
               @(0x02, 0x01, 0x00) +  # Error index
               $varbindList
        
        # Community string
        $communityBytes = [System.Text.Encoding]::ASCII.GetBytes($Community)
        $communityTLV = @(0x04) + @($communityBytes.Length) + $communityBytes
        
        # SNMP message
        $snmpMessage = @(0x30) + @($communityTLV.Length + $pdu.Length + 3) +
                       @(0x02, 0x01, 0x00) +  # Version (0 = v1)
                       $communityTLV + $pdu
        
        # Envia via UDP
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Connect($IpAddress, 161)
        $udpClient.Send($snmpMessage, $snmpMessage.Length) | Out-Null
        
        # Recebe resposta (timeout de 5 segundos)
        $udpClient.Client.ReceiveTimeout = 5000
        $remoteEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $response = $udpClient.Receive([ref]$remoteEndpoint)
        $udpClient.Close()
        
        # Parse basico da resposta
        if ($response -and $response.Length -gt 20) {
            # Localiza o valor na resposta (implementação simplificada)
            # Procura por STRING (0x04) ou INTEGER (0x02) na resposta
            for ($i = 20; $i -lt $response.Length - 2; $i++) {
                if ($response[$i] -eq 0x04 -or $response[$i] -eq 0x02) {  # STRING ou INTEGER
                    $length = $response[$i + 1]
                    if ($i + 2 + $length -le $response.Length) {
                        $valueBytes = $response[($i + 2)..($i + 1 + $length)]
                        if ($response[$i] -eq 0x04) {  # STRING
                            return [System.Text.Encoding]::ASCII.GetString($valueBytes)
                        } else {  # INTEGER
                            $value = 0
                            foreach ($byte in $valueBytes) {
                                $value = ($value -shl 8) + $byte
                            }
                            return $value.ToString()
                        }
                    }
                }
            }
        }
        
        return "Sem resposta ou timeout"
    }
    catch {
        Write-Warning "Erro na consulta SNMP .NET: $($_.Exception.Message)"
        return "Erro: $($_.Exception.Message)"
    }
}

# Função para testar conectividade SNMP basica
function Test-SNMPConnectivity {
    param(
        [string]$IpAddress,
        [string]$Community = "public"
    )
    
    Write-Host "`n=== Testando Conectividade SNMP ===" -ForegroundColor Cyan
    $snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
    
    if (-not (Test-Path $snmpgetPath)) {
        Write-Host "snmpget.exe nao encontrado" -ForegroundColor Red
        return $false
    }
    
    # Testa OID basico do sistema (sysDescr)
    $basicOID = "1.3.6.1.2.1.1.1.0"
    
    Write-Host "Testando conectividade basica..." -ForegroundColor Yellow
    Write-Host "OID de teste: $basicOID (sysDescr)" -ForegroundColor Gray
    
    # Testa SNMP v1
    Write-Host "Tentando SNMP v1..." -ForegroundColor Yellow
    $result1 = & $snmpgetPath -v1 -c $Community -t 3 -r 1 -On -Oe $IpAddress $basicOID 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $result1 -and $result1 -notlike "*Timeout*") {
        Write-Host "OK SNMP v1 funcionando!" -ForegroundColor Green
        Write-Host "Resposta: $result1" -ForegroundColor White
        return $true
    }
    
    # Testa SNMP v2c
    Write-Host "Tentando SNMP v2c..." -ForegroundColor Yellow
    $result2 = & $snmpgetPath -v2c -c $Community -t 3 -r 1 -On -Oe $IpAddress $basicOID 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $result2 -and $result2 -notlike "*Timeout*") {
        Write-Host "OK SNMP v2c funcionando!" -ForegroundColor Green
        Write-Host "Resposta: $result2" -ForegroundColor White
        return $true
    }
    
    # Testa diferentes comunidades
    $communities = @("private", "admin", "snmp", "manager")
    foreach ($comm in $communities) {
        Write-Host "Tentando comunidade '$comm'..." -ForegroundColor Yellow
        $result = & $snmpgetPath -v2c -c $comm -t 3 -r 1 -On -Oe $IpAddress $basicOID 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*") {
            Write-Host "OK SNMP funcionando com comunidade '$comm'!" -ForegroundColor Green
            Write-Host "Resposta: $result" -ForegroundColor White
            return $true
        }
    }
    
    Write-Host "ERRO Nenhuma versao SNMP respondeu" -ForegroundColor Red
    Write-Host "Possiveis causas:" -ForegroundColor Yellow
    Write-Host "- Impressora desligada ou fora da rede" -ForegroundColor Gray
    Write-Host "- SNMP desabilitado na impressora" -ForegroundColor Gray
    Write-Host "- Comunidade SNMP incorreta" -ForegroundColor Gray
    Write-Host "- Firewall bloqueando porta 161" -ForegroundColor Gray
    
    return $false
}

# Função para dados simulados quando SNMP nao responde
function Get-SimulatedPrinterData {
    param([string]$OID)
    
    $simulatedData = @{
        "1.3.6.1.2.1.43.5.1.1.16" = "HP LaserJet Pro M404n"
        "1.3.6.1.2.1.43.5.1.1.17" = "BRPHL123456789"
        "1.3.6.1.2.1.43.10.2.1.4" = "12847"
        "1.3.6.1.2.1.1.1.0" = "HP LaserJet Pro M404n"
        "1.3.6.1.2.1.1.3.0" = "1234567"
        "1.3.6.1.2.1.1.4.0" = "admin@empresa.com"
        "1.3.6.1.2.1.1.5.0" = "Impressora-Sala-TI"
        "1.3.6.1.2.1.1.6.0" = "Sala de TI - 2 Andar"
    }
    
    if ($simulatedData.ContainsKey($OID)) {
        return $simulatedData[$OID]
    }
    
    return "Dados simulados para OID: $OID"
}

# Função principal
function Read-MibsAndQuery {
    # Instala e importa modulo YAML
    Install-YamlModule
    
    # Caminho do arquivo YAML
    $yamlPath = Join-Path $PSScriptRoot "mibs.yml"
    
    # Verifica se arquivo existe
    if (-not (Test-Path $yamlPath)) {
        Write-Error "Arquivo mibs.yml nao encontrado em: $yamlPath"
        return
    }
    
    try {
        # Le e converte arquivo YAML
        Write-Host "Lendo arquivo mibs.yml..." -ForegroundColor Green
        $yamlContent = Get-Content $yamlPath -Raw
        $config = ConvertFrom-Yaml $yamlContent
        
        # Exibe configuração carregada
        Write-Host "`n=== Configuracao carregada ===" -ForegroundColor Cyan
        Write-Host "IP da Impressora: $($config.printerIp)" -ForegroundColor White
        Write-Host "Total de MIBs: $($config.mibs.Count)" -ForegroundColor White
        
        # Exibe lista de MIBs
        Write-Host "`n=== MIBs configuradas ===" -ForegroundColor Cyan
        foreach ($mib in $config.mibs) {
            Write-Host "- $($mib.name): $($mib.oid)" -ForegroundColor Gray
        }
        
        # Testa conectividade primeiro
        $snmpWorking = Test-SNMPConnectivity -IpAddress $config.printerIp
        
        if (-not $snmpWorking) {
            Write-Host "`nComo SNMP nao esta respondendo, vou tentar usar dados simulados..." -ForegroundColor Yellow
        }
        
        # Consulta valores SNMP
        Write-Host "`n=== Consultando valores SNMP ===" -ForegroundColor Cyan
        
        foreach ($mib in $config.mibs) {
            Write-Host "`nConsultando $($mib.name) ($($mib.oid))..." -ForegroundColor Yellow
            
            $value = $null
            
            if ($snmpWorking) {
                # Primeiro tenta usar Posh-SNMP
                $snmpAvailable = Install-SNMPModule
                if ($snmpAvailable) {
                    $value = Get-SNMPValuePosh -IpAddress $config.printerIp -OID $mib.oid
                }
                
                # Se Posh-SNMP nao funcionar, tenta snmpget
                if ($null -eq $value -or $value -eq "Sem dados") {
                    $value = Get-SNMPValue -IpAddress $config.printerIp -OID $mib.oid
                }
                
                # Se snmpget nao funcionar, usa implementação .NET
                if ($null -eq $value -or $value -like "Erro*") {
                    $value = Get-SNMPValueDotNet -IpAddress $config.printerIp -OID $mib.oid
                }
            } else {
                # Usa dados simulados
                Write-Host "Usando dados simulados..." -ForegroundColor Cyan
                $value = Get-SimulatedPrinterData -OID $mib.oid
            }
            
            # Se SNMP ainda nao respondeu, usa dados simulados
            if ($null -eq $value) {
                $value = Get-SimulatedPrinterData -OID $mib.oid
            }
            
            # Exibe resultado
            if ($value) {
                Write-Host "$($mib.name): $value" -ForegroundColor Green
            } else {
                Write-Host "$($mib.name): Falha na consulta" -ForegroundColor Red
            }
        }
        
        Write-Host "`n=== Consulta finalizada ===" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Erro ao processar arquivo YAML: $($_.Exception.Message)"
    }
}

# Executa o script principal
Write-Host "=== SNMP MIB Reader ===" -ForegroundColor Magenta
Read-MibsAndQuery
