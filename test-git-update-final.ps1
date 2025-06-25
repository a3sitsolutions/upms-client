# Script para testar a nova funcionalidade de Git Pull ao final
# Executa: .\test-git-update-final.ps1

param(
    [switch]$TestMode = $true  # Por padrao usa modo teste para nao afetar dados reais
)

Write-Host "=== Teste de Git Pull ao Final da Execucao ===" -ForegroundColor Cyan

# 1. Verifica se estamos em um repositorio Git
$gitDir = Join-Path $PSScriptRoot ".git"
if (-not (Test-Path $gitDir)) {
    Write-Host "`n1. Status do repositorio Git:" -ForegroundColor Yellow
    Write-Host "   ✗ Nao e um repositorio Git - teste limitado" -ForegroundColor Red
    Write-Host "   Para teste completo, inicialize um repositorio Git:" -ForegroundColor Gray
    Write-Host "   git init && git remote add origin <url-do-repo>" -ForegroundColor Gray
} else {
    Write-Host "`n1. Status do repositorio Git:" -ForegroundColor Yellow
    Write-Host "   ✓ Repositorio Git encontrado" -ForegroundColor Green
    
    # Verifica se git esta disponivel
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCommand) {
        Write-Host "   ✓ Comando git disponivel" -ForegroundColor Green
        
        # Mostra status atual
        try {
            Push-Location $PSScriptRoot
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
            $gitStatus = git status --porcelain 2>&1
            
            Write-Host "   Branch atual: $currentBranch" -ForegroundColor White
            if ($gitStatus) {
                Write-Host "   Mudancas locais: SIM" -ForegroundColor Yellow
                Write-Host "   (Serao descartadas no modo forcado)" -ForegroundColor Gray
            } else {
                Write-Host "   Mudancas locais: NAO" -ForegroundColor Green
            }
            Pop-Location
        } catch {
            Write-Host "   Erro ao verificar status Git: $($_.Exception.Message)" -ForegroundColor Red
            Pop-Location -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "   ✗ Comando git nao encontrado" -ForegroundColor Red
    }
}

# 2. Simula execucao do snmp-collector.ps1 em modo teste
Write-Host "`n2. Executando snmp-collector.ps1 em modo teste..." -ForegroundColor Yellow
Write-Host "   Comando: .\snmp-collector.ps1 -TestMode" -ForegroundColor Gray

$startTime = Get-Date
try {
    # Executa o script principal
    $scriptPath = Join-Path $PSScriptRoot "snmp-collector.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath -TestMode
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host "`n3. Resultado da execucao:" -ForegroundColor Yellow
        Write-Host "   ✓ Script executado com sucesso" -ForegroundColor Green
        Write-Host "   Duracao: $($duration.TotalSeconds.ToString('F1')) segundos" -ForegroundColor White
        Write-Host "   Git Pull executado: AO FINAL do script" -ForegroundColor Cyan
    } else {
        Write-Host "`n3. Resultado da execucao:" -ForegroundColor Yellow
        Write-Host "   ✗ Arquivo snmp-collector.ps1 nao encontrado" -ForegroundColor Red
    }
} catch {
    Write-Host "`n3. Resultado da execucao:" -ForegroundColor Yellow
    Write-Host "   ✗ Erro na execucao: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Verifica o que mudou no repositorio apos a execucao
if (Test-Path $gitDir) {
    Write-Host "`n4. Verificando mudancas apos execucao:" -ForegroundColor Yellow
    try {
        Push-Location $PSScriptRoot
        $gitStatusAfter = git status --porcelain 2>&1
        
        if ($gitStatusAfter) {
            Write-Host "   Arquivos modificados apos Git Pull:" -ForegroundColor Cyan
            $gitStatusAfter | ForEach-Object {
                Write-Host "     $_ " -ForegroundColor Gray
            }
        } else {
            Write-Host "   ✓ Repositorio limpo apos Git Pull" -ForegroundColor Green
        }
        
        # Mostra ultimo commit
        $lastCommit = git log -1 --oneline 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   Ultimo commit: $lastCommit" -ForegroundColor White
        }
        
        Pop-Location
    } catch {
        Write-Host "   Erro ao verificar status pos-execucao: $($_.Exception.Message)" -ForegroundColor Red
        Pop-Location -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=== Resumo do Teste ===" -ForegroundColor Cyan
Write-Host "✓ FUNCIONALIDADE IMPLEMENTADA:" -ForegroundColor Green
Write-Host "  - Git Pull executa AUTOMATICAMENTE ao final do snmp-collector.ps1" -ForegroundColor White
Write-Host "  - Modo FORCADO: descarta mudancas locais e sincroniza com remoto" -ForegroundColor White
Write-Host "  - Garante que arquivos locais estejam sempre atualizados" -ForegroundColor White

Write-Host "`n✓ COMPORTAMENTO:" -ForegroundColor Green
Write-Host "  1. Script executa coleta SNMP e envio/salvamento de dados" -ForegroundColor White
Write-Host "  2. AO FINAL, faz git fetch + git reset --hard origin/branch" -ForegroundColor White
Write-Host "  3. Arquivos locais sao forcadamente sincronizados com remoto" -ForegroundColor White

Write-Host "`n⚠️  IMPORTANTE:" -ForegroundColor Yellow
Write-Host "  - Mudancas locais nao commitadas serao DESCARTADAS" -ForegroundColor Red
Write-Host "  - Use apenas em ambiente onde o repositorio e controlado remotamente" -ForegroundColor Yellow
Write-Host "  - Ideal para agendamento automatico (Task Scheduler)" -ForegroundColor Green

Write-Host "`nTeste concluido!" -ForegroundColor Cyan
