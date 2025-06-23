# Guia Rápido de Troubleshooting - UPMS Agent

## ✅ PROBLEMA RESOLVIDO: API Funcionando

### ✅ Descoberta:
A API está funcionando corretamente. O erro 500 ocorre porque **a impressora não está cadastrada no sistema UPMS**.

### ✅ Teste Manual Bem-sucedido:
```bash
curl -X 'POST' \
  'https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "model": "Brother NC-8300w, Firmware Ver.X  ,MID 8C5-H27,FID 2",
  "serialNumber": "U63885F9N733180",
  "totalPrintedPages": 24580,
  "time": "2025-06-22"
}'
```

### 🎯 Solução:
**Cadastrar a impressora no sistema UPMS** com os dados exatos:
- **Modelo**: "Brother NC-8300w, Firmware Ver.X  ,MID 8C5-H27,FID 2"
- **Número de série**: "U63885F9N733180"
- **IP**: 192.168.15.106

### 🚀 Após o Cadastro:
1. Execute o script novamente: `.\snmp-collector.ps1`
2. Os 4 registros salvos localmente serão enviados automaticamente
3. Futuras execuções funcionarão normalmente

## 🚨 Cenário Anterior: API retornando erro 500

### O que estava acontecendo:
- ✅ **Servidor acessível**: `upms-backend.maranguape.a3sitsolutions.com.br` responde
- ❌ **API rejeitando dados**: Impressora não cadastrada (erro 500) 
- ✅ **Dados preservados**: 4 registros salvos localmente aguardando reenvio
- ✅ **SNMP funcionando**: Coletando dados reais das impressoras

### Diagnóstico Rápido:

#### 1. Testar API manualmente:
```powershell
.\test-api.ps1 -ApiEndpoint "https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer"
```

#### 2. Verificar dados salvos:
```powershell
Get-Content .\local-data\printer-data-2025-06-22.json | ConvertFrom-Json | Format-Table
```

#### 3. Listar todos os dados pendentes:
```powershell
Get-ChildItem .\local-data\*.json | ForEach-Object { 
    Write-Host "Arquivo: $($_.Name)"
    (Get-Content $_.FullName | ConvertFrom-Json) | Where-Object {$_.status -eq "pending"} | Measure-Object | Select-Object Count
}
```

### Possíveis Causas do Erro 500:

1. **Impressora não cadastrada no sistema UPMS**
   - Modelo: "Brother NC-8300w, Firmware Ver.X ,MID 8C5-H27,FID 2"
   - Série: "U63885F9N733180"

2. **Problema no banco de dados do servidor**
   - Verificar logs do backend
   - Confirmar conectividade com BD

3. **Configuração da API**
   - Endpoint correto: `/api/printer-history-public/by-printer`
   - Método: POST
   - Headers: Content-Type: application/json

### O que o script está fazendo corretamente:

✅ **Detecta servidor online**: HTTP 404 indica que servidor responde
✅ **Tenta reenvio automático**: Processa 4 registros salvos
✅ **Preserva dados**: Mantém registros como "pending" 
✅ **Fallback funciona**: Salva novos dados localmente
✅ **Logs detalhados**: Mostra exatamente o erro da API

### Próximos Passos:

1. **Verificar no sistema UPMS** se a impressora está cadastrada:
   - Modelo: Brother NC-8300w
   - Número de série: U63885F9N733180

2. **Verificar logs do servidor backend** para detalhes do erro 500

3. **Aguardar correção da API** - os dados estão seguros e serão enviados automaticamente

4. **Monitorar execuções** - execute periodicamente para ver quando API voltar a funcionar

### Comandos de Monitoramento:

```powershell
# Execução normal (tenta reenviar dados + coleta novos)
.\snmp-collector.ps1

# Apenas reenvio de dados salvos
.\snmp-collector.ps1 -RetryOnly

# Modo teste (não salva nem envia)
.\snmp-collector.ps1 -TestMode
```

### Status Atual dos Dados:
- **Dados coletados**: ✅ 298935, 298937, 298941 páginas (crescimento normal)
- **Dados salvos localmente**: ✅ 4 registros pendentes
- **Perda de dados**: ❌ ZERO - tudo preservado
- **Próximo reenvio**: ✅ Automático na próxima execução
