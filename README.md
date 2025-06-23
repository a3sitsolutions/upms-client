# UPMS Agent - Coletor SNMP com Fallback Local

Este script coleta dados de impressoras via SNMP e envia para a API do UPMS. Quando não há conexão com o servidor, os dados são salvos localmente e reenviados automaticamente quando a conectividade é restaurada.

## Funcionalidades

### 🔄 Fallback Automático
- Testa conectividade com o servidor antes de coletar dados
- Salva dados localmente quando servidor indisponível
- Reenvio automático de dados salvos na próxima execução

### 📊 Dados Coletados
- Modelo da impressora
- Número de série
- Total de páginas impressas
- Data e hora da coleta

### 💾 Armazenamento Local
- Dados salvos em `local-data/printer-data-YYYY-MM-DD.json`
- Formato JSON com timestamp e status de envio
- Organização por data para facilitar manutenção

## Modos de Execução

### Modo Produção (padrão)
```powershell
.\snmp-collector.ps1
```
- Coleta dados das impressoras
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

### Endpoint Personalizado
```powershell
.\snmp-collector.ps1 -ApiEndpoint "https://seu-servidor.com/api/endpoint"
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
    "apiEndpoint": "https://upms-backend.maranguape.a3sitsolutions.com.br/api/printer-history-public/by-printer",
    "status": "pending"
  }
]
```

## Estrutura do Projeto

```
upms-agent/
├── snmp-collector.ps1          # Script principal de coleta
├── printers-config.yml         # Configuração das impressoras
├── schedule-task.ps1           # Script para agendamento automático
├── cleanup-local-data.ps1      # Script para limpeza de dados antigos
├── README.md                   # Este arquivo
├── .gitignore                  # Ignora pasta local-data
├── exemplo-dados-locais.json   # Exemplo da estrutura de dados locais
├── local-data/                 # Dados salvos quando servidor indisponível
│   └── printer-data-YYYY-MM-DD.json
├── curl/                       # Executáveis curl para Windows
│   ├── curl.exe
│   └── libcurl-x64.dll
└── snmp/                       # Executáveis SNMP para Windows
    ├── snmpget.exe
    └── outros executáveis...
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
        type: "Counter32"
      # ... outros OIDs
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

### Relatório Final
```
=== RELATÓRIO FINAL ===
Total de impressoras processadas: 1
Envios bem-sucedidos para API: 0
Dados salvos localmente: 1
Falhas totais: 0

NOTA: Dados salvos localmente serão reenviados automaticamente
      na próxima execução quando o servidor estiver disponível.
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
Para configurar manualmente:

1. Abra o **Agendador de Tarefas**
2. Crie **Nova Tarefa**
3. **Ação**: Iniciar programa
4. **Programa**: `powershell.exe`
5. **Argumentos**: `-ExecutionPolicy Bypass -File "C:\caminho\para\snmp-collector.ps1"`
6. **Gatilho**: Repetir a cada 1 hora

### Script de Reenvio Separado
Para reenvios mais frequentes de dados salvos:

```powershell
# Executa reenvio a cada 15 minutos
.\snmp-collector.ps1 -RetryOnly
```

### Limpeza de Dados Antigos
Use o script `cleanup-local-data.ps1` para remover dados antigos:

```powershell
# Simulação - mostra o que seria removido
.\cleanup-local-data.ps1 -WhatIf

# Remove dados mais antigos que 30 dias (padrão)
.\cleanup-local-data.ps1

# Remove dados mais antigos que 7 dias
.\cleanup-local-data.ps1 -DaysToKeep 7
```

## Solução de Problemas

### Servidor Indisponível
- ✅ Dados são salvos automaticamente em `local-data/`
- ✅ Reenvio automático na próxima execução
- ✅ Use `-RetryOnly` para reenvio manual

### Impressora Não Responde SNMP
- ✅ Usa dados simulados baseados no modelo
- ⚠️ Dados simulados são identificados no log

### Erro de Permissões
- Execute PowerShell como Administrador
- Verifique permissões na pasta do projeto

### Módulo YAML Não Instala
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Install-Module -Name powershell-yaml -Force -Scope CurrentUser
```
