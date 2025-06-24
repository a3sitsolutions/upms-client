# SNMP Walk to YAML Export Script
# 
# Este script executa um SNMP walk em uma impressora e salva o resultado em formato YAML
# na pasta local-mibs, nomeando o arquivo com o modelo da impressora.
#
# Uso rápido:
#   .\snmp-walk-to-yaml.ps1 -IP "192.168.1.100"
#   .\snmp-walk-to-yaml.ps1 -IP "192.168.1.100" -Community "public" -TimeoutSeconds 3
#   .\snmp-walk-to-yaml.ps1 -IP "192.168.1.100" -BaseOID "1.3.6.1.2.1" -OutputDir ".\custom-mibs"
#
# Requisitos:
#   - snmp\snmpwalk.exe presente no diretório
#   - snmp\snmpget.exe presente no diretório
#   - Conectividade SNMP com o dispositivo alvo

param(
    [Parameter(Mandatory=$true)]
    [string]$IP,
    
    [Parameter(Mandatory=$false)]
    [string]$Community = "public",
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 2,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseOID = "1.3.6.1.2.1",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\local-mibs"
)

# Função para obter informações do dispositivo
function Get-DeviceInfo {
    param(
        [string]$IP,
        [string]$Community,
        [int]$TimeoutSeconds
    )
    
    $snmpPath = ".\snmp\snmpget.exe"
    
    # OIDs para identificação do dispositivo
    $sysDescrOID = "1.3.6.1.2.1.1.1.0"      # System Description
    $sysNameOID = "1.3.6.1.2.1.1.5.0"       # System Name
    $printerModelOID = "1.3.6.1.2.1.25.3.2.1.3.1"  # Printer Model
    
    $deviceInfo = @{
        Model = "Unknown"
        Name = "Unknown"
        Description = "Unknown"
        IP = $IP
    }
    
    try {
        # Tentar obter modelo da impressora
        $modelResult = & $snmpPath -v2c -c $Community -t $TimeoutSeconds $IP $printerModelOID 2>$null
        if ($modelResult -and $modelResult -notlike "*Timeout*" -and $modelResult -notlike "*No Response*") {
            $model = ($modelResult -split '=')[1].Trim() -replace '"', ''
            if ($model -and $model -ne "No Such Object available on this agent at this OID") {
                $deviceInfo.Model = $model
            }
        }
        
        # Tentar obter descrição do sistema
        $descrResult = & $snmpPath -v2c -c $Community -t $TimeoutSeconds $IP $sysDescrOID 2>$null
        if ($descrResult -and $descrResult -notlike "*Timeout*" -and $descrResult -notlike "*No Response*") {
            $description = ($descrResult -split '=')[1].Trim() -replace '"', ''
            if ($description -and $description -ne "No Such Object available on this agent at this OID") {
                $deviceInfo.Description = $description
                # Se não conseguiu o modelo, tentar extrair da descrição
                if ($deviceInfo.Model -eq "Unknown") {
                    # Procurar por padrões comuns de modelos na descrição
                    if ($description -match '(HP|Canon|Epson|Brother|Samsung|Lexmark|Xerox)\s+([A-Za-z0-9\-\s]+)') {
                        $deviceInfo.Model = $matches[0].Trim()
                    }
                }
            }
        }
        
        # Tentar obter nome do sistema
        $nameResult = & $snmpPath -v2c -c $Community -t $TimeoutSeconds $IP $sysNameOID 2>$null
        if ($nameResult -and $nameResult -notlike "*Timeout*" -and $nameResult -notlike "*No Response*") {
            $name = ($nameResult -split '=')[1].Trim() -replace '"', ''
            if ($name -and $name -ne "No Such Object available on this agent at this OID") {
                $deviceInfo.Name = $name
            }
        }
    }
    catch {
        Write-Warning "Erro ao obter informações do dispositivo: $_"
    }
    
    return $deviceInfo
}

# Função para executar SNMP walk
function Invoke-SNMPWalk {
    param(
        [string]$IP,
        [string]$Community,
        [int]$TimeoutSeconds,
        [string]$BaseOID
    )
    
    $snmpPath = ".\snmp\snmpwalk.exe"
    
    Write-Host "Executando SNMP walk em $IP com OID base $BaseOID..." -ForegroundColor Cyan
    
    try {
        $walkResult = & $snmpPath -v2c -c $Community -t $TimeoutSeconds $IP $BaseOID 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $walkResult) {
            return $walkResult
        } else {
            throw "SNMP walk falhou. Exit code: $LASTEXITCODE"
        }
    }
    catch {
        throw "Erro ao executar SNMP walk: $_"
    }
}

# Função para converter resultado SNMP para formato YAML
function Convert-SNMPToYAML {
    param(
        [string[]]$SNMPData,
        [hashtable]$DeviceInfo
    )
    
    $yaml = @()
    $yaml += "# SNMP Walk Results"
    $yaml += "# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $yaml += ""
    $yaml += "device_info:"
    $yaml += "  ip: '$($DeviceInfo.IP)'"
    $yaml += "  model: '$($DeviceInfo.Model)'"
    $yaml += "  name: '$($DeviceInfo.Name)'"
    $yaml += "  description: '$($DeviceInfo.Description)'"
    $yaml += ""
    $yaml += "snmp_data:"
    
    foreach ($line in $SNMPData) {
        if ($line -and $line.Trim() -ne "") {
            # Parse SNMP line: OID = TYPE: VALUE
            if ($line -match '^([^\s]+)\s*=\s*([^:]+):\s*(.*)$') {
                $oid = $matches[1].Trim()
                $type = $matches[2].Trim()
                $value = $matches[3].Trim()
                
                # Escapar aspas no valor se necessário
                $value = $value -replace '"', '\"'
                
                # Formatar para YAML
                $yaml += "  '$oid':"
                $yaml += "    type: '$type'"
                $yaml += "    value: '$value'"
            }
        }
    }
    
    return $yaml
}

# Função para gerar nome de arquivo seguro
function Get-SafeFileName {
    param(
        [string]$ModelName,
        [string]$IP
    )
    
    # Remover caracteres inválidos para nome de arquivo
    $safeName = $ModelName -replace '[\\/:*?"<>|]', '_'
    $safeName = $safeName -replace '\s+', '_'
    $safeName = $safeName.Trim('_')
    
    if ($safeName -eq "" -or $safeName -eq "Unknown") {
        $safeName = "Device_$($IP -replace '\.', '_')"
    }
    
    return "$safeName.yml"
}

# Script principal
try {
    Write-Host "=== SNMP Walk to YAML Export ===" -ForegroundColor Green
    Write-Host "IP: $IP" -ForegroundColor Yellow
    Write-Host "Community: $Community" -ForegroundColor Yellow
    Write-Host "Timeout: ${TimeoutSeconds}s" -ForegroundColor Yellow
    Write-Host "Base OID: $BaseOID" -ForegroundColor Yellow
    Write-Host "Output Dir: $OutputDir" -ForegroundColor Yellow
    Write-Host ""
    
    # Verificar se os executáveis SNMP existem
    $snmpGetPath = ".\snmp\snmpget.exe"
    $snmpWalkPath = ".\snmp\snmpwalk.exe"
    
    if (!(Test-Path $snmpGetPath)) {
        throw "snmpget.exe não encontrado em .\snmp\"
    }
    
    if (!(Test-Path $snmpWalkPath)) {
        throw "snmpwalk.exe não encontrado em .\snmp\"
    }
    
    # Criar diretório de saída se não existir
    if (!(Test-Path $OutputDir)) {
        Write-Host "Criando diretório de saída: $OutputDir" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    # Obter informações do dispositivo
    Write-Host "Obtendo informações do dispositivo..." -ForegroundColor Cyan
    $deviceInfo = Get-DeviceInfo -IP $IP -Community $Community -TimeoutSeconds $TimeoutSeconds
    
    Write-Host "Dispositivo identificado:" -ForegroundColor Green
    Write-Host "  Modelo: $($deviceInfo.Model)" -ForegroundColor White
    Write-Host "  Nome: $($deviceInfo.Name)" -ForegroundColor White
    Write-Host "  Descrição: $($deviceInfo.Description)" -ForegroundColor White
    Write-Host ""
    
    # Executar SNMP walk
    $startTime = Get-Date
    $snmpData = Invoke-SNMPWalk -IP $IP -Community $Community -TimeoutSeconds $TimeoutSeconds -BaseOID $BaseOID
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "SNMP walk concluído em $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
    Write-Host "Coletados $($snmpData.Count) registros SNMP" -ForegroundColor Green
    Write-Host ""
    
    # Converter para YAML
    Write-Host "Convertendo dados para formato YAML..." -ForegroundColor Cyan
    $yamlContent = Convert-SNMPToYAML -SNMPData $snmpData -DeviceInfo $deviceInfo
    
    # Gerar nome do arquivo
    $fileName = Get-SafeFileName -ModelName $deviceInfo.Model -IP $IP
    $outputPath = Join-Path $OutputDir $fileName
    
    # Salvar arquivo YAML
    Write-Host "Salvando arquivo: $outputPath" -ForegroundColor Cyan
    $yamlContent | Out-File -FilePath $outputPath -Encoding UTF8 -Force
    
    Write-Host ""
    Write-Host "=== PROCESSO CONCLUÍDO ===" -ForegroundColor Green
    Write-Host "Arquivo YAML salvo: $outputPath" -ForegroundColor Yellow
    Write-Host "Registros SNMP: $($snmpData.Count)" -ForegroundColor Yellow
    Write-Host "Tempo total: $($duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Yellow
    
    # Mostrar primeiras linhas do arquivo para confirmação
    Write-Host ""
    Write-Host "Primeiras linhas do arquivo gerado:" -ForegroundColor Cyan
    Get-Content $outputPath | Select-Object -First 15 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    if ((Get-Content $outputPath).Count -gt 15) {
        Write-Host "... (arquivo completo salvo)" -ForegroundColor Gray
    }
}
catch {
    Write-Error "Erro durante o processo: $_"
    exit 1
}
