# Script para limpeza de dados locais antigos
# Remove arquivos de dados locais mais antigos que X dias

param(
    [int]$DaysToKeep = 30,
    [switch]$WhatIf = $false
)

$localDataDir = Join-Path $PSScriptRoot "local-data"

if (-not (Test-Path $localDataDir)) {
    Write-Host "Pasta local-data nao encontrada." -ForegroundColor Yellow
    exit
}

$cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
$jsonFiles = Get-ChildItem $localDataDir -Filter "*.json"

Write-Host "=== Limpeza de Dados Locais ===" -ForegroundColor Cyan
Write-Host "Mantendo arquivos dos ultimos $DaysToKeep dias" -ForegroundColor White
Write-Host "Data limite: $($cutoffDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray

$filesToDelete = @()
$totalSize = 0

foreach ($file in $jsonFiles) {
    if ($file.CreationTime -lt $cutoffDate) {
        $filesToDelete += $file
        $totalSize += $file.Length
    }
}

if ($filesToDelete.Count -eq 0) {
    Write-Host "Nenhum arquivo antigo encontrado para remocao." -ForegroundColor Green
    exit
}

Write-Host "`nArquivos a serem removidos:" -ForegroundColor Yellow
foreach ($file in $filesToDelete) {
    $fileSize = [math]::Round($file.Length / 1KB, 2)
    Write-Host "  $($file.Name) ($fileSize KB) - $($file.CreationTime.ToString('yyyy-MM-dd'))" -ForegroundColor White
}

$totalSizeKB = [math]::Round($totalSize / 1KB, 2)
Write-Host "`nTotal: $($filesToDelete.Count) arquivo(s), $totalSizeKB KB" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "`nMODO SIMULACAO: Nenhum arquivo foi removido." -ForegroundColor Yellow
    Write-Host "Execute sem -WhatIf para remover os arquivos." -ForegroundColor Yellow
} else {
    $confirmation = Read-Host "`nDeseja continuar com a remocao? (S/N)"
    if ($confirmation -eq 'S' -or $confirmation -eq 's') {
        foreach ($file in $filesToDelete) {
            try {
                Remove-Item $file.FullName -Force
                Write-Host "  Removido: $($file.Name)" -ForegroundColor Green
            }
            catch {
                Write-Host "  Erro ao remover $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host "`nLimpeza concluida!" -ForegroundColor Green
    } else {
        Write-Host "Operacao cancelada." -ForegroundColor Yellow
    }
}
