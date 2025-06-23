# Script para limpeza de dados locais

param(
    [switch]$Force = $false,
    [switch]$OnlySent = $false,
    [switch]$OnlyNotFound = $false,
    [switch]$OnlyOld = $false,
    [int]$DaysOld = 30
)

Write-Host "=== Limpeza de Dados Locais ===" -ForegroundColor Cyan

$localDataDir = Join-Path $PSScriptRoot "local-data"
$localDataFile = Join-Path $localDataDir "local-data.json"

if (-not (Test-Path $localDataFile)) {
    Write-Host "Nenhum arquivo de dados locais encontrado." -ForegroundColor Yellow
    
    # Verifica se existem arquivos antigos do formato anterior
    if (Test-Path $localDataDir) {
        $oldFiles = Get-ChildItem $localDataDir -Filter "printer-data-*.json"
        if ($oldFiles.Count -gt 0) {
            Write-Host "Encontrados $($oldFiles.Count) arquivo(s) do formato antigo:" -ForegroundColor Yellow
            foreach ($file in $oldFiles) {
                Write-Host "  - $($file.Name)" -ForegroundColor Gray
            }
            Write-Host "Execute 'migrate-local-data.ps1' para migrar para o novo formato." -ForegroundColor Cyan
        }
    }
    return
}

try {
    $fileContent = Get-Content $localDataFile -Raw
    if (-not $fileContent) {
        Write-Host "Arquivo de dados locais esta vazio." -ForegroundColor Yellow
        return
    }
    
    $dataEntries = ConvertFrom-Json $fileContent
    
    # Garante que seja sempre um array
    if ($dataEntries -isnot [System.Array]) {
        $dataEntries = @($dataEntries)
    }
    
    Write-Host "Total de registros encontrados: $($dataEntries.Count)" -ForegroundColor White
    
    # Mostra estatisticas por status
    $pendingCount = ($dataEntries | Where-Object { $_.status -eq "pending" }).Count
    $notFoundCount = ($dataEntries | Where-Object { $_.status -eq "not_found" }).Count
    $sentCount = ($dataEntries | Where-Object { $_.status -eq "sent" }).Count
    $otherCount = $dataEntries.Count - $pendingCount - $notFoundCount - $sentCount
    
    Write-Host "`nEstatisticas por status:" -ForegroundColor Cyan
    Write-Host "  Pendentes: $pendingCount" -ForegroundColor Yellow
    Write-Host "  Nao encontrados (404): $notFoundCount" -ForegroundColor Red
    Write-Host "  Enviados: $sentCount" -ForegroundColor Green
    if ($otherCount -gt 0) {
        Write-Host "  Outros: $otherCount" -ForegroundColor Gray
    }
    
    # Determina o que limpar baseado nos parametros
    $toRemove = @()
    $reason = ""
    
    if ($OnlySent) {
        $toRemove = $dataEntries | Where-Object { $_.status -eq "sent" }
        $reason = "registros com status 'sent'"
    } elseif ($OnlyNotFound) {
        $toRemove = $dataEntries | Where-Object { $_.status -eq "not_found" }
        $reason = "registros com status 'not_found'"
    } elseif ($OnlyOld) {
        $cutoffDate = (Get-Date).AddDays(-$DaysOld)
        $toRemove = $dataEntries | Where-Object { 
            $entryDate = [DateTime]::ParseExact($_.timestamp, "yyyy-MM-dd HH:mm:ss", $null)
            $entryDate -lt $cutoffDate
        }
        $reason = "registros mais antigos que $DaysOld dias"
    } else {
        # Remove todos os registros 'sent' por padrao (conforme nova logica)
        $toRemove = $dataEntries | Where-Object { $_.status -eq "sent" }
        $reason = "registros com status 'sent' (logica padrao)"
    }
    
    if ($toRemove.Count -eq 0) {
        Write-Host "`nNenhum registro encontrado para remocao ($reason)." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nRegistros a serem removidos ($reason): $($toRemove.Count)" -ForegroundColor Yellow
    
    if (-not $Force) {
        # Mostra alguns exemplos dos registros que serao removidos
        $examples = $toRemove | Select-Object -First 3
        Write-Host "`nExemplos de registros que serao removidos:" -ForegroundColor Gray
        foreach ($example in $examples) {
            Write-Host "  - ID: $($example.id)" -ForegroundColor Gray
            Write-Host "    Timestamp: $($example.timestamp)" -ForegroundColor Gray
            Write-Host "    Impressora: $($example.model)" -ForegroundColor Gray
            Write-Host "    Status: $($example.status)" -ForegroundColor Gray
            Write-Host ""
        }
        
        if ($toRemove.Count -gt 3) {
            Write-Host "  ... e mais $($toRemove.Count - 3) registro(s)" -ForegroundColor Gray
        }
        
        $confirm = Read-Host "`nConfirma a remocao destes registros? (s/n)"
        if ($confirm -ne "s" -and $confirm -ne "S") {
            Write-Host "Operacao cancelada pelo usuario." -ForegroundColor Yellow
            return
        }
    }
    
    # Remove os registros selecionados
    $remainingEntries = $dataEntries | Where-Object { $_ -notin $toRemove }
    
    if ($remainingEntries.Count -gt 0) {
        # Salva registros restantes
        $remainingEntries | ConvertTo-Json -Depth 3 | Set-Content $localDataFile -Encoding UTF8
        Write-Host "`nLimpeza concluida!" -ForegroundColor Green
        Write-Host "Registros removidos: $($toRemove.Count)" -ForegroundColor White
        Write-Host "Registros restantes: $($remainingEntries.Count)" -ForegroundColor White
    } else {
        # Remove o arquivo se nao restou nenhum registro
        Remove-Item $localDataFile -Force
        Write-Host "`nLimpeza concluida!" -ForegroundColor Green
        Write-Host "Todos os registros foram removidos." -ForegroundColor White
        Write-Host "Arquivo local-data.json foi removido." -ForegroundColor Gray
    }
}
catch {
    Write-Host "Erro ao processar dados locais: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Opcoes de uso ===" -ForegroundColor Cyan
Write-Host "  -OnlySent      Remove apenas registros enviados com sucesso" -ForegroundColor White
Write-Host "  -OnlyNotFound  Remove apenas registros marcados como 'not_found'" -ForegroundColor White
Write-Host "  -OnlyOld       Remove registros mais antigos que X dias" -ForegroundColor White
Write-Host "  -DaysOld N     Define quantos dias (padrao: 30)" -ForegroundColor White
Write-Host "  -Force         Nao pede confirmacao" -ForegroundColor White
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
