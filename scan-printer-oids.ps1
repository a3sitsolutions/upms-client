# Script para varredura de OIDs em impressoras
# Descobre automaticamente OIDs para páginas impressas, modelo, número de série, etc.

param(
    [string]$PrinterIP = "",
    [string]$NetworkRange = "",
    [string]$Community = "public",
    [switch]$FullScan = $false,
    [switch]$ExportConfig = $false,
    [string]$OutputFile = "",
    [switch]$QuickScan = $false,
    [switch]$NetworkScan = $false
)

# OIDs conhecidos para diferentes propriedades de impressoras
$KnownOIDs = @{
    "Sistema" = @{
        "1.3.6.1.2.1.1.1.0" = "Descrição do Sistema (sysDescr)"
        "1.3.6.1.2.1.1.5.0" = "Nome do Sistema (sysName)"
        "1.3.6.1.2.1.1.6.0" = "Localização (sysLocation)"
        "1.3.6.1.2.1.1.4.0" = "Contato (sysContact)"
        "1.3.6.1.2.1.1.3.0" = "Uptime do Sistema (sysUpTime)"
    }
    "Páginas Impressas" = @{
        "1.3.6.1.2.1.43.10.2.1.4.1.1" = "Contador de páginas (padrão MIB-II)"
        "1.3.6.1.2.1.43.10.2.1.4.1.2" = "Contador de páginas alternativo"
        "1.3.6.1.4.1.2699.1.2.1.2.1.1.1.9.1.1" = "Contador PWG"
        "1.3.6.1.4.1.1602.1.2.1.4.1.1.1.1" = "Contador Canon"
        "1.3.6.1.4.1.11.2.3.9.4.2.1.1.16.3.1.1" = "Contador HP"
        "1.3.6.1.4.1.253.8.53.3.2.1.3.1" = "Contador Xerox"
        "1.3.6.1.4.1.641.2.1.2.1.6.1" = "Contador Lexmark"
        "1.3.6.1.4.1.1347.43.10.1.1.12.1.1" = "Contador Brother"
    }
    "Número de Série" = @{
        "1.3.6.1.2.1.43.5.1.1.17.1" = "Número de série (padrão MIB-II)"
        "1.3.6.1.4.1.1602.1.2.1.4.1.1.3.1" = "Número de série Canon"
        "1.3.6.1.4.1.11.2.3.9.4.2.1.1.3.3.0" = "Número de série HP"
        "1.3.6.1.4.1.253.8.53.3.2.1.2.1" = "Número de série Xerox"
        "1.3.6.1.4.1.641.2.1.2.1.2.1" = "Número de série Lexmark"
        "1.3.6.1.4.1.1347.42.2.1.1.1.4.1" = "Número de série Brother"
        "1.3.6.1.4.1.2699.1.2.1.2.1.1.1.3.1" = "Número de série PWG"
    }
    "Modelo/Descrição" = @{
        "1.3.6.1.2.1.1.1.0" = "Descrição do sistema (modelo incluído)"
        "1.3.6.1.2.1.25.3.2.1.3.1" = "Descrição do dispositivo"
        "1.3.6.1.4.1.1602.1.1.1.4.1.2" = "Modelo Canon"
        "1.3.6.1.4.1.11.2.3.9.4.2.1.1.3.1.0" = "Modelo HP"
        "1.3.6.1.4.1.253.8.53.13.2.1.6.1.20.1" = "Modelo Xerox"
        "1.3.6.1.4.1.641.2.1.2.1.3.1" = "Modelo Lexmark"
        "1.3.6.1.4.1.1347.42.2.1.1.1.1.1" = "Modelo Brother"
    }
    "Status e Suprimentos" = @{
        "1.3.6.1.2.1.43.11.1.1.9.1.1" = "Nível de toner/tinta"
        "1.3.6.1.2.1.43.11.1.1.8.1.1" = "Capacidade máxima de toner"
        "1.3.6.1.2.1.43.8.2.1.10.1.1" = "Status da impressora"
        "1.3.6.1.2.1.25.3.5.1.1.1" = "Status do dispositivo"
        "1.3.6.1.2.1.43.16.5.1.2.1.1" = "Alerta atual"
    }
    "Informações de Rede" = @{
        "1.3.6.1.2.1.4.20.1.1" = "Endereço IP"
        "1.3.6.1.2.1.2.2.1.6.1" = "Endereço MAC"
        "1.3.6.1.2.1.1.5.0" = "Nome do host"
    }
}

# Função para consultar SNMP usando executável local
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
            $result = & $snmpgetPath -v2c -c $Community -t 3 -r 1 -On -Oe $IpAddress $OID 2>&1
        } else {
            Write-Warning "snmpget.exe não encontrado em: $snmpgetPath"
            return $null
        }
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*" -and $result -notlike "*No Such*") {
            # Converte resultado para string se for array
            if ($result -is [array]) {
                $resultText = $result -join "`n"
            } else {
                $resultText = $result.ToString()
            }
            
            # Procura pela linha com o valor real
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
            
            # Método alternativo: procura por STRING: ou INTEGER: em qualquer linha
            if ($resultText -match 'STRING:\s*"([^"]*)"') {
                return $matches[1]
            } elseif ($resultText -match 'STRING:\s*([^\r\n]*)') {
                return $matches[1].Trim()
            } elseif ($resultText -match 'INTEGER:\s*(\d+)') {
                return $matches[1]
            } elseif ($resultText -match 'Counter32:\s*(\d+)') {
                return $matches[1]
            } elseif ($resultText -match 'Gauge32:\s*(\d+)') {
                return $matches[1]
            }
            
            return $null
        } else {
            return $null
        }
    }
    catch {
        return $null
    }
}

# Função para fazer scan SNMP walk em uma subárvore
function Get-SNMPWalk {
    param(
        [string]$IpAddress,
        [string]$Community = "public",
        [string]$OID
    )
    
    try {
        $snmpwalkPath = Join-Path $PSScriptRoot "snmp\snmpwalk.exe"
        
        if (-not (Test-Path $snmpwalkPath)) {
            Write-Warning "snmpwalk.exe não encontrado"
            return @()
        }
        
        $result = & $snmpwalkPath -v2c -c $Community -t 3 -r 1 -On -Oe $IpAddress $OID 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $result) {
            $values = @()
            foreach ($line in $result) {
                if ($line -match "^(\.[\d\.]+) = (.+)$") {
                    $oidFound = $matches[1]
                    $valueFound = $matches[2]
                    
                    # Remove tipo de dados do valor
                    if ($valueFound -match '^[A-Z]+:\s*(.*)$') {
                        $valueFound = $matches[1] -replace '^"(.*)"$', '$1'
                    }
                    
                    $values += @{
                        OID = $oidFound
                        Value = $valueFound.Trim()
                    }
                }
            }
            return $values
        }
        
        return @()
    }
    catch {
        return @()
    }
}

# Função para identificar o tipo de dados baseado no valor
function Get-DataType {
    param([string]$Value)
    
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "Empty"
    }
    
    # Tenta identificar números
    if ($Value -match '^\d+$') {
        $num = [int]$Value
        if ($num -gt 1000) {
            return "Counter/Pages"
        } else {
            return "Number"
        }
    }
    
    # Identifica endereços MAC
    if ($Value -match '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$') {
        return "MAC Address"
    }
    
    # Identifica endereços IP
    if ($Value -match '^\d+\.\d+\.\d+\.\d+$') {
        return "IP Address"
    }
    
    # Identifica números de série (padrões comuns)
    if ($Value -match '^[A-Z0-9]{6,20}$' -and $Value -notmatch '^\d+$') {
        return "Serial Number"
    }
    
    # Identifica modelos/descrições
    if ($Value -like "*Brother*" -or $Value -like "*HP*" -or $Value -like "*Canon*" -or 
        $Value -like "*Laser*" -or $Value -like "*Printer*" -or $Value -like "*MFC*") {
        return "Model/Description"
    }
    
    return "Text"
}

# Função principal de varredura
function Start-PrinterOIDScan {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "SCANNER DE OIDS PARA IMPRESSORAS" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "IP da Impressora: $PrinterIP" -ForegroundColor White
    Write-Host "Comunidade SNMP: $Community" -ForegroundColor White
    
    # Testa conectividade básica
    Write-Host "`nTestando conectividade SNMP..." -ForegroundColor Yellow
    $basicTest = Get-SNMPValue -IpAddress $PrinterIP -Community $Community -OID "1.3.6.1.2.1.1.1.0"
      if (-not $basicTest) {
        Write-Host "ERRO: Impressora nao responde ao SNMP" -ForegroundColor Red
        Write-Host "Verifique:" -ForegroundColor Yellow
        Write-Host "  IP da impressora esta correto" -ForegroundColor Gray
        Write-Host "  SNMP esta habilitado na impressora" -ForegroundColor Gray
        Write-Host "  Comunidade SNMP esta correta (padrao: public)" -ForegroundColor Gray
        Write-Host "  Firewall nao esta bloqueando porta 161" -ForegroundColor Gray
        return
    }
      Write-Host "OK SNMP funcionando!" -ForegroundColor Green
    Write-Host "Descricao do sistema: $basicTest" -ForegroundColor Cyan
    
    $foundOIDs = @()
    $printerInfo = @{
        IP = $PrinterIP
        Community = $Community
        SystemDescription = $basicTest
        FoundOIDs = @()
        RecommendedConfig = @{}
    }
    
    Write-Host "`n===============================================" -ForegroundColor Yellow
    Write-Host "VARREDURA DE OIDS CONHECIDOS" -ForegroundColor Yellow
    Write-Host "===============================================" -ForegroundColor Yellow
    
    foreach ($category in $KnownOIDs.Keys) {
        Write-Host "`nCategoria: $category" -ForegroundColor Magenta
        Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray
        
        $foundInCategory = 0
        
        foreach ($oid in $KnownOIDs[$category].Keys) {
            $description = $KnownOIDs[$category][$oid]
            $value = Get-SNMPValue -IpAddress $PrinterIP -Community $Community -OID $oid
            
            if ($value) {
                $foundInCategory++
                $dataType = Get-DataType -Value $value
                
                Write-Host "  OK $oid" -ForegroundColor Green
                Write-Host "     Descrição: $description" -ForegroundColor Gray
                Write-Host "     Valor: $value" -ForegroundColor White
                Write-Host "     Tipo: $dataType" -ForegroundColor Cyan
                
                $foundOID = @{
                    OID = $oid
                    Description = $description
                    Value = $value
                    DataType = $dataType
                    Category = $category
                }
                
                $foundOIDs += $foundOID
                $printerInfo.FoundOIDs += $foundOID
                
                # Identifica OIDs recomendados para configuração
                switch ($dataType) {
                    "Counter/Pages" {
                        if (-not $printerInfo.RecommendedConfig.ContainsKey("paginasImpressas")) {
                            $printerInfo.RecommendedConfig["paginasImpressas"] = @{
                                oid = $oid
                                description = $description
                                type = "Counter32"
                            }
                        }
                    }
                    "Serial Number" {
                        if (-not $printerInfo.RecommendedConfig.ContainsKey("numeroSerie")) {
                            $printerInfo.RecommendedConfig["numeroSerie"] = @{
                                oid = $oid
                                description = $description
                                type = "String"
                            }
                        }
                    }
                    "Model/Description" {
                        if (-not $printerInfo.RecommendedConfig.ContainsKey("modeloImpressora")) {
                            $printerInfo.RecommendedConfig["modeloImpressora"] = @{
                                oid = $oid
                                description = $description
                                type = "String"
                            }
                        }
                    }
                }
                
                Write-Host "" # Linha em branco
            } else {
                Write-Host "  ERRO $oid - Nao responde" -ForegroundColor Red
            }
        }
        
        if ($foundInCategory -eq 0) {
            Write-Host "  AVISO Nenhum OID encontrado nesta categoria" -ForegroundColor Yellow
        } else {
            Write-Host "`nTotal encontrados: $foundInCategory" -ForegroundColor Cyan
        }
    }
    
    # Scan adicional se solicitado
    if ($FullScan) {
        Write-Host "`n===============================================" -ForegroundColor Yellow
        Write-Host "VARREDURA COMPLETA (SNMP WALK)" -ForegroundColor Yellow
        Write-Host "===============================================" -ForegroundColor Yellow
        Write-Host "AVISO Isso pode demorar alguns minutos..." -ForegroundColor Yellow
        
        $walkOIDs = @(
            "1.3.6.1.2.1.43",    # Printer MIB
            "1.3.6.1.2.1.25",    # Host Resources MIB
            "1.3.6.1.4.1"        # Private Enterprise Numbers (limitado)
        )
        
        foreach ($walkOID in $walkOIDs) {
            Write-Host "`nExplorando: $walkOID" -ForegroundColor Cyan
            $walkResults = Get-SNMPWalk -IpAddress $PrinterIP -Community $Community -OID $walkOID
            
            foreach ($result in $walkResults) {
                if ($result.Value -and $result.Value.Length -gt 0) {
                    $dataType = Get-DataType -Value $result.Value
                    
                    if ($dataType -in @("Counter/Pages", "Serial Number", "Model/Description")) {
                        Write-Host "  ENCONTRADO $($result.OID)" -ForegroundColor Yellow
                        Write-Host "     Valor: $($result.Value)" -ForegroundColor White
                        Write-Host "     Tipo: $dataType" -ForegroundColor Cyan
                        
                        $foundOIDs += @{
                            OID = $result.OID
                            Description = "Descoberto via walk"
                            Value = $result.Value
                            DataType = $dataType
                            Category = "Descoberto"
                        }
                    }
                }
            }
        }
    }
    
    # Resumo final
    Write-Host "`n===============================================" -ForegroundColor Green
    Write-Host "RESUMO DA VARREDURA" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
    
    Write-Host "Total de OIDs encontrados: $($foundOIDs.Count)" -ForegroundColor White
      $categoryCounts = $foundOIDs | Group-Object Category | Sort-Object Count -Descending
    foreach ($cat in $categoryCounts) {
        Write-Host "   $($cat.Name): $($cat.Count) OIDs" -ForegroundColor Cyan
    }
    
    # Configuração recomendada
    if ($printerInfo.RecommendedConfig.Count -gt 0) {
        Write-Host "`nCONFIGURACAO RECOMENDADA PARA PRINTERS-CONFIG.YML:" -ForegroundColor Green
        Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor Gray
        
        # Detecta marca/modelo da impressora
        $brand = "Unknown"
        if ($basicTest -like "*Brother*") { $brand = "Brother" }
        elseif ($basicTest -like "*HP*") { $brand = "HP" }
        elseif ($basicTest -like "*Canon*") { $brand = "Canon" }
        elseif ($basicTest -like "*Xerox*") { $brand = "Xerox" }
        elseif ($basicTest -like "*Lexmark*") { $brand = "Lexmark" }
        
        $configYAML = @"
  - model: "$brand Printer"
    description: "Impressora $brand - IP $PrinterIP"
    ip: "$PrinterIP"
    community: "$Community"
    oids:
"@
        
        foreach ($configKey in $printerInfo.RecommendedConfig.Keys) {
            $config = $printerInfo.RecommendedConfig[$configKey]
            $configYAML += @"

      $configKey`:
        oid: "$($config.oid)"
        description: "$($config.description)"
        type: "$($config.type)"
"@
        }
        
        if (-not $printerInfo.RecommendedConfig.ContainsKey("nomeSistema")) {
            $configYAML += @"

      nomeSistema:
        oid: "1.3.6.1.2.1.1.5.0"
        description: "Nome do sistema (sysName)"
        type: "String"
"@
        }
        
        Write-Host $configYAML -ForegroundColor White
    }
      # Exporta resultados se solicitado
    if ($ExportConfig) {
        $outputPath = if ($OutputFile) { $OutputFile } else { "printer-scan-$PrinterIP-$(Get-Date -Format 'yyyyMMdd-HHmmss').json" }
        
        $printerInfo | ConvertTo-Json -Depth 4 | Set-Content $outputPath -Encoding UTF8
        Write-Host "`nResultados exportados para: $outputPath" -ForegroundColor Cyan
    }
      # Sugestões finais
    Write-Host "`n💡 PROXIMOS PASSOS:" -ForegroundColor Yellow
    Write-Host "1. Copie a configuracao YAML acima para o arquivo printers-config.yml" -ForegroundColor Gray
    Write-Host "2. Ajuste o modelo e descricao conforme necessario" -ForegroundColor Gray
    Write-Host "3. Teste com: .\snmp-collector.ps1 -TestMode" -ForegroundColor Gray
    Write-Host "4. Execute em producao: .\snmp-collector.ps1" -ForegroundColor Gray
    
    if ($foundOIDs.Count -lt 3) {
        Write-Host "`nATENCAO: Poucos OIDs encontrados!" -ForegroundColor Yellow
        Write-Host "   Tente executar com -FullScan para busca mais ampla" -ForegroundColor Yellow
        Write-Host "   Comando: .\scan-printer-oids.ps1 -PrinterIP $PrinterIP -FullScan" -ForegroundColor Gray
    }
}

# Execução principal
Write-Host "SCANNER DE OIDS E DESCOBERTA DE IMPRESSORAS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Verifica se deve fazer varredura de rede primeiro
if ([string]::IsNullOrWhiteSpace($PrinterIP) -or $NetworkScan) {
    
    # Se não foi especificado range de rede, tenta detectar automaticamente
    if ([string]::IsNullOrWhiteSpace($NetworkRange)) {
        Write-Host "`nDetectando rede local..." -ForegroundColor Yellow
        
        # Obtém configuração de rede local
        $networkConfig = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" -and $_.IPv4Address -ne $null }
        
        if ($networkConfig) {
            $localIP = $networkConfig[0].IPv4Address.IPAddress
            $prefixLength = $networkConfig[0].IPv4Address.PrefixLength
            
            # Calcula rede base
            $ipParts = $localIP.Split('.')
            $NetworkRange = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).*"
            
            Write-Host "Rede detectada: $NetworkRange (baseada no IP local: $localIP)" -ForegroundColor Cyan
        } else {
            Write-Host "Não foi possível detectar a rede automaticamente." -ForegroundColor Red
            Write-Host "Especifique o range de rede manualmente:" -ForegroundColor Yellow
            Write-Host "  Exemplo: .\scan-printer-oids.ps1 -NetworkRange '192.168.1.*'" -ForegroundColor Gray
            return
        }
    }
    
    # Executa varredura de rede
    $foundPrinters = Start-NetworkPrinterScan -NetworkRange $NetworkRange -Community $Community
    
    if ($foundPrinters.Count -eq 0) {
        Write-Host "`nNenhuma impressora encontrada. Encerrando." -ForegroundColor Yellow
        return
    }
    
    # Permite seleção de impressora para varredura de OIDs
    Write-Host "`n===============================================" -ForegroundColor Magenta
    Write-Host "SELECAO DE IMPRESSORA PARA VARREDURA DE OIDS" -ForegroundColor Magenta
    Write-Host "===============================================" -ForegroundColor Magenta
    
    if ($foundPrinters.Count -eq 1) {
        $selectedPrinter = $foundPrinters[0]
        Write-Host "Apenas uma impressora encontrada. Selecionando automaticamente:" -ForegroundColor Green
        Write-Host "IP: $($selectedPrinter.IP) - $($selectedPrinter.Model)" -ForegroundColor White
        $PrinterIP = $selectedPrinter.IP
    } else {
        Write-Host "Múltiplas impressoras encontradas. Selecione uma:" -ForegroundColor Yellow
        
        for ($i = 0; $i -lt $foundPrinters.Count; $i++) {
            $printer = $foundPrinters[$i]
            Write-Host "$($i + 1). $($printer.IP) - $($printer.Model)" -ForegroundColor White
        }
        
        Write-Host "$($foundPrinters.Count + 1). Escanear todas as impressoras" -ForegroundColor Cyan
        Write-Host "0. Cancelar" -ForegroundColor Red
        
        do {
            $selection = Read-Host "`nDigite o número da opção"
            $selectionInt = 0
            $validSelection = [int]::TryParse($selection, [ref]$selectionInt)
        } while (-not $validSelection -or $selectionInt -lt 0 -or $selectionInt -gt ($foundPrinters.Count + 1))
        
        if ($selectionInt -eq 0) {
            Write-Host "Operação cancelada." -ForegroundColor Yellow
            return
        } elseif ($selectionInt -eq ($foundPrinters.Count + 1)) {
            # Escanear todas as impressoras
            Write-Host "`nIniciando varredura de OIDs em todas as impressoras..." -ForegroundColor Green
            
            foreach ($printer in $foundPrinters) {
                Write-Host "`n" + "="*60 -ForegroundColor Yellow
                Write-Host "ESCANEANDO: $($printer.IP) - $($printer.Model)" -ForegroundColor Magenta
                Write-Host "="*60 -ForegroundColor Yellow
                
                $global:PrinterIP = $printer.IP
                Start-PrinterOIDScan
            }
            return
        } else {
            $selectedPrinter = $foundPrinters[$selectionInt - 1]
            $PrinterIP = $selectedPrinter.IP
            Write-Host "`nImpressora selecionada: $($selectedPrinter.IP) - $($selectedPrinter.Model)" -ForegroundColor Green
        }
    }
}

# Verifica se foi especificado um IP específico
if ([string]::IsNullOrWhiteSpace($PrinterIP)) {
    Write-Host "`nErro: IP da impressora não especificado." -ForegroundColor Red
    Write-Host "Use uma das opções:" -ForegroundColor Yellow
    Write-Host "  .\scan-printer-oids.ps1 -PrinterIP 192.168.1.100" -ForegroundColor Gray
    Write-Host "  .\scan-printer-oids.ps1 -NetworkRange '192.168.1.*'" -ForegroundColor Gray
    Write-Host "  .\scan-printer-oids.ps1 -NetworkScan" -ForegroundColor Gray
    return
}

Write-Host "`nIniciando varredura de OIDs para impressora $PrinterIP..." -ForegroundColor Cyan

if ($QuickScan) {
    Write-Host "Modo Quick Scan: Apenas OIDs essenciais" -ForegroundColor Yellow
    $KnownOIDs = @{
        "Essenciais" = @{
            "1.3.6.1.2.1.1.1.0" = "Descrição do Sistema"
            "1.3.6.1.2.1.43.10.2.1.4.1.1" = "Contador de páginas"
            "1.3.6.1.2.1.43.5.1.1.17.1" = "Número de série"
            "1.3.6.1.2.1.1.5.0" = "Nome do Sistema"
        }
    }
}

Start-PrinterOIDScan

# Função para gerar lista de IPs de uma rede
function Get-NetworkIPs {
    param(
        [string]$NetworkRange
    )
    
    $ips = @()
    
    # Suporte para diferentes formatos de rede
    if ($NetworkRange -match '^(\d+\.\d+\.\d+\.)(\d+)-(\d+)$') {
        # Formato: 192.168.1.1-254
        $baseNetwork = $matches[1]
        $startRange = [int]$matches[2]
        $endRange = [int]$matches[3]
        
        for ($i = $startRange; $i -le $endRange; $i++) {
            $ips += "$baseNetwork$i"
        }
    }
    elseif ($NetworkRange -match '^(\d+\.\d+\.\d+\.\d+)/(\d+)$') {
        # Formato CIDR: 192.168.1.0/24
        $networkAddr = $matches[1]
        $cidr = [int]$matches[2]
        
        $ip = [System.Net.IPAddress]::Parse($networkAddr)
        $mask = [System.Net.IPAddress]::Parse((ConvertTo-SubnetMask -CIDR $cidr))
        
        # Calcula rede e broadcast
        $networkInt = [System.BitConverter]::ToUInt32($ip.GetAddressBytes(), 0)
        $maskInt = [System.BitConverter]::ToUInt32($mask.GetAddressBytes(), 0)
        $networkStart = $networkInt -band $maskInt
        $networkEnd = $networkStart -bor (-bnot $maskInt)
        
        for ($i = $networkStart + 1; $i -lt $networkEnd; $i++) {
            $ipBytes = [System.BitConverter]::GetBytes($i)
            $ips += [System.Net.IPAddress]::new($ipBytes).ToString()
        }
    }
    elseif ($NetworkRange -match '^(\d+\.\d+\.\d+\.\*)$') {
        # Formato: 192.168.1.*
        $baseNetwork = $NetworkRange -replace '\*', ''
        for ($i = 1; $i -le 254; $i++) {
            $ips += "$baseNetwork$i"
        }
    }
    else {
        Write-Host "Formato de rede não suportado. Use:" -ForegroundColor Red
        Write-Host "  192.168.1.1-254" -ForegroundColor Gray
        Write-Host "  192.168.1.0/24" -ForegroundColor Gray  
        Write-Host "  192.168.1.*" -ForegroundColor Gray
        return @()
    }
    
    return $ips
}

# Função para converter CIDR em máscara de sub-rede
function ConvertTo-SubnetMask {
    param([int]$CIDR)
    
    $mask = [Math]::Pow(2, 32) - [Math]::Pow(2, (32 - $CIDR))
    $bytes = [System.BitConverter]::GetBytes([UInt32]$mask)
    return [System.Net.IPAddress]::new($bytes[3], $bytes[2], $bytes[1], $bytes[0]).ToString()
}

# Função para testar se um IP tem SNMP habilitado
function Test-SNMPDevice {
    param(
        [string]$IpAddress,
        [string]$Community = "public",
        [int]$TimeoutSeconds = 2
    )
    
    try {
        $snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
        
        if (-not (Test-Path $snmpgetPath)) {
            return $null
        }
        
        # Testa OID básico do sistema (sysDescr) com timeout curto
        $result = & $snmpgetPath -v2c -c $Community -t $TimeoutSeconds -r 1 -On -Oe $IpAddress "1.3.6.1.2.1.1.1.0" 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*" -and $result -notlike "*No Such*") {
            # Converte resultado para string
            if ($result -is [array]) {
                $resultText = $result -join "`n"
            } else {
                $resultText = $result.ToString()
            }
            
            # Extrai valor da descrição do sistema
            if ($resultText -match 'STRING:\s*"([^"]*)"') {
                return $matches[1]
            } elseif ($resultText -match 'STRING:\s*([^\r\n]*)') {
                return $matches[1].Trim()
            }
        }
        
        return $null
    }
    catch {
        return $null
    }
}

# Função para identificar se um dispositivo é uma impressora
function Test-IsPrinter {
    param(
        [string]$SystemDescription
    )
    
    if ([string]::IsNullOrWhiteSpace($SystemDescription)) {
        return $false
    }
    
    $printerKeywords = @(
        "printer", "print", "laser", "inkjet", "multifunction", "mfc", "mfp",
        "brother", "hp", "canon", "epson", "xerox", "lexmark", "kyocera",
        "laserjet", "deskjet", "officejet", "imagerunner", "workforce",
        "copystar", "ricoh", "sharp", "konica", "bizhub", "taskalfa"
    )
    
    $description = $SystemDescription.ToLower()
    
    foreach ($keyword in $printerKeywords) {
        if ($description -contains $keyword -or $description -like "*$keyword*") {
            return $true
        }
    }
    
    return $false
}

# Função para extrair modelo da impressora da descrição
function Get-PrinterModel {
    param(
        [string]$SystemDescription
    )
    
    if ([string]::IsNullOrWhiteSpace($SystemDescription)) {
        return "Modelo Desconhecido"
    }
    
    # Remove caracteres de controle e limpa a string
    $cleanDescription = $SystemDescription -replace '[^\x20-\x7E]', '' -replace '\s+', ' '
    $cleanDescription = $cleanDescription.Trim()
    
    # Tenta extrair modelo específico
    if ($cleanDescription -match '(Brother\s+[A-Z0-9\-]+)') {
        return $matches[1]
    }
    elseif ($cleanDescription -match '(HP\s+\w+[\w\s\-]+)') {
        return $matches[1]
    }
    elseif ($cleanDescription -match '(Canon\s+[\w\s\-]+)') {
        return $matches[1]
    }
    elseif ($cleanDescription -match '(Xerox\s+[\w\s\-]+)') {
        return $matches[1]
    }
    elseif ($cleanDescription -match '(Lexmark\s+[\w\s\-]+)') {
        return $matches[1]
    }
    else {
        # Se não conseguir extrair modelo específico, retorna os primeiros 50 caracteres
        if ($cleanDescription.Length -gt 50) {
            return $cleanDescription.Substring(0, 50) + "..."
        }
        return $cleanDescription
    }
}

# Função para varredura de rede em busca de impressoras
function Start-NetworkPrinterScan {
    param(
        [string]$NetworkRange,
        [string]$Community = "public"
    )
    
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "VARREDURA DE REDE - PROCURANDO IMPRESSORAS" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Rede: $NetworkRange" -ForegroundColor White
    Write-Host "Comunidade SNMP: $Community" -ForegroundColor White
    
    # Gera lista de IPs para testar
    Write-Host "`nGerando lista de IPs para verificar..." -ForegroundColor Yellow
    $ips = Get-NetworkIPs -NetworkRange $NetworkRange
    
    if ($ips.Count -eq 0) {
        Write-Host "Erro: Não foi possível gerar lista de IPs" -ForegroundColor Red
        return @()
    }
    
    Write-Host "Total de IPs para verificar: $($ips.Count)" -ForegroundColor Cyan
    Write-Host "Iniciando varredura SNMP..." -ForegroundColor Yellow
    Write-Host "(Isso pode demorar alguns minutos dependendo do tamanho da rede)" -ForegroundColor Gray
    
    $foundDevices = @()
    $printers = @()
    $currentIP = 0
    $totalIPs = $ips.Count
    
    foreach ($ip in $ips) {
        $currentIP++
        
        # Mostra progresso a cada 10 IPs
        if ($currentIP % 10 -eq 0 -or $currentIP -eq $totalIPs) {
            $percentage = [math]::Round(($currentIP / $totalIPs) * 100, 1)
            Write-Host "Progresso: $currentIP/$totalIPs ($percentage%) - Verificando $ip" -ForegroundColor Gray
        }
        
        # Testa SNMP no IP
        $systemDescription = Test-SNMPDevice -IpAddress $ip -Community $Community -TimeoutSeconds 2
        
        if ($systemDescription) {
            $foundDevices += @{
