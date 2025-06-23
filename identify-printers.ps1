# Script para identificar impressoras que precisam ser cadastradas no sistema UPMS
# Este script coleta dados via SNMP e mostra o que precisa ser cadastrado

param(
    [switch]$ShowOnlyUnconfigured = $false
)

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
        $snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
        
        if (Test-Path $snmpgetPath) {
            $result = & $snmpgetPath -v2c -c $Community -t 5 -r 2 -On -Oe $IpAddress $OID 2>&1
        } else {
            $snmpget = Get-Command snmpget -ErrorAction SilentlyContinue
            if (-not $snmpget) {
                return $null
            }
            $result = & snmpget -v2c -c $Community $IpAddress $OID 2>$null
        }
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*") {
            if ($result -is [array]) {
                $resultText = $result -join "`n"
            } else {
                $resultText = $result.ToString()
            }
            
            $valueLines = $resultText -split "`n" | Where-Object { $_ -match "^\.[\d\.]+ = " }
            
            if ($valueLines -and $valueLines.Count -gt 0) {
                $valueLine = $valueLines[0]
                if ($valueLine -match "^\.[\d\.]+ = [A-Z]+:\s*(.*)$") {
                    $value = $matches[1]
                    $value = $value -replace '^"(.*)"$', '$1'
                    return $value.Trim()
                }
            }
            
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
        return $null
    }
}

# Funcao principal
function Get-PrintersForRegistration {
    Install-YamlModule
    
    $yamlPath = Join-Path $PSScriptRoot "printers-config.yml"
    
    if (-not (Test-Path $yamlPath)) {
        Write-Error "Arquivo printers-config.yml nao encontrado"
        return
    }
    
    try {
        $yamlContent = Get-Content $yamlPath -Raw
        $config = ConvertFrom-Yaml $yamlContent
        
        Write-Host "=== DADOS PARA CADASTRO NO SISTEMA UPMS ===" -ForegroundColor Cyan
        Write-Host "Coletando dados via SNMP das impressoras configuradas..." -ForegroundColor Gray
        Write-Host ""
        
        $printersData = @()
        
        foreach ($printer in $config.printers) {
            Write-Host "Coletando dados de: $($printer.model) ($($printer.ip))" -ForegroundColor Yellow
            
            # Coleta dados via SNMP
            $modelData = Get-SNMPValue -IpAddress $printer.ip -Community $printer.community -OID $printer.oids.modeloImpressora.oid
            $serialData = Get-SNMPValue -IpAddress $printer.ip -Community $printer.community -OID $printer.oids.numeroSerie.oid
            $pagesData = Get-SNMPValue -IpAddress $printer.ip -Community $printer.community -OID $printer.oids.paginasImpressas.oid
            
            # Se SNMP nao responder, usa dados simulados baseados no modelo
            if (-not $modelData -or $modelData -eq "Erro na consulta SNMP") {
                $modelData = "$($printer.model) (Simulado - SNMP nao disponivel)"
                $serialData = "SIM" + (Get-Random -Minimum 100000 -Maximum 999999)
                $pagesData = Get-Random -Minimum 10000 -Maximum 50000
                Write-Host "  * SNMP nao disponivel - usando dados simulados" -ForegroundColor Red
            } else {
                Write-Host "  * SNMP funcionando - dados reais coletados" -ForegroundColor Green
            }
            
            $printerInfo = @{
                ConfiguredModel = $printer.model
                SNMPModel = $modelData
                SerialNumber = $serialData
                TotalPages = $pagesData
                IP = $printer.ip
                Description = $printer.description
                SNMPWorking = ($modelData -notlike "*Simulado*")
            }
            
            $printersData += $printerInfo
        }
        
        Write-Host "`n" + "="*80 -ForegroundColor Cyan
        Write-Host "RESUMO PARA CADASTRO NO SISTEMA UPMS" -ForegroundColor Cyan
        Write-Host "="*80 -ForegroundColor Cyan
        
        foreach ($printer in $printersData) {
            if ($ShowOnlyUnconfigured -and $printer.SNMPWorking) {
                # Pula impressoras que ja funcionam (assumindo que ja estao cadastradas)
                continue
            }
            
            Write-Host "`nImpressora: $($printer.ConfiguredModel)" -ForegroundColor Magenta
            Write-Host "IP: $($printer.IP)" -ForegroundColor White
            Write-Host "Descricao: $($printer.Description)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "DADOS PARA CADASTRO:" -ForegroundColor Yellow
            Write-Host "  Modelo (usar este exato): `"$($printer.SNMPModel)`"" -ForegroundColor White
            Write-Host "  Numero de Serie: `"$($printer.SerialNumber)`"" -ForegroundColor White
            Write-Host "  Paginas Atuais: $($printer.TotalPages)" -ForegroundColor White
            Write-Host "  Status SNMP: $(if ($printer.SNMPWorking) { 'Funcionando' } else { 'Indisponivel' })" -ForegroundColor $(if ($printer.SNMPWorking) { 'Green' } else { 'Red' })
            
            if ($printer.SNMPWorking) {
                Write-Host "`n  JSON para teste da API:" -ForegroundColor Cyan
                $testJson = @{
                    model = $printer.SNMPModel
                    serialNumber = $printer.SerialNumber
                    totalPrintedPages = [int]$printer.TotalPages
                    time = Get-Date -Format "yyyy-MM-dd"
                } | ConvertTo-Json -Compress
                Write-Host "  $testJson" -ForegroundColor Gray
            }
            
            Write-Host "-" * 60 -ForegroundColor DarkGray
        }
        
        Write-Host "`n=== COMANDOS DE TESTE ===" -ForegroundColor Cyan
        Write-Host "Apos cadastrar as impressoras no sistema UPMS:" -ForegroundColor Yellow
        Write-Host "1. Execute: .\snmp-collector.ps1" -ForegroundColor White
        Write-Host "2. Ou teste manualmente: .\test-api.ps1" -ForegroundColor White
        Write-Host "3. Dados salvos localmente serao reenviados automaticamente" -ForegroundColor White
        
    }
    catch {
        Write-Error "Erro ao processar: $($_.Exception.Message)"
    }
}

Write-Host "=== IDENTIFICADOR DE IMPRESSORAS PARA CADASTRO ===" -ForegroundColor Magenta
Get-PrintersForRegistration
