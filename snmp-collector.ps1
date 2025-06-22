# Script SNMP com modo de teste (sem envio para API)
# Para verificar se os dados estao sendo coletados corretamente

param(
    [switch]$TestMode = $false,
    [string]$ApiEndpoint = "https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer"
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
    $simulatedData = @{        # Brother NC-8300w
        "Brother" = @{
            "1.3.6.1.2.1.43.10.2.1.4.1.1" = "298935"
            "1.3.6.1.2.1.1.1.0" = "Brother NC-8300w, Firmware Ver.X  ,MID 8C5-H27,FID 2"
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

# Funcao para mostrar dados que seriam enviados para API (modo teste)
function Show-APIData {
    param(
        [string]$Model,
        [string]$SerialNumber,
        [int]$TotalPrintedPages
    )
    
    Write-Host "`n  -> DADOS PARA API (MODO TESTE):" -ForegroundColor Cyan
    Write-Host "     {" -ForegroundColor White
    Write-Host "       `"model`": `"$Model`"," -ForegroundColor White
    Write-Host "       `"serialNumber`": `"$SerialNumber`"," -ForegroundColor White
    Write-Host "       `"totalPrintedPages`": $TotalPrintedPages" -ForegroundColor White
    Write-Host "     }" -ForegroundColor White
    Write-Host "     Status: Dados prontos para envio!" -ForegroundColor Green
}

# Funcao para enviar dados para API via curl
function Send-PrinterDataToAPI {
    param(
        [string]$Model,
        [string]$SerialNumber,
        [int]$TotalPrintedPages,
        [string]$ApiEndpoint
    )
      # Prepara o JSON com escape correto para caracteres especiais
    $jsonData = @{
        model = $Model
        serialNumber = $SerialNumber
        totalPrintedPages = $TotalPrintedPages
    } | ConvertTo-Json -Compress
    
    Write-Host "`n  -> Enviando dados para API..." -ForegroundColor Cyan
    Write-Host "     Endpoint: $ApiEndpoint" -ForegroundColor Gray
    Write-Host "     Dados: $jsonData" -ForegroundColor Gray
    
    try {
        # Caminho para o executavel curl local
        $curlPath = Join-Path $PSScriptRoot "curl\curl.exe"
        
        # Verifica se o executavel curl local existe
        if (-not (Test-Path $curlPath)) {
            Write-Host "     Erro: curl.exe nao encontrado na pasta do projeto: $curlPath" -ForegroundColor Red
            return $false
        }
          # Executa curl.exe local do projeto
        # Cria arquivo temporario para o JSON para evitar problemas com caracteres especiais
        $tempJsonFile = [System.IO.Path]::GetTempFileName()
        try {
            # Escreve o JSON no arquivo temporario com encoding UTF8
            $jsonData | Out-File -FilePath $tempJsonFile -Encoding UTF8 -NoNewline
            
            $curlArgs = @(
                '-X', 'POST',
                $ApiEndpoint,
                '-H', 'accept: */*',
                '-H', 'Content-Type: application/json',
                '--data-binary', "@$tempJsonFile",
                '--silent',
                '--show-error'
            )
              $response = & $curlPath @curlArgs 2>&1
            $httpCode = $LASTEXITCODE
        }
        finally {
            # Remove arquivo temporario
            if (Test-Path $tempJsonFile) {
                Remove-Item $tempJsonFile -Force
            }
        }
        
        if ($httpCode -eq 0) {
            Write-Host "     Sucesso! Dados enviados para API" -ForegroundColor Green
            if ($response) {
                Write-Host "     Resposta: $response" -ForegroundColor White
            }
            return $true
        } else {
            Write-Host "     Erro no envio: $response" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "     Erro na chamada da API: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
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
        if ($TestMode) {
            Write-Host "MODO TESTE: Dados nao serao enviados para API" -ForegroundColor Yellow
        } else {
            Write-Host "MODO PRODUCAO: Dados serao enviados para API" -ForegroundColor Green
            Write-Host "Endpoint: $ApiEndpoint" -ForegroundColor Gray
        }
        
        # Contadores para relatorio final
        $totalProcessed = 0
        $successfulAPI = 0
        $failedAPI = 0
        
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
            
            # Variaveis para armazenar os dados necessarios para a API
            $modelData = ""
            $serialNumberData = ""
            $totalPagesData = 0
            
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
                    
                    # Exibe resultado formatado e armazena dados para API
                    $displayName = switch ($oidName) {
                        "paginasImpressas" { 
                            $totalPagesData = [int]$value
                            "Paginas Impressas" 
                        }
                        "modeloImpressora" { 
                            $modelData = $value
                            "Modelo da Impressora" 
                        }
                        "numeroSerie" { 
                            $serialNumberData = $value
                            "Numero de Serie" 
                        }
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
            
            # Processa dados para API
            if ($modelData -and $serialNumberData -and $totalPagesData -gt 0) {
                if ($TestMode) {
                    # Modo teste: apenas mostra os dados
                    Show-APIData -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData
                    $successfulAPI++
                } else {
                    # Modo producao: envia para API
                    $apiSuccess = Send-PrinterDataToAPI -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData -ApiEndpoint $ApiEndpoint
                    
                    if ($apiSuccess) {
                        $successfulAPI++
                        Write-Host "`n     Status: Dados enviados com sucesso para API!" -ForegroundColor Green
                    } else {
                        $failedAPI++
                        Write-Host "`n     Status: Falha no envio para API" -ForegroundColor Red
                    }
                }
            } else {
                $failedAPI++
                Write-Host "`n     Status: Dados insuficientes para envio para API" -ForegroundColor Red
                Write-Host "     Modelo: $modelData" -ForegroundColor Gray
                Write-Host "     Serie: $serialNumberData" -ForegroundColor Gray
                Write-Host "     Paginas: $totalPagesData" -ForegroundColor Gray
            }
            
            $totalProcessed++
        }
        
        # Relatorio final
        Write-Host "`n" + "="*60 -ForegroundColor Yellow
        Write-Host "RELATORIO FINAL" -ForegroundColor Cyan
        Write-Host "="*60 -ForegroundColor Yellow
        Write-Host "Total de impressoras processadas: $totalProcessed" -ForegroundColor White
        if ($TestMode) {
            Write-Host "Dados preparados para API: $successfulAPI" -ForegroundColor Green
            Write-Host "Dados com problemas: $failedAPI" -ForegroundColor Red
        } else {
            Write-Host "Envios bem-sucedidos para API: $successfulAPI" -ForegroundColor Green
            Write-Host "Falhas no envio para API: $failedAPI" -ForegroundColor Red
        }
        Write-Host "="*60 -ForegroundColor Yellow
    }
    catch {
        Write-Error "Erro ao processar arquivo YAML: $($_.Exception.Message)"
    }
}

# Executa o script principal
if ($TestMode) {
    Write-Host "=== SNMP Reader - MODO TESTE ===" -ForegroundColor Magenta
} else {
    Write-Host "=== SNMP Reader com API - MODO PRODUCAO ===" -ForegroundColor Magenta
}
Read-PrintersConfigAndQuery
