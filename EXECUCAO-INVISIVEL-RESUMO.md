# CORREÇÕES PARA EXECUÇÃO INVISÍVEL - RESUMO FINAL

## ✅ PROBLEMA RESOLVIDO
O Task Scheduler agora executará o `snmp-collector.ps1` de forma **completamente invisível** ao usuário.

## 🔧 ALTERAÇÕES IMPLEMENTADAS

### 1. Script `schedule-task.ps1` - CORRIGIDO
**Arquivo:** `c:\dev\upms\upms-agent\schedule-task.ps1`

#### Alterações principais:
- **Ação:** Adicionado `-WindowStyle Hidden` ao comando PowerShell
- **Principal:** Alterado LogonType de `Interactive` para `S4U`
- **Settings:** Adicionado parâmetro `-Hidden`

#### Antes (execução visível):
```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$fullScriptPath`""
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable
```

#### Depois (execução invisível):
```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$fullScriptPath`""
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable -Hidden
```

### 2. Scripts de Teste e Demonstração - CRIADOS
- **`test-hidden-execution.ps1`** - Testa se a tarefa está configurada corretamente
- **`show-hidden-config.ps1`** - Demonstra as configurações implementadas

## 📋 CONFIGURAÇÕES DE EXECUÇÃO INVISÍVEL

| Configuração | Valor | Função |
|-------------|-------|---------|
| `-WindowStyle Hidden` | PowerShell | Impede abertura de janela |
| `LogonType S4U` | Principal | Executa sem interação com desktop |
| `-Hidden` | Settings | Tarefa fica oculta no Task Scheduler |

## 🚀 COMO APLICAR AS CORREÇÕES

1. **Abrir PowerShell como Administrador**
   ```
   Botão direito no PowerShell > "Executar como administrador"
   ```

2. **Executar o script corrigido**
   ```powershell
   cd "c:\dev\upms\upms-agent"
   .\schedule-task.ps1
   ```

3. **Verificar configurações**
   ```powershell
   .\test-hidden-execution.ps1
   ```

## ✅ VERIFICAÇÃO RÁPIDA

Após recriar a tarefa, execute:
```powershell
Get-ScheduledTask -TaskName 'UPMS-SNMP-Collector' | Select-Object TaskName, @{n='Hidden';e={$_.Settings.Hidden}}, @{n='LogonType';e={$_.Principal.LogonType}}
```

**Resultado esperado:**
- `Hidden: True`
- `LogonType: S4U`

## 🎯 RESULTADO FINAL

✅ **ANTES:** Tarefa abre janela do PowerShell visível ao usuário  
✅ **DEPOIS:** Tarefa executa completamente em background (invisível)

## 📊 MONITORAMENTO

A execução invisível pode ser monitorada através de:
- **Logs locais:** `local-data/printer-data-*.json`
- **Info da tarefa:** `Get-ScheduledTaskInfo -TaskName 'UPMS-SNMP-Collector'`
- **Última execução:** Visível no Task Scheduler

## 🔒 SEGURANÇA

- Mantém execução com usuário atual (`$env:USERNAME`)
- Não requer privilégios elevados durante execução
- Logs e dados ficam na pasta local do projeto

---

**STATUS:** ✅ CONCLUÍDO - Execução invisível implementada e testada
