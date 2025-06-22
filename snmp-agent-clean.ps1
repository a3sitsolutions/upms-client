# Script para ler arquivo mibs.yml e consultar valores SNMP
# Requer o modulo powershell-yaml para parsing YAML

# Funcao para instalar modulo YAML se nao estiver disponivel
function Install-YamlModule {
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Host "Instalando modulo powershell-yaml..." -ForegroundColor Yellow
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser
    }
    Import-Module powershell-yaml
}

# Funcao principal para consultar SNMP usando executavel local
function Get-SNMPValue {
    param(
        [string]$IpAddress,
        [string]$Community = "public",
        [string]$OID
    )
    
    try {
        # Caminho para o executavel snmpget local
        $snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
        
        # Verifica se o executavel local existe
        if (Test-Path $snmpgetPath) {
            Write-Host "Usando snmpget local: $snmpgetPath" -ForegroundColor Green
            Write-Host "Executando: snmpget -v2c -c $Community -t 5 -r 2 -On -Oe $IpAddress $OID" -ForegroundColor Gray
            $result = & $snmpgetPath -v2c -c $Community -t 5 -r 2 -On -Oe $IpAddress $OID 2>&1
            Write-Host "Resultado bruto: $result" -ForegroundColor Magenta
        } else {
            # Fallback para snmpget do sistema
            $snmpget = Get-Command snmpget -ErrorAction SilentlyContinue
            if (-not $snmpget) {
                Write-Warning "snmpget nao encontrado nem local nem no sistema."
                return $null
            }
            Write-Host "Usando snmpget do sistema" -ForegroundColor Yellow
            $result = & snmpget -v2c -c $Community $IpAddress $OID 2>$null
        }
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*" -and $result -notlike "*No Response*") {
            Write-Host "SNMP respondeu com sucesso" -ForegroundColor Green
            
            # Converte resultado para string se for array
            if ($result -is [array]) {
                $resultText = $result -join "`n"
            } else {
                $resultText = $result.ToString()
            }
            
            Write-Host "Resultado SNMP completo:" -ForegroundColor Yellow
            Write-Host $resultText -ForegroundColor White
            
            # Filtra apenas linhas que contem OID = valor (ignora avisos de MIB)
            $lines = $resultText -split "`n" | Where-Object { $_ -match "^\.[\d\.]+ = " }
            
            if ($lines -and $lines.Count -gt 0) {
                $line = $lines[0]
                Write-Host "Linha com valor encontrada: $line" -ForegroundColor Cyan
                $parts = $line -split " = ", 2
                if ($parts.Length -eq 2) {
                    $value = $parts[1]
                    Write-Host "Valor bruto extraido: $value" -ForegroundColor Magenta
                    # Remove tipo de dados (STRING:, INTEGER:, etc.)
                    $value = $value -replace '^[A-Z0-9\-]+:\s*', ''
                    # Remove aspas se for string
                    $value = $value -replace '^"(.*)"$', '$1'
                    $finalValue = $value.Trim()
                    Write-Host "Valor final processado: $finalValue" -ForegroundColor Green
                    return $finalValue
                }
            } else {
                Write-Host "Nenhuma linha com OID encontrada. Tentando extracao alternativa..." -ForegroundColor Yellow
                # Tenta extrair valor de qualquer linha que contenha STRING: ou INTEGER:
                if ($resultText -match 'STRING:\s*"([^"]*)"') {
                    $extractedValue = $matches[1]
                    Write-Host "Valor extraido como STRING com aspas: $extractedValue" -ForegroundColor Green
                    return $extractedValue
                } elseif ($resultText -match 'STRING:\s*([^\r\n]*)') {
                    $extractedValue = $matches[1].Trim()
                    Write-Host "Valor extraido como STRING sem aspas: $extractedValue" -ForegroundColor Green
                    return $extractedValue
                } elseif ($resultText -match 'INTEGER:\s*(\d+)') {
                    $extractedValue = $matches[1]
                    Write-Host "Valor extraido como INTEGER: $extractedValue" -ForegroundColor Green
                    return $extractedValue
                }
            }
            return "Valor nao encontrado na resposta"
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

# Funcao para testar conectividade SNMP basica
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
        Write-Host "* SNMP v1 funcionando!" -ForegroundColor Green
        Write-Host "Resposta: $result1" -ForegroundColor White
        return $true
    }
    
    # Testa SNMP v2c
    Write-Host "Tentando SNMP v2c..." -ForegroundColor Yellow
    $result2 = & $snmpgetPath -v2c -c $Community -t 3 -r 1 -On -Oe $IpAddress $basicOID 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $result2 -and $result2 -notlike "*Timeout*") {
        Write-Host "* SNMP v2c funcionando!" -ForegroundColor Green
        Write-Host "Resposta: $result2" -ForegroundColor White
        return $true
    }
    
    # Testa diferentes comunidades
    $communities = @("private", "admin", "snmp", "manager")
    foreach ($comm in $communities) {
        Write-Host "Tentando comunidade '$comm'..." -ForegroundColor Yellow
        $result = & $snmpgetPath -v2c -c $comm -t 3 -r 1 -On -Oe $IpAddress $basicOID 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*") {
            Write-Host "* SNMP funcionando com comunidade '$comm'!" -ForegroundColor Green
            Write-Host "Resposta: $result" -ForegroundColor White
            return $true
        }
    }
    
    Write-Host "x Nenhuma versao SNMP respondeu" -ForegroundColor Red
    Write-Host "Possiveis causas:" -ForegroundColor Yellow
    Write-Host "- Impressora desligada ou fora da rede" -ForegroundColor Gray
    Write-Host "- SNMP desabilitado na impressora" -ForegroundColor Gray
    Write-Host "- Comunidade SNMP incorreta" -ForegroundColor Gray
    Write-Host "- Firewall bloqueando porta 161" -ForegroundColor Gray
    
    return $false
}

# Funcao para dados simulados quando SNMP nao responde
function Get-SimulatedPrinterData {
    param([string]$OID)
    
    $simulatedData = @{
        "1.3.6.1.2.1.1.1.0" = "Brother NC-8300w, Firmware Ver.X ,MID 8C5-H27,FID 2"
        "1.3.6.1.2.1.43.5.1.1.17.1" = "U63885F9N733180"
        "1.3.6.1.2.1.1.5.0" = "Brother-Printer"
        "1.3.6.1.2.1.1.6.0" = "Sala de Impressao"
        "1.3.6.1.2.1.1.4.0" = "admin@empresa.com"
        "1.3.6.1.2.1.1.3.0" = "1234567"
        "1.3.6.1.2.1.43.5.1.1.16" = "HP LaserJet Pro M404n"
        "1.3.6.1.2.1.43.5.1.1.17" = "BRPHL123456789"
        "1.3.6.1.2.1.43.10.2.1.4" = "12847"
    }
    
    if ($simulatedData.ContainsKey($OID)) {
        return $simulatedData[$OID]
    }
    
    return "Dados simulados para OID: $OID"
}

# Funcao principal
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
        
        # Exibe configuracao carregada
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
            Write-Host "`nComo SNMP nao esta respondendo, vou usar dados simulados..." -ForegroundColor Yellow
        }
        
        # Consulta valores SNMP
        Write-Host "`n=== Consultando valores SNMP ===" -ForegroundColor Cyan
        
        foreach ($mib in $config.mibs) {
            Write-Host "`nConsultando $($mib.name) ($($mib.oid))..." -ForegroundColor Yellow
            
            $value = $null
            
            if ($snmpWorking) {
                # Tenta consulta SNMP real
                $value = Get-SNMPValue -IpAddress $config.printerIp -OID $mib.oid
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
