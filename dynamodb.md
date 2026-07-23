# DynamoDB — Guia Completo (DVA-C02)

## 1. O que é

DynamoDB é um banco de dados **NoSQL gerenciado (fully managed)**, key-value e document, projetado para **baixa latência em qualquer escala** (single-digit milliseconds). Não há servidores para gerenciar, patch, ou escalar manualmente — a AWS cuida de replicação, particionamento e disponibilidade.

Do ponto de vista do desenvolvedor (foco da prova), o que importa é: **como modelar dados para acesso eficiente**, já que DynamoDB não tem JOINs nem query ad-hoc como SQL — o design da tabela é guiado pelos **padrões de acesso** (access patterns), não pela normalização.

---

## 2. Conceitos fundamentais

### Estrutura de dados
- **Tabela**: coleção de itens.
- **Item**: equivalente a uma "linha" — um conjunto de atributos (JSON-like). Máx **400 KB** por item.
- **Atributo**: par chave-valor dentro de um item. Tipos: String, Number, Binary, Boolean, Null, List, Map, String/Number/Binary Set.

### Chave primária
- **Partition Key (PK) simples**: determina em qual partição física o item fica. O hash da PK decide o "shard".
- **Partition Key + Sort Key (composta)**: permite múltiplos itens com o mesmo PK, ordenados pela SK. É o padrão mais usado em modelagem avançada (single-table design).

### Cardinalidade da Partition Key

Cardinalidade, no contexto do DynamoDB, é a quantidade de valores distintos que uma chave pode assumir no conjunto de dados.

- **Alta cardinalidade**: muitos valores diferentes de PK (ex: `userId`, `orderId`).
- **Baixa cardinalidade**: poucos valores repetidos (ex: `status` com `ACTIVE`, `PENDING`, `DONE`).

Por que isso importa:
- Alta cardinalidade melhora a distribuição de dados e tráfego entre partições físicas.
- Baixa cardinalidade concentra carga em poucas partições, aumentando risco de **hot partition** e throttling.

Como isso aparece na prova (DVA-C02):
- Cenário de chave quente e gargalo recorrente geralmente indica PK com cardinalidade insuficiente.
- A correção típica é redesenhar a PK (aumentar cardinalidade) ou aplicar **write sharding**.

### Hot Partition

**Hot partition** é quando uma partição física do DynamoDB recebe tráfego desproporcional (muitas leituras/escritas em relação às demais), tornando-se um ponto de gargalo.

Efeitos comuns:
- aumento de latência;
- throttling (requisições limitadas);
- desempenho inconsistente, mesmo quando a tabela parece ter capacidade total suficiente.

Causas típicas:
- PK com baixa cardinalidade;
- padrão de acesso concentrado em poucos valores de PK;
- picos de tráfego sobre uma mesma entidade (ex: contador global, votação, ranking muito acessado).

Mitigações frequentes:
- redesenhar a partition key para melhorar distribuição;
- aplicar **write sharding** em chaves naturalmente quentes;
- para leituras intensas, avaliar cache (ex: DAX) quando fizer sentido ao caso de uso.

⚠️ **Pegadinha**: a escolha da PK define diretamente a distribuição de carga. Uma PK com baixa cardinalidade (ex: `status` com só 3 valores possíveis) causa **"hot partition"** — muito tráfego concentrado em poucas partições físicas.

### Shard da Partition Key (explicação detalhada)

Neste tema, pense em 2 camadas diferentes:

1. **Partição física (interna da AWS)**
    - DynamoDB aplica hash na PK e decide automaticamente onde guardar.
    - Você não controla manualmente essas partições.

    Esclarecimento importante:
    - **Hash**: é o cálculo/mecanismo de mapeamento.
    - **Shard**: é o destino físico (a partição onde o item é salvo).
    - Em outras palavras: o hash **define para qual shard** o item vai; hash e shard não são a mesma coisa.

2. **Sharding lógico da PK (write sharding)**
    - Técnica de modelagem para distribuir carga quando uma chave lógica está "quente".
    - Em vez de gravar tudo em uma única PK, você cria várias PKs derivadas.

Exemplo direto:
- Sem shard: `VOTE#CANDIDATE_A`
- Com shard: `VOTE#CANDIDATE_A#0` até `VOTE#CANDIDATE_A#19`

Ideia central: mais valores de PK => melhor distribuição de escrita/leitura => menor chance de hot partition.

#### Quando você precisa de shard?

Use quando existe **muito tráfego concentrado na mesma PK lógica**, por exemplo:
- contador global;
- votos em tempo real;
- leaderboard muito acessado;
- eventos de pico em uma única entidade.

Sinal típico: throttling recorrente em padrão concentrado, mesmo após ajustes de capacidade.

#### Como funciona na escrita (passo a passo)

1. Defina quantidade de shards lógicos `N` (ex: 10, 20, 50).
2. Para cada escrita, escolha um shard (`0..N-1`).
3. Grave no item cuja PK inclui esse sufixo.

Fórmula comum para escolha de shard:
- aleatória: `rand(0, N-1)`
- determinística: `hash(chaveDeNegocio) mod N`

#### Como funciona na leitura

Depende do tipo de shard:

- **Shard aleatório**:
    - escrita distribui muito bem;
    - para total agregado, você consulta vários shards e soma os resultados;
    - para leitura pontual, é difícil saber onde o item foi parar sem índice extra.

- **Shard determinístico**:
    - escrita continua distribuída;
    - leitura pontual fica fácil, pois o app recalcula o shard;
    - para total agregado, ainda pode exigir consulta em vários shards.

#### Como escolher quantidade de shards (regra prática)

1. Estime writes por segundo da chave quente.
2. Divida pelo throughput por partição que você quer respeitar.
3. Arredonde para cima e adicione margem de segurança.

Exemplo conceitual:
- carga esperada: ~20.000 writes/s para uma chave lógica;
- com 20 shards, média de ~1.000 writes/s por shard (se distribuição uniforme).

#### Trade-off que cai na prova

- **Ganho**: reduz gargalo em escrita concentrada.
- **Custo**: leitura agregada fica mais complexa e pode custar mais.

#### Armadilhas clássicas

- Confundir shard lógico com configuração manual de partição física.
- Implementar shard aleatório e depois precisar de leitura pontual sem estratégia de descoberta.
- Esquecer que GSI com baixa cardinalidade também pode ficar "quente" e gerar backpressure na tabela base.
- Achar que sort key resolve hotspot de PK (não resolve distribuição de PK).

#### Como isso aparece na DVA-C02

Se o enunciado trouxer "hot key", throttling concentrado e alta escrita na mesma entidade, a resposta costuma envolver:
- melhorar cardinalidade da PK;
- aplicar write sharding;
- e, para leitura, prever agregação/consulta múltipla de shards.

---

## 3. Índices

| Tipo | Partition Key | Sort Key | Quando criar | Consistência |
|---|---|---|---|---|
| **LSI** (Local) | Igual à tabela base | Diferente | **Só na criação da tabela** | Forte ou eventual |
| **GSI** (Global) | Pode ser diferente | Pode ser diferente | A qualquer momento | **Apenas eventual** |

- LSI: até 5 por tabela, compartilha capacidade (RCU/WCU) da tabela base.
- GSI: até 20 por tabela (padrão, pode aumentar via suporte), tem **capacidade própria** — se o GSI throttle, pode throttle a tabela base também (efeito colateral clássico de prova).

---

## 4. Capacity Modes (como você paga e como a AWS aloca throughput)

### Provisioned
Você define RCU (Read Capacity Units) e WCU (Write Capacity Units) manualmente ou via **Auto Scaling**.
- **1 RCU** = 1 leitura fortemente consistente de item até 4 KB (leitura eventualmente consistente = metade do custo, 0,5 RCU)
- **1 WCU** = 1 escrita de item até 1 KB
- `TransactWriteItems`/`TransactGetItems` consomem **2x** a capacidade normal (ACID tem custo).

### On-Demand
Paga por requisição, sem precisar prever capacidade. Bom para tráfego imprevisível/spiky, mas custo por request é mais alto que Provisioned bem dimensionado.

⚠️ **Pegadinha de prova**: cenário clássico é "carga imprevisível e picos repentinos" → resposta é **On-Demand**; cenário "carga previsível e otimização de custo" → **Provisioned + Auto Scaling**.

---

## 5. Operações principais

| Operação | Descrição |
|---|---|
| `GetItem` / `PutItem` / `UpdateItem` / `DeleteItem` | Item único |
| `Query` | Busca por PK (obrigatório) + filtro opcional de SK — **eficiente** |
| `Scan` | Varre a tabela inteira — **caro, evitar em produção** |
| `BatchGetItem` | Até 100 itens / 16 MB por chamada |
| `BatchWriteItem` | Até 25 itens / 16 MB por chamada |
| `TransactWriteItems`/`TransactGetItems` | Até 25 itens, **ACID** (all-or-nothing) |

⚠️ **Pegadinha importante**: `FilterExpression` no `Query`/`Scan` filtra **depois** de ler os dados — você paga RCU pelo total lido, não pelo resultado filtrado. Muita gente acha que filtra "antes" e economiza capacidade, o que é falso.

---

## 6. Recursos avançados

### DynamoDB Streams
Captura mudanças (create/update/delete) em ordem cronológica por partição, disponível por 24h. Integra nativamente com **Lambda** (padrão: Lambda faz polling do stream).

View types:
- `KEYS_ONLY` — só as chaves do item modificado
- `NEW_IMAGE` — item após a mudança
- `OLD_IMAGE` — item antes da mudança
- `NEW_AND_OLD_IMAGES` — ambos

Caso de uso típico: auditoria, replicação cross-region, triggers de negócio (ex: enviar email quando pedido muda de status).

### TTL (Time to Live)
Atributo do tipo Number (epoch timestamp) que faz o DynamoDB **deletar automaticamente** o item após expirado. A exclusão não é instantânea (pode levar até 48h), e **não consome WCU**. Útil para sessões, cache, dados temporários.

### DAX (DynamoDB Accelerator)
Cache in-memory totalmente gerenciado, compatível com a API do DynamoDB, reduz latência de milissegundos para **microssegundos**. Só funciona com **leitura eventualmente consistente** (não suporta strongly consistent reads).

### Global Tables
Replicação **multi-region, multi-master** automática. Usa Streams internamente. Resolve conflitos por "last writer wins" (baseado em timestamp).

### Point-in-Time Recovery (PITR)
Backup contínuo, permite restaurar a tabela para qualquer segundo nos últimos 35 dias.

---

## 7. Segurança e integrações

- **IAM** controla acesso via policies, incluindo **condition keys** como `dynamodb:LeadingKeys` (fine-grained access control — restringe um usuário a acessar só itens onde a PK é igual ao seu próprio ID, comum com Cognito Identity Pools).
- Criptografia em repouso habilitada por padrão (KMS).
- VPC Endpoints (Gateway type) permitem acesso privado sem sair para a internet pública.

---

## 8. Limitações importantes (memorize para a prova)

| Limite | Valor |
|---|---|
| Tamanho máximo de item | 400 KB |
| Itens por `BatchGetItem` | 100 |
| Itens por `BatchWriteItem` | 25 |
| Itens por transação | 25 |
| GSIs por tabela (padrão) | 20 |
| LSIs por tabela | 5 |
| Retenção do Stream | 24 horas |
| Tamanho de partição (para LSI) | 10 GB |

*(Sempre confirme limites exatos na documentação atual — a AWS já alterou alguns desses valores ao longo do tempo.)*

---

## 9. Comparação rápida com outros serviços

- **DynamoDB vs RDS**: DynamoDB = NoSQL, escala horizontal automática, sem schema fixo, sem JOIN. RDS = relacional, JOINs, transações complexas, schema rígido.
- **DynamoDB vs ElastiCache**: DynamoDB é banco persistente; ElastiCache é cache in-memory (dados podem ser perdidos). DAX fica "no meio" — cache gerenciado só para DynamoDB.

---

## 10. Exemplo prático (C#)

```csharp
var request = new QueryRequest
{
    TableName = "Orders",
    KeyConditionExpression = "customerId = :cid AND orderDate > :date",
    ExpressionAttributeValues = new Dictionary<string, AttributeValue>
    {
        { ":cid", new AttributeValue { S = "cust-123" } },
        { ":date", new AttributeValue { S = "2026-01-01" } }
    }
};

var response = await dynamoDbClient.QueryAsync(request);
```

---

## Anexo: LSI vs GSI (resumo comparativo)

| Aspecto | LSI (Local Secondary Index) | GSI (Global Secondary Index) |
|---|---|---|
| Partition Key | **Igual** à da tabela base | **Pode ser diferente** da tabela base |
| Sort Key | Diferente da tabela base | Pode ser diferente (ou nem ter) |
| Quando criar | **Somente na criação da tabela** | A qualquer momento (criar/deletar depois) |
| Capacidade (RCU/WCU) | Compartilha da tabela base | **Tem capacidade própria** |
| Consistência de leitura | Suporta forte ou eventual | **Apenas eventual** |
| Limite | Até 5 por tabela | Até 20 por tabela (padrão) |
| Tamanho do item | Conta contra o limite de 10 GB por partição da tabela base | Sem esse limite compartilhado |

**Pegadinhas da prova:**
- LSI **não pode ser adicionado depois** — se você esqueceu de criar na hora da tabela, terá que recriar a tabela inteira (migração de dados).
- GSI **nunca suporta leitura fortemente consistente** — mesmo que você peça `ConsistentRead=true`, isso é ignorado/inválido para GSI. É a pegadinha mais clássica.
- GSI tem **throttling próprio**: se o GSI não tiver capacidade suficiente, as escritas na tabela base também podem ser throttled ("GSI overloaded"), mesmo que a tabela principal tenha capacidade sobrando.

**Exemplo:**
```
Tabela base: PK = customerId, SK = orderId
LSI: PK = customerId (igual), SK = orderStatus   → ordena pedidos do mesmo cliente por status
GSI: PK = orderStatus, SK = orderDate            → busca pedidos de QUALQUER cliente por status
```