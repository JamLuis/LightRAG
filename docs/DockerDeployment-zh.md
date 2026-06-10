# LightRAG Docker 部署手册（小白版，Windows 实操）

这是一份按实际落地过程整理出来的操作手册，目标是让第一次接触 LightRAG、Docker、数据库的人，也能一步一步完成部署。

本文采用的路线是：

- 使用仓库自带的交互式向导生成配置
- 使用 Docker 部署 LightRAG
- 使用 PostgreSQL 作为 KV、Vector、Doc Status 存储
- 使用 Neo4j 作为 Graph 存储
- 暂时不配置登录账号、JWT、API Key、SSL

如果你只是想先把服务跑起来，这是最适合服务器的路径之一。

如果你部署完成后，想从内网系统直接调用上传、图谱查看和问答能力，可以继续看 [IntranetAPIUsage-zh.md](./IntranetAPIUsage-zh.md)。

## 1. 你最终会得到什么

完成后，你会得到以下结果：

- 一个可运行的 LightRAG 容器
- 一个 PostgreSQL 容器
- 一个 Neo4j 容器
- 一个由向导生成的 `.env`
- 一个由向导生成的 `docker-compose.final.yml`

启动成功后，你可以用下面两个地址验证：

- 健康检查：`http://localhost:9621/health`
- WebUI：`http://localhost:9621/webui`

## 2. 适用环境

本文按下面环境编写：

- Windows
- Docker Desktop 已安装并已启动
- Git for Windows 已安装
- 仓库已经拉到本地

建议在 Windows 上优先使用 Git Bash 运行向导，不要优先用 WSL 跑向导脚本。

原因很简单：这次实测里，WSL 执行向导时出现了 shell 换行兼容问题，而 Git Bash 可以稳定跑通。

## 3. 第一步：确认 Docker 可用

在 PowerShell 中运行：

```powershell
docker --version
docker compose version
```

你至少要看到版本号输出，不能报 “command not found” 或 “不是内部或外部命令”。

如果 Docker Desktop 没启动，请先启动它，等右下角状态稳定后再继续。

## 4. 第二步：进入仓库目录

如果你已经把仓库下载好了，进入项目根目录：

```powershell
cd D:\code\LightRAG
```

如果你还没下载：

```powershell
git clone https://github.com/HKUDS/LightRAG.git
cd LightRAG
```

## 5. 第三步：生成基础配置

先运行基础向导：

```bash
make env-base
```

第一次建议这样选：

- LLM：远程托管模型
- Embedding：远程托管 embedding
- 本地 embedding Docker：`no`
- rerank：`no`

这一步的目标只有一个：先生成 `.env`。

跑完后，项目根目录里应该能看到：

- `.env`

如果你之前已经跑过这一步，可以直接进入下一步。

### 5.1 如果你使用本文这次实配的 Azure OpenAI 模型

如果你打算直接复用这次部署时已经验证过的 LLM 配置，可以把 `.env` 里的 LLM 段改成下面这样：

```env
LLM_BINDING=azure_openai
LLM_MODEL=gpt-5.4
LLM_BINDING_HOST=https://jhx-mk84i2is-eastus2.cognitiveservices.azure.com/openai/v1/
LLM_BINDING_API_KEY=<你的 Azure OpenAI API Key>
AZURE_OPENAI_ENDPOINT=https://jhx-mk84i2is-eastus2.cognitiveservices.azure.com/openai/v1/
AZURE_OPENAI_API_KEY=<你的 Azure OpenAI API Key>
AZURE_OPENAI_DEPLOYMENT=gpt-5.4
AZURE_OPENAI_API_VERSION=2024-08-01-preview
```

说明：

- `LLM_BINDING=azure_openai` 表示 LLM 走 Azure OpenAI。
- `LLM_MODEL` 和 `AZURE_OPENAI_DEPLOYMENT` 都填 `gpt-5.4`，避免部署名和模型名不一致。
- 如果你的模型侧要求使用 `max_completion_tokens` 而不是 `max_tokens`，可以额外在 `.env` 里保留：

```env
OPENAI_LLM_MAX_COMPLETION_TOKENS=9000
```

这不是固定值，你也可以按自己需要改大或改小。

如果你连 embedding 也要一起切到 Azure OpenAI，可以继续补下面这一段：

```env
EMBEDDING_BINDING=azure_openai
EMBEDDING_MODEL=text-embedding-3-large
EMBEDDING_DIM=3072
EMBEDDING_BINDING_HOST=https://jhx-mk84i2is-eastus2.cognitiveservices.azure.com/
EMBEDDING_BINDING_API_KEY=<你的 Azure OpenAI API Key>
AZURE_EMBEDDING_ENDPOINT=https://jhx-mk84i2is-eastus2.cognitiveservices.azure.com/
AZURE_EMBEDDING_API_KEY=<你的 Azure OpenAI API Key>
AZURE_EMBEDDING_DEPLOYMENT=text-embedding-3-large
AZURE_EMBEDDING_API_VERSION=2024-08-01-preview
```

注意：

- 上面假设你在 Azure OpenAI 里已经部署了 `text-embedding-3-large`。
- 如果你的 Azure embedding 部署名不是 `text-embedding-3-large`，就把 `EMBEDDING_MODEL` 和 `AZURE_EMBEDDING_DEPLOYMENT` 都改成你自己的部署名。
- 这次实配后的状态就是：LLM 走 Azure OpenAI，Embedding 也走 Azure OpenAI。

如果你想保留 LLM 走 Azure OpenAI，但把 embedding 改成阿里云百炼（Qwen embedding），可以改成下面这样：

```env
EMBEDDING_BINDING=openai
EMBEDDING_MODEL=text-embedding-v4
EMBEDDING_DIM=1024
EMBEDDING_BINDING_HOST=https://dashscope.aliyuncs.com/compatible-mode/v1
EMBEDDING_BINDING_API_KEY=<你的 DashScope API Key>
DASHSCOPE_API_KEY=<你的 DashScope API Key>
EMBEDDING_SEND_DIM=false
```

注意：

- 这里用的是百炼北京区官方 OpenAI-compatible 地址，优先用这个，不用手填 workspace 域名。
- 这套接法在 LightRAG 里走的是 `openai` 兼容 binding。
- 我本次实测 `https://dashscope.aliyuncs.com/compatible-mode/v1/embeddings` 可以直接返回 `text-embedding-v4` 向量，维度是 `1024`。

## 6. 第四步：生成数据库与存储配置

这一步开始切换到数据库存储。

### 6.1 推荐在 Git Bash 中执行

打开 Git Bash，进入仓库目录：

```bash
cd /d/code/LightRAG
```

然后运行：

```bash
make env-storage
```

### 6.2 这一步应该怎么选

向导会问你 4 类存储分别用什么后端，本文实际采用的是：

- KV storage：`PGKVStorage`
- Vector storage：`PGVectorStorage`
- Graph storage：`Neo4JStorage`
- Doc status storage：`PGDocStatusStorage`

然后它会继续问数据库是否由 Docker 本地托管。

这次部署的选择是：

- PostgreSQL：`yes`
- Neo4j：`yes`

可以参考下面这一组值填写。

PostgreSQL：

- host：`localhost`
- port：`5432`
- user：你自己设置，比如 `rag`
- password：请设置你自己的强密码
- database：建议 `lightrag`

Neo4j：

- URI：`neo4j://localhost:7687`
- username：建议 `neo4j`
- password：请设置你自己的强密码
- database：建议 `neo4j`

最后看到下面这类提示时，输入：

```text
yes
```

也就是确认写入 `.env`。

### 6.3 这一步完成后会生成什么

成功后，项目根目录通常会出现或更新：

- `.env`
- `.env.backup.时间戳`
- `docker-compose.final.yml`

其中：

- `.env` 是当前配置
- `.env.backup.*` 是自动备份
- `docker-compose.final.yml` 是向导生成的最终 compose 文件

## 7. 第五步：先校验配置，不要急着启动

先检查向导生成的配置是否有效。

### 7.1 校验 `.env`

在 Git Bash 中运行：

```bash
bash scripts/setup/setup.sh --validate
```

如果输出：

```text
Validation passed.
```

说明 `.env` 本身是通的。

### 7.2 校验 compose 文件

在 PowerShell 或 Git Bash 中运行：

```powershell
docker compose -f docker-compose.final.yml config -q
```

如果这个命令没有输出，也没有报错，说明 compose 文件语法没问题。

## 8. 第六步：如果你在 Windows 上遇到 compose 报错，按下面修正

这次实测里，向导生成的 `docker-compose.final.yml` 在 Windows Docker Compose 下暴露了两个兼容问题。

如果你没有遇到这些报错，可以直接跳到下一步。

### 8.1 报错 1：`invalid IP address: 0.0.0.0` 或 `invalid hostPort: 9621`

打开项目根目录下的 `docker-compose.final.yml`，找到 `lightrag` 服务下的 `ports` 配置。

如果你看到类似：

```yaml
ports:
  - "${HOST:-0.0.0.0}:${PORT:-9621}:9621"
```

或者：

```yaml
ports:
  - "${PORT:-9621}:9621"
```

请改成最直接的写法：

```yaml
ports:
  - "9621:9621"
```

### 8.2 报错 2：`service "neo4j" refers to undefined volume neo4j_data`

如果 compose 校验时报这个错，说明文件底部缺少卷定义。

请在 `docker-compose.final.yml` 最后补上：

```yaml
volumes:
  postgres_data:
  neo4j_data:
```

补完后重新运行：

```powershell
docker compose -f docker-compose.final.yml config -q
```

直到不报错为止。

## 9. 第七步：启动容器

配置通过后，启动容器：

```powershell
docker compose -f docker-compose.final.yml up -d
```

第一次启动时会自动拉取镜像，所以可能会比较慢。

## 10. 第八步：查看容器状态

启动后运行：

```powershell
docker compose -f docker-compose.final.yml ps
```

正常情况下，你应该至少能看到：

- `lightrag`
- `postgres`
- `neo4j`

并且状态是 `Up` 或健康中。

## 11. 第九步：查看日志

如果你想实时看日志：

```powershell
docker compose -f docker-compose.final.yml logs -f
```

如果你只想看 LightRAG：

```powershell
docker compose -f docker-compose.final.yml logs -f lightrag
```

## 12. 第十步：验证服务是否真的可用

### 12.1 健康检查

```powershell
curl http://localhost:9621/health
```

如果返回健康状态，说明服务已经启动成功。

### 12.2 打开 WebUI

浏览器访问：

```text
http://localhost:9621/webui
```

如果页面能打开，说明基础部署已经完成。

## 13. 这次部署的实际选择记录

为了方便以后复用，这次部署使用的是下面这套组合：

- `make env-base` 已先生成 `.env`
- 存储组合：PostgreSQL + Neo4j
- `LIGHTRAG_KV_STORAGE=PGKVStorage`
- `LIGHTRAG_VECTOR_STORAGE=PGVectorStorage`
- `LIGHTRAG_GRAPH_STORAGE=Neo4JStorage`
- `LIGHTRAG_DOC_STATUS_STORAGE=PGDocStatusStorage`
- PostgreSQL 由 Docker 托管
- Neo4j 由 Docker 托管
- 暂未执行 `make env-server`
- 暂未配置认证、API Key、SSL

这意味着它更适合：

- 本机自测
- 内网环境验证
- 先把系统跑起来，再补安全配置

如果你要正式对外提供服务，下一步应该继续做：

```bash
make env-server
make env-security-check
```

## 14. 常见问题排查

### 14.1 `make env-storage` 在 WSL 下报错：`invalid option nameh: line 2: set: pipefail`

这次实测中，Windows 工作区里的向导脚本是 CRLF 换行，WSL Bash 会直接解析失败。

解决办法：

- 不要用 WSL 跑这个向导
- 改用 Git Bash 执行 `make env-base`、`make env-storage`、`make env-server`

### 14.2 `docker pull neo4j:5-community` 失败，提示连不上 `registry-1.docker.io:443`

这不是 LightRAG 配置问题，而是当前机器访问 Docker Hub 失败。

常见原因：

- 网络不通
- Docker Desktop 没配代理
- Docker 镜像源不可用
- 公司网络限制了 Docker Hub

你可以这样检查：

```powershell
docker pull neo4j:5-community
```

如果单独拉这个镜像都失败，就先解决 Docker Hub 连通性，再重新执行：

```powershell
docker compose -f docker-compose.final.yml up -d
```

### 14.3 改了 PostgreSQL 用户名、密码、数据库名，但容器里没生效

这是 Docker 数据卷的正常行为。

PostgreSQL 的首次初始化只会在空数据卷上发生一次。

如果你已经启动过旧容器，再改这些值，旧库不会自动重建。

如果你明确知道自己不要旧数据，可以这样清掉卷再重建：

```powershell
docker compose -f docker-compose.final.yml down -v
docker compose -f docker-compose.final.yml up -d
```

注意：这会删除容器关联的数据卷。

## 15. 最常用的运维命令

启动：

```powershell
docker compose -f docker-compose.final.yml up -d
```

停止：

```powershell
docker compose -f docker-compose.final.yml down
```

重启：

```powershell
docker compose -f docker-compose.final.yml restart
```

查看状态：

```powershell
docker compose -f docker-compose.final.yml ps
```

查看全部日志：

```powershell
docker compose -f docker-compose.final.yml logs -f
```

只看 LightRAG 日志：

```powershell
docker compose -f docker-compose.final.yml logs -f lightrag
```

## 16. 对纯小白的最终建议

如果你是第一次部署，按下面顺序做最稳：

1. 先确认 Docker Desktop 已启动。
2. 先跑 `make env-base`，只生成基础 `.env`。
3. 再跑 `make env-storage`，把存储切到 PostgreSQL + Neo4j。
4. 先用 `docker compose -f docker-compose.final.yml config -q` 做校验。
5. 校验通过后，再 `up -d`。
6. 最后用 `/health` 和 `/webui` 验证结果。

不要一上来就同时改很多配置。先跑通，再逐步加认证、SSL、外网访问，是最省心的办法。
