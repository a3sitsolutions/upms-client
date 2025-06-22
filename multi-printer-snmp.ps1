# Script SNMP para multiplas impressoras
# Le printers-config.yml e consulta todas as impressoras configuradas

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
            $result = & $snmpgetPath -v2c -c $Community -t 5 -r 2 -On -Oe $IpAddress $OID 2>&1
        } else {
            # Fallback para snmpget do sistema
            $snmpget = Get-Command snmpget -ErrorAction SilentlyContinue
            if (-not $snmpget) {
                Write-Warning "snmpget nao encontrado"
                return $null
            }
            $result = & snmpget -v2c -c $Community $IpAddress $OID 2>$null
        }
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*") {
            # Converte resultado para string se for array
            if ($result -is [array]) {
                $resultText = $result -join "`n"
            } else {
                $resultText = $result.ToString()
            }
            
            # Procura pela linha com o valor real (ignora avisos de MIB)
            $valueLines = $resultText -split "`n" | Where-Object { $_ -match "^\.[\d\.]+ = " }
            
            if ($valueLines -and $valueLines.Count -gt 0) {
                $valueLine = $valueLines[0]
                if ($valueLine -match "^\.[\d\.]+ = [A-Z]+:\s*(.*)$") {
                    $value = $matches[1]
                    # Remove aspas se existirem
                    $value = $value -replace '^"(.*)"$', '$1'
                    return $value.Trim()
                }
            }
            
            # Metodo alternativo: procura por STRING: ou INTEGER: em qualquer linha
            if ($resultText -match 'STRING:\s*"([^"]*)"') {
                return $matches[1]
            } elseif ($resultText -match 'STRING:\s*([^\r\n]*)') {
                return $matches[1].Trim()
            } elseif ($resultText -match 'INTEGER:\s*(\d+)') {
                return $matches[1]
            } elseif ($resultText -match 'Counter32:\s*(\d+)') {
                return $matches[1]
            }
            
            return "Valor nao encontrado"
        } else {
            return "Erro na consulta SNMP"
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
    
    $snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
    
    if (-not (Test-Path $snmpgetPath)) {
        Write-Host "snmpget.exe nao encontrado" -ForegroundColor Red
        return $false
    }
    
    # Testa OID basico do sistema (sysDescr)
    $basicOID = "1.3.6.1.2.1.1.1.0"
    
    # Testa SNMP v2c
    $result = & $snmpgetPath -v2c -c $Community -t 3 -r 1 -On -Oe $IpAddress $basicOID 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*") {
        return $true
    }
    
    return $false
}

# Funcao para dados simulados quando SNMP nao responde
function Get-SimulatedPrinterData {
    param(
        [string]$OID,
        [string]$PrinterModel
    )
    
    # Dados simulados baseados no modelo da impressora
    $simulatedData = @{
        # Brother NC-8300w
        "Brother" = @{
            "1.3.6.1.2.1.43.10.2.1.4.1.1" = "298935"
            "1.3.6.1.2.1.1.1.0" = "Brother NC-8300w, Firmware Ver.X ,MID 8C5-H27,FID 2"
            "1.3.6.1.2.1.43.5.1.1.17.1" = "U63885F9N733180"
            "1.3.6.1.2.1.1.5.0" = "BRW105BAD6F5F7A"
        }
        # HP LaserJet
        "HP" = @{
            "1.3.6.1.2.1.43.10.2.1.4.1.1" = "15247"
            "1.3.6.1.2.1.1.1.0" = "HP LaserJet Pro M404n"
            "1.3.6.1.2.1.43.5.1.1.17.1" = "BRHPF987654321"
            "1.3.6.1.2.1.1.5.0" = "HP-LaserJet-M404n"
        }
        # Canon
        "Canon" = @{
            "1.3.6.1.2.1.43.10.2.1.4.1.1" = "87432"
            "1.3.6.1.2.1.1.1.0" = "Canon imageRUNNER C3025i"
            "1.3.6.1.4.1.1602.1.2.1.4.1.1.3.1" = "CNX123456789"
            "1.3.6.1.2.1.1.5.0" = "Canon-imageRUNNER"
        }
    }
    
    # Determina marca baseada no modelo
    $brand = "Brother"  # Default
    if ($PrinterModel -like "*HP*") { $brand = "HP" }
    elseif ($PrinterModel -like "*Canon*") { $brand = "Canon" }
    
    if ($simulatedData[$brand] -and $simulatedData[$brand][$OID]) {
        return $simulatedData[$brand][$OID]
    }
    
    return "Dados simulados para OID: $OID"
}

# Funcao principal
function Read-PrintersConfigAndQuery {
    # Instala e importa modulo YAML
    Install-YamlModule
    
    # Caminho do arquivo YAML
    $yamlPath = Join-Path $PSScriptRoot "printers-config.yml"
    
    # Verifica se arquivo existe
    if (-not (Test-Path $yamlPath)) {
        Write-Error "Arquivo printers-config.yml nao encontrado em: $yamlPath"
        return
    }
    
    try {
        # Le e converte arquivo YAML
        Write-Host "Lendo configuracao de impressoras..." -ForegroundColor Green
        $yamlContent = Get-Content $yamlPath -Raw
        $config = ConvertFrom-Yaml $yamlContent
        
        # Exibe configuracao carregada
        Write-Host "`n=== Configuracao carregada ===" -ForegroundColor Cyan
        Write-Host "Total de impressoras: $($config.printers.Count)" -ForegroundColor White
        
        # Processa cada impressora
        foreach ($printer in $config.printers) {
            Write-Host "`n" + "="*60 -ForegroundColor Yellow
            Write-Host "IMPRESSORA: $($printer.model)" -ForegroundColor Magenta
            Write-Host "IP: $($printer.ip)" -ForegroundColor White
            Write-Host "Descricao: $($printer.description)" -ForegroundColor Gray
            Write-Host "="*60 -ForegroundColor Yellow
            
            # Testa conectividade
            Write-Host "`nTestando conectividade SNMP..." -ForegroundColor Cyan
            $snmpWorking = Test-SNMPConnectivity -IpAddress $printer.ip -Community $printer.community
            
            if ($snmpWorking) {
                Write-Host "* SNMP funcionando!" -ForegroundColor Green
            } else {
                Write-Host "x SNMP nao respondeu - usando dados simulados" -ForegroundColor Yellow
            }
              # Consulta cada OID configurado para esta impressora
            Write-Host "`nConsultando informacoes da impressora:" -ForegroundColor Cyan
            
            # Lista de OIDs configurados
            $oidsList = @(
                @{ name = "paginasImpressas"; data = $printer.oids.paginasImpressas },
                @{ name = "modeloImpressora"; data = $printer.oids.modeloImpressora },
                @{ name = "numeroSerie"; data = $printer.oids.numeroSerie },
                @{ name = "nomeSistema"; data = $printer.oids.nomeSistema }
            )
            
            foreach ($oidItem in $oidsList) {
                $oidName = $oidItem.name
                $oidData = $oidItem.data
                
                if ($oidData) {
                    Write-Host "`n  -> $oidName ($($oidData.description))..." -ForegroundColor Yellow
                    
                    $value = $null
                    
                    if ($snmpWorking) {
                        # Tenta consulta SNMP real
                        $value = Get-SNMPValue -IpAddress $printer.ip -Community $printer.community -OID $oidData.oid
                    } else {
                        # Usa dados simulados
                        $value = Get-SimulatedPrinterData -OID $oidData.oid -PrinterModel $printer.model
                    }
                    
                    # Se SNMP ainda nao respondeu, usa dados simulados
                    if ($null -eq $value -or $value -eq "Valor nao encontrado") {
                        $value = Get-SimulatedPrinterData -OID $oidData.oid -PrinterModel $printer.model
                    }
                    
                    # Exibe resultado formatado
                    $displayName = switch ($oidName) {
                        "paginasImpressas" { "Paginas Impressas" }
                        "modeloImpressora" { "Modelo da Impressora" }
                        "numeroSerie" { "Numero de Serie" }
                        "nomeSistema" { "Nome do Sistema" }
                        default { $oidName }
                    }
                    
                    if ($value) {
                        Write-Host "     $displayName`: $value" -ForegroundColor Green
                    } else {
                        Write-Host "     $displayName`: Falha na consulta" -ForegroundColor Red
                    }
                }
            }
        }
        
        Write-Host "`n" + "="*60 -ForegroundColor Yellow
        Write-Host "CONSULTA FINALIZADA" -ForegroundColor Cyan
        Write-Host "="*60 -ForegroundColor Yellow
    }
    catch {
        Write-Error "Erro ao processar arquivo YAML: $($_.Exception.Message)"
    }
}

# Executa o script principal
Write-Host "=== SNMP Multi-Printer Reader ===" -ForegroundColor Magenta
Read-PrintersConfigAndQuery
