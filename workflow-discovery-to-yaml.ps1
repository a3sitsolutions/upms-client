# Workflow Completo: Descoberta + SNMP Walk + YAML Export
# 
# Este script demonstra um workflow completo:
# 1. Descobrir impressoras na rede usando scan-printer-oids.ps1
# 2. Para cada impressora encontrada, fazer SNMP walk completo
# 3. Salvar dados detalhados em arquivos YAML individuais
#
# Uso:
#   .\workflow-discovery-to-yaml.ps1 -NetworkRange "192.168.1.1-192.168.1.254"
#   .\workflow-discovery-to-yaml.ps1 -IPList @("192.168.1.100", "192.168.1.200")

param(
    [Parameter(Mandatory=$false)]
    [string]$NetworkRange,
    
    [Parameter(Mandatory=$false)]
    [string[]]$IPList,
    
    [Parameter(Mandatory=$false)]
    [string]$Community = "public",
    
    [Parameter(Mandatory=$false)]
    [int]$ScanTimeoutSeconds = 1,
    
    [Parameter(Mandatory=$false)]
    [int]$WalkTimeoutSeconds = 3,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseOID = "1.3.6.1.2.1",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\local-mibs"
)

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Green
    Write-Host $Text -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "--- $Text ---" -ForegroundColor Cyan
}

Write-Banner "WORKFLOW: DESCOBERTA + SNMP WALK + YAML EXPORT"

# Validar parâmetros
if (-not $NetworkRange -and -not $IPList) {
    Write-Error "Especifique -NetworkRange ou -IPList"
    Write-Host ""
    Write-Host "Exemplos:" -ForegroundColor Yellow
    Write-Host "  .\workflow-discovery-to-yaml.ps1 -NetworkRange `"192.168.1.1-192.168.1.254`"" -ForegroundColor White
    Write-Host "  .\workflow-discovery-to-yaml.ps1 -IPList @(`"192.168.1.100`", `"192.168.1.200`")" -ForegroundColor White
    exit 1
}

Write-Host "Configuração:" -ForegroundColor Yellow
if ($NetworkRange) {
    Write-Host "  Range de rede: $NetworkRange" -ForegroundColor White
}
if ($IPList) {
    Write-Host "  Lista de IPs: $($IPList -join ', ')" -ForegroundColor White
}
Write-Host "  Community: $Community" -ForegroundColor White
Write-Host "  Timeout scan: ${ScanTimeoutSeconds}s" -ForegroundColor White
Write-Host "  Timeout walk: ${WalkTimeoutSeconds}s" -ForegroundColor White
Write-Host "  Base OID: $BaseOID" -ForegroundColor White
Write-Host "  Diretório saída: $OutputDir" -ForegroundColor White

# Verificar se os scripts necessários existem
$scanScript = ".\scan-printer-oids.ps1"
$walkScript = ".\snmp-walk-to-yaml.ps1"

if (!(Test-Path $scanScript)) {
    Write-Error "Script não encontrado: $scanScript"
    exit 1
}

if (!(Test-Path $walkScript)) {
    Write-Error "Script não encontrado: $walkScript"
    exit 1
}

$startTime = Get-Date

# FASE 1: Descoberta de impressoras
Write-Section "FASE 1: DESCOBERTA DE IMPRESSORAS"

$discoveredPrinters = @()

if ($NetworkRange) {
    Write-Host "Executando scan na rede: $NetworkRange" -ForegroundColor Cyan
    try {
        # Executar scan e capturar resultado
        $scanResult = & $scanScript -NetworkRange $NetworkRange -TimeoutSeconds $ScanTimeoutSeconds -Community $Community
        
        # Parse do resultado para extrair IPs das impressoras
        # Assumindo que o scan retorna linhas com IPs de impressoras
        # Você pode ajustar esta lógica baseado no formato real de saída do seu scan script
        
        Write-Host "Scan concluído. Analisando resultados..." -ForegroundColor Green
        
        # Para demonstração, vamos simular algumas impressoras descobertas
        # Em produção, você parsearia a saída real do scan-printer-oids.ps1
        Write-Host "NOTA: Esta é uma versão de demonstração." -ForegroundColor Yellow
        Write-Host "Em produção, parsearia a saída real do scan-printer-oids.ps1" -ForegroundColor Yellow
        
    }
    catch {
        Write-Warning "Erro no scan: $_"
    }
}

if ($IPList) {
    Write-Host "Usando lista de IPs fornecida" -ForegroundColor Cyan
    $discoveredPrinters = $IPList
}

# Para demonstração, usar IPs de exemplo se nenhum foi descoberto
if ($discoveredPrinters.Count -eq 0) {
    Write-Host "Usando IPs de exemplo para demonstração:" -ForegroundColor Yellow
    $discoveredPrinters = @("192.168.1.100", "192.168.1.200", "192.168.1.250")
    foreach ($ip in $discoveredPrinters) {
        Write-Host "  - $ip (exemplo)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Impressoras descobertas: $($discoveredPrinters.Count)" -ForegroundColor Green

# FASE 2: SNMP Walk para cada impressora
Write-Section "FASE 2: SNMP WALK E EXPORT YAML"

$successCount = 0
$failCount = 0
$walkResults = @()

foreach ($ip in $discoveredPrinters) {
    Write-Host ""
    Write-Host "Processando: $ip" -ForegroundColor Yellow
    
    try {
        # Executar SNMP walk
        $walkStartTime = Get-Date
        & $walkScript -IP $ip -Community $Community -TimeoutSeconds $WalkTimeoutSeconds -BaseOID $BaseOID -OutputDir $OutputDir
        $walkEndTime = Get-Date
        $walkDuration = $walkEndTime - $walkStartTime
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            $walkResults += @{
                IP = $ip
                Status = "Sucesso"
                Duration = $walkDuration.TotalSeconds
            }
            Write-Host "  ✓ Sucesso ($($walkDuration.TotalSeconds.ToString('F1'))s)" -ForegroundColor Green
        } else {
            $failCount++
            $walkResults += @{
                IP = $ip
                Status = "Falha"
                Duration = $walkDuration.TotalSeconds
            }
            Write-Host "  ✗ Falha" -ForegroundColor Red
        }
    }
    catch {
        $failCount++
        $walkResults += @{
            IP = $ip
            Status = "Erro: $_"
            Duration = 0
        }
        Write-Host "  ✗ Erro: $_" -ForegroundColor Red
    }
}

# FASE 3: Relatório final
Write-Section "FASE 3: RELATÓRIO FINAL"

$endTime = Get-Date
$totalDuration = $endTime - $startTime

Write-Host "Resumo da execução:" -ForegroundColor Green
Write-Host "  Impressoras processadas: $($discoveredPrinters.Count)" -ForegroundColor White
Write-Host "  Sucessos: $successCount" -ForegroundColor Green
Write-Host "  Falhas: $failCount" -ForegroundColor Red
Write-Host "  Tempo total: $($totalDuration.TotalSeconds.ToString('F1'))s" -ForegroundColor White

if ($successCount -gt 0) {
    Write-Host ""
    Write-Host "Arquivos YAML gerados:" -ForegroundColor Cyan
    if (Test-Path $OutputDir) {
        Get-ChildItem $OutputDir -Filter "*.yml" | ForEach-Object {
            $fileSize = [math]::Round($_.Length / 1KB, 1)
            Write-Host "  $($_.Name) (${fileSize}KB)" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Detalhes por dispositivo:" -ForegroundColor Cyan
foreach ($result in $walkResults) {
    $statusColor = if ($result.Status -eq "Sucesso") { "Green" } else { "Red" }
    $durationText = if ($result.Duration -gt 0) { " ($($result.Duration.ToString('F1'))s)" } else { "" }
    Write-Host "  $($result.IP): $($result.Status)$durationText" -ForegroundColor $statusColor
}

Write-Banner "WORKFLOW CONCLUÍDO"

# Sugestões para próximos passos
Write-Host "Próximos passos sugeridos:" -ForegroundColor Yellow
Write-Host "  1. Revisar arquivos YAML gerados em $OutputDir" -ForegroundColor White
Write-Host "  2. Analisar dados específicos das impressoras" -ForegroundColor White
Write-Host "  3. Configurar coleta automática com snmp-collector.ps1" -ForegroundColor White
Write-Host "  4. Implementar alertas baseados nos dados coletados" -ForegroundColor White
