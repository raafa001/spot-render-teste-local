#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Script de inicialização do LocalStack
# Cria as filas SQS e buckets S3 necessários para o Spot Render
# ──────────────────────────────────────────────────────────────────────────────

set -e

echo "[LocalStack Init] Aguardando serviços ficarem prontos..."
sleep 5

# ─── SQS Queues ───────────────────────────────────────────────────────────────

echo "[LocalStack Init] Criando fila principal de jobs..."
awslocal sqs create-queue \
    --queue-name spot-render-jobs \
    --attributes '{"VisibilityTimeout": "300", "MessageRetentionPeriod": "345600", "ReceiveMessageWaitTimeSeconds": "20"}'

echo "[LocalStack Init] Criando Dead Letter Queue..."
awslocal sqs create-queue \
    --queue-name spot-render-jobs-dlq \
    --attributes '{"MessageRetentionPeriod": "1209600", "ReceiveMessageWaitTimeSeconds": "20"}'

# Configurar redrive policy na fila principal
DLQ_ARN=$(awslocal sqs get-queue-attributes \
    --queue-url spot-render-jobs-dlq \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text)

awslocal sqs set-queue-attributes \
    --queue-url spot-render-jobs \
    --attributes '{"RedrivePolicy": "{\"deadLetterTargetArn\": \"'"$DLQ_ARN"'\", \"maxReceiveCount\": 3}"}'

echo "[LocalStack Init] Filas SQS criadas com sucesso!"

# ─── S3 Buckets ───────────────────────────────────────────────────────────────

echo "[LocalStack Init] Criando buckets S3..."
awslocal s3 mb s3://spot-render-assets --region us-east-1 || true
awslocal s3 mb s3://spot-render-renderlists --region us-east-1 || true
awslocal s3 mb s3://spot-render-output --region us-east-1 || true

echo "[LocalStack Init] Buckets S3 criados com sucesso!"

# ─── Secrets Manager ───────────────────────────────────────────────────────────

echo "[LocalStack Init] Criando secrets no Secrets Manager..."
awslocal secretsmanager create-secret \
    --name spot-render/database/credentials \
    --secret-string '{"username":"render_admin","password":"localdev123!","engine":"postgres","host":"postgres","port":5432,"dbname":"renderqueue"}' \
    --region us-east-1 || true

awslocal secretsmanager create-secret \
    --name spot-render/redis/credentials \
    --secret-string '{"host":"redis","port":6379,"password":"localdev123!"}' \
    --region us-east-1 || true

awslocal secretsmanager create-secret \
    --name spot-render/sqs/credentials \
    --secret-string '{"queue_url":"http://localstack:4566/000000000000/spot-render-jobs","dlq_url":"http://localstack:4566/000000000000/spot-render-jobs-dlq"}' \
    --region us-east-1 || true

echo "[LocalStack Init] Secrets Manager configurado!"

echo "[LocalStack Init] Inicialização concluída!"
