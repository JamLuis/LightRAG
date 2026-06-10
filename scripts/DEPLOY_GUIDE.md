# LightRAG 部署脚本指南

本指南介绍如何使用一键化部署脚本快速启动和管理 LightRAG 服务。

## 📋 目录

- [快速开始](#快速开始)
- [Windows 用户 (PowerShell)](#windows-用户-powershell)
  - [基础用法](#基础用法)
  - [高级选项](#高级选项)
  - [示例](#示例)
- [Linux/Mac 用户 (Bash)](#linuxmac-用户-bash)
  - [基础用法](#基础用法-1)
  - [高级选项](#高级选项-1)
  - [示例](#示例-1)
- [脚本功能](#脚本功能)
- [常见问题](#常见问题)

## 🚀 快速开始

### Windows (PowerShell)

```powershell
# 一键启动（重建镜像 + 启动容器）
.\scripts\deploy.ps1

# 快速重启（不重建镜像）
.\scripts\deploy.ps1 -NoRebuild
```

### Linux/Mac (Bash)

```bash
# 一键启动（重建镜像 + 启动容器）
./scripts/deploy.sh

# 快速重启（不重建镜像）
./scripts/deploy.sh --no-rebuild
```

## Windows 用户 (PowerShell)

### 基础用法

```powershell
.\scripts\deploy.ps1
```

这个命令将：
1. ✅ 检查 Docker 和 .env 文件
2. ✅ 停止现有容器
3. ✅ 清理旧容器
4. ✅ 重新构建 Docker 镜像
5. ✅ 启动新容器
6. ✅ 显示服务状态

### 高级选项

| 选项 | 说明 |
|------|------|
| `-NoRebuild` | 跳过镜像重建，直接使用现有镜像快速启动 |
| `-NoDocker` | 禁用 Docker，仅进行初始化检查 |
| `-DevServer` | 启动本地开发服务器而不是 Docker 容器 |
| `-BuildWebUI` | 同时构建前端 WebUI |

### 示例

#### 例1：快速重启（不重建镜像，节省时间）

```powershell
.\scripts\deploy.ps1 -NoRebuild
```

输出示例：
```
ℹ️  检查依赖项...
✅ Docker 已安装: Docker version 24.0.0, build abc123
✅ .env 文件已存在

ℹ️  停止现有容器...
✅ 容器已停止

ℹ️  清理旧容器...
✅ 旧容器已清理

ℹ️  跳过镜像重建 (使用 --no-rebuild 标志)

ℹ️  启动 Docker 容器...
✅ Docker 容器已启动
ℹ️  等待服务就绪...
✅ 服务已就绪 (http://localhost:9621/health)
✨ LightRAG API 地址: http://localhost:9621
📊 WebUI 地址: http://localhost:9621/docs
```

#### 例2：完整部署（包含 WebUI 构建）

```powershell
.\scripts\deploy.ps1 -BuildWebUI
```

#### 例3：开发模式（本地 Python 服务器）

```powershell
.\scripts\deploy.ps1 -DevServer
```

这将激活虚拟环境并直接运行 Python 服务器（用于开发测试）。

## Linux/Mac 用户 (Bash)

### 基础用法

```bash
./scripts/deploy.sh
```

这个命令将执行与 Windows 相同的操作。

### 高级选项

| 选项 | 说明 |
|------|------|
| `--no-rebuild` | 跳过镜像重建 |
| `--no-docker` | 禁用 Docker |
| `--dev-server` | 启动开发服务器 |
| `--build-webui` | 构建前端 WebUI |

### 示例

#### 例1：快速重启

```bash
./scripts/deploy.sh --no-rebuild
```

#### 例2：完整部署

```bash
./scripts/deploy.sh --build-webui
```

#### 例3：开发模式

```bash
./scripts/deploy.sh --dev-server
```

#### 例4：组合选项

```bash
# 快速重启 + 构建 WebUI
./scripts/deploy.sh --no-rebuild --build-webui
```

## 🔧 脚本功能

### 1. **前置条件检查** ✅

- 验证 Docker 可用性
- 确认 Docker Compose 已安装
- 检查 `.env` 配置文件
- 自动从 `env.example` 复制（如不存在）

### 2. **容器管理** 🐳

- **停止容器**：优雅地停止现有 LightRAG 容器
- **清理旧容器**：删除已停止的容器
- **重建镜像**：根据 Dockerfile 重新构建镜像
- **启动容器**：使用 `docker compose up` 启动服务

### 3. **健康检查** 🏥

脚本在启动容器后会自动检查服务健康状态：
- 定期向 `/health` 端点发送请求
- 最多尝试 30 次（每次间隔 1 秒）
- 服务就绪时显示访问地址

### 4. **构建支持** 🔨

- **WebUI 构建**：自动检测 Bun 或 npm，构建前端资源
- **Python 服务器**：支持开发模式直接运行

### 5. **状态报告** 📊

脚本完成后会显示：
- 容器名称、运行状态、端口映射
- 查看日志的命令
- 访问 API 和 WebUI 的地址

## 🛠️ 常见问题

### Q1: 脚本提示 "Docker 未安装"

**A:** 请先安装 Docker:
- **Windows**: [Docker Desktop](https://www.docker.com/products/docker-desktop)
- **Linux**: `sudo apt-get install docker.io docker-compose-plugin`
- **Mac**: [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)

### Q2: 容器启动后速度很慢

**A:** 第一次启动会构建镜像，这可能需要几分钟。后续可用 `-NoRebuild` / `--no-rebuild` 跳过重建。

### Q3: 端口 9621 被占用

**A:** 修改 `.env` 文件中的 `PORT` 配置：
```env
PORT=9622  # 改为其他未被占用的端口
```

### Q4: 如何查看容器日志

**A:** 使用以下命令：
```bash
# Docker
docker compose logs -f lightrag

# 仅查看最近 100 行
docker compose logs -f lightrag --tail 100
```

### Q5: 如何更新代码后重新部署

**A:** 无需手动操作，直接运行脚本：
```powershell
# Windows
.\scripts\deploy.ps1

# Linux/Mac
./scripts/deploy.sh
```

脚本会自动检测变化并重建镜像。

### Q6: 开发模式 (`--dev-server`) 与 Docker 模式有什么区别

**A:**
| 方面 | 开发模式 | Docker 模式 |
|------|---------|-----------|
| 启动方式 | 直接运行 Python | 在容器内运行 |
| 构建速度 | 快 | 慢 |
| 立即反映代码变化 | 是（需重启） | 否（需重建镜像） |
| 生产推荐 | ❌ | ✅ |
| 调试友好 | ✅ | ❌ |

## 📝 环境变量配置

脚本会自动检查 `.env` 文件。重要的环境变量包括：

```env
# 服务器配置
HOST=0.0.0.0
PORT=9621

# 存储目录
WORKING_DIR=./data/rag_storage
INPUT_DIR=./data/inputs
PROMPT_DIR=./data/prompts

# LLM 配置（示例）
OPENAI_API_KEY=your-api-key
OPENAI_MODEL_NAME=gpt-4o-mini

# 其他配置...
```

详见 `env.example` 文件。

## 💡 使用建议

1. **首次部署**：使用完整部署命令
   ```powershell
   .\scripts\deploy.ps1
   ```

2. **日常重启**：使用快速重启，节省时间
   ```powershell
   .\scripts\deploy.ps1 -NoRebuild
   ```

3. **代码更新后**：使用完整部署以确保镜像最新
   ```powershell
   .\scripts\deploy.ps1
   ```

4. **开发调试**：使用开发服务器模式
   ```powershell
   .\scripts\deploy.ps1 -DevServer
   ```

## 🔐 安全性说明

- 脚本不会删除 `.env` 文件或数据目录
- 所有容器操作都是安全的，不会影响其他容器
- 建议定期备份 `data/rag_storage` 目录

## 📞 获取帮助

如遇问题，请提供以下信息：

1. 运行脚本时的完整错误日志
2. Docker 版本：`docker --version`
3. Docker Compose 版本：`docker compose version`
4. 系统信息：`uname -a` (Linux/Mac) 或 Windows 版本
5. `.env` 文件内容（敏感信息可省略）

---

**最后更新**: 2026-06-10
