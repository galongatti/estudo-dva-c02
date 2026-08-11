# Serviços AWS — Referência Rápida para DVA-C02

## Lambda

**Limites importantes:**
- Timeout máximo: 15 minutos
- Memória: 128 MB – 10.240 MB (CPU escala proporcionalmente)
- Package (zip): 50 MB direto, 250 MB descomprimido, 10 GB via container image
- Variáveis de ambiente: 4 KB total
- /tmp storage: 512 MB (10.240 MB com efemeral storage configurado)
- Concorrência padrão por região: 1.000 (soft limit)

**Pegadinhas da prova:**
- Handler é executado a cada invocação; código fora do handler persiste na execução aquecida (use para connection pooling)
- Reserved concurrency = limite máximo; Provisioned concurrency = pré-aquecido (elimina cold start)
- Aliases apontam para versões; `$LATEST` não pode ter reserved concurrency
- DLQ funciona apenas para invocações assíncronas

**Triggers assíncronos:** S3, SNS, EventBridge → Lambda gerencia retry (2x) + DLQ  
**Triggers síncronos:** API Gateway, ALB, Cognito triggers → caller gerencia retry  
**Polling (stream):** SQS, DynamoDB Streams, Kinesis → Lambda faz polling, processa em batch

---

## DynamoDB

**Tipos de chave:**
- Partition Key (PK) apenas: tabela simples
- PK + Sort Key (SK): permite múltiplos itens com mesmo PK

**Índices:**
- LSI (Local Secondary Index): mesmo PK, SK diferente — criado apenas na criação da tabela
- GSI (Global Secondary Index): PK e SK diferentes — pode ser criado depois, tem capacidade própria

**Cálculo de capacidade:**
- 1 RCU = 1 leitura fortemente consistente de item até 4 KB (eventually consistent = 0,5 RCU)
- 1 WCU = 1 escrita de item até 1 KB

**Operações:**
- `GetItem` / `PutItem` / `DeleteItem` / `UpdateItem`: item único
- `BatchGetItem` (máx 100 itens, 16 MB) / `BatchWriteItem` (máx 25 itens, 16 MB)
- `Query`: por PK (obrigatório) + filtro de SK — eficiente
- `Scan`: varre a tabela inteira — caro, evitar em produção
- `TransactWriteItems` / `TransactGetItems`: até 25 itens, ACID

**Pegadinhas:**
- FilterExpression filtra APÓS leitura (consome RCU do resultado total antes do filtro)
- GSI não suporta leitura fortemente consistente
- Streams: OLD_IMAGE, NEW_IMAGE, NEW_AND_OLD_IMAGES, KEYS_ONLY

---

## SQS

**Standard vs FIFO:**
- Standard: throughput ilimitado, at-least-once, best-effort ordering
- FIFO: 300 TPS (3.000 com batching), exactly-once, ordem garantida por MessageGroupId

**Parâmetros importantes:**
- Visibility Timeout: tempo que mensagem fica invisível após recebida (padrão 30s, máx 12h)
- Message Retention: 1 min – 14 dias (padrão 4 dias)
- Max Message Size: 256 KB (usar S3 + pointer para mensagens maiores — SQS Extended Client)
- Long Polling: WaitTimeSeconds 1-20s — reduz chamadas vazias e custos
- Dead Letter Queue: após maxReceiveCount falhas, mensagem vai para DLQ

**Pegadinhas:**
- Visibility timeout muito curto → mensagem processada mais de uma vez
- Short polling pode retornar lista vazia mesmo com mensagens
- FIFO exige MessageGroupId; MessageDeduplicationId garante exactly-once (5 minutos)

---

## SNS

- Pub/Sub: 1 publisher, múltiplos subscribers (SQS, Lambda, HTTP, Email, SMS)
- Fan-out pattern: SNS → múltiplos SQS
- Message Filtering: SubscriptionFilterPolicy por atributos da mensagem
- FIFO Topics: integração com SQS FIFO apenas

---

## API Gateway

**Tipos:**
- REST API: completo, mais recursos, mais configurações
- HTTP API: mais simples, mais barato, menor latência (preferido para Lambda + JWT)
- WebSocket API: conexões persistentes, ideal para chat/real-time

**Integração Lambda:**
- Lambda Proxy: API Gateway passa evento completo, Lambda retorna statusCode + headers + body
- Lambda Custom: mapeamento de request/response via VTL templates

**Authorizers:**
- Lambda Authorizer TOKEN: recebe token (JWT/OAuth), retorna IAM policy
- Lambda Authorizer REQUEST: recebe headers/querystring/body completo
- Cognito User Pool Authorizer: valida JWT automaticamente

**Pegadinhas:**
- Stage variables: como variáveis de ambiente para o stage (útil para apontar para diferentes aliases Lambda)
- Throttling: 10.000 req/s por conta (burst 5.000) — configurável por stage/método

---

## Cognito

**User Pools:**
- Diretório de usuários gerenciado
- Retorna tokens JWT: ID Token (claims do usuário), Access Token (autorização), Refresh Token
- Triggers Lambda: Pre Sign-up, Post Confirmation, Pre Token Generation, etc.
- Hosted UI disponível out-of-the-box

**Identity Pools (Federated Identities):**
- Fornece credenciais AWS temporárias (via STS)
- Federar com: User Pools, Google, Facebook, SAML, OpenID Connect
- Fluxo: usuário autentica → troca token por credenciais AWS → acessa serviços diretamente

**Pegadinha clássica:**
- User Pool = autenticação (quem é o usuário)
- Identity Pool = autorização para recursos AWS (o que o usuário pode fazer)

---

## CloudFormation

**Estrutura do template (YAML/JSON):**
```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: ...
Parameters: {}      # inputs
Mappings: {}        # lookup tables
Conditions: {}      # lógica condicional
Resources: {}       # OBRIGATÓRIO
Outputs: {}         # valores exportados
```

**Funções importantes:**
- `Ref`: retorna valor de parâmetro ou ID físico de recurso
- `Fn::GetAtt`: retorna atributo de recurso (ex: ARN, DNS)
- `Fn::Sub`: substituição de string com variáveis
- `Fn::ImportValue`: importa output de outra stack

**Change Sets:** preview de mudanças antes de aplicar  
**Stack Policy:** protege recursos de atualização/deleção acidental  
**Drift Detection:** compara estado real vs template  
**StackSets:** deploy em múltiplas contas/regiões

---

## CodeDeploy

**appspec.yml (EC2/On-premises):**
```yaml
version: 0.0
os: linux
files:
  - source: /
    destination: /var/www/app
hooks:
  BeforeInstall:
    - location: scripts/install_dependencies.sh
  AfterInstall:
    - location: scripts/start_server.sh
  ApplicationStart:
    - location: scripts/validate.sh
  ValidateService:
    - location: scripts/health_check.sh
```

**Deployment Configurations:**
- `CodeDeployDefault.AllAtOnce`: todos de uma vez (maior risco)
- `CodeDeployDefault.HalfAtATime`: metade por vez
- `CodeDeployDefault.OneAtATime`: um por vez (mais seguro)
- Custom: define percentual mínimo de instâncias saudáveis

**Blue/Green:** provisiona novo ambiente, redireciona tráfego, termina antigo (rollback fácil)

---

## X-Ray

**Conceitos:**
- **Segment:** unidade de trabalho de um serviço (ex: uma Lambda invocation)
- **Subsegment:** chamada downstream dentro de um segment (ex: chamada ao DynamoDB)
- **Trace:** coleção de segments de uma requisição ponta a ponta
- **Annotations:** key-value indexados, usados em filtros e grupos (máx 50)
- **Metadata:** key-value não indexados, apenas para análise manual

**Sampling:** por padrão, 1 req/s + 5% do restante. Customizável via sampling rules.

**Pegadinha:** X-Ray Daemon deve estar rodando (Lambda o executa automaticamente quando X-Ray ativo; EC2 requer instalação manual)

---

## Elastic Beanstalk

**Deployment Policies:**
| Policy | Downtime | Rollback | Custo Extra |
|---|---|---|---|
| All at once | Sim | Manual re-deploy | Não |
| Rolling | Não | Manual re-deploy | Não |
| Rolling with additional batch | Não | Manual re-deploy | Sim (batch extra) |
| Immutable | Não | Terminar nova ASG | Sim |
| Blue/Green | Não | Swap URL de volta | Sim |

**Configuração via `.ebextensions/`:** arquivos YAML/JSON para customizar instâncias, instalar pacotes, configurar variáveis.

**Worker tier:** processa tarefas de uma fila SQS (ideal para processamento assíncrono/background jobs).

---

## Serviços em escopo frequentemente negligenciados

### Integração e orquestração
- **AppSync:** GraphQL gerenciado com integração a Lambda, DynamoDB e autorização via IAM/Cognito.
- **Step Functions:** orquestração de fluxos com retries, catches e estados de compensação.

### Deploy e gestão de configuração
- **AppConfig:** separação de configuração por ambiente, validação de configuração e rollout controlado.
- **ECR:** armazenamento de imagens para workloads em ECS/EKS/Lambda com imagem de contêiner.
- **CodeArtifact:** repositório gerenciado de dependências para builds reprodutíveis.

### Rede e entrega
- **CloudFront:** cache de conteúdo e redução de latência para APIs e assets estáticos.
- **Route 53:** roteamento DNS, health checks e failover básico.
- **ELB (ALB/NLB):** distribuição de tráfego e integração com aplicações containerizadas.

### Segurança e proteção de borda
- **WAF:** proteção de aplicações web com regras gerenciadas e customizadas.

### Armazenamento e analytics
- **EBS/EFS:** persistência para workloads em EC2/ECS, com diferenças de performance e compartilhamento.
- **Athena:** consultas SQL em dados no S3 para análise operacional e troubleshooting.
- **Kinesis/OpenSearch:** ingestão e análise de dados em tempo quase real.
