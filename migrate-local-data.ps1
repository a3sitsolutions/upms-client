# Script para migrar dados locais antigos para o novo formato unico

Write-Host "=== Migracao de Dados Locais ===" -ForegroundColor Cyan
Write-Host "Convertendo arquivos por data para arquivo unico local-data.json" -ForegroundColor White

$localDataDir = Join-Path $PSScriptRoot "local-data"

if (-not (Test-Path $localDataDir)) {
    Write-Host "Diretorio local-data nao encontrado. Nada para migrar." -ForegroundColor Yellow
    return
}

# Localiza todos os arquivos antigos por data
$oldFiles = Get-ChildItem $localDataDir -Filter "printer-data-*.json"

if ($oldFiles.Count -eq 0) {
    Write-Host "Nenhum arquivo antigo encontrado para migrar." -ForegroundColor Yellow
    return
}

Write-Host "Encontrados $($oldFiles.Count) arquivo(s) antigo(s) para migrar:" -ForegroundColor White
foreach ($file in $oldFiles) {
    Write-Host "  - $($file.Name)" -ForegroundColor Gray
}

# Array para armazenar todos os dados migrados
$allMigratedData = @()
$totalMigrated = 0

foreach ($file in $oldFiles) {
    try {
        Write-Host "`nProcessando $($file.Name)..." -ForegroundColor Yellow
        
        $fileContent = Get-Content $file.FullName -Raw
        if (-not $fileContent) { 
            Write-Host "  Arquivo vazio, pulando..." -ForegroundColor Gray
            continue 
        }
        
        $dataEntries = ConvertFrom-Json $fileContent
        
        # Garante que seja sempre um array
        if ($dataEntries -isnot [System.Array]) {
            $dataEntries = @($dataEntries)
        }
        
        $fileMigrated = 0
        
        foreach ($entry in $dataEntries) {
            # Converte para novo formato se necessario
            $migratedEntry = @{
                id = [System.Guid]::NewGuid().ToString()
                timestamp = $entry.timestamp
                printerIP = $entry.printerIP
                model = $entry.model
                serialNumber = $entry.serialNumber
                totalPrintedPages = $entry.totalPrintedPages
                time = $entry.time
                apiEndpoint = $entry.apiEndpoint
                status = if ($entry.status -eq "sent") { "sent" } elseif ($entry.status -eq "not_found") { "not_found" } else { "pending" }
            }
            
            # Adiciona campos extras se existirem
            if ($entry.sentTimestamp) {
                $migratedEntry.sentTimestamp = $entry.sentTimestamp
            }
            if ($entry.lastTryTimestamp) {
                $migratedEntry.lastTryTimestamp = $entry.lastTryTimestamp
            }
            if ($entry.httpCode) {
                $migratedEntry.httpCode = $entry.httpCode
            }
            if ($entry.lastHttpCode) {
                $migratedEntry.lastHttpCode = $entry.lastHttpCode
            }
            
            # Adiciona apenas registros pendentes e not_found ao novo arquivo
            # Registros "sent" sao descartados conforme nova logica
            if ($migratedEntry.status -ne "sent") {
                $allMigratedData += $migratedEntry
                $fileMigrated++
            }
        }
        
        Write-Host "  Migrados: $fileMigrated registro(s)" -ForegroundColor Green
        $totalMigrated += $fileMigrated
    }
    catch {
        Write-Host "  Erro ao processar arquivo: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Salva dados migrados no novo arquivo unico
$newDataFile = Join-Path $localDataDir "local-data.json"

if ($allMigratedData.Count -gt 0) {
    try {
        $allMigratedData | ConvertTo-Json -Depth 3 | Set-Content $newDataFile -Encoding UTF8
        Write-Host "`nMigracao concluida com sucesso!" -ForegroundColor Green
        Write-Host "Total de registros migrados: $totalMigrated" -ForegroundColor White
        Write-Host "Arquivo criado: $newDataFile" -ForegroundColor Cyan
        
        # Pergunta se quer backup dos arquivos antigos
        $backup = Read-Host "`nDeseja fazer backup dos arquivos antigos antes de remove-los? (s/n)"
        
        if ($backup -eq "s" -or $backup -eq "S") {
            $backupDir = Join-Path $localDataDir "backup-migration-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
            New-Item -ItemType Directory -Path $backupDir | Out-Null
            
            foreach ($file in $oldFiles) {
                Copy-Item $file.FullName $backupDir
            }
            
            Write-Host "Backup criado em: $backupDir" -ForegroundColor Cyan
        }
        
        # Pergunta se quer remover arquivos antigos
        $remove = Read-Host "Deseja remover os arquivos antigos? (s/n)"
        
        if ($remove -eq "s" -or $remove -eq "S") {
            foreach ($file in $oldFiles) {
                Remove-Item $file.FullName -Force
                Write-Host "Removido: $($file.Name)" -ForegroundColor Gray
            }
            Write-Host "Arquivos antigos removidos." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Erro ao salvar arquivo migrado: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nNenhum registro pendente ou not_found encontrado para migrar." -ForegroundColor Yellow
    Write-Host "Todos os registros eram 'sent' e foram descartados conforme nova logica." -ForegroundColor Gray
}

Write-Host "`n=== Migracao finalizada ===" -ForegroundColor Cyan
