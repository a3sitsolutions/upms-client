# Script de teste para demonstrar o snmp-walk-to-yaml.ps1
# Este script simula dados SNMP para testar a funcionalidade

param(
    [Parameter(Mandatory=$false)]
    [string]$TestIP = "192.168.1.200"
)

# Dados SNMP simulados para uma impressora HP
$simulatedSNMPData = @(
    "1.3.6.1.2.1.1.1.0 = STRING: HP LaserJet Pro M404dn",
    "1.3.6.1.2.1.1.2.0 = OID: 1.3.6.1.4.1.11.2.3.9.1",
    "1.3.6.1.2.1.1.3.0 = Timeticks: (123456789) 14 days, 6:56:07.89",
    "1.3.6.1.2.1.1.4.0 = STRING: admin@empresa.com",
    "1.3.6.1.2.1.1.5.0 = STRING: PRINTER-SALA-01",
    "1.3.6.1.2.1.1.6.0 = STRING: Sala de reunioes - Andar 2",
    "1.3.6.1.2.1.25.3.2.1.3.1 = STRING: HP LaserJet Pro M404dn",
    "1.3.6.1.2.1.43.5.1.1.16.1 = STRING: Ready",
    "1.3.6.1.2.1.43.10.2.1.4.1.1 = INTEGER: 50",
    "1.3.6.1.2.1.43.11.1.1.6.1.1 = Counter32: 12345",
    "1.3.6.1.2.1.43.11.1.1.9.1.1 = Counter32: 987"
)

Write-Host "=== Teste do snmp-walk-to-yaml.ps1 ===" -ForegroundColor Green
Write-Host "Criando dados SNMP simulados para IP: $TestIP" -ForegroundColor Yellow
Write-Host ""

# Criar arquivo temporário com dados simulados
$tempFile = "temp_snmp_data.txt"
$simulatedSNMPData | Out-File -FilePath $tempFile -Encoding UTF8

# Simular a função Convert-SNMPToYAML
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

# Simular informações do dispositivo
$deviceInfo = @{
    IP = $TestIP
    Model = "HP LaserJet Pro M404dn"
    Name = "PRINTER-SALA-01"
    Description = "HP LaserJet Pro M404dn"
}

Write-Host "Informações do dispositivo simulado:" -ForegroundColor Cyan
Write-Host "  IP: $($deviceInfo.IP)" -ForegroundColor White
Write-Host "  Modelo: $($deviceInfo.Model)" -ForegroundColor White
Write-Host "  Nome: $($deviceInfo.Name)" -ForegroundColor White
Write-Host "  Descrição: $($deviceInfo.Description)" -ForegroundColor White
Write-Host ""

# Converter para YAML
Write-Host "Convertendo dados simulados para YAML..." -ForegroundColor Cyan
$yamlContent = Convert-SNMPToYAML -SNMPData $simulatedSNMPData -DeviceInfo $deviceInfo

# Criar diretório se não existir
$outputDir = ".\local-mibs"
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Gerar nome de arquivo
$fileName = "HP_LaserJet_Pro_M404dn_EXAMPLE.yml"
$outputPath = Join-Path $outputDir $fileName

# Salvar arquivo
Write-Host "Salvando arquivo exemplo: $outputPath" -ForegroundColor Yellow
$yamlContent | Out-File -FilePath $outputPath -Encoding UTF8 -Force

Write-Host ""
Write-Host "=== EXEMPLO CRIADO ===" -ForegroundColor Green
Write-Host "Arquivo YAML exemplo salvo: $outputPath" -ForegroundColor Yellow
Write-Host "Registros SNMP simulados: $($simulatedSNMPData.Count)" -ForegroundColor Yellow

# Mostrar conteúdo do arquivo
Write-Host ""
Write-Host "Conteúdo do arquivo YAML gerado:" -ForegroundColor Cyan
Get-Content $outputPath | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# Limpar arquivo temporário
if (Test-Path $tempFile) {
    Remove-Item $tempFile -Force
}

Write-Host ""
Write-Host "=== Uso do script real ===" -ForegroundColor Green
Write-Host "Para usar com uma impressora real:" -ForegroundColor Yellow
Write-Host "  .\snmp-walk-to-yaml.ps1 -IP `"192.168.1.100`"" -ForegroundColor White
Write-Host "  .\snmp-walk-to-yaml.ps1 -IP `"192.168.1.100`" -Community `"public`" -TimeoutSeconds 3" -ForegroundColor White
Write-Host "  .\snmp-walk-to-yaml.ps1 -IP `"192.168.1.100`" -BaseOID `"1.3.6.1.2.1.43`" -OutputDir `".\custom-mibs`"" -ForegroundColor White
