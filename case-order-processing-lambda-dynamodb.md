# Case de Estudo — Sistema de Processamento de Pedidos (Order Processing)
### Projeto prático para certificação AWS Certified Developer – Associate (DVA-C02)

---

## Cenário

Uma loja online recebe pedidos via API. Cada pedido precisa ser:

1. Salvo de forma confiável
2. Notificado para outros sistemas (ex: time de estoque, time de faturamento) sem acoplamento direto
3. Processado de forma idempotente (evitar pedido duplicado se o cliente reenviar a requisição)

---

## Arquitetura

```
Cliente → API Gateway → Lambda (CreateOrder) → DynamoDB (tabela Orders)
                                                      │
                                                      ▼ (DynamoDB Streams)
                                              Lambda (StreamProcessor)
                                                      │
                                                      ▼
                                              SNS Topic "order-events"
                                              ├──► SQS "estoque-queue" → Lambda (Estoque)
                                              └──► SQS "faturamento-queue" → Lambda (Faturamento)
                                                      │
                                              (com DLQ em cada fila)
```

---

## Componentes e o que cada um treina pra prova

| Componente | Serviço | Conceito de exame |
|---|---|---|
| Recebe pedido | API Gateway + Lambda | Proxy integration, validação de request |
| Persiste pedido | DynamoDB | Partition key design, conditional writes (idempotência) |
| Reage à mudança | DynamoDB Streams | NEW_IMAGE vs NEW_AND_OLD_IMAGES, event source mapping |
| Distribui evento | SNS | Fan-out pattern, message filtering |
| Processa assíncrono | SQS | Standard queue, visibility timeout, DLQ |
| Permissões | IAM | Least privilege por Lambda (cada função só acessa o que precisa) |
| Observabilidade | CloudWatch/X-Ray | Logs estruturados, tracing distribuído |

---

## Schema do DynamoDB (tabela `Orders`)

```
PK: ORDER#<order_id>
SK: METADATA

Atributos:
- order_id (string, UUID)
- customer_id (string)
- status (string: PENDING | PROCESSING | COMPLETED | FAILED)
- items (list de maps: {product_id, quantity, price})
- total (number)
- created_at (string ISO 8601)
- idempotency_key (string) ← usado num GSI para evitar duplicatas
```

**Design decision pra discutir**: use `idempotency_key` (ex: hash do payload + customer_id) como chave de um **GSI**, e faça um `ConditionExpression` no `PutItem` pra rejeitar duplicatas. Isso é exatamente o tipo de pegadinha que cai na prova sobre idempotência em sistemas distribuídos.

---

## Roteiro de implementação (Python)

### Etapa 1 — Lambda `CreateOrder`
- Recebe evento do API Gateway (`event['body']`)
- Valida payload
- Usa `boto3.resource('dynamodb').Table('Orders').put_item()` com `ConditionExpression='attribute_not_exists(order_id)'` pra idempotência
- Retorna 201 com o `order_id`

### Etapa 2 — Habilitar DynamoDB Streams
- Ative o stream na tabela com `StreamViewType=NEW_IMAGE`
- Configure o **Event Source Mapping** entre a stream e a Lambda `StreamProcessor` (batch size, starting position)

### Etapa 3 — Lambda `StreamProcessor`
- Recebe `event['Records']`, cada um com `eventName` (INSERT/MODIFY/REMOVE)
- Filtra só `INSERT` com `status == PENDING`
- Publica no SNS via `boto3.client('sns').publish()` com `MessageAttributes` (útil pra ensinar SNS filter policies)

### Etapa 4 — SNS + SQS (fan-out)
- Duas filas SQS assinam o mesmo tópico SNS
- Cada fila tem uma **DLQ** configurada (`maxReceiveCount`, ex: 3)
- Lambdas `ProcessarEstoque` e `ProcessarFaturamento` consomem cada fila via event source mapping

### Etapa 5 — Tratamento de erro / retry
- Simule uma falha proposital em uma das Lambdas consumidoras
- Observe a mensagem migrando pra DLQ após as tentativas
- Configure um alarme CloudWatch na DLQ (`ApproximateNumberOfMessagesVisible > 0`)

### Etapa 6 — IAM
- Crie uma role por Lambda, com policy mínima (ex: `CreateOrder` só precisa de `dynamodb:PutItem` naquela tabela específica, não em `*`)

### Etapa 7 (opcional, avançado) — X-Ray
- Ative tracing ativo nas Lambdas (`Tracing: Active` no SAM/CDK)
- Adicione `aws-xray-sdk` no código Python pra ver os segments no console

---

## Stack sugerida

Como o desenvolvimento é em Python, dá pra fazer tudo com **AWS SAM** (`template.yaml` + código Lambda) ou **AWS CDK em Python** — os dois caem na prova, então é uma boa oportunidade de aprender na prática o que a teoria descreve.

---

## Próximos passos sugeridos

- Modelar o `template.yaml` (SAM) com todos os recursos conectados
- Implementar a Lambda `CreateOrder` em Python
- Testar localmente com `sam local invoke` antes de fazer deploy
- Revisar os tópicos de DynamoDB Streams e SNS/SQS fan-out no domínio 1 do exame após concluir o projeto
