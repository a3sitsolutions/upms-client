# GUIA COMPLETO: Como Varrer Todos os IPs

## 🚀 NOVA FUNCIONALIDADE: -ScanAll

### ✅ COMANDO MAIS SIMPLES (RECOMENDADO):
```powershell
.\scan-printer-oids.ps1 -ScanAll
```
- Detecta automaticamente sua rede local
- Varre todos os IPs da rede
- Processa TODAS as impressoras encontradas automaticamente
- Não pede para escolher - varre tudo!

### 🎯 OUTRAS OPÇÕES PARA VARRER TODOS OS IPs:

#### 1. Rede específica com asterisco:
```powershell
.\scan-printer-oids.ps1 -NetworkRange "192.168.1.*" -ScanAll
```

#### 2. Formato CIDR:
```powershell
.\scan-printer-oids.ps1 -NetworkRange "10.0.0.0/24" -ScanAll
```

#### 3. Range específico:
```powershell
.\scan-printer-oids.ps1 -NetworkRange "172.16.1.1-172.16.1.254" -ScanAll
```

### 🔧 COMBINAÇÕES ÚTEIS:

#### Varredura rápida de todas:
```powershell
.\scan-printer-oids.ps1 -ScanAll -QuickScan
```

#### Varredura completa com exportação:
```powershell
.\scan-printer-oids.ps1 -ScanAll -FullScan -ExportConfig
```

#### Varredura com arquivo de saída específico:
```powershell
.\scan-printer-oids.ps1 -ScanAll -ExportConfig -OutputFile "minha-config.json"
```

### 📊 DIFERENÇAS:

| Modo | Descrição | Interação |
|------|-----------|-----------|
| **Sem -ScanAll** | Você escolhe qual impressora varrer | Pede para selecionar |
| **Com -ScanAll** | Varre TODAS automaticamente | Automático |

### ⚡ EXEMPLOS PRÁTICOS:

1. **Scan rápido da rede local:**
   ```powershell
   .\scan-printer-oids.ps1 -ScanAll -QuickScan
   ```

2. **Scan completo com exportação:**
   ```powershell
   .\scan-printer-oids.ps1 -ScanAll -FullScan -ExportConfig
   ```

3. **Scan de rede específica:**
   ```powershell
   .\scan-printer-oids.ps1 -NetworkRange "192.168.1.*" -ScanAll
   ```

### 🎉 RESULTADO:
- O script encontra todas as impressoras na rede
- Varre automaticamente cada uma
- Gera configuração YAML para cada impressora
- Exporta tudo se `-ExportConfig` for usado

### 💡 DICA:
Use `-ScanAll` quando quiser processar todas as impressoras de uma só vez, 
sem interação manual!
