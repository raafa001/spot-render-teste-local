#!/usr/bin/env python3
"""
Spot Render - Autonomous AI Agent
Runs inside Kubernetes pods and uses Ollama for self-healing and issue resolution.
"""

import os
import sys
import json
import time
import logging
import urllib.request
import urllib.error
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("autonomous_agent")


class OllamaClient:
    def __init__(self, base_url: str, model: str):
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.timeout = 120

    def is_available(self) -> bool:
        try:
            req = urllib.request.Request(f"{self.base_url}/api/tags")
            with urllib.request.urlopen(req, timeout=5) as response:
                return response.status == 200
        except Exception as e:
            logger.error(f"Ollama not available: {e}")
            return False

    def chat(self, message: str, context: Optional[str] = None) -> str:
        system_prompt = """Você é o Spotinho, assistente de IA do Spot Render.

SUAS FUNÇÕES:
1. Analisar logs de erro e identificar causas raiz
2. Propor soluções de auto-correção (self-healing)
3. Executar comandos kubectl para diagnosticar e corrigir problemas
4. Monitorar métricas e detectar anomalias

REGRAS DE SEGURANÇA (NUNCA viole):
- Nunca exponha credenciais, senhas, tokens ou chaves
- Nunca execute comandos destrutivos sem confirmar o impacto
- Sempre prefira soluções não-destrutivas
- Documente todas as ações tomadas

Ao analisar problemas, responda NO FORMATO JSON:
{
    "diagnosis": "descrição do problema identificado",
    "cause": "causa raiz provável",
    "actions": [
        {"action": "comando ou ação específica", "reason": "por que esta ação"}
    ],
    "prevention": "como prevenir no futuro"
}"""

        messages = [
            {"role": "system", "content": system_prompt}
        ]

        if context:
            messages.append({"role": "system", "content": f"Contexto adicional:\n{context}"})

        messages.append({"role": "user", "content": message})

        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False
        }

        try:
            data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(
                f"{self.base_url}/api/chat",
                data=data,
                headers={'Content-Type': 'application/json'}
            )
            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                result = json.loads(response.read().decode('utf-8'))
                return result.get('message', {}).get('content', 'No response')
        except Exception as e:
            logger.error(f"Ollama chat error: {e}")
            return json.dumps({
                "diagnosis": f"Erro ao comunicar com Ollama: {e}",
                "cause": "Falha na comunicação",
                "actions": [],
                "prevention": "Verificar conectividade com Ollama"
            })


class KubernetesClient:
    def __init__(self):
        self.namespace = os.getenv("POD_NAMESPACE", "spot-render")

    def get_pods(self, label_selector: str = "") -> List[Dict]:
        try:
            import subprocess
            cmd = ["kubectl", "get", "pods", "-n", self.namespace, "-o", "json"]
            if label_selector:
                cmd.extend(["-l", label_selector])
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                data = json.loads(result.stdout)
                return data.get('items', [])
        except Exception as e:
            logger.error(f"Error getting pods: {e}")
        return []

    def get_pod_logs(self, pod_name: str, limit: int = 100) -> str:
        try:
            import subprocess
            result = subprocess.run(
                ["kubectl", "logs", "-n", self.namespace, pod_name, "--tail", str(limit)],
                capture_output=True, text=True, timeout=30
            )
            return result.stdout if result.returncode == 0 else ""
        except Exception as e:
            logger.error(f"Error getting pod logs: {e}")
            return ""

    def describe_pod(self, pod_name: str) -> str:
        try:
            import subprocess
            result = subprocess.run(
                ["kubectl", "describe", "pod", "-n", self.namespace, pod_name],
                capture_output=True, text=True, timeout=30
            )
            return result.stdout if result.returncode == 0 else ""
        except Exception as e:
            logger.error(f"Error describing pod: {e}")
            return ""

    def get_events(self, since_minutes: int = 30) -> str:
        try:
            import subprocess
            since = (datetime.now() - timedelta(minutes=since_minutes)).isoformat()
            result = subprocess.run(
                ["kubectl", "get", "events", "-n", self.namespace, "--since", since, "-o", "wide"],
                capture_output=True, text=True, timeout=30
            )
            return result.stdout if result.returncode == 0 else ""
        except Exception as e:
            logger.error(f"Error getting events: {e}")
            return ""

    def execute_command(self, command: List[str]) -> tuple:
        try:
            import subprocess
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            return result.stdout, result.stderr, result.returncode
        except Exception as e:
            return "", str(e), 1


class AutonomousAgent:
    def __init__(self):
        self.ollama_url = os.getenv("OLLAMA_BASE_URL", "http://ollama.spot-ai.svc.cluster.local:11434")
        self.ollama_model = os.getenv("OLLAMA_MODEL", "llama3.2:latest")
        self.interval = int(os.getenv("AGENT_INTERVAL_SECONDS", "300"))
        self.self_healing_enabled = os.getenv("SELF_HEALING_ENABLED", "true").lower() == "true"
        self.max_retries = int(os.getenv("MAX_RETRIES_PER_ISSUE", "3"))

        self.ollama = OllamaClient(self.ollama_url, self.ollama_model)
        self.k8s = KubernetesClient()

        self.issues_handled: Dict[str, int] = {}
        self.last_analysis: Optional[datetime] = None

    def check_ollama_health(self) -> bool:
        if not self.ollama.is_available():
            logger.warning("Ollama is not available!")
            return False
        logger.info("Ollama is healthy")
        return True

    def analyze_system_health(self) -> Dict[str, Any]:
        logger.info("Analyzing system health...")

        events = self.k8s.get_events(since_minutes=30)
        unhealthy_pods = []

        for pod in self.k8s.get_pods():
            phase = pod.get('status', {}).get('phase', '')
            if phase in ['Pending', 'Failed', 'Unknown']:
                unhealthy_pods.append({
                    'name': pod['metadata']['name'],
                    'phase': phase,
                    'reason': self._get_pod_issue(pod)
                })

        return {
            'timestamp': datetime.now().isoformat(),
            'unhealthy_pods': unhealthy_pods,
            'recent_events': events[:2000] if events else "",
            'ollama_available': self.ollama.is_available()
        }

    def _get_pod_issue(self, pod: Dict) -> str:
        status = pod.get('status', {})
        conditions = status.get('conditions', [])

        for cond in conditions:
            if cond.get('type') == 'Ready' and cond.get('status') != 'True':
                return f"NotReady: {cond.get('reason', 'unknown')}"

        container_statuses = status.get('containerStatuses', [])
        for cs in container_statuses:
            if cs.get('state', {}).get('waiting'):
                waiting = cs['state']['waiting']
                return f"Waiting: {waiting.get('reason', 'unknown')} - {waiting.get('message', '')}"

        return "Unknown"

    def diagnose_with_ai(self, health_report: Dict[str, Any]) -> str:
        prompt = f"""Analise o seguinte relatório de saúde do sistema e proponha ações de auto-correção:

Saúde do Sistema:
- Timestamp: {health_report['timestamp']}
- Pods não saudáveis: {json.dumps(health_report['unhealthy_pods'], indent=2)}

Eventos recentes (últimos 30 min):
{health_report['recent_events']}

Responda em JSON com diagnóstico e ações de correção."""

        logger.info("Sending diagnosis request to Ollama...")
        return self.ollama.chat(prompt)

    def execute_self_healing(self, diagnosis: Dict) -> bool:
        if not self.self_healing_enabled:
            logger.info("Self-healing is disabled")
            return False

        issue_key = diagnosis.get('diagnosis', 'unknown')
        retry_count = self.issues_handled.get(issue_key, 0)

        if retry_count >= self.max_retries:
            logger.warning(f"Issue already handled {self.max_retries} times, skipping: {issue_key}")
            return False

        actions = diagnosis.get('actions', [])
        executed = []

        for action in actions:
            action_text = action.get('action', '')
            reason = action.get('reason', '')

            logger.info(f"Executing action: {action_text} (reason: {reason})")

            if action_text.startswith('kubectl'):
                parts = action_text.split()
                stdout, stderr, code = self.k8s.execute_command(parts)
                if code == 0:
                    executed.append(f"SUCCESS: {action_text}")
                    logger.info(f"Action succeeded: {action_text}")
                else:
                    executed.append(f"FAILED: {action_text} - {stderr}")
                    logger.error(f"Action failed: {action_text} - {stderr}")
            elif action_text.startswith('#') or not action_text:
                continue
            else:
                logger.warning(f"Unknown action type: {action_text}")

        self.issues_handled[issue_key] = retry_count + 1
        return len(executed) > 0

    def run_cycle(self):
        logger.info("=" * 50)
        logger.info("Starting autonomous cycle")
        logger.info("=" * 50)

        if not self.check_ollama_health():
            logger.warning("Skipping cycle - Ollama not available")
            return

        health = self.analyze_system_health()
        logger.info(f"System health: {len(health['unhealthy_pods'])} unhealthy pods")

        if health['unhealthy_pods']:
            diagnosis_json = self.diagnose_with_ai(health)
            logger.info(f"AI Diagnosis: {diagnosis_json}")

            try:
                diagnosis = json.loads(diagnosis_json)
                self.execute_self_healing(diagnosis)
            except json.JSONDecodeError:
                logger.error("Failed to parse AI diagnosis as JSON")

        self.last_analysis = datetime.now()
        logger.info("Cycle complete")

    def run(self):
        logger.info(f"Starting Autonomous Agent")
        logger.info(f"Ollama: {self.ollama_url}")
        logger.info(f"Model: {self.ollama_model}")
        logger.info(f"Interval: {self.interval}s")
        logger.info(f"Self-healing: {self.self_healing_enabled}")

        while True:
            try:
                self.run_cycle()
            except Exception as e:
                logger.error(f"Error in cycle: {e}")

            logger.info(f"Sleeping for {self.interval} seconds...")
            time.sleep(self.interval)


def health_check():
    print("OK")
    sys.exit(0)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--health":
        health_check()

    agent = AutonomousAgent()
    agent.run()
