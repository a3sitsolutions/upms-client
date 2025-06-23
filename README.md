# UPMS Agent - Coletor SNMP com Controle Diário

Este script coleta dados de impressoras via SNMP e envia para a API do UPMS. Implementa controle diário para evitar envios duplicados, salvando dados localmente quando necessário e reenviando automaticamente em caso de falha.

## Funcionalidades

### 🔄 Controle Diário de Envios
- **1 envio por dia por impressora** - Evita envios duplicados
- Testa conectividade com o servidor antes de coletar dados
- Salva dados localmente quando servidor indisponível
- Reenvio automático de dados salvos até obter sucesso
- Histórico de envios bem-sucedidos para controle

### 📊 Dados Coletados
- Modelo da impressora
- Número de série
- Total de páginas impressas
- Data e hora da coleta
- **Data da coleta (campo `time`)** - Formato YYYY-MM-DD para a API

### 💾 Armazenamento Local Unificado
- Dados salvos em `local-data/local-data.json`
- Status de controle: `pending`, `sent`, `not_found`
- Formato JSON com timestamp e status de envio
- Histórico de envios para evitar duplicatas

### 🎯 Estratégia de Execução (a cada 1 hora)
1. **Verifica se já foi enviado hoje**: Se status = `sent` para a data atual, pula
2. **Verifica pendências**: Se há status = `pending` para hoje, aguarda reenvio
3. **Novo envio**: Se não há registro para hoje, tenta enviar
4. **Marca como enviado**: Em caso de sucesso, salva status = `sent`
5. **Retry automático**: Falhas ficam como `pending` para nova tentativa

## Status dos Dados

- **`pending`**: Dados pendentes, serão reenviados automaticamente
- **`sent`**: Dados enviados com sucesso, não serão reenviados
- **`not_found`**: Impressora não encontrada (404), não serão reenviados

## Modos de Execução

### Modo Produção (padrão)
```powershell
.\snmp-collector.ps1
```
- Coleta dados das impressoras (se não enviado hoje)
- Tenta enviar para API
- Salva localmente se servidor indisponível
- Retenta envio de dados salvos anteriormente

### Modo Teste
```powershell
.\snmp-collector.ps1 -TestMode
```
- Coleta dados das impressoras
- Exibe dados que seriam enviados
- **NÃO** envia para API nem salva localmente

### Modo Reenvio
```powershell
.\snmp-collector.ps1 -RetryOnly
```
- **NÃO** coleta novos dados
- Apenas tenta reenviar dados salvos localmente
- Útil para reenvio manual quando servidor volta a funcionar

## Agendamento Automático

### ⏰ Configuração com Task Scheduler
O script `schedule-task.ps1` configura execução automática a cada hora:

```powershell
# Executar como Administrador
.\schedule-task.ps1
```

**Configurações da tarefa:**
- Nome: "UPMS-SNMP-Collector"
- Intervalo: A cada 1 hora
- Executa mesmo com bateria
- Só executa se houver conexão de rede
- Inicia automaticamente após criação

### 📋 Gerenciamento de Tarefas

**Ver tarefas criadas:**
```powershell
Get-ScheduledTask -TaskName "UPMS-SNMP-Collector"
```

**Executar manualmente:**
```powershell
Start-ScheduledTask -TaskName "UPMS-SNMP-Collector"
```

**Remover tarefa:**
```powershell
.\schedule-task.ps1 -RemoveTask
```

**Configurar intervalo diferente:**
```powershell
.\schedule-task.ps1 -IntervalHours 2  # A cada 2 horas
```

## Scripts Auxiliares

### 🧪 Pré-teste de Dependências
```powershell
.\pre-test.ps1
```
- Verifica módulo `powershell-yaml`
- Verifica executável `curl.exe`
- Verifica executável `snmpget.exe`
- Testa conectividade com servidor usando `Test-NetConnection`

### 🧹 Limpeza de Dados Antigos
```powershell
.\cleanup-old-data.ps1
```
- Remove registros `sent` com mais de 30 dias
- Mantém todos os registros `pending` e `not_found`
- Exibe estatísticas dos dados mantidos

**Personalizar dias para manter:**
```powershell
.\cleanup-old-data.ps1 -DaysToKeep 60  # Mantém últimos 60 dias
```

## Estrutura dos Arquivos Locais

```json
[
  {
    "timestamp": "2025-06-22 14:30:45",
    "printerIP": "192.168.15.106",
    "model": "Brother NC-8300w",
    "serialNumber": "U63885F9N733180",
    "totalPrintedPages": 298935,
    "time": "2025-06-22",
    "apiEndpoint": "https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer",
    "status": "pending"
  }
]
```

### Campos dos Dados Locais

- **`timestamp`**: Data e hora completa da coleta (formato: "YYYY-MM-DD HH:mm:ss")
- **`time`**: Data da coleta no formato esperado pela API (formato: "YYYY-MM-DD")
- **`printerIP`**: Endereço IP da impressora
- **`model`**: Modelo da impressora obtido via SNMP
- **`serialNumber`**: Número de série da impressora
- **`totalPrintedPages`**: Total de páginas impressas
- **`apiEndpoint`**: URL da API para onde os dados devem ser enviados
- **`status`**: Status do envio ("pending" ou "sent")
- **`sentTimestamp`**: Data e hora do envio bem-sucedido (apenas quando status = "sent")

## Estrutura do Projeto

```
upms-agent/
├── snmp-collector.ps1          # Script principal de coleta
├── printers-config.yml         # Configuração das impressoras
├── schedule-task.ps1           # Script para agendamento automático
├── pre-test.ps1                # Script de pré-teste de dependências
├── cleanup-old-data.ps1        # Script para limpeza de dados antigos
├── migrate-local-data.ps1      # Script para migração de dados antigos
├── test-api.ps1                # Script para testar a API
├── identify-printers.ps1       # Script para identificar dados para cadastro
├── README.md                   # Este arquivo
├── TROUBLESHOOTING.md          # Guia rápido de solução de problemas
├── .gitignore                  # Ignora pasta local-data
├── local-data/                 # Dados salvos quando servidor indisponível
│   └── local-data.json         # Arquivo único com controle de status
├── curl/                       # Executáveis curl para Windows
│   ├── curl.exe
│   ├── curl-ca-bundle.crt
│   ├── libcurl-x64.dll
│   ├── LICENSE
│   └── README.md
└── snmp/                       # Executáveis SNMP para Windows
    ├── snmpget.exe
    ├── snmpwalk.exe
    └── outros executáveis...
```

## Fluxo de Funcionamento Diário

### 📅 Execução Automática (a cada hora)
```
08:00 → Script executa → Verifica: não enviado hoje → Coleta + Envia → Status: "sent"
09:00 → Script executa → Verifica: já enviado hoje → Pula
10:00 → Script executa → Verifica: já enviado hoje → Pula
...
23:00 → Script executa → Verifica: já enviado hoje → Pula

Dia seguinte:
08:00 → Script executa → Novo dia → Coleta + Envia → Status: "sent"
```

### 🔄 Cenário com Falha
```
08:00 → Script executa → Servidor OFF → Salva local → Status: "pending"
09:00 → Script executa → Verifica: pendente hoje → Tenta reenviar → Status: "sent"
10:00 → Script executa → Verifica: já enviado hoje → Pula
```

## Configuração

### Arquivo `printers-config.yml`
Configure as impressoras que serão monitoradas:

```yaml
printers:
  - model: "Brother NC-8300w"
    description: "Impressora multifuncional Brother NC-8300w"
    ip: "192.168.15.106"
    community: "public"
    oids:
      paginasImpressas:
        oid: "1.3.6.1.2.1.43.10.2.1.4.1.1"
        description: "Contador de páginas impressas"
      modeloImpressora:
        oid: "1.3.6.1.2.1.1.1.0"
        description: "Descrição do sistema/modelo"
      numeroSerie:
        oid: "1.3.6.1.2.1.43.5.1.1.17.1"
        description: "Número de série da impressora"
      nomeSistema:
        oid: "1.3.6.1.2.1.1.5.0"
        description: "Nome do sistema (sysName)"
```

### Endpoint Personalizado
```powershell
.\snmp-collector.ps1 -ApiEndpoint "https://seu-servidor.com/api/endpoint"
```

## Dependências

- **PowerShell 5.1+**
- **Módulo powershell-yaml** (instalado automaticamente)
- **curl.exe** (incluído na pasta `curl/`)
- **snmpget.exe** (incluído na pasta `snmp/`)

## Logs e Monitoramento

### Códigos de Status no Terminal
- 🟢 **Verde**: Operações bem-sucedidas
- 🟡 **Amarelo**: Avisos e dados simulados  
- 🔵 **Ciano**: Informações e dados salvos localmente
- 🔴 **Vermelho**: Erros e falhas

### Indicadores de Status Importantes

#### Conectividade do Servidor
```bash
✅ "Servidor acessível! (HTTP 200)"     # API funcionando
⚠️ "Servidor acessível! (HTTP 500)"     # Servidor OK, API com erro
❌ "Servidor inacessível ou sem conexão" # Sem conectividade
```

#### Status do SNMP
```bash
✅ "* SNMP funcionando!"                 # Dados reais da impressora
❌ "x SNMP não respondeu"                # Usando dados simulados
```

#### Status do Envio
```bash
✅ "Dados enviados com sucesso para API!"
💾 "Dados salvos localmente com sucesso!"
❌ "Erro da API: {...}"
```

### Relatório Final
Sempre exibe um resumo da execução:
```
=== RELATÓRIO FINAL ===
Total de impressoras processadas: 1
Envios bem-sucedidos para API: 0
Dados salvos localmente: 1
Falhas totais: 0

NOTA: Dados salvos localmente serão reenviados automaticamente
      na próxima execução quando o servidor estiver disponível.
```

### Monitoramento de Arquivos Locais
Verifique o arquivo local para ver dados salvos:
```powershell
# Ver conteúdo do arquivo local
Get-Content .\local-data\local-data.json | ConvertFrom-Json

# Filtrar apenas registros pendentes
$data = Get-Content .\local-data\local-data.json | ConvertFrom-Json
$data | Where-Object { $_.status -eq "pending" }

# Estatísticas dos dados
$data | Group-Object status | Select-Object Name, Count
```

## Instalação Rápida

### 1️⃣ **Verificar Dependências**
```powershell
.\pre-test.ps1
```

### 2️⃣ **Testar Coleta (Modo Teste)**
```powershell
.\snmp-collector.ps1 -TestMode
```

### 3️⃣ **Configurar Agendamento**
```powershell
# Executar como Administrador
.\schedule-task.ps1
```

### 4️⃣ **Testar Execução Manual**
```powershell
Start-ScheduledTask -TaskName "UPMS-SNMP-Collector"
```

### 5️⃣ **Manutenção (Opcional)**
```powershell
# Limpeza mensal de dados antigos
.\cleanup-old-data.ps1
```

## Automação

### Agendamento Automático
Use o script `schedule-task.ps1` para configurar agendamento automático:

```powershell
# Configura execução a cada hora (como Administrador)
.\schedule-task.ps1

# Configura execução a cada 30 minutos
.\schedule-task.ps1 -IntervalHours 0.5

# Remove agendamento
.\schedule-task.ps1 -RemoveTask
```

### Agendamento Manual com Task Scheduler
## Automação Completa

O sistema é totalmente automatizado após a configuração inicial:

### ⚙️ Configuração Automática via Task Scheduler
```powershell
# Executar como Administrador (uma única vez)
.\schedule-task.ps1
```

**Configuração automática:**
- ✅ Execução a cada 1 hora
- ✅ Inicia na próxima hora após criação
- ✅ Executa mesmo com bateria
- ✅ Só executa se houver rede
- ✅ Logs automáticos no Event Viewer

### 📋 Configuração Manual (Alternativa)
Para configurar manualmente no Agendador de Tarefas:

1. Abra o **Agendador de Tarefas**
2. Crie **Nova Tarefa**
3. **Ação**: Iniciar programa
4. **Programa**: `powershell.exe`
5. **Argumentos**: `-ExecutionPolicy Bypass -File "C:\caminho\para\snmp-collector.ps1"`
6. **Gatilho**: Repetir a cada 1 hora

### 🔄 Fluxo Automático Completo
```
Hora 08:00 → Task Scheduler → snmp-collector.ps1 → Verificação Git → Coleta + Envia → Status: "sent"
Hora 09:00 → Task Scheduler → snmp-collector.ps1 → Verificação Git → Já enviado hoje → Pula
Hora 10:00 → Task Scheduler → snmp-collector.ps1 → Verificação Git → Já enviado hoje → Pula
...
Dia seguinte → Novo ciclo completo
```

### 🔄 Verificação e Atualização Automática do Git

**O script automaticamente verifica e atualiza o repositório Git antes de cada execução principal:**

**Funcionalidades:**
- ✅ **Detecção automática** de repositório Git
- ✅ **Stash automático** de mudanças locais
- ✅ **Fetch e verificação** de atualizações remotas
- ✅ **Pull automático** se houver atualizações
- ✅ **Restauração** de mudanças locais após atualização
- ✅ **Reset forçado** em caso de conflitos
- ✅ **Fallback gracioso** se Git não estiver disponível

**Comportamento:**
1. **Mudanças locais**: Salva automaticamente com `git stash`
2. **Busca atualizações**: `git fetch origin`
3. **Compara versões**: Local vs. Remoto
4. **Atualiza se necessário**: `git pull` automático
5. **Restaura mudanças**: `git stash pop` das mudanças locais
6. **Continua execução**: Mesmo se houver problemas Git

**Casos especiais:**
- **Sem Git**: Continua execução normalmente com aviso
- **Sem repositório**: Pula verificação com aviso
- **Conflitos**: Tenta reset forçado se necessário
- **Falhas**: Continua com versão atual

### 🧹 Manutenção Automática (Opcional)
Configure limpeza automática de dados antigos:

```powershell
# Adicionar segunda tarefa para limpeza semanal
.\schedule-task.ps1 -TaskName "UPMS-Cleanup" -IntervalHours 168  # 7 dias
```

## Solução de Problemas

### Servidor Indisponível
- ✅ Dados são salvos automaticamente em `local-data/local-data.json`
- ✅ Reenvio automático na próxima execução
- ✅ Use `-RetryOnly` para reenvio manual

**Sintomas no log:**
```
Servidor inacessível ou sem conexão
Status: Servidor indisponível - salvando dados localmente
```

### API com Problemas (Erro 500/404)
- ✅ Servidor responde mas API retorna erro
- ✅ Dados salvos localmente para tentar depois
- ✅ Reenvio automático de dados antigos funciona
- ⚠️ Verificar logs da API no servidor
- 🔧 Possíveis causas: banco de dados offline, impressora não cadastrada, configuração do servidor

**Sintomas no log:**
```
Servidor acessível! (HTTP 404)
=== Tentando reenviar dados salvos localmente ===
Erro da API: {"status":500,"error":"Internal Server Error"}
Total tentativas: 4, Sucessos: 0, Falhas: 4
```

**Verificações recomendadas:**
1. Confirmar se impressora está cadastrada no sistema UPMS
2. Verificar logs do servidor backend
3. Testar API manualmente com `.\test-api.ps1`
4. Dados ficam preservados até problema ser resolvido

### Impressora Não Responde SNMP
- ✅ Usa dados simulados baseados no modelo
- ⚠️ Dados simulados são identificados no log
- 🔧 Verificar conectividade de rede com a impressora

**Sintomas no log:**
```
x SNMP não respondeu - usando dados simulados
```

### SNMP Funcionando Corretamente
- ✅ Dados reais coletados da impressora
- ✅ Páginas impressas atualizadas em tempo real

**Sintomas no log:**
```
* SNMP funcionando!
Páginas Impressas: 298937
```

### Erro de Permissões
- Execute PowerShell como Administrador
- Verifique permissões na pasta do projeto

### Módulo YAML Não Instala
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Install-Module -Name powershell-yaml -Force -Scope CurrentUser
```

## Formato da API

O script envia dados para sua API no seguinte formato JSON:

```json
{
  "model": "Brother NC-8300w",
  "serialNumber": "U63885F9N733180", 
  "totalPrintedPages": 298935,
  "time": "2025-06-22"
}
```

### Exemplo de curl para teste manual:
```bash
curl -X 'POST' \
  'http://localhost:8080/api/printer-history-public/by-printer' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "model": "HP LaserJet Pro MFP M428fdw",
  "serialNumber": "VN83K12345",
  "totalPrintedPages": 24580,
  "time": "2025-06-22"
}'
```

### Script de Teste da API
Use o script `test-api.ps1` para testar se sua API está funcionando corretamente:

```powershell
# Teste básico com dados padrão
.\test-api.ps1

# Teste com endpoint personalizado
.\test-api.ps1 -ApiEndpoint "http://localhost:8080/api/printer-history-public/by-printer"

# Teste com dados personalizados
.\test-api.ps1 -Model "Brother NC-8300w" -SerialNumber "U63885F9N733180" -TotalPages 299000 -Date "2025-06-22"
```

### Script de Identificação de Impressoras
Use o script `identify-printers.ps1` para obter os dados exatos que devem ser cadastrados no sistema UPMS:

```powershell
# Mostra dados de todas as impressoras configuradas
.\identify-printers.ps1

# Mostra apenas impressoras que ainda não funcionam
.\identify-printers.ps1 -ShowOnlyUnconfigured
```

Este script coleta dados via SNMP e mostra o modelo exato e número de série que devem ser utilizados no cadastro do sistema UPMS.

## Diagnóstico da API

### Verificando Status da API
Quando o servidor está acessível mas retorna erros, use estes comandos para diagnóstico:

```powershell
# Teste rápido de conectividade
.\test-api.ps1 -ApiEndpoint "https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer"

# Teste apenas conectividade (sem dados)
curl -I https://upms-backend.maranguape.a3sitsolutions.com.br
```

### Códigos de Erro da API

#### ✅ Sucesso (200-299)
```json
{
  "id": 123,
  "message": "Dados salvos com sucesso"
}
```

#### ⚠️ Erro do Cliente (400-499)
```json
{
  "status": 404,
  "error": "Not Found", 
  "message": "Impressora não encontrada"
}
```
**Ação**: Verificar se impressora está cadastrada no sistema.

#### ❌ Erro do Servidor (500-599)
```json
{
  "status": 500,
  "error": "Internal Server Error",
  "timestamp": "2025-06-23T00:28:37.684+00:00"
}
```
**Ação**: Problema no servidor. Dados serão salvos localmente e reenviados automaticamente.

### Solução para Erro 500
1. **Verificar logs do servidor backend**
2. **Confirmar se banco de dados está funcionando**
3. **Validar se impressora está cadastrada no sistema**
4. **Os dados ficam salvos localmente até API voltar a funcionar**

## Cenários de Execução

O script pode encontrar diferentes situações durante a execução:

### ✅ Cenário Ideal - Tudo Funcionando
```
Servidor acessível! (HTTP 200)
* SNMP funcionando!
Status: Dados enviados com sucesso para API!
```

### 🌐 Servidor Indisponível - Fallback Local
```
Servidor inacessível ou sem conexão
* SNMP funcionando!
Status: Servidor indisponível - salvando dados localmente
Status: Dados salvos localmente com sucesso!
```
**Resultado**: Dados preservados, serão reenviados automaticamente.

### ⚠️ API com Erro - Fallback Local
```
Servidor acessível! (HTTP 404/500)
=== Tentando reenviar dados salvos localmente ===
Erro da API: {"status":500,"error":"Internal Server Error"}
Status: Falha no reenvio
Resultado do reenvio: Total tentativas: 4, Sucessos: 0, Falhas: 4
```
**Resultado**: Servidor responde mas API tem problema interno. Dados permanecem salvos localmente para próxima tentativa.

### 📡 SNMP Indisponível - Dados Simulados
```
Servidor acessível! (HTTP 200)
x SNMP não respondeu - usando dados simulados
Status: Dados enviados com sucesso para API!
```
**Resultado**: Usa dados simulados baseados no modelo da impressora.

### 🔄 Reenvio Automático - Sucesso
```
Servidor acessível! (HTTP 200)
=== Tentando reenviar dados salvos localmente ===
Status: Reenviado com sucesso!
```
**Resultado**: Dados antigos foram enviados e marcados como "sent".

## 🎉 API Funcionando - Solução Encontrada

### ✅ Teste Manual Confirmado
A API está funcionando corretamente quando testada manualmente com curl:

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

### 🔍 Causa do Erro 500
O erro 500 indica que a impressora **deve estar cadastrada no sistema UPMS** com:
- **Modelo exato**: "Brother NC-8300w, Firmware Ver.X  ,MID 8C5-H27,FID 2"
- **Número de série**: "U63885F9N733180"

### ✅ Próximos Passos
1. **Cadastrar a impressora no sistema UPMS** com os dados exatos coletados via SNMP
2. **Executar o script novamente** - os 4 registros salvos serão enviados automaticamente
3. **Monitorar execuções futuras** - dados serão enviados em tempo real
