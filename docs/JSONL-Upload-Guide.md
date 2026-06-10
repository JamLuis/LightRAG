# JSONL 文件上传功能说明

本文档介绍如何使用 LightRAG 的 JSONL 文件上传和处理功能。

## 📋 什么是 JSONL？

JSONL (JSON Lines) 是一种文本格式，其中每行都是一个有效的 JSON 对象。这种格式特别适合处理大量结构化数据。

**示例 JSONL 文件：**
```jsonl
{"text": "First record with some content"}
{"text": "Second record with different content"}
{"content": "Another record using different field name"}
{"data": "Third record with yet another structure"}
```

## ✨ 支持的字段

LightRAG 的 JSONL 处理器会自动查找以下常见字段来提取内容：

1. **`text`** - 最常见的文本字段
2. **`content`** - 内容字段
3. **`message`** - 消息字段
4. **`data`** - 数据字段
5. **`body`** - 主体字段

如果 above 字段都不存在，整个 JSON 对象会被序列化为字符串进行处理。

## 🚀 快速开始

### 1. 通过 cURL 上传 JSONL 文件

```bash
curl -X POST "http://localhost:9621/documents/upload" \
  -F "file=@data.jsonl"
```

### 2. 通过 Python 脚本上传

```python
import requests

with open("data.jsonl", "rb") as f:
    files = {"file": ("data.jsonl", f, "application/x-jsonl")}
    response = requests.post(
        "http://localhost:9621/documents/upload",
        files=files
    )

print(response.json())
```

### 3. 查看完整示例

详见 [examples/upload_jsonl_example.py](upload_jsonl_example.py)

运行示例：
```bash
# 确保服务运行在 http://localhost:9621
python examples/upload_jsonl_example.py
```

## 📝 JSONL 文件格式指南

### 基础格式

每行必须是一个完整的 JSON 对象。例如：

```jsonl
{"text": "First document"}
{"text": "Second document"}
{"text": "Third document"}
```

### 带有元数据的格式

```jsonl
{"text": "Machine learning content", "source": "tutorial"}
{"text": "AI research paper", "source": "arxiv", "year": 2023}
{"content": "Another document", "author": "John Doe"}
```

### 混合字段格式

由于字段自动检测，可以在同一文件中使用不同的字段名：

```jsonl
{"text": "First document"}
{"content": "Second document"}
{"message": "Third document"}
{"data": "Fourth document"}
```

## ⚠️ 注意事项

### 1. 编码要求
- JSONL 文件必须使用 UTF-8 编码
- 确保所有特殊字符都正确转义

### 2. JSON 有效性
```jsonl
✅ {"text": "Valid JSON"}
❌ {"text": "Invalid JSON with unescaped quote: ""}
❌ Not a JSON object
```

### 3. 空行处理
- 空行会被自动跳过
- 无效的 JSON 行会被记录警告并跳过

### 4. 大文件处理
- 单个文件大小限制默认为 100MB（可配置）
- 每行可以包含任意大小的文本

## 🔄 处理流程

### 1. 上传阶段
```bash
curl -X POST "http://localhost:9621/documents/upload" \
  -F "file=@data.jsonl"
```

响应：
```json
{
  "status": "success",
  "message": "File 'data.jsonl' uploaded successfully. Processing will continue in background.",
  "track_id": "upload_20260610_123456_abc123"
}
```

### 2. 处理阶段
系统会自动：
- 逐行解析 JSON
- 提取文本内容
- 构建知识图谱
- 创建向量索引

### 3. 查询阶段
处理完成后，可以查询数据：
```json
{
  "query": "Tell me about machine learning",
  "param": {
    "mode": "hybrid",
    "top_k": 5
  }
}
```

## 📊 检查处理状态

### 查看单个文件状态
```bash
curl "http://localhost:9621/documents/track_status/{track_id}"
```

### 查看整体统计
```bash
curl "http://localhost:9621/documents/status_counts"
```

响应示例：
```json
{
  "all": 156,
  "processed": 150,
  "preprocessing": 3,
  "processing": 2,
  "failed": 1
}
```

## 🛠️ 高级用法

### 通过 API 直接上传文本数据

如果你想逐行发送数据而不创建文件：

```python
import requests

# 单条文本
response = requests.post(
    "http://localhost:9621/documents/text",
    json={
        "text": "Your text content",
        "file_source": "my_data.jsonl"
    }
)

# 批量文本
response = requests.post(
    "http://localhost:9621/documents/texts",
    json={
        "texts": [
            "First document",
            "Second document",
            "Third document"
        ],
        "file_sources": [
            "my_data.jsonl",
            "my_data.jsonl",
            "my_data.jsonl"
        ]
    }
)
```

## ❓ 常见问题

### Q: 上传成功但处理失败，如何调试？

**A:** 检查处理状态和错误信息：
```bash
# 查看文件处理状态
curl "http://localhost:9621/documents"

# 查看具体错误
curl "http://localhost:9621/documents/track_status/{track_id}"
```

### Q: 如何上传特别大的 JSONL 文件？

**A:** 考虑以下方案：
1. 分割文件为多个小文件逐次上传
2. 修改 `.env` 中的 `MAX_UPLOAD_SIZE` 配置
3. 通过 `batch text` API 逐行发送

### Q: JSONL 文件中的字段顺序重要吗？

**A:** 不重要。字段顺序不会影响处理结果。处理器会查找匹配的字段名。

### Q: 支持嵌套 JSON 对象吗？

**A:** 部分支持。如果指定字段（如 `text`）指向字符串，会正确处理。如果指向对象，会转换为字符串。例如：
```jsonl
{"text": "Simple string - works fine"}
{"data": {"nested": "object"} - will be converted to string}
```

## 📚 示例数据集

### 新闻文章
```jsonl
{"text": "Breaking: New AI model surpasses benchmarks"}
{"text": "Tech giant announces partnership with startup"}
```

### 聊天记录
```jsonl
{"message": "Hello, how can I help?"}
{"message": "I need information about your services"}
```

### API 日志
```jsonl
{"data": "Request to /api/users completed in 245ms"}
{"data": "Database query executed successfully"}
```

## 🔐 安全性考虑

1. **认证**：如果启用了 API 认证，需要添加 `-H "X-API-Key: your-api-key"`
2. **大小限制**：使用 `MAX_UPLOAD_SIZE` 防止滥用
3. **私密数据**：确保不上传包含敏感信息的数据

## 📞 获取帮助

遇到问题时：

1. 查看 LightRAG 日志：`docker compose logs -f lightrag`
2. 检查文件格式：每行必须是有效的 JSON
3. 验证编码：确保 UTF-8 编码无 BOM
4. 查看 API 文档：`http://localhost:9621/docs`

---

**功能引入日期**: 2026-06-10

**相关文档**:
- [LightRAG API 文档](../docs/LightRAG-API-Server-zh.md)
- [文件处理流水线](../docs/FileProcessingPipeline-zh.md)
- [示例代码](upload_jsonl_example.py)
