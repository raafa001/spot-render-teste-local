# spot-render-teste-local

> Ambiente de teste local para a plataforma Spot-Render com GPU rendering usando spot instances AWS.

## 🎯 Visão Geral

Este repositório contém a configuração para um ambiente de teste local completo, incluindo:

- **Kubernetes (Kind)** - Cluster local para desenvolvimento
- **API Backend** - FastAPI Python para gerenciamento de jobs
- **Portal Web** - Next.js React frontend
- **Argo Workflows** - Orquestrador de workflows de renderização
- **Observability** - Prometheus, Grafana, Loki
- **AIOps Agents** - Agentes autônomos de operações (24/7)

---

## 🚀 Quick Start

### 1. Setup Completo (tudo de uma vez)

```bash
cd ~/git/spot-render-teste-local

# Sobe o cluster, containers, e AIOps Agents
bash setup-local.sh
```

### 2. Verificar Status

```bash
# Ver pods Kubernetes
kubectl get pods -n spot-render

# Ver containers Docker
docker ps

# Ver AIOps Agents
curl -s http://localhost:11434/api/version
```

### 3. Acessar Serviços

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| Portal | http://spot-render.local | - |
| API | http://spot-render.local/api | - |
| PGAdmin | http://localhost:5050 | admin@spot-render.local / admin123! |
| Redis Commander | http://localhost:8081 | - |
| Grafana | kubectl port-forward | - |

---

## 🤖 AIOps Agents

Este ambiente inclui **AIOps Agents** que rodam autonomamente 24/7.

### Agentes Disponíveis

| Agente | O que faz |
|--------|-----------|
| **SecurityScanner** | Escaneia CVEs, secrets, IaC |
| **Documenter** | Gera/atualiza README e docs |
| **MonitorAgent** | Métricas e detecção de anomalias |
| **RootCauseAnalyzer** | Análise de causa raiz (5 Whys) |
| **IncidentResponder** | Playbooks de resposta |
| **AlertGenerator** | Gera regras Prometheus |
| **CapacityPlanner** | Forecasting de recursos |

### Custo: **$0/mês** (Usa Ollama local)

### Uso dos Agents

```bash
# Rodar um agente manualmente
cd ~/git/spot-render
source agents/venv/bin/activate
export OLLAMA_BASE_URL=http://localhost:11434
python -m agents.main --agent security-scanner --repo ~/git/spot-render-teste-local

# Rodar em loop autônomo (a cada 5 min)
cd ~/git/spot-render-teste-local
bash scripts/run-autonomous.sh
```

### Validar que está funcionando

```bash
# 1. Verificar Ollama
curl -s http://localhost:11434/api/version

# 2. Ver relatórios gerados
ls -la ~/git/spot-render-teste-local/security-reports/

# 3. Ver documentação gerada
ls -la ~/git/spot-render-teste-local/docs/
```

### 📖 Documentação Completa

Consulte **[docs/AIOPS_AGENTS.md](docs/AIOPS_AGENTS.md)** para documentação técnica detalhada.

---

## 📁 Estrutura de Diretórios

```
spot-render-teste-local/
├── agents/                      # Symlink para spot-render/agents
├── .env.aiops                   # Configuração AIOps
├── docs/                        # Documentação
│   ├── AIOPS_AGENTS.md         # Documentação completa dos agents
│   ├── postmortems/            # Análises de incidentes
│   ├── runbooks/               # Procedimentos operacionais
│   └── playbooks/              # Playbooks de resposta
├── security-reports/           # Relatórios de segurança
├── artifacts/                  # Artefatos dos agents
├── scripts/
│   ├── setup-local.sh          # Setup completo
│   ├── teardown-local.sh       # Cleanup completo
│   ├── setup-aiops.sh          # Setup AIOps
│   ├── run-autonomous.sh       # Loop autônomo
│   └── cleanup.sh              # Cleanup
├── k8s/                        # Manifests Kubernetes
├── docker-compose.local.yml     # Infraestrutura local
└── kind-config.yaml            # Configuração Kind
```

---

## 🔧 Scripts Principais

| Script | Descrição |
|---------|-----------|
| `setup-local.sh` | Sobe todo o ambiente (K8s + Docker + AIOps) |
| `teardown-local.sh` | Derruba todo o ambiente e limpa |
| `setup-aiops.sh` | Configura apenas os AIOps Agents |
| `run-autonomous.sh` | Inicia loop autônomo dos agents |
| `cleanup.sh` | Limpa recursos K8s e Docker |

---

## 📊 Outputs dos Agents

### Security Scanner
```
security-reports/
└── security-report-20260716-184427.json
```

### Documenter
```
docs/
├── README.md (atualizado)
├── api/ (se detectado API)
└── architecture/ (se detectado)
```

### Monitor
```
artifacts/
└── anomaly-*.json
```

---

## 👤 Aprovação Humana

**Ações críticas requerem aprovação humana:**

- `delete`, `drop`, `terminate` (SEMPRE)
- `deploy` em produção (SEMPRE)
- `restart`, `rollback` (SEMPRE)
- `production_change` (SEMPRE)

Os agents notificam via Slack (se configurado) e aguardam confirmação antes de executar ações críticas.

---

## 🔍 Troubleshooting

### Ollama não está rodando

```bash
# Verificar
ps aux | grep ollama

# Iniciar
ollama serve

# Ver logs
tail -f /tmp/ollama.log
```

### Agents não funcionam

```bash
# Verificar Python
cd ~/git/spot-render/agents
source venv/bin/activate

# Testar LLM
python -c "from lib.llm import get_llm; print(get_llm().is_available())"
```

### Ambiente não sobe

```bash
# Ver logs do Docker
docker compose -f docker-compose.local.yml logs

# Ver logs do K8s
kubectl get events -n spot-render
```

---

## 📚 Referências

- [AIOps Agents - Documentação Técnica](docs/AIOPS_AGENTS.md)
- [Spot-Render API](../spot-render-api)
- [Spot-Render Portal](../spot-render-portal)
- [Spot-Render Infra AWS](../spot-render-infra-aws)

---

## 📝 Licença

MIT
