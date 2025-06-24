# SNMP Walk to YAML - Documentação

## Visão Geral

O script `snmp-walk-to-yaml.ps1` executa um SNMP walk completo em uma impressora ou dispositivo de rede e salva todos os dados coletados em formato YAML estruturado na pasta `local-mibs`. O arquivo é nomeado automaticamente com base no modelo da impressora detectado.

## Funcionalidades

- **Identificação automática do dispositivo**: Detecta modelo, nome e descrição da impressora
- **SNMP walk completo**: Coleta todos os OIDs disponíveis a partir de um OID base
- **Exportação YAML estruturada**: Salva dados em formato legível e organizados
- **Nomenclatura inteligente**: Nome do arquivo baseado no modelo da impressora
- **Configuração flexível**: Parâmetros personalizáveis para diferentes cenários

## Parâmetros

### Obrigatórios
- **`-IP`**: Endereço IP do dispositivo alvo

### Opcionais
- **`-Community`**: Community SNMP (padrão: "public")
- **`-TimeoutSeconds`**: Timeout em segundos para operações SNMP (padrão: 2)
- **`-BaseOID`**: OID base para o walk (padrão: "1.3.6.1.2.1")
- **`-OutputDir`**: Diretório de saída (padrão: ".\local-mibs")

## Exemplos de Uso

### Uso básico
```powershell
.\snmp-walk-to-yaml.ps1 -IP "192.168.1.100"
```

### Com parâmetros personalizados
```powershell
.\snmp-walk-to-yaml.ps1 -IP "192.168.1.100" -Community "private" -TimeoutSeconds 5
```

### Walk específico de impressoras (OID 43)
```powershell
.\snmp-walk-to-yaml.ps1 -IP "192.168.1.100" -BaseOID "1.3.6.1.2.1.43"
```

### Diretório de saída personalizado
```powershell
.\snmp-walk-to-yaml.ps1 -IP "192.168.1.100" -OutputDir ".\custom-mibs"
```

## Estrutura do Arquivo YAML Gerado

```yaml
# SNMP Walk Results
# Generated on: 2025-06-24 17:13:50

device_info:
  ip: '192.168.1.100'
  model: 'HP LaserJet Pro M404dn'
  name: 'PRINTER-SALA-01'
  description: 'HP LaserJet Pro M404dn'

snmp_data:
  '1.3.6.1.2.1.1.1.0':
    type: 'STRING'
    value: 'HP LaserJet Pro M404dn'
  '1.3.6.1.2.1.1.5.0':
    type: 'STRING'
    value: 'PRINTER-SALA-01'
  # ... outros OIDs
```

## OIDs Importantes para Impressoras

### Informações Básicas
- **1.3.6.1.2.1.1.1.0**: Descrição do sistema
- **1.3.6.1.2.1.1.5.0**: Nome do sistema
- **1.3.6.1.2.1.25.3.2.1.3.1**: Modelo da impressora

### Impressoras (OID Base: 1.3.6.1.2.1.43)
- **1.3.6.1.2.1.43.5.1.1.16.1**: Status da impressora
- **1.3.6.1.2.1.43.10.2.1.4.1.1**: Nível de toner/tinta
- **1.3.6.1.2.1.43.11.1.1.6.1.1**: Contadores de página
- **1.3.6.1.2.1.43.16.5.1.2.1.1**: Informações de papel

## Fluxo de Execução

1. **Validação**: Verifica se os executáveis SNMP estão disponíveis
2. **Criação de diretório**: Cria o diretório de saída se necessário
3. **Identificação do dispositivo**: Coleta informações básicas (modelo, nome, descrição)
4. **SNMP Walk**: Executa walk completo a partir do OID base
5. **Conversão**: Transforma dados SNMP em formato YAML estruturado
6. **Nomenclatura**: Gera nome de arquivo baseado no modelo da impressora
7. **Salvamento**: Salva arquivo YAML no diretório especificado

## Nomenclatura de Arquivos

O script gera nomes de arquivo seguros baseados no modelo da impressora:

- **Modelo detectado**: `HP_LaserJet_Pro_M404dn.yml`
- **Modelo com caracteres especiais**: `Canon_PIXMA_G3010_WiFi.yml`
- **Modelo desconhecido**: `Device_192_168_1_100.yml` (baseado no IP)

## Tratamento de Erros

- **Timeout SNMP**: Exibe erro claro e código de saída
- **Dispositivo não acessível**: Informa sobre falha de conectividade
- **Executáveis ausentes**: Verifica presença de snmpget.exe e snmpwalk.exe
- **Permissões de arquivo**: Trata erros de escrita no diretório de saída

## Requisitos

- **Executáveis SNMP**: `snmp\snmpget.exe` e `snmp\snmpwalk.exe`
- **PowerShell**: Versão 5.1 ou superior
- **Conectividade**: Acesso SNMP ao dispositivo alvo na porta 161/UDP
- **Permissões**: Escrita no diretório de saída

## Integração com Outros Scripts

Este script pode ser usado em conjunto com:

- **`scan-printer-oids.ps1`**: Para descobrir impressoras antes do walk
- **`snmp-collector.ps1`**: Para coleta contínua de dados
- **Scripts de análise customizados**: Para processar os arquivos YAML gerados

## Troubleshooting

### Timeout ou "No Response"
- Verificar conectividade de rede
- Testar community SNMP diferente
- Aumentar o valor de TimeoutSeconds
- Verificar se o dispositivo tem SNMP habilitado

### Executáveis não encontrados
```
snmpget.exe não encontrado em .\snmp\
```
- Verificar se a pasta `snmp\` existe
- Confirmar presença dos executáveis necessários

### Modelo não detectado
- O arquivo será nomeado com base no IP
- Verificar se o dispositivo responde aos OIDs de identificação
- Tentar OIDs específicos do fabricante

## Performance

- **Dispositivos pequenos**: 1-2 segundos para walk básico
- **Dispositivos complexos**: 10-30 segundos para walk completo
- **Timeouts recomendados**: 2-5 segundos dependendo da rede
- **Tamanho típico de arquivo**: 5-50 KB dependendo do dispositivo
