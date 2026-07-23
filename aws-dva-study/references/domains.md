# Domínios DVA-C02 — Mapeamento Detalhado

## Domínio 1: Desenvolvimento com Serviços AWS (32%)

### Tópicos principais
- **Lambda:** handler, event sources (S3, SQS, DynamoDB Streams, API Gateway, EventBridge), environment variables, layers, versioning & aliases, concurrency (reserved vs provisioned), cold start, execution role, limits (timeout 15min, memory 128MB–10GB, package 50MB zipped / 250MB unzipped)
- **API Gateway:** REST vs HTTP vs WebSocket APIs, integração com Lambda (proxy vs custom), stages, deployment, throttling, caching, CORS, authorizers (Lambda authorizer, Cognito)
- **DynamoDB:** partition key vs sort key, LSI vs GSI, Scan vs Query, ProjectionExpression, FilterExpression, BatchGetItem/BatchWriteItem, TransactWriteItems, Streams, TTL, on-demand vs provisioned, DAX
- **S3:** eventos (triggers para Lambda/SQS/SNS), presigned URLs (GetObject/PutObject), multipart upload, lifecycle rules, versioning, encriptação (SSE-S3, SSE-KMS, SSE-C, client-side), replication
- **SQS/SNS/EventBridge:** padrões de integração, fan-out pattern, dead-letter queues, visibility timeout, long polling, FIFO ordering, deduplication
- **Step Functions:** Express vs Standard, estados (Task, Choice, Wait, Parallel, Map), integração com Lambda e outros serviços

### Conceitos teóricos cobrados
- Idempotência e at-least-once delivery
- Eventual consistency vs strong consistency
- Retry strategies e exponential backoff
- Event-driven architecture patterns

---

## Domínio 2: Segurança (26%)

### Tópicos principais
- **IAM:** policies (identity-based vs resource-based), roles, STS (AssumeRole, AssumeRoleWithWebIdentity), permission boundaries, service-linked roles
- **Cognito User Pools:** sign-up/sign-in, JWT tokens (ID token, Access token, Refresh token), triggers Lambda, Hosted UI
- **Cognito Identity Pools:** federação com User Pools ou provedores externos (Google, SAML), credentials temporárias via STS
- **KMS:** CMK (Customer Managed Key), envelope encryption, Decrypt/Encrypt/GenerateDataKey APIs, key policies
- **Secrets Manager vs SSM Parameter Store:** quando usar cada um, rotação automática, integração com Lambda e RDS
- **S3 Bucket Policies e ACLs:** Block Public Access, presigned URLs
- **API Gateway Authorizers:** Lambda authorizer (TOKEN vs REQUEST), Cognito User Pool authorizer

### Conceitos teóricos cobrados
- Princípio do menor privilégio
- Autenticação vs Autorização
- Tokens JWT: estrutura e validação
- Encryption at rest vs encryption in transit

---

## Domínio 3: Deploy (24%)

### Tópicos principais
- **Elastic Beanstalk:** plataformas suportadas, deployment policies (All at once, Rolling, Rolling with additional batch, Immutable, Blue/Green), .ebextensions, configuração de ambiente, worker tier
- **CodeCommit:** repositório Git gerenciado, triggers, notificações
- **CodeBuild:** buildspec.yml (phases: install, pre_build, build, post_build), artifacts, cache, variáveis de ambiente
- **CodeDeploy:** appspec.yml, deployment types (In-Place, Blue/Green), deployment configurations (OneAtATime, HalfAtATime, AllAtOnce), hooks de lifecycle (BeforeInstall, AfterInstall, ApplicationStart, ValidateService)
- **CodePipeline:** stages e actions, integração com CodeCommit/GitHub/S3, approval actions, integração com CodeBuild e CodeDeploy
- **CloudFormation:** templates (Resources obrigatório), parâmetros, outputs, Fn::Sub, Fn::GetAtt, Ref, mappings, conditions, change sets, drift detection, stack policies, StackSets, nested stacks
- **SAM (Serverless Application Model):** extensão do CloudFormation, recursos SAM (AWS::Serverless::Function, Api, SimpleTable), `sam build` / `sam deploy`
- **CDK:** conceitos básicos (constructs, stacks, apps) — geralmente questões conceituais

### Conceitos teóricos cobrados
- Blue/Green vs Canary vs Rolling deployments
- Rollback strategies
- Infrastructure as Code princípios
- CI/CD pipeline design

---

## Domínio 4: Solução de Problemas e Otimização (18%)

### Tópicos principais
- **CloudWatch:** métricas customizadas (PutMetricData), log groups/streams, metric filters, alarms (estados: OK, ALARM, INSUFFICIENT_DATA), CloudWatch Insights (sintaxe de queries), Embedded Metric Format
- **X-Ray:** SDK instrumentation, daemon, segments e subsegments, annotations vs metadata, sampling rules, service map, grupos, GetTraceSummaries API
- **CloudTrail:** log de chamadas de API, integração com S3 e CloudWatch Logs, event history, data events vs management events
- **Lambda troubleshooting:** timeout, memory, concurrency throttling (429), cold start, function URL
- **DynamoDB troubleshooting:** hot partitions, ProvisionedThroughputExceededException, WCU/RCU cálculo
- **SQS troubleshooting:** mensagens na DLQ, visibility timeout muito curto, duplicate processing

### Conceitos teóricos cobrados
- Cálculo de RCU/WCU no DynamoDB
- Lambda concurrency limits e throttling
- Estratégias de cache (TTL, invalidação)
- Performance optimization patterns (connection pooling fora do handler, lazy initialization)
