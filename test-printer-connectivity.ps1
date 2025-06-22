# Script para diagnosticar conectividade com impressora
param(
    [string]$PrinterIP = "192.168.15.106"
)

Write-Host "=== Diagnóstico de Conectividade ===" -ForegroundColor Magenta
Write-Host "Testando IP: $PrinterIP" -ForegroundColor White

# Teste 1: Ping básico
Write-Host "`n1. Testando conectividade básica (ping)..." -ForegroundColor Cyan
try {
    $ping = Test-Connection -ComputerName $PrinterIP -Count 2 -Quiet
    if ($ping) {
        Write-Host "✓ Ping OK - Impressora responde na rede" -ForegroundColor Green
    } else {
        Write-Host "✗ Ping falhou - Impressora não responde" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Erro no ping: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste 2: Porta 161 (SNMP)
Write-Host "`n2. Testando porta SNMP (161)..." -ForegroundColor Cyan
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $tcpClient.BeginConnect($PrinterIP, 161, $null, $null)
    $wait = $asyncResult.AsyncWaitHandle.WaitOne(3000, $false)
    
    if ($wait) {
        $tcpClient.EndConnect($asyncResult)
        Write-Host "✓ Porta 161 aberta - SNMP pode estar disponível" -ForegroundColor Green
        $tcpClient.Close()
    } else {
        Write-Host "✗ Porta 161 fechada ou filtrada" -ForegroundColor Red
        $tcpClient.Close()
    }
} catch {
    Write-Host "✗ Erro ao testar porta 161: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste 3: Porta 80 (HTTP - interface web)
Write-Host "`n3. Testando interface web (porta 80)..." -ForegroundColor Cyan
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $tcpClient.BeginConnect($PrinterIP, 80, $null, $null)
    $wait = $asyncResult.AsyncWaitHandle.WaitOne(3000, $false)
    
    if ($wait) {
        $tcpClient.EndConnect($asyncResult)
        Write-Host "✓ Porta 80 aberta - Interface web disponível" -ForegroundColor Green
        Write-Host "  Acesse: http://$PrinterIP para configurar SNMP" -ForegroundColor Gray
        $tcpClient.Close()
    } else {
        Write-Host "✗ Porta 80 fechada" -ForegroundColor Red
        $tcpClient.Close()
    }
} catch {
    Write-Host "✗ Erro ao testar porta 80: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste 4: Porta 443 (HTTPS - interface web segura)
Write-Host "`n4. Testando interface web segura (porta 443)..." -ForegroundColor Cyan
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $tcpClient.BeginConnect($PrinterIP, 443, $null, $null)
    $wait = $asyncResult.AsyncWaitHandle.WaitOne(3000, $false)
    
    if ($wait) {
        $tcpClient.EndConnect($asyncResult)
        Write-Host "✓ Porta 443 aberta - Interface web segura disponível" -ForegroundColor Green
        Write-Host "  Acesse: https://$PrinterIP para configurar SNMP" -ForegroundColor Gray
        $tcpClient.Close()
    } else {
        Write-Host "✗ Porta 443 fechada" -ForegroundColor Red
        $tcpClient.Close()
    }
} catch {
    Write-Host "✗ Erro ao testar porta 443: $($_.Exception.Message)" -ForegroundColor Red
}

# Teste 5: SNMP usando executável local (se disponível)
$snmpgetPath = Join-Path $PSScriptRoot "snmp\snmpget.exe"
if (Test-Path $snmpgetPath) {
    Write-Host "`n5. Testando SNMP com executável local..." -ForegroundColor Cyan
    
    # Lista de OIDs comuns para testar
    $testOIDs = @{
        "1.3.6.1.2.1.1.1.0" = "Descrição do sistema"
        "1.3.6.1.2.1.1.5.0" = "Nome do sistema"
        "1.3.6.1.2.1.1.6.0" = "Localização do sistema"
    }
    
    foreach ($oid in $testOIDs.Keys) {
        Write-Host "  Testando $($testOIDs[$oid]) ($oid)..." -ForegroundColor Yellow
        
        $result = & $snmpgetPath -v2c -c public -t 2 -r 1 -On -Oe $PrinterIP $oid 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $result -and $result -notlike "*Timeout*") {
            Write-Host "  ✓ Resposta: $result" -ForegroundColor Green
            break
        } else {
            Write-Host "  ✗ Sem resposta" -ForegroundColor Red
        }
    }
} else {
    Write-Host "`n5. snmpget.exe não encontrado na pasta local" -ForegroundColor Yellow
}

Write-Host "`n=== Recomendações ===" -ForegroundColor Magenta

if ($ping) {
    Write-Host "✓ Impressora está na rede" -ForegroundColor Green
    Write-Host "Próximos passos:" -ForegroundColor White
    Write-Host "1. Acessar interface web da impressora (http://$PrinterIP)" -ForegroundColor Gray
    Write-Host "2. Procurar configurações de SNMP/Rede" -ForegroundColor Gray
    Write-Host "3. Habilitar SNMP se estiver desabilitado" -ForegroundColor Gray
    Write-Host "4. Verificar comunidade SNMP (geralmente 'public')" -ForegroundColor Gray
    Write-Host "5. Verificar se há restrições de IP/rede" -ForegroundColor Gray
} else {
    Write-Host "✗ Impressora não responde na rede" -ForegroundColor Red
    Write-Host "Verificar:" -ForegroundColor White
    Write-Host "1. Impressora está ligada?" -ForegroundColor Gray
    Write-Host "2. Cabo de rede conectado?" -ForegroundColor Gray
    Write-Host "3. IP correto? (verificar no painel da impressora)" -ForegroundColor Gray
    Write-Host "4. Mesma rede/VLAN do computador?" -ForegroundColor Gray
}

Write-Host "`n=== Finalizado ===" -ForegroundColor Magenta
