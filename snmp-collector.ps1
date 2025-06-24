# Script SNMP com modo de teste (sem envio para API)
# Para verificar se os dados estao sendo coletados corretamente

param(
    [switch]$TestMode = $false,
    [switch]$RetryOnly = $false,
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
        [int]$TotalPrintedPages,
        [string]$CollectionTime = $null
    )
    
    # Se nao foi fornecida uma data especifica, usa a data atual
    if (-not $CollectionTime) {
        $CollectionTime = Get-Date -Format "yyyy-MM-dd"
    }
    
    Write-Host "`n  -> DADOS PARA API (MODO TESTE):" -ForegroundColor Cyan
    Write-Host "     {" -ForegroundColor White
    Write-Host "       `"model`": `"$Model`"," -ForegroundColor White
    Write-Host "       `"serialNumber`": `"$SerialNumber`"," -ForegroundColor White
    Write-Host "       `"totalPrintedPages`": $TotalPrintedPages," -ForegroundColor White
    Write-Host "       `"time`": `"$CollectionTime`"" -ForegroundColor White
    Write-Host "     }" -ForegroundColor White
    Write-Host "     Status: Dados prontos para envio!" -ForegroundColor Green
}

# Funcao para enviar dados para API via curl
function Send-PrinterDataToAPI {
    param(
        [string]$Model,
        [string]$SerialNumber,
        [int]$TotalPrintedPages,
        [string]$ApiEndpoint,
        [string]$CollectionTime = $null
    )
    
    # Se nao foi fornecida uma data especifica, usa a data atual
    if (-not $CollectionTime) {
        $CollectionTime = Get-Date -Format "yyyy-MM-dd"
    }
    
    # Prepara o JSON com escape correto para caracteres especiais
    $jsonData = @{
        model = $Model
        serialNumber = $SerialNumber
        totalPrintedPages = $TotalPrintedPages
        time = $CollectionTime
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
            return @{ success = $false; status = "error"; httpCode = 0 }
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
                '-w', '%{http_code}',  # Adiciona codigo HTTP na resposta
                '--silent',
                '--show-error'
            )
              $response = & $curlPath @curlArgs 2>&1
            $curlExitCode = $LASTEXITCODE
            
            # Extrai codigo HTTP da resposta (ultimos 3 caracteres)
            $httpCode = 0
            if ($response -and $response.Length -ge 3) {
                $httpCodeStr = $response.Substring($response.Length - 3)
                if ([int]::TryParse($httpCodeStr, [ref]$httpCode)) {
                    $response = $response.Substring(0, $response.Length - 3)
                }
            }
        }
        finally {
            # Remove arquivo temporario
            if (Test-Path $tempJsonFile) {
                Remove-Item $tempJsonFile -Force
            }
        }
          if ($curlExitCode -eq 0) {
            if ($httpCode -eq 200 -or $httpCode -eq 201) {
                Write-Host "     Sucesso! Dados enviados para API (HTTP $httpCode)" -ForegroundColor Green
                if ($response) {
                    Write-Host "     Resposta: $response" -ForegroundColor White
                }
                return @{ success = $true; status = "success"; httpCode = $httpCode }
            } elseif ($httpCode -eq 404) {
                Write-Host "     Erro 404: Impressora nao encontrada no sistema" -ForegroundColor Red
                return @{ success = $false; status = "not_found"; httpCode = $httpCode }
            } elseif ($httpCode -eq 500) {
                Write-Host "     Erro 500: Erro interno do servidor" -ForegroundColor Red
                return @{ success = $false; status = "server_error"; httpCode = $httpCode }
            } else {
                Write-Host "     Erro HTTP $httpCode`: $response" -ForegroundColor Red
                return @{ success = $false; status = "http_error"; httpCode = $httpCode }
            }
        } else {
            Write-Host "     Erro no envio: $response" -ForegroundColor Red
            return @{ success = $false; status = "connection_error"; httpCode = 0 }
        }
    }
    catch {
        Write-Host "     Erro na chamada da API: $($_.Exception.Message)" -ForegroundColor Red
        return @{ success = $false; status = "error"; httpCode = 0 }
    }
}

# Funcao para testar conectividade com o servidor
function Test-ServerConnectivity {
    param(
        [string]$ApiEndpoint,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        # Extrai apenas o dominio base da URL para teste
        $uri = [System.Uri]$ApiEndpoint
        $hostname = $uri.Host
        $port = if ($uri.Port -and $uri.Port -ne -1) { $uri.Port } else { if ($uri.Scheme -eq "https") { 443 } else { 80 } }
        
        Write-Host "     Testando conectividade com servidor usando Test-NetConnection..." -ForegroundColor Gray
        Write-Host "     Host: $hostname, Porta: $port" -ForegroundColor Gray
        
        # Usa Test-NetConnection para verificar conectividade TCP
        $connectionTest = Test-NetConnection -ComputerName $hostname -Port $port -WarningAction SilentlyContinue
        
        if ($connectionTest.TcpTestSucceeded) {
            Write-Host "     Servidor acessivel! (TCP conectado)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "     Servidor inaccessivel ou sem conexao" -ForegroundColor Yellow
            Write-Host "     Detalhes: $($connectionTest.TcpTestSucceeded)" -ForegroundColor Gray
            return $false
        }
    }
    catch {
        Write-Host "     Erro ao testar conectividade: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Funcao para verificar se impressora ja foi enviada hoje
function Check-DailySubmission {
    param(
        [string]$PrinterIP,
        [string]$CollectionDate
    )
    
    $localDataDir = Join-Path $PSScriptRoot "local-data"
    $localDataFile = Join-Path $localDataDir "local-data.json"
    
    if (-not (Test-Path $localDataFile)) {
        return @{ alreadySent = $false; hasPending = $false }
    }
    
    try {
        $fileContent = Get-Content $localDataFile -Raw
        if (-not $fileContent) {
            return @{ alreadySent = $false; hasPending = $false }
        }
        
        $dataEntries = ConvertFrom-Json $fileContent
        if ($dataEntries -isnot [System.Array]) {
            $dataEntries = @($dataEntries)
        }
        
        # Verifica se ja foi enviado com sucesso hoje
        $successEntry = $dataEntries | Where-Object { 
            $_.printerIP -eq $PrinterIP -and 
            $_.time -eq $CollectionDate -and 
            $_.status -eq "sent" 
        }
        
        # Verifica se tem pendencia para hoje
        $pendingEntry = $dataEntries | Where-Object { 
            $_.printerIP -eq $PrinterIP -and 
            $_.time -eq $CollectionDate -and 
            $_.status -eq "pending" 
        }
          return @{ 
            alreadySent = ($null -ne $successEntry)
            hasPending = ($null -ne $pendingEntry)
        }
    }
    catch {
        Write-Host "     Erro ao verificar envios diarios: $($_.Exception.Message)" -ForegroundColor Red
        return @{ alreadySent = $false; hasPending = $false }
    }
}

# Funcao para salvar dados localmente quando servidor indisponivel
function Save-DataLocally {
    param(
        [string]$Model,
        [string]$SerialNumber,
        [int]$TotalPrintedPages,
        [string]$PrinterIP,
        [string]$ApiEndpoint,
        [string]$CollectionTime = $null,
        [string]$Status = "pending"
    )
    
    try {
        # Se nao foi fornecida uma data especifica, usa a data atual
        if (-not $CollectionTime) {
            $CollectionTime = Get-Date -Format "yyyy-MM-dd"
        }
        
        # Cria diretorio local-data se nao existir
        $localDataDir = Join-Path $PSScriptRoot "local-data"
        if (-not (Test-Path $localDataDir)) {
            New-Item -ItemType Directory -Path $localDataDir | Out-Null
        }
        
        # Usa arquivo unico local-data.json
        $localDataFile = Join-Path $localDataDir "local-data.json"
        
        # Cria objeto com dados e timestamp
        $dataEntry = @{
            id = [System.Guid]::NewGuid().ToString()
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            printerIP = $PrinterIP
            model = $Model
            serialNumber = $SerialNumber
            totalPrintedPages = $TotalPrintedPages
            time = $CollectionTime
            apiEndpoint = $ApiEndpoint
            status = $Status
        }        # Le dados existentes no arquivo ou cria array vazio
        $existingData = @()
        if (Test-Path $localDataFile) {
            $existingContent = Get-Content $localDataFile -Raw
            if ($existingContent) {
                $jsonData = ConvertFrom-Json $existingContent
                # Garante que existingData seja sempre um array
                if ($jsonData -is [System.Array]) {
                    $existingData = $jsonData
                } else {
                    $existingData = @($jsonData)
                }
            }
        }
        
        # Se for status "sent", remove qualquer entrada anterior para mesma impressora/data
        if ($Status -eq "sent") {
            $existingData = $existingData | Where-Object { 
                -not ($_.printerIP -eq $PrinterIP -and $_.time -eq $CollectionTime) 
            }
        }
        
        # Adiciona nova entrada (conversão segura para array)
        $updatedData = @()
        $updatedData += $existingData
        $updatedData += $dataEntry
        $existingData = $updatedData
        
        # Salva dados atualizados
        $existingData | ConvertTo-Json -Depth 3 | Set-Content $localDataFile -Encoding UTF8
        
        Write-Host "     Dados salvos localmente: $localDataFile" -ForegroundColor Cyan
        Write-Host "     ID: $($dataEntry.id)" -ForegroundColor Gray
        Write-Host "     Status: $Status" -ForegroundColor Gray
        
        return $true
    }
    catch {
        Write-Host "     Erro ao salvar dados localmente: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Funcao para tentar reenviar dados salvos localmente
function Retry-LocalData {
    param(
        [string]$ApiEndpoint
    )
    
    $localDataDir = Join-Path $PSScriptRoot "local-data"
    $localDataFile = Join-Path $localDataDir "local-data.json"
    
    if (-not (Test-Path $localDataFile)) {
        Write-Host "Nenhum dado local encontrado para reenvio." -ForegroundColor Gray
        return
    }
    
    try {
        $fileContent = Get-Content $localDataFile -Raw
        if (-not $fileContent) { 
            Write-Host "Arquivo local vazio." -ForegroundColor Gray
            return 
        }
        
        $dataEntries = ConvertFrom-Json $fileContent
        
        # Garante que seja sempre um array
        if ($dataEntries -isnot [System.Array]) {
            $dataEntries = @($dataEntries)
        }
        
        # Filtra apenas registros pendentes
        $pendingEntries = $dataEntries | Where-Object { $_.status -eq "pending" }
        $notFoundEntries = $dataEntries | Where-Object { $_.status -eq "not_found" }
        
        if ($pendingEntries.Count -eq 0) {
            Write-Host "Nenhum dado pendente para reenvio." -ForegroundColor Gray
            if ($notFoundEntries.Count -gt 0) {
                Write-Host "Existem $($notFoundEntries.Count) registro(s) marcado(s) como 'not_found' (nao serao reenviados)." -ForegroundColor Yellow
            }
            return
        }
        
        Write-Host "`n=== Tentando reenviar dados salvos localmente ===" -ForegroundColor Magenta
        Write-Host "Total de registros pendentes: $($pendingEntries.Count)" -ForegroundColor White
        
        $totalRetried = 0
        $totalSuccess = 0
        $totalNotFound = 0
        $updatedEntries = @()
        
        # Mantém registros "not_found" no arquivo (conversão segura)
        if ($notFoundEntries) {
            $updatedEntries += $notFoundEntries
        }
        
        foreach ($entry in $pendingEntries) {
            $totalRetried++
            Write-Host "`nTentando reenviar dados de $($entry.timestamp):" -ForegroundColor Yellow
            Write-Host "  ID: $($entry.id)" -ForegroundColor Gray
            Write-Host "  Impressora: $($entry.model) ($($entry.printerIP))" -ForegroundColor Gray
              $result = Send-PrinterDataToAPI -Model $entry.model -SerialNumber $entry.serialNumber -TotalPrintedPages $entry.totalPrintedPages -ApiEndpoint $entry.apiEndpoint -CollectionTime $entry.time            if ($result.success) {
                $totalSuccess++
                Write-Host "  Status: Reenviado com sucesso! (Marcado como 'sent')" -ForegroundColor Green
                
                # Cria novo objeto marcado como 'sent' para historico
                $sentEntry = @{
                    id = $entry.id
                    timestamp = $entry.timestamp
                    printerIP = $entry.printerIP
                    model = $entry.model
                    serialNumber = $entry.serialNumber
                    totalPrintedPages = $entry.totalPrintedPages
                    time = $entry.time
                    apiEndpoint = $entry.apiEndpoint
                    status = "sent"
                    sentTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    httpCode = $result.httpCode
                }
                $updatedEntries = $updatedEntries + @($sentEntry)            } elseif ($result.status -eq "not_found") {
                $totalNotFound++
                Write-Host "  Status: Impressora nao encontrada (404) - marcado como 'not_found'" -ForegroundColor Red
                
                # Cria novo objeto marcado como not_found
                $notFoundEntry = @{
                    id = $entry.id
                    timestamp = $entry.timestamp
                    printerIP = $entry.printerIP
                    model = $entry.model
                    serialNumber = $entry.serialNumber
                    totalPrintedPages = $entry.totalPrintedPages
                    time = $entry.time
                    apiEndpoint = $entry.apiEndpoint
                    status = "not_found"
                    lastTryTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    httpCode = $result.httpCode
                }
                $updatedEntries = $updatedEntries + @($notFoundEntry)
            } else {
                Write-Host "  Status: Falha no reenvio - mantido como pendente" -ForegroundColor Red
                
                # Cria novo objeto mantendo como pendente com timestamp atualizado
                $pendingEntry = @{
                    id = $entry.id
                    timestamp = $entry.timestamp
                    printerIP = $entry.printerIP
                    model = $entry.model
                    serialNumber = $entry.serialNumber
                    totalPrintedPages = $entry.totalPrintedPages
                    time = $entry.time
                    apiEndpoint = $entry.apiEndpoint
                    status = "pending"
                    lastTryTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                if ($result.httpCode) {
                    $pendingEntry.lastHttpCode = $result.httpCode
                }
                $updatedEntries = $updatedEntries + @($pendingEntry)
            }
        }
          # Atualiza arquivo com registros atualizados
        if ($updatedEntries.Count -gt 0) {
            $updatedEntries | ConvertTo-Json -Depth 3 | Set-Content $localDataFile -Encoding UTF8
        } else {
            # Se nao ha mais registros, remove o arquivo
            Remove-Item $localDataFile -Force
            Write-Host "`nArquivo local removido (nenhum registro restante)." -ForegroundColor Green
        }
          Write-Host "`nResultado do reenvio:" -ForegroundColor Cyan
        Write-Host "  Total tentativas: $totalRetried" -ForegroundColor White
        Write-Host "  Sucessos (marcados como 'sent'): $totalSuccess" -ForegroundColor Green
        Write-Host "  Nao encontrados (404): $totalNotFound" -ForegroundColor Yellow
        Write-Host "  Falhas (mantidos como 'pending'): $($totalRetried - $totalSuccess - $totalNotFound)" -ForegroundColor Red
        Write-Host "  Total de registros no arquivo: $($updatedEntries.Count)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Erro ao processar dados locais: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Funcao para verificar e atualizar repositorio Git
function Update-GitRepository {
    param(
        [string]$RepositoryUrl = "git@github.com:a3sitsolutions/upms-client.git"
    )
    
    Write-Host "`n=== Verificando atualizacoes do repositorio Git ===" -ForegroundColor Cyan
    Write-Host "Repositorio: $RepositoryUrl" -ForegroundColor Gray
    
    try {
        # Verifica se estamos em um repositorio Git
        $gitDir = Join-Path $PSScriptRoot ".git"
        if (-not (Test-Path $gitDir)) {
            Write-Host "     Aviso: Diretorio nao e um repositorio Git - pulando verificacao" -ForegroundColor Yellow
            return $true
        }
        
        # Verifica se git esta disponivel
        $gitCommand = Get-Command git -ErrorAction SilentlyContinue
        if (-not $gitCommand) {
            Write-Host "     Aviso: Git nao encontrado no sistema - pulando verificacao" -ForegroundColor Yellow
            return $true
        }
        
        Write-Host "     Verificando status do repositorio..." -ForegroundColor Gray
        
        # Muda para o diretorio do script
        Push-Location $PSScriptRoot
        
        try {
            # Verifica se ha mudancas locais nao commitadas
            $gitStatus = git status --porcelain 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "     Erro ao verificar status Git: $gitStatus" -ForegroundColor Red
                return $false
            }
            
            if ($gitStatus) {
                Write-Host "     Aviso: Ha mudancas locais nao commitadas" -ForegroundColor Yellow
                Write-Host "     Stashing mudancas locais temporariamente..." -ForegroundColor Gray
                
                # Salva mudancas locais temporariamente
                $stashResult = git stash push -m "Auto-stash antes de update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "     Erro ao fazer stash: $stashResult" -ForegroundColor Red
                    return $false
                }
                Write-Host "     Mudancas locais salvas temporariamente" -ForegroundColor Green
            }
            
            # Busca atualizacoes do repositorio remoto
            Write-Host "     Buscando atualizacoes do repositorio remoto..." -ForegroundColor Gray
            $fetchResult = git fetch origin 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "     Erro ao buscar atualizacoes: $fetchResult" -ForegroundColor Red
                return $false
            }
            
            # Verifica se ha atualizacoes disponiveis
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "     Erro ao obter branch atual: $currentBranch" -ForegroundColor Red
                return $false
            }
            
            $localCommit = git rev-parse HEAD 2>&1
            $remoteCommit = git rev-parse "origin/$currentBranch" 2>&1
            
            if ($localCommit -eq $remoteCommit) {
                Write-Host "     Repositorio ja esta atualizado!" -ForegroundColor Green
                
                # Se houve stash, restaura as mudancas
                if ($gitStatus) {
                    Write-Host "     Restaurando mudancas locais..." -ForegroundColor Gray
                    $popResult = git stash pop 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "     Mudancas locais restauradas" -ForegroundColor Green
                    } else {
                        Write-Host "     Aviso: Erro ao restaurar mudancas: $popResult" -ForegroundColor Yellow
                    }
                }
                
                return $true
            }
            
            # Ha atualizacoes disponiveis - forca update
            Write-Host "     Atualizacoes encontradas! Fazendo pull forcado..." -ForegroundColor Yellow
            $pullResult = git pull origin $currentBranch 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "     Repositorio atualizado com sucesso!" -ForegroundColor Green
                
                # Se houve stash, tenta restaurar as mudancas
                if ($gitStatus) {
                    Write-Host "     Tentando restaurar mudancas locais..." -ForegroundColor Gray
                    $popResult = git stash pop 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "     Mudancas locais restauradas" -ForegroundColor Green
                    } else {
                        Write-Host "     Conflito ao restaurar mudancas. Verifique manualmente:" -ForegroundColor Yellow
                        Write-Host "     $popResult" -ForegroundColor Gray
                        Write-Host "     Use 'git stash list' e 'git stash pop' para resolver" -ForegroundColor Gray
                    }
                }
                
                return $true
            } else {
                Write-Host "     Erro ao fazer pull: $pullResult" -ForegroundColor Red
                
                # Em caso de erro, tenta reset hard para forcar atualizacao
                Write-Host "     Tentando reset forcado para a versao remota..." -ForegroundColor Yellow
                $resetResult = git reset --hard "origin/$currentBranch" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "     Reset forcado realizado com sucesso!" -ForegroundColor Green
                    Write-Host "     ATENCAO: Mudancas locais foram perdidas!" -ForegroundColor Red
                    return $true
                } else {
                    Write-Host "     Erro no reset forcado: $resetResult" -ForegroundColor Red
                    return $false
                }
            }
        }
        finally {
            # Retorna ao diretorio original
            Pop-Location
        }
    }
    catch {
        Write-Host "     Erro na verificacao Git: $($_.Exception.Message)" -ForegroundColor Red
        Pop-Location -ErrorAction SilentlyContinue
        return $false
    }
}

# Funcao principal
function Read-PrintersConfigAndQuery {
    # Se modo RetryOnly, apenas tenta reenviar dados salvos
    if ($RetryOnly) {
        Write-Host "=== MODO REENVIO - Apenas tentando reenviar dados salvos ===" -ForegroundColor Magenta
        Write-Host "Testando conectividade com servidor..." -ForegroundColor Cyan
        $serverAvailable = Test-ServerConnectivity -ApiEndpoint $ApiEndpoint
        
        if ($serverAvailable) {
            Retry-LocalData -ApiEndpoint $ApiEndpoint
        } else {
            Write-Host "Servidor indisponivel. Nao e possivel reenviar dados no momento." -ForegroundColor Red
        }
        return
    }
    
    # Verifica e atualiza repositorio Git antes da execucao principal
    Write-Host "Verificando atualizacoes do repositorio..." -ForegroundColor Cyan
    $gitUpdateSuccess = Update-GitRepository
    if (-not $gitUpdateSuccess) {
        Write-Host "Aviso: Problemas na atualizacao do repositorio Git" -ForegroundColor Yellow
        Write-Host "Continuando execucao com versao atual..." -ForegroundColor Yellow
    }
    
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
          # Testa conectividade com servidor antes de processar
        $serverAvailable = $false
        if (-not $TestMode) {
            Write-Host "`nTestando conectividade com servidor..." -ForegroundColor Cyan
            $serverAvailable = Test-ServerConnectivity -ApiEndpoint $ApiEndpoint
            
            if ($serverAvailable) {
                # Se servidor disponivel, tenta reenviar dados salvos anteriormente
                Retry-LocalData -ApiEndpoint $ApiEndpoint
            }
        }
        
        # Contadores para relatorio final
        $totalProcessed = 0
        $successfulAPI = 0
        $failedAPI = 0
        $savedLocally = 0
        
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
            $collectionTime = Get-Date -Format "yyyy-MM-dd"
            
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
            }            # Processa dados para API
            if ($modelData -and $serialNumberData -and $totalPagesData -gt 0) {
                if ($TestMode) {
                    # Modo teste: apenas mostra os dados
                    Show-APIData -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData -CollectionTime $collectionTime
                    $successfulAPI++
                } else {
                    # Modo producao: verifica se ja foi enviado hoje
                    $dailyCheck = Check-DailySubmission -PrinterIP $printer.ip -CollectionDate $collectionTime
                    
                    if ($dailyCheck.alreadySent) {
                        Write-Host "`n     Status: Dados ja enviados hoje - pulando envio" -ForegroundColor Green
                        $successfulAPI++
                    } elseif ($dailyCheck.hasPending) {
                        Write-Host "`n     Status: Tentativa pendente para hoje - sera processada no reenvio" -ForegroundColor Yellow
                        $savedLocally++
                    } else {
                        # Verifica conectividade e envia/salva conforme necessario
                        if ($serverAvailable) {
                            # Servidor disponivel: tenta enviar para API
                            $apiResult = Send-PrinterDataToAPI -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData -ApiEndpoint $ApiEndpoint -CollectionTime $collectionTime
                            
                            if ($apiResult.success) {
                                $successfulAPI++
                                Write-Host "`n     Status: Dados enviados com sucesso para API!" -ForegroundColor Green
                                # Salva como 'sent' para controle diario
                                Save-DataLocally -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData -PrinterIP $printer.ip -ApiEndpoint $ApiEndpoint -CollectionTime $collectionTime -Status "sent"
                            } elseif ($apiResult.status -eq "not_found") {
                                # Erro 404: salva como not_found (nao sera reenviado)
                                Write-Host "`n     Status: Impressora nao encontrada (404) - salvando como 'not_found'" -ForegroundColor Yellow
                                $saveSuccess = Save-DataLocally -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData -PrinterIP $printer.ip -ApiEndpoint $ApiEndpoint -CollectionTime $collectionTime -Status "not_found"
                                if ($saveSuccess) {
                                    $savedLocally++
                                } else {
                                    $failedAPI++
                                }
                            } else {
                                # Outros erros: salva como pending para reenvio
                                $failedAPI++
                                Write-Host "`n     Status: Falha no envio para API - salvando localmente" -ForegroundColor Yellow
                                $saveSuccess = Save-DataLocally -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData -PrinterIP $printer.ip -ApiEndpoint $ApiEndpoint -CollectionTime $collectionTime -Status "pending"
                                if ($saveSuccess) {
                                    $savedLocally++
                                }
                            }
                        } else {
                            # Servidor indisponivel: salva dados localmente como pending
                            Write-Host "`n     Status: Servidor indisponivel - salvando dados localmente" -ForegroundColor Yellow
                            $saveSuccess = Save-DataLocally -Model $modelData -SerialNumber $serialNumberData -TotalPrintedPages $totalPagesData -PrinterIP $printer.ip -ApiEndpoint $ApiEndpoint -CollectionTime $collectionTime -Status "pending"
                            
                            if ($saveSuccess) {
                                $savedLocally++
                                Write-Host "`n     Status: Dados salvos localmente com sucesso!" -ForegroundColor Cyan
                            } else {
                                $failedAPI++
                                Write-Host "`n     Status: Falha ao salvar dados localmente" -ForegroundColor Red
                            }
                        }
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
            Write-Host "Dados salvos localmente: $savedLocally" -ForegroundColor Cyan
            Write-Host "Falhas totais: $failedAPI" -ForegroundColor Red
            
            if ($savedLocally -gt 0) {
                Write-Host "`nNOTA: Dados salvos localmente serao reenviados automaticamente" -ForegroundColor Yellow
                Write-Host "      na proxima execucao quando o servidor estiver disponivel." -ForegroundColor Yellow
            }
        }
        Write-Host "="*60 -ForegroundColor Yellow
    }
    catch {
        Write-Error "Erro ao processar arquivo YAML: $($_.Exception.Message)"
    }
}

# Executa o script principal
if ($RetryOnly) {
    Write-Host "=== SNMP Reader - MODO REENVIO ===" -ForegroundColor Magenta
} elseif ($TestMode) {
    Write-Host "=== SNMP Reader - MODO TESTE ===" -ForegroundColor Magenta
} else {
    Write-Host "=== SNMP Reader com API - MODO PRODUCAO ===" -ForegroundColor Magenta
}
Read-PrintersConfigAndQuery
