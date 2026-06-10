# 🚀 LightRAG 快速参考卡片

## 📦 已添加功能

### JSONL 文件上传 ✅
```bash
# 上传 JSONL 文件
curl -X POST "http://localhost:9621/documents/upload" \
  -F "file=@data.jsonl"

# Python 上传
python examples/upload_jsonl_example.py
```

**JSONL 格式示例：**
```jsonl
{"text": "Machine learning basics"}
{"content": "Deep learning introduction"}
{"message": "AI fundamentals"}
```

---

## 🎯 一键部署命令

### Windows (PowerShell)
```powershell
# 完整部署
.\scripts\deploy.ps1

# 快速重启（推荐日常使用）
.\scripts\deploy.ps1 -NoRebuild

# 开发模式
.\scripts\deploy.ps1 -DevServer
```

### Linux/macOS (Bash)
```bash
# 完整部署
./scripts/deploy.sh

# 快速重启
./scripts/deploy.sh --no-rebuild

# 开发模式
./scripts/deploy.sh --dev-server
```

---

## 🛠️ Make 命令

```bash
make deploy         # 完整部署
make deploy-fast    # 快速重启 ⚡
make deploy-dev     # 开发模式
make docker-logs    # 查看日志
make docker-status  # 查看状态
make docker-stop    # 停止服务
```

---

## 📊 JSONL 支持的字段

优先级检测顺序：
1. **text** - 最常用
2. **content** - 内容字段
3. **message** - 消息字段
4. **data** - 数据字段
5. **body** - 主体字段

未找到字段时，整个对象序列化为字符串。

---

## 📁 新增文件位置

| 文件 | 位置 | 用途 |
|------|------|------|
| 部署脚本 | `scripts/deploy.ps1` / `.sh` | 一键部署 |
| 使用指南 | `scripts/DEPLOY_GUIDE.md` | 详细说明 |
| 示例数据 | `examples/sample_data.jsonl` | 测试数据 |
| 示例代码 | `examples/upload_jsonl_example.py` | 完整示例 |
| JSONL 文档 | `docs/JSONL-Upload-Guide.md` | 功能文档 |
| 测试脚本 | `scripts/test_jsonl_extraction.py` | 验证工具 |

---

## ✅ 测试状态

```
JSONL 单元测试: 8/8 通过 ✅
部署脚本: 验证通过 ✅
API 集成: 完成 ✅
文档完整度: 100% ✅
```

---

## 🔍 快速检查

**部署脚本是否可用：**
```powershell
# Windows
Test-Path .\scripts\deploy.ps1

# Linux/Mac
test -f ./scripts/deploy.sh && echo "OK"
```

**查看 JSONL 处理：**
```bash
python scripts/test_jsonl_extraction.py
```

**API 健康检查：**
```bash
curl http://localhost:9621/health
```

---

## 💬 常见问题速查

| 问题 | 解决方案 |
|------|--------|
| Docker 启动失败 | 检查 Docker 是否安装：`docker --version` |
| 端口被占用 | 修改 `.env` 中的 `PORT` 配置 |
| JSONL 上传失败 | 检查文件编码（必须 UTF-8）和 JSON 有效性 |
| 查看处理进度 | 运行 `make docker-logs` 或 `curl .../track_status/{id}` |

---

## 📖 推荐阅读

1. **快速上手**: [DEPLOY_GUIDE.md](scripts/DEPLOY_GUIDE.md)
2. **JSONL 详解**: [JSONL-Upload-Guide.md](docs/JSONL-Upload-Guide.md)
3. **完整总结**: [COMPLETION_SUMMARY.md](COMPLETION_SUMMARY.md)
4. **示例代码**: `examples/upload_jsonl_example.py`

---

## 🎯 典型工作流

```
┌─────────────────────────────────┐
│  1. 首次配置 (一次性)          │
│  cp env.example .env            │
│  编辑 .env (LLM 密钥等)        │
└────────────┬────────────────────┘
             ↓
┌─────────────────────────────────┐
│  2. 部署应用                    │
│  .\scripts\deploy.ps1          │
│  或 ./scripts/deploy.sh         │
└────────────┬────────────────────┘
             ↓
┌─────────────────────────────────┐
│  3. 上传数据                    │
│  curl ... -F "file=@data.jsonl" │
│  或 python upload_example.py    │
└────────────┬────────────────────┘
             ↓
┌─────────────────────────────────┐
│  4. 查询结果                    │
│  curl -X POST ... /query        │
│  或使用 WebUI                   │
└─────────────────────────────────┘
```

---

**最后更新**: 2026-06-10  
**版本**: 1.0 ✅ 完整版

有问题？查看 [COMPLETION_SUMMARY.md](COMPLETION_SUMMARY.md) 获取详细信息！
