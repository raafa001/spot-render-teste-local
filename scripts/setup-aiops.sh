#!/usr/bin/env bash
# setup-aiops.sh - Setup AIOps Agents para spot-render-teste-local
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
AGENTS_DIR="$REPO_ROOT/../spot-render/agents"

function info() { echo "[+] $1"; }
function warn() { echo "[!] $1"; }
function info_aiops() { echo "  🤖 $1"; }

info "=========================================="
info "  AIOps Agents Setup"
info "=========================================="

# ─── Verificar e instalar Ollama ───────────────────────────────────────────────
setup_ollama() {
    info "Verificando Ollama..."

    if curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
        info "  ✓ Ollama já está rodando"
        OLLAMA_RUNNING=true
    else
        info "  Instalando e iniciando Ollama..."

        # Detectar SO
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew > /dev/null 2>&1; then
                brew install ollama
            else
                warn "No macOS, instale Ollama manualmente: https://ollama.com/download"
            fi
        else
            # Linux - baixar binário
            local OLLAMA_VERSION="v0.32.0"
            local INSTALL_DIR="$HOME/bin"

            mkdir -p "$INSTALL_DIR"

            if ! command -v ollama > /dev/null 2>&1; then
                info "  Baixando Ollama..."
                curl -fsSL "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" -o /tmp/ollama.tar.zst 2>/dev/null || \
                curl -fsSL "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64" -o "$INSTALL_DIR/ollama"

                if [[ -f "$INSTALL_DIR/ollama" ]]; then
                    chmod +x "$INSTALL_DIR/ollama"
                    info "  ✓ Ollama instalado em $INSTALL_DIR/ollama"
                fi
            fi
        fi

        # Tentar iniciar Ollama
        if command -v ollama > /dev/null 2>&1; then
            export PATH="$HOME/bin:$PATH"
            nohup ollama serve > /tmp/ollama.log 2>&1 &
            sleep 3

            if curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
                info "  ✓ Ollama iniciado com sucesso"
                OLLAMA_RUNNING=true
            else
                warn "  ✗ Não foi possível iniciar Ollama"
                OLLAMA_RUNNING=false
            fi
        else
            warn "  ✗ Ollama não encontrado"
            OLLAMA_RUNNING=false
        fi
    fi
}

# ─── Baixar modelo LLM ────────────────────────────────────────────────────────
setup_model() {
    if [[ "$OLLAMA_RUNNING" != "true" ]]; then
        warn "  Pulando download do modelo (Ollama não está rodando)"
        return
    fi

    info "Verificando modelo LLM..."

    export PATH="$HOME/bin:$PATH"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$HOME/.ollama/lib"

    if ollama list 2>/dev/null | grep -q "llama3.2"; then
        info "  ✓ Modelo llama3.2 já está disponível"
    else
        info "  Baixando modelo llama3.2 (isso pode levar alguns minutos)..."
        ollama pull llama3.2
        info "  ✓ Modelo baixado"
    fi
}

# ─── Setup Python environment ─────────────────────────────────────────────────
setup_python() {
    info "Configurando ambiente Python..."

    if [[ ! -d "$AGENTS_DIR" ]]; then
        warn "  Diretório de agents não encontrado: $AGENTS_DIR"
        return
    fi

    cd "$AGENTS_DIR"

    # Criar venv se não existir
    if [[ ! -d "venv" ]]; then
        info "  Criando ambiente virtual..."
        python3 -m venv venv
    fi

    # Ativar e instalar dependências
    source venv/bin/activate
    pip install -q -r requirements.txt 2>/dev/null || pip install -q requests boto3

    info "  ✓ Ambiente Python configurado"
}

# ─── Criar diretórios e symlinks ─────────────────────────────────────────────
setup_directories() {
    info "Criando estrutura de diretórios..."

    # Diretórios de documentação
    mkdir -p "$REPO_ROOT/docs/postmortems"
    mkdir -p "$REPO_ROOT/docs/runbooks"
    mkdir -p "$REPO_ROOT/docs/playbooks"
    mkdir -p "$REPO_ROOT/docs/security"
    mkdir -p "$REPO_ROOT/artifacts"
    mkdir -p "$REPO_ROOT/security-reports"

    # Symlink para agents se não existir
    if [[ ! -e "$REPO_ROOT/agents" ]]; then
        ln -s "$AGENTS_DIR" "$REPO_ROOT/agents"
        info "  ✓ Symlink para agents criado"
    else
        info "  ✓ Symlink para agents já existe"
    fi

    # Permissões
    chmod +x "$REPO_ROOT/scripts/setup-aiops.sh" 2>/dev/null || true
    chmod +x "$REPO_ROOT/scripts/run-autonomous.sh" 2>/dev/null || true

    info "  ✓ Diretórios criados"
}

# ─── Setup variáveis de ambiente ─────────────────────────────────────────────
setup_env() {
    info "Configurando variáveis de ambiente..."

    # Criar .env para AIOps se não existir
    local ENV_FILE="$REPO_ROOT/.env.aiops"
    if [[ ! -f "$ENV_FILE" ]]; then
        cat <<EOF > "$ENV_FILE"
# AIOps Agents Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2

# Notificações (opcional)
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Diretórios
AIOPS_DOCS_PATH=$REPO_ROOT/docs
AIOPS_SECURITY_REPORTS_PATH=$REPO_ROOT/security-reports
AIOPS_ARTIFACTS_PATH=$REPO_ROOT/artifacts
EOF
        info "  ✓ Arquivo .env.aiops criado"
    else
        info "  ✓ Arquivo .env.aiops já existe"
    fi
}

# ─── Testar agente ────────────────────────────────────────────────────────────
test_agent() {
    if [[ "$OLLAMA_RUNNING" != "true" ]]; then
        warn "  Pulando teste (Ollama não está rodando)"
        return
    fi

    info "Testando agente..."

    cd "$AGENTS_DIR"
    source venv/bin/activate
    export PYTHONPATH="$AGENTS_DIR:$PYTHONPATH"
    export OLLAMA_BASE_URL=http://localhost:11434
    export OLLAMA_MODEL=llama3.2

    # Teste simples
    if python -c "from lib.llm import get_llm; llm = get_llm(); print('LLM OK' if llm.is_available() else 'LLM Error')" 2>/dev/null; then
        info "  ✓ LLM configurado corretamente"
    else
        warn "  ✗ Problema no LLM (será corrigido automaticamente)"
    fi
}

# ─── Execução principal ────────────────────────────────────────────────────────
main() {
    setup_ollama
    setup_model
    setup_python
    setup_directories
    setup_env
    test_agent

    echo ""
    info "=========================================="
    info "  ✅ AIOps Agents Setup Completo!"
    info "=========================================="
    echo ""
    info "Para usar os agentes:"
    echo ""
    info "  1. Carregar variáveis de ambiente:"
    info "     source $REPO_ROOT/.env.aiops"
    echo ""
    info "  2. Rodar um agente manualmente:"
    info "     cd $AGENTS_DIR"
    info "     source venv/bin/activate"
    info "     python -m agents.main --agent security-scanner --repo $REPO_ROOT"
    echo ""
    info "  3. Rodar em modo autônomo (loop):"
    info "     cd $REPO_ROOT"
    info "     bash scripts/run-autonomous.sh"
    echo ""
    info "  4. Ver relatórios gerados:"
    info "     ls $REPO_ROOT/security-reports/"
    echo ""
    info "=========================================="
}

main "$@"
