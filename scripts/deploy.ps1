# LightRAG 一键部署脚本 (PowerShell Windows版本)
# 用途: 快速重启、重建并部署 LightRAG 容器和服务
# 用法: .\scripts\deploy.ps1 [--no-rebuild] [--no-docker] [--dev-server]

param(
    [switch]$NoRebuild = $false,
    [switch]$NoDocker = $false,
    [switch]$DevServer = $false,
    [switch]$BuildWebUI = $false
)

$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"

# 颜色定义
$InfoColor = "Cyan"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$ErrorColor = "Red"

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $InfoColor
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $SuccessColor
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $WarningColor
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $ErrorColor
}

function Check-Prerequisites {
    Write-Info "检查依赖项..."
    
    # 检查 Docker
    if (-not $NoDocker) {
        try {
            $dockerVersion = docker --version 2>$null
            Write-Success "Docker 已安装: $dockerVersion"
        }
        catch {
            Write-Error "Docker 未安装或不可用，请先安装 Docker"
            exit 1
        }
    }
    
    # 检查 .env 文件
    if (-not (Test-Path ".env")) {
        Write-Warning ".env 文件不存在，正在复制 env.example..."
        if (Test-Path "env.example") {
            Copy-Item "env.example" ".env"
            Write-Success ".env 文件已创建，请根据需要修改配置"
        }
        else {
            Write-Error "env.example 文件不存在"
            exit 1
        }
    }
    else {
        Write-Success ".env 文件已存在"
    }
}

function Stop-ExistingContainers {
    Write-Info "停止现有容器..."
    
    try {
        $containers = docker ps -q --filter "name=lightrag" 2>$null
        if ($containers) {
            docker stop $containers 2>$null | Out-Null
            Write-Success "容器已停止"
            
            # 等待容器完全停止
            Start-Sleep -Seconds 2
        }
        else {
            Write-Info "没有正在运行的 LightRAG 容器"
        }
    }
    catch {
        Write-Warning "停止容器时出错（可能不存在）: $_"
    }
}

function Clean-OldContainers {
    Write-Info "清理旧容器..."
    
    try {
        $oldContainers = docker ps -a -q --filter "name=lightrag" 2>$null
        if ($oldContainers) {
            docker rm $oldContainers 2>$null | Out-Null
            Write-Success "旧容器已清理"
        }
    }
    catch {
        Write-Warning "清理容器时出错: $_"
    }
}

function Build-WebUI {
    if ($BuildWebUI) {
        Write-Info "构建 WebUI..."
        
        if (-not (Test-Path "lightrag_webui")) {
            Write-Error "lightrag_webui 目录不存在"
            exit 1
        }
        
        Push-Location "lightrag_webui"
        try {
            # 检查 bun 或 npm
            $hasNpm = $null -ne (Get-Command npm -ErrorAction SilentlyContinue)
            $hasBun = $null -ne (Get-Command bun -ErrorAction SilentlyContinue)
            
            if ($hasBun) {
                Write-Info "使用 Bun 构建..."
                bun install --frozen-lockfile
                bun run build
            }
            elseif ($hasNpm) {
                Write-Info "使用 npm 构建..."
                npm install
                npm run build
            }
            else {
                Write-Error "未找到 Bun 或 npm，请先安装其中一个"
                exit 1
            }
            
            Write-Success "WebUI 构建完成"
        }
        catch {
            Write-Error "WebUI 构建失败: $_"
            exit 1
        }
        finally {
            Pop-Location
        }
    }
}

function Build-DockerImage {
    if ($NoRebuild) {
        Write-Info "跳过镜像重建 (使用 --no-rebuild 标志)"
        return
    }
    
    Write-Info "构建 Docker 镜像..."
    
    try {
        docker build -t lightrag:latest `
            -f Dockerfile `
            --progress=plain `
            . 2>&1
        
        Write-Success "Docker 镜像构建完成"
    }
    catch {
        Write-Error "Docker 镜像构建失败: $_"
        exit 1
    }
}

function Start-DockerContainer {
    if ($NoDocker) {
        Write-Info "跳过 Docker 容器启动 (使用 --no-docker 标志)"
        return
    }
    
    Write-Info "启动 Docker 容器..."
    
    try {
        # 读取 .env 文件中的港口配置，默认为 9621
        $port = "9621"
        $envContent = Get-Content ".env" -ErrorAction SilentlyContinue
        if ($envContent -match "PORT\s*=\s*(\d+)") {
            $port = $matches[1]
        }
        
        # 启动容器
        docker compose up -d --remove-orphans
        
        Write-Success "Docker 容器已启动"
        Write-Info "等待服务就绪..."
        Start-Sleep -Seconds 3
        
        # 检查服务健康状态
        $healthUrl = "http://localhost:$port/health"
        $maxAttempts = 30
        $attempt = 0
        
        while ($attempt -lt $maxAttempts) {
            try {
                $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    Write-Success "服务已就绪 ($healthUrl)"
                    Write-Info "✨ LightRAG API 地址: http://localhost:$port"
                    Write-Info "📊 WebUI 地址: http://localhost:$port/docs"
                    return
                }
            }
            catch {
                # 还未就绪，继续等待
            }
            
            $attempt++
            Start-Sleep -Seconds 1
        }
        
        Write-Warning "服务启动可能未完成，但容器已运行"
        Write-Info "✨ LightRAG API 地址: http://localhost:$port"
        Write-Info "📊 WebUI 地址: http://localhost:$port/docs"
    }
    catch {
        Write-Error "启动 Docker 容器失败: $_"
        exit 1
    }
}

function Start-DevServer {
    if (-not $DevServer) {
        return
    }
    
    Write-Info "启动开发服务器..."
    
    try {
        # 激活虚拟环境
        if (Test-Path ".venv\Scripts\Activate.ps1") {
            & ".\.venv\Scripts\Activate.ps1"
        }
        elseif (Test-Path "venv\Scripts\Activate.ps1") {
            & ".\venv\Scripts\Activate.ps1"
        }
        else {
            Write-Warning "虚拟环境不存在，跳过激活"
        }
        
        # 设置环境变量用于 UTF-8 输出（Windows特定）
        $env:PYTHONIOENCODING = "utf-8"
        $env:PYTHONUTF8 = "1"
        
        Write-Info "启动 LightRAG 开发服务器..."
        python -m lightrag.api.lightrag_server
    }
    catch {
        Write-Error "启动开发服务器失败: $_"
        exit 1
    }
}

function Show-Status {
    Write-Info "显示服务状态..."
    
    if (-not $NoDocker) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $InfoColor
        Write-Host "Docker 容器状态:" -ForegroundColor $InfoColor
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $InfoColor
        
        docker ps --filter "name=lightrag" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Out-Host
        
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $InfoColor
    }
    
    # 显示日志提示
    if (-not $NoDocker) {
        Write-Info "查看日志命令: docker compose logs -f lightrag"
    }
}

# 主执行流程
function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor $SuccessColor
    Write-Host "║   LightRAG 一键部署脚本                  ║" -ForegroundColor $SuccessColor
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor $SuccessColor
    Write-Host ""
    
    Write-Info "部署配置:"
    Write-Info "  - 重建镜像: $(if ($NoRebuild) { '否' } else { '是' })"
    Write-Info "  - Docker: $(if ($NoDocker) { '禁用' } else { '启用' })"
    Write-Info "  - 开发服务器: $(if ($DevServer) { '是' } else { '否' })"
    Write-Info "  - 构建 WebUI: $(if ($BuildWebUI) { '是' } else { '否' })"
    Write-Host ""
    
    # 检查前置条件
    Check-Prerequisites
    Write-Host ""
    
    # 构建 WebUI (如果需要)
    if ($BuildWebUI) {
        Build-WebUI
        Write-Host ""
    }
    
    # 如果不是开发服务器模式，执行 Docker 部署
    if (-not $DevServer) {
        # 停止旧容器
        Stop-ExistingContainers
        Write-Host ""
        
        # 清理旧容器
        Clean-OldContainers
        Write-Host ""
        
        # 构建镜像
        Build-DockerImage
        Write-Host ""
        
        # 启动容器
        Start-DockerContainer
    }
    else {
        # 开发模式：直接启动 Python 服务器
        Start-DevServer
    }
    
    # 显示状态
    Write-Host ""
    Show-Status
    
    Write-Host ""
    Write-Success "部署完成！"
    Write-Host ""
}

# 运行主函数
Main
