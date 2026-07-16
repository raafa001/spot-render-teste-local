# AIOps Agents - Documentação Técnica

> **PT-BR:** Agentes autônomos de AIOps para operações de TI usando LLMs gratuitos (Ollama local).
> **EN:** Autonomous AIOps agents for IT operations using free LLMs (local Ollama).

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Agentes Disponíveis](#agentes-disponíveis)
4. [Stack Tecnológica](#stack-tecnológica)
5. [Configuração](#configuração)
6. [Uso](#uso)
7. [Validação](#validação)
8. [Métricas](#métricas)
9. [Aprovação Humana](#aprova%C3%A7%C3%A3o-humana)
10. [Base de Conhecimento](#base-de-conhecimento)
11. [Solução de Problemas](#solu%C3%A7%C3%A3o-de-problemas)

---

## 🎯 Visão Geral

Os **AIOps Agents** são agentes autônomos que automatizam operações de TI usando Inteligência Artificial. Eles monitoram, detectam anomalias, geram documentação e auxiliam na resposta a incidentes.

### Objetivos

| Objetivo | Descrição |
|----------|-----------|
| **Autonomia** | Agentes operam automaticamente 24/7 |
| **Inteligência** | Usam LLM para análise e decisão |
| **Segurança** | Aprovação humana para ações críticas |
| **Aprendizado** | Aprendem com incidentes passados |
| **Zero Custo** | Usam Ollama local (sem API keys) |

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    AIOps Agents                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Monitor    │  │  Security   │  │  Documenter │         │
│  │  Agent      │  │  Scanner    │  │  Agent      │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐       │
│  │    Base     │  │   Base      │  │   Base      │       │
│  │    Agent    │  │   Agent     │  │   Agent     │       │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│         │                │                │                 │
│  ┌──────┴────────────────┴────────────────┴──────┐         │
│  │              Base Classes                        │         │
│  │  • lib/llm.py        (Ollama Client)           │         │
│  │  • lib/knowledge_base.py (Histórico)           │         │
│  │  • lib/approval_workflow.py (Aprovações)       │         │
│  │  • lib/notifications.py (Slack/PagerDuty)       │         │
│  └───────────────────────┬─────────────────────────┘         │
│                          │                                   │
│                    ┌─────┴─────┐                            │
│                    │   Ollama   │                            │
│                    │   LLM      │                            │
│                    │  (llama3.2)│                            │
│                    └───────────┘                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🤖 Agentes Disponíveis

### 1. SecurityScanner (Prioridade: 🔴 Alta)

**Objetivo:** Escaneia repositórios em busca de vulnerabilidades de segurança.

**O que monitora:**
- Segredos/credenciais vazados (gitleaks)
- Vulnerabilidades em dependências (npm audit, pip-audit)
- Misconfigurações IaC (checkov)
- Problemas SAST (semgrep)
- Vulnerabilidades em containers (trivy)

**Saída:**
- Relatório JSON em `security-reports/`
- Notificações via Slack (se configurado)

```bash
# Uso
python -m agents.main --agent security-scanner --repo /path/to/repo
```

---

### 2. Documenter (Prioridade: 🟡 Média)

**Objetivo:** Gera e atualiza documentação automaticamente.

**O que gera:**
- README.md (análise e atualização)
- Documentação de APIs
- Diagramas de arquitetura (Mermaid)
- Runbooks de workflows CI/CD

```bash
# Uso
python -m agents.main --agent documenter --repo /path/to/repo
```

---

### 3. MonitorAgent (Prioridade: 🔴 Alta)

**Objetivo:** Monitora métricas em tempo real e detecta anomalias.

**Métodos de detecção:**
- **3-Sigma:** Detecção estatística clássica
- **EWMA:** Exponential Weighted Moving Average
- **Isolation Forest:** Para padrões complexos (opcional)

**Métricas monitoradas:**
- CPU, Memória, Disco
- Latência de requisições
- Taxa de erros
- Tamanho de filas

```bash
# Iniciar monitoramento contínuo
python -m agents.main --agent monitor --action start

# Verificar status
python -m agents.main --agent monitor --action status

# Ver métricas
python -m agents.main --agent monitor --action check
```

---

### 4. RootCauseAnalyzer (Prioridade: 🔴 Alta)

**Objetivo:** Analisa incidentes e determina causa raiz.

**Metodologia:**
- **5 Whys:** Análise causal encadeada
- Correlação de eventos
- Timeline de alterações
- Busca em base de conhecimento

**Saída:**
- Postmortem automático em Markdown
- Action items SMART
- Medidas preventivas

```bash
# Uso
python -m agents.main --agent root-cause-analyzer \
    --incident '{"title": "High latency", "symptoms": ["p99 > 2s"]}'
```

---

### 5. AlertGenerator (Prioridade: 🟢 Baixa)

**Objetivo:** Gera regras de alertas otimizadas.

**O que gera:**
- Regras Prometheus
- Configurações Grafana
- Alertas PagerDuty

```bash
# Gerar alertas
python -m agents.main --agent alert-generator \
    --metrics cpu memory latency error_rate
```

---

### 6. CapacityPlanner (Prioridade: 🟢 Baixa)

**Objetivo:** Previsão de capacidade e custos.

**Funcionalidades:**
- Forecasting de uso de recursos
- Recomendações de right-sizing
- Estimativa de custos AWS

```bash
# Prever capacidade
python -m agents.main --agent capacity-planner \
    --action forecast --metric cpu_usage --horizon-days 30
```

---

### 7. IncidentResponder (Prioridade: 🟡 Média)

**Objetivo:** Resposta autônoma a incidentes.

**Playbooks integrados:**
- high_latency
- high_error_rate
- queue_backup
- resource_exhaustion

**⚠️ Ações destrutivas SEMPRE requerem aprovação humana.**

```bash
# Gerar plano de resposta
python -m agents.main --agent incident-responder \
    --incident '{"title": "High latency", "severity": "high"}'
```

---

## 💻 Stack Tecnológica

| Componente | Tecnologia | Custo |
|------------|------------|-------|
| **LLM** | Ollama + llama3.2 | $0 |
| **Linguagem** | Python 3.11+ | $0 |
| **Monitoring** | Statistical (3-sigma, EWMA) | $0 |
| **Notificações** | Slack webhook | $0 |
| **Storage** | Sistema de arquivos local | $0 |

### Dependências Python

```txt
# agents/requirements.txt
requests>=2.31.0
boto3>=1.34.0
```

### Modelos de LLM Suportados

| Modelo | Tamanho | Uso Recomendado |
|--------|---------|----------------|
| `llama3.2` | 2GB | Uso geral (padrão) |
| `llama3` | 8GB | Melhor qualidade |
| `mistral` | 4GB | Equilíbrio |
| `codellama` | 4GB | Análise de código |

---

## ⚙️ Configuração

### Variáveis de Ambiente

```bash
# Obrigatórias para LLM
export OLLAMA_BASE_URL=http://localhost:11434
export OLLAMA_MODEL=llama3.2

# Opcional - Notificações
export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Opcional - Diretórios
export AIOPS_DOCS_PATH=./docs
export AIOPS_SECURITY_REPORTS_PATH=./security-reports
```

### Arquivo .env.aiops

Criado automaticamente em `spot-render-teste-local/.env.aiops`:

```bash
# AIOps Agents Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2

# Notificações (opcional)
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Diretórios
AIOPS_DOCS_PATH=./docs
AIOPS_SECURITY_REPORTS_PATH=./security-reports
AIOPS_ARTIFACTS_PATH=./artifacts
```

---

## 🚀 Uso

### 1. Setup (primeira vez)

```bash
cd ~/git/spot-render-teste-local

# O setup-local.sh já chama o setup de AIOps automaticamente
bash setup-local.sh
```

### 2. Rodar um agente manualmente

```bash
cd ~/git/spot-render-teste-local

# Carregar variáveis
source .env.aiops

# Ir para diretório dos agents
cd ../spot-render/agents

# Ativar ambiente virtual
source venv/bin/activate

# Rodar security scanner
python -m agents.main --agent security-scanner --repo ~/git/spot-render-teste-local

# Rodar documenter
python -m agents.main --agent documenter --repo ~/git/spot-render-teste-local
```

### 3. Rodar em modo autônomo

```bash
cd ~/git/spot-render-teste-local

# Rodar loop autônomo (a cada 5 minutos)
bash scripts/run-autonomous.sh

# Ou rodar apenas um ciclo
bash scripts/run-autonomous.sh --once
```

### 4. Ver resultados

```bash
# Ver relatórios de segurança
ls -la ~/git/spot-render-teste-local/security-reports/

# Ver documentação gerada
ls -la ~/git/spot-render-teste-local/docs/

# Ver artefatos
ls -la ~/git/spot-render-teste-local/artifacts/
```

---

## ✅ Validação

### Validar que os agentes estão funcionando

```bash
cd ~/git/spot-render-teste-local

# 1. Verificar se Ollama está rodando
curl -s http://localhost:11434/api/version
# Esperado: {"version":"0.32.0"}

# 2. Verificar se modelo está disponível
cd ../spot-render/agents
source venv/bin/activate
ollama list
# Esperado: NAME               ID              SIZE      MODIFIED
#          llama3.2:latest    a80c4f17acd5    2.0 GB    ...

# 3. Testar LLM diretamente
python -c "
from lib.llm import get_llm
llm = get_llm()
print('LLM available:', llm.is_available())
response = llm.generate('What is 2+2?')
print('Response:', response)
"

# 4. Testar um agente
python -m agents.main --agent security-scanner --repo ~/git/spot-render-teste-local

# 5. Verificar saída
ls -la ~/git/spot-render-teste-local/security-reports/
```

### Checklist de Validação

| Item | Comando | Esperado |
|------|---------|----------|
| Ollama rodando | `curl localhost:11434/api/version` | `{"version":"..."}` |
| Modelo disponível | `ollama list` | `llama3.2` na lista |
| LLM responde | Teste Python | Responde corretamente |
| Security Scanner | `python -m agents.main --agent security-scanner` | Gera relatório |
| Relatório existe | `ls security-reports/` | Arquivo `.json` |

---

## 📊 Métricas

### Métricas de Execução dos Agentes

```bash
# Ver logs de execução
tail -f /tmp/aiops-*.log

# Ver último ciclo autônomo
cat /tmp/last-aiops-cycle.txt
```

### Métricas Monitoradas (MonitorAgent)

| Métrica | Descrição | Limiar Padrão |
|---------|-----------|---------------|
| `cpu_usage_percent` | Uso de CPU | 80% (warning), 95% (critical) |
| `memory_usage_percent` | Uso de memória | 85% (warning), 95% (critical) |
| `http_request_duration_seconds` | Latência HTTP | 1s (warning), 2s (critical) |
| `http_requests_total` (5xx) | Taxa de erros | 1% (warning), 5% (critical) |
| `job_queue_length` | Tamanho da fila | 100 (warning), 500 (critical) |

### Métricas de Security Scanner

```json
{
  "total_vulnerabilities": 0,
  "by_severity": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "scans": ["gitleaks", "dependency-scanner", "checkov", "semgrep", "trivy"]
}
```

---

## 👤 Aprovação Humana

### Ações que requerem aprovação

| Ação | Ambiente | Risco | Aprovação |
|------|----------|-------|-----------|
| `delete` | qualquer | CRITICAL | SEMPRE |
| `terminate` | qualquer | CRITICAL | SEMPRE |
| `drop` | qualquer | CRITICAL | SEMPRE |
| `deploy` | production | CRITICAL | SEMPRE |
| `restart` | qualquer | HIGH | SEMPRE |
| `rollback` | qualquer | HIGH | SEMPRE |
| `production_change` | qualquer | CRITICAL | SEMPRE |
| `security_change` | qualquer | CRITICAL | SEMPRE |

### Fluxo de Aprovação

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Agente     │────▶│   Verifica    │────▶│  Solicita    │
│   detecta    │     │   Risco       │     │  Aprovação   │
│   problema   │     │               │     │              │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                           ┌──────────────────────┘
                           ▼
                    ┌──────────────┐
                    │   Humano    │
                    │   aprova?   │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
       ┌──────────────┐          ┌──────────────┐
       │    SIM       │          │     NÃO      │
       │  Executa     │          │   Rejeita   │
       │  ação       │          │   Notifica   │
       └──────────────┘          └──────────────┘
```

---

## 🧠 Base de Conhecimento

Os agentes aprendem com incidentes passados armazenando dados em:

```
docs/
├── postmortems/     # Análises de incidentes
│   └── postmortem-INC-0001-20260716.md
├── incidents/       # Histórico de incidentes (JSON)
│   └── 20260716-143000.json
├── runbooks/        # Procedimentos operacionais
├── playbooks/       # Resposta a incidentes
└── security/        # Findings de segurança
```

### Buscar incidentes similares

```python
from lib.knowledge_base import get_knowledge_base

kb = get_knowledge_base()

# Encontrar incidentes similares
similar = kb.find_similar_incidents("high latency")
print(similar)

# Obter medidas preventivas
measures = kb.get_preventive_measures("database")
print(measures)
```

---

## 🔧 Solução de Problemas

### Ollama não está rodando

```bash
# Verificar status
ps aux | grep ollama

# Iniciar manualmente
ollama serve

# Ver logs
tail -f /tmp/ollama.log
```

### Modelo não encontrado

```bash
# Baixar modelo
ollama pull llama3.2

# Ver modelos instalados
ollama list
```

### Agente não responde LLM

```bash
# Testar conexão
curl http://localhost:11434/api/generate \
  -d '{"model":"llama3.2","prompt":"test"}'

# Verificar variáveis de ambiente
echo $OLLAMA_BASE_URL
echo $OLLAMA_MODEL
```

### Permissão negada em diretórios

```bash
# Corrigir permissões
chmod +x scripts/*.sh
chmod +x agents/*.sh

# Criar diretórios com permissão
mkdir -p docs/postmortems docs/runbooks security-reports artifacts
chmod -R 755 .
```

---

## 📁 Estrutura de Arquivos

```
spot-render-teste-local/
├── agents/                      # Symlink para spot-render/agents
├── .env.aiops                  # Variáveis de ambiente
├── scripts/
│   ├── setup-aiops.sh          # Setup dos agentes
│   ├── run-autonomous.sh       # Loop autônomo
│   └── cleanup.sh              # Limpeza
├── docs/
│   ├── postmortems/            # Análises de incidentes
│   ├── runbooks/               # Procedimentos
│   └── playbooks/              # Playbooks de resposta
├── security-reports/           # Relatórios de segurança
│   └── security-report-*.json
└── artifacts/                  # Artefatos dos agentes
```

---

## 📖 Referências

- [Documentação Ollama](https://github.com/ollama/ollama)
- [Llama3.2 Model Card](https://ollama.com/library/llama3.2)
- [AIOps Best Practices](./AIOPS_BEST_PRACTICES.md)

---

*Documento gerado automaticamente. Última atualização: 2026-07-16*
