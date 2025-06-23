# Script para limpar dados antigos do arquivo local-data.json
# Remove registros de status 'sent' com mais de 30 dias

param(
    [int]$DaysToKeep = 30
)

Write-Host "=== Limpeza de dados antigos ===" -ForegroundColor Cyan
Write-Host "Mantendo registros dos ultimos $DaysToKeep dias" -ForegroundColor White

$localDataDir = Join-Path $PSScriptRoot "local-data"
$localDataFile = Join-Path $localDataDir "local-data.json"

if (-not (Test-Path $localDataFile)) {
    Write-Host "Nenhum arquivo de dados encontrado." -ForegroundColor Gray
    exit
}

try {
    $fileContent = Get-Content $localDataFile -Raw
    if (-not $fileContent) {
        Write-Host "Arquivo de dados vazio." -ForegroundColor Gray
        exit
    }
    
    $dataEntries = ConvertFrom-Json $fileContent
    if ($dataEntries -isnot [System.Array]) {
        $dataEntries = @($dataEntries)
    }
    
    $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    $totalEntries = $dataEntries.Count
    
    # Filtra registros:
    # - Mantem todos os registros 'pending' e 'not_found' (independente da data)
    # - Mantem registros 'sent' apenas dos ultimos X dias
    $filteredEntries = $dataEntries | Where-Object {
        if ($_.status -eq "sent") {
            $entryDate = [DateTime]::ParseExact($_.time, "yyyy-MM-dd", $null)
            return $entryDate -ge $cutoffDate
        } else {
            # Mantem todos os registros pending e not_found
            return $true
        }
    }
    
    $removedCount = $totalEntries - $filteredEntries.Count
    
    if ($removedCount -gt 0) {
        # Salva dados filtrados
        $filteredEntries | ConvertTo-Json -Depth 3 | Set-Content $localDataFile -Encoding UTF8
        Write-Host "Limpeza concluida:" -ForegroundColor Green
        Write-Host "  Total de registros original: $totalEntries" -ForegroundColor White
        Write-Host "  Registros removidos: $removedCount" -ForegroundColor Yellow
        Write-Host "  Registros mantidos: $($filteredEntries.Count)" -ForegroundColor Green
    } else {
        Write-Host "Nenhum registro antigo encontrado para remoção." -ForegroundColor Green
    }
    
    # Estatisticas dos registros mantidos
    if ($filteredEntries.Count -gt 0) {
        $sentCount = ($filteredEntries | Where-Object { $_.status -eq "sent" }).Count
        $pendingCount = ($filteredEntries | Where-Object { $_.status -eq "pending" }).Count
        $notFoundCount = ($filteredEntries | Where-Object { $_.status -eq "not_found" }).Count
        
        Write-Host "`nEstatisticas dos registros mantidos:" -ForegroundColor Cyan
        Write-Host "  Enviados (sent): $sentCount" -ForegroundColor Green
        Write-Host "  Pendentes (pending): $pendingCount" -ForegroundColor Yellow
        Write-Host "  Nao encontrados (not_found): $notFoundCount" -ForegroundColor Red
    }
}
catch {
    Write-Host "Erro durante a limpeza: $($_.Exception.Message)" -ForegroundColor Red
}
