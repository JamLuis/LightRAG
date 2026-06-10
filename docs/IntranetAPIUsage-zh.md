# LightRAG 内网 API 调用指南

这份文档面向这样的场景：

- LightRAG 已经部署在内网服务器上
- 你不打算依赖 WebUI，而是希望从你自己的系统、脚本、服务或内网门户里直接调用 LightRAG API
- 你最关心三类能力：上传知识数据、查看图谱、进行问答

本文只覆盖最常用的调用闭环，不展开部署本身。如果你还没有把服务跑起来，先看 [DockerDeployment-zh.md](./DockerDeployment-zh.md) 和 [LightRAG-API-Server-zh.md](./LightRAG-API-Server-zh.md)。

## 1. 先理解三类能力怎么映射到 API

LightRAG 对“知识图谱接入”有两种常见方式：

1. 上传文档或纯文本，让系统自动抽取实体和关系，再写入图谱。
2. 直接调用图谱编辑接口，手工创建实体和关系。

所以“上传知识图谱”在 API 层不是单一接口，而是下面两条路径：

- 自动构图：`/documents/upload`、`/documents/text`、`/documents/texts`
- 手工补图：`/graph/entity/create`、`/graph/relation/create`

查看图谱和问答则分别对应：

- 查看图谱：`/graph/label/list`、`/graph/label/search`、`/graphs`
- 问答：`/query`、`/query/data`、`/query/stream`

## 2. 内网调用前提

假设你的 LightRAG 服务地址是：

```text
http://10.10.10.25:9621
```

下文统一记为：

```text
BASE_URL=http://10.10.10.25:9621
```

如果你前面挂了 Nginx、Traefik 或 API 网关，那么把它替换成你实际暴露给内网系统的地址即可，例如：

```text
https://rag-gateway.intra.company.local
```

## 3. 认证怎么带

LightRAG 常见有两种调用方式。

### 3.1 如果你开启了 API Key

如果服务配置了 `LIGHTRAG_API_KEY`，最简单的方式就是在请求头里带：

```http
X-API-Key: <你的 API Key>
```

示例：

```bash
curl -X GET "${BASE_URL}/health" \
  -H "X-API-Key: your-api-key"
```

### 3.2 如果你没有单独启 API Key

可以先调用：

```text
GET /auth-status
```

如果当前服务没有启账号认证，它会返回一个 guest token。你可以把这个 token 当成 Bearer Token 使用：

```http
Authorization: Bearer <access_token>
```

示例：

```bash
curl -X GET "${BASE_URL}/auth-status"
```

返回类似：

```json
{
  "auth_configured": false,
  "access_token": "...",
  "token_type": "bearer",
  "auth_mode": "disabled"
}
```

后续请求可写成：

```bash
curl -X GET "${BASE_URL}/health" \
  -H "Authorization: Bearer <access_token>"
```

### 3.3 推荐实践

在内网系统集成里，优先建议你显式配置 `LIGHTRAG_API_KEY`，然后统一走 `X-API-Key`。

原因很简单：

- 不需要每次先换 token
- 更适合服务到服务调用
- 网关、APISIX、Nginx 或后端 SDK 更容易统一封装

## 4. 先做一个最小连通性检查

无论你最终要上传、看图还是问答，先打一次健康检查：

```bash
curl -X GET "${BASE_URL}/health" \
  -H "X-API-Key: your-api-key"
```

你应该能看到类似结果：

```json
{
  "status": "healthy",
  "webui_available": true,
  "configuration": {
    "llm_binding": "azure_openai",
    "embedding_binding": "openai"
  }
}
```

如果这里都不通，先不要继续调业务接口。

## 5. 方式一：上传文档或文本，让系统自动构图

这是最常用的接入方式。你只需要把资料送进去，LightRAG 会做分块、抽实体、抽关系、写图谱和向量库。

### 5.1 上传文件

接口：

```text
POST /documents/upload
```

调用示例：

```bash
curl -X POST "${BASE_URL}/documents/upload" \
  -H "X-API-Key: your-api-key" \
  -F "file=@D:/data/company-knowledge.pdf"
```

返回示例：

```json
{
  "status": "success",
  "message": "File 'company-knowledge.pdf' uploaded successfully. Processing will continue in background.",
  "track_id": "upload_20260609_123456_abc123"
}
```

重点注意：

- 这个接口返回成功，不代表文档已经处理完，只代表它已经进入后台任务。
- 你必须记录 `track_id`，后面要靠它查处理结果。
- 如果同名文件已存在，会返回 `409`，需要先删旧文档再传。

### 5.2 直接插入纯文本

如果你的知识本来就已经被上游系统解析成纯文本，不需要先落成文件，可以用：

```text
POST /documents/text
```

调用示例：

```bash
curl -X POST "${BASE_URL}/documents/text" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "LightRAG 是一个基于图谱和向量检索的 RAG 系统。",
    "file_source": "knowledge/light-rag-intro.txt"
  }'
```

如果一次要送多段文本，可以用：

```text
POST /documents/texts
```

### 5.3 查询处理进度

接口：

```text
GET /documents/track_status/{track_id}
```

调用示例：

```bash
curl -X GET "${BASE_URL}/documents/track_status/upload_20260609_123456_abc123" \
  -H "X-API-Key: your-api-key"
```

返回示例：

```json
{
  "track_id": "upload_20260609_123456_abc123",
  "documents": [
    {
      "id": "doc-123",
      "status": "processed",
      "file_path": "company-knowledge.pdf",
      "error_msg": null
    }
  ],
  "total_count": 1,
  "status_summary": {
    "processed": 1
  }
}
```

你真正关心的是：

- `status=processed`：说明已经入库完成，可以问答、看图
- `status=failed`：说明处理失败，要重点看 `error_msg`

## 6. 方式二：手工补图或直接构造图谱

如果你的上游系统本身已经有实体和关系，不想让 LightRAG 从文本里重新抽取，可以直接调图谱接口。

这条路径适合：

- 主数据系统里本来就有结构化实体关系
- 你只想把外部图谱同步进来
- 你想在自动抽图之后再手工补点、补边

### 6.1 创建实体

接口：

```text
POST /graph/entity/create
```

调用示例：

```bash
curl -X POST "${BASE_URL}/graph/entity/create" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_name": "LightRAG",
    "entity_data": {
      "description": "A graph-based RAG framework",
      "entity_type": "PRODUCT"
    }
  }'
```

### 6.2 创建关系

接口：

```text
POST /graph/relation/create
```

调用示例：

```bash
curl -X POST "${BASE_URL}/graph/relation/create" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "source_entity": "LightRAG",
    "target_entity": "Neo4j",
    "relation_data": {
      "description": "LightRAG can use Neo4j as graph storage",
      "keywords": "storage,database,graph",
      "weight": 1.0
    }
  }'
```

说明：

- 手工建图时，实体要先于关系创建。
- 这些接口会同时更新图结构和相关向量索引，不是“只写图不写检索”。

## 7. 查看图谱

实际使用时，通常不是一上来就调 `/graphs`，而是先拿一个可用的 label，再展开子图。

### 7.1 获取图谱标签列表

接口：

```text
GET /graph/label/list
```

调用示例：

```bash
curl -X GET "${BASE_URL}/graph/label/list" \
  -H "X-API-Key: your-api-key"
```

### 7.2 搜索标签

接口：

```text
GET /graph/label/search?q=<keyword>&limit=50
```

调用示例：

```bash
curl -X GET "${BASE_URL}/graph/label/search?q=LightRAG&limit=20" \
  -H "X-API-Key: your-api-key"
```

### 7.3 获取某个节点的子图

接口：

```text
GET /graphs?label=<label>&max_depth=3&max_nodes=1000
```

调用示例：

```bash
curl -X GET "${BASE_URL}/graphs?label=LightRAG&max_depth=2&max_nodes=200" \
  -H "X-API-Key: your-api-key"
```

常用参数：

- `label`：起始节点名称
- `max_depth`：向外扩几层
- `max_nodes`：最多返回多少节点

典型调用顺序是：

1. `/graph/label/search?q=...`
2. 选中一个命中的 label
3. `/graphs?label=...`

## 8. 进行问答

问答最常用的是两个接口：

- `/query`：直接返回最终答案
- `/query/data`：返回检索到的结构化数据，不做最终生成

### 8.1 直接问答

接口：

```text
POST /query
```

调用示例：

```bash
curl -X POST "${BASE_URL}/query" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "什么是 LightRAG？",
    "mode": "mix",
    "top_k": 10,
    "chunk_top_k": 10,
    "include_references": true
  }'
```

返回示例：

```json
{
  "response": "LightRAG 是一个结合知识图谱和向量检索的 RAG 系统。",
  "references": [
    {
      "reference_id": "1",
      "file_path": "knowledge/light-rag-intro.txt"
    }
  ]
}
```

常用 `mode`：

- `mix`：通常最推荐，图谱和向量一起参与
- `naive`：只看向量检索
- `local`：偏实体局部关系
- `global`：偏全局关系
- `hybrid`：局部和全局结合

### 8.2 先看检索结果，不让模型生成

接口：

```text
POST /query/data
```

这个接口特别适合内网系统联调，因为你可以先确认“是不是检索错了”，再判断“是不是模型答偏了”。

调用示例：

```bash
curl -X POST "${BASE_URL}/query/data" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "LightRAG 和 Neo4j 是什么关系？",
    "mode": "mix",
    "top_k": 10,
    "chunk_top_k": 10
  }'
```

返回里会包含：

- `entities`
- `relationships`
- `chunks`
- `references`

这对排查问题很有用。

### 8.3 流式问答

如果你要做聊天窗口或边生成边显示，可以用：

```text
POST /query/stream
```

返回类型是 NDJSON，适合前端逐行消费。

## 9. Python 调用示例

下面给一个最小 Python 封装，适合内网后端服务直接复用。

```python
import time
import requests

BASE_URL = 'http://10.10.10.25:9621'
HEADERS = {
    'X-API-Key': 'your-api-key',
}


def upload_text(text: str, file_source: str) -> str:
    resp = requests.post(
        f'{BASE_URL}/documents/text',
        headers={**HEADERS, 'Content-Type': 'application/json'},
        json={
            'text': text,
            'file_source': file_source,
        },
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()['track_id']


def wait_until_processed(track_id: str, timeout_seconds: int = 180):
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        resp = requests.get(
            f'{BASE_URL}/documents/track_status/{track_id}',
            headers=HEADERS,
            timeout=30,
        )
        resp.raise_for_status()
        payload = resp.json()
        docs = payload.get('documents', [])
        if docs:
            status = docs[0]['status']
            if status == 'processed':
                return payload
            if status == 'failed':
                raise RuntimeError(docs[0].get('error_msg'))
        time.sleep(2)
    raise TimeoutError(f'track_id={track_id} still not completed')


def query(question: str):
    resp = requests.post(
        f'{BASE_URL}/query',
        headers={**HEADERS, 'Content-Type': 'application/json'},
        json={
            'query': question,
            'mode': 'mix',
            'top_k': 10,
            'chunk_top_k': 10,
            'include_references': True,
        },
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()


if __name__ == '__main__':
    track_id = upload_text(
        text='LightRAG can use Neo4j as graph storage.',
        file_source='demo/light-rag.txt',
    )
    wait_until_processed(track_id)
    result = query('LightRAG 和 Neo4j 是什么关系？')
    print(result)
```

## 10. 一个推荐的内网接入流程

如果你要把 LightRAG 接到自己的 OA、知识平台、客服平台或流程系统里，建议按这个顺序接：

1. 用 `/health` 做服务探活。
2. 用 `/documents/upload` 或 `/documents/text` 做数据入库。
3. 用 `/documents/track_status/{track_id}` 确认处理完成。
4. 用 `/query/data` 调检索结果，确认命中是否合理。
5. 再接 `/query` 做正式问答。
6. 如果需要图谱展示，再接 `/graph/label/search` 和 `/graphs`。
7. 如果需要人工修图，再接 `/graph/entity/create` 和 `/graph/relation/create`。

## 11. 常见问题

### 11.1 为什么上传成功了，但问答没有结果？

最常见有三种原因：

- 文档还没处理完，你太早开始问了
- 文档处理失败了，需要看 `track_status` 里的 `error_msg`
- 你刚改过 embedding 模型、维度或 provider，但没有清空旧向量数据并重建索引

### 11.2 为什么图谱里查不到节点？

先确认两点：

- 该文档处理时没有禁用知识图谱构建
- 你查的 label 名称和系统实际写入的实体名称一致

调试顺序建议是：

1. `/query/data`
2. `/graph/label/search`
3. `/graphs`

### 11.3 我只想做问答，不关心图谱，可以吗？

可以。

你仍然可以只用 `/documents/text` 或 `/documents/upload` 入库，然后直接使用 `/query` 或 `/query/data`。如果某些文档处理选项关闭了图谱构建，`naive` 检索仍然可用。

### 11.4 内网里有自签名 HTTPS 证书怎么办？

优先建议把证书链配正确，让调用方信任它。不要长期依赖关闭 TLS 校验的方式。

如果你是经 Nginx 或网关转发 LightRAG，请同时确认：

- 反向代理能转发大文件上传
- `/query/stream` 没有被缓冲截断
- 根路径、前缀和超时设置与你的网关一致

## 12. 下一步建议

如果你准备把这套 API 提供给内网应用团队，建议你再补三层封装：

1. 一个统一的 API Client，屏蔽认证头、超时和重试。
2. 一个“知识入库任务状态机”，不要让业务方直接轮询裸接口。
3. 一个内部领域层，把 `/query`、`/graphs`、`/documents/*` 转成你自己的业务语义接口。

这样后续切换 LLM、embedding、存储后端或鉴权方式时，上层系统不用跟着改。
