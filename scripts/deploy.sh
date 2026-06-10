#!/bin/bash

# LightRAG 一键部署脚本 (Bash Linux/Mac版本)
# 用途: 快速重启、重建并部署 LightRAG 容器和服务
# 用法: ./scripts/deploy.sh [--no-rebuild] [--no-docker] [--dev-server] [--build-webui]

set -e

# 颜色定义
INFO='\033[0;36m'      # Cyan
SUCCESS='\033[0;32m'   # Green
WARNING='\033[0;33m'   # Yellow
ERROR='\033[0;31m'     # Red
NC='\033[0m'          # No Color

# 配置参数
NO_REBUILD=false
NO_DOCKER=false
DEV_SERVER=false
BUILD_WEBUI=false
PYTHON_CMD="python3"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-rebuild)
            NO_REBUILD=true
            shift
            ;;
        --no-docker)
            NO_DOCKER=true
            shift
            ;;
        --dev-server)
            DEV_SERVER=true
            shift
            ;;
        --build-webui)
            BUILD_WEBUI=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# 日志函数
log_info() {
    echo -e "${INFO}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${SUCCESS}✅ $1${NC}"
}

log_warning() {
    echo -e "${WARNING}⚠️  $1${NC}"
}

log_error() {
    echo -e "${ERROR}❌ $1${NC}"
}

log_header() {
    echo -e "\n${SUCCESS}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${SUCCESS}$1${NC}"
    echo -e "${SUCCESS}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 检查前置条件
check_prerequisites() {
    log_info "检查依赖项..."
    
    if [ "$NO_DOCKER" = false ]; then
        if ! command -v docker &> /dev/null; then
            log_error "Docker 未安装，请先安装 Docker"
            exit 1
        fi
        log_success "Docker 已安装"
        
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            log_error "Docker Compose 未安装，请先安装 Docker Compose"
            exit 1
        fi
        log_success "Docker Compose 已安装"
    fi
    
    # 检查 .env 文件
    if [ ! -f ".env" ]; then
        log_warning ".env 文件不存在，正在复制 env.example..."
        if [ -f "env.example" ]; then
            cp "env.example" ".env"
            log_success ".env 文件已创建，请根据需要修改配置"
        else
            log_error "env.example 文件不存在"
            exit 1
        fi
    else
        log_success ".env 文件已存在"
    fi
}

# 停止现有容器
stop_existing_containers() {
    log_info "停止现有容器..."
    
    if docker ps -q --filter "name=lightrag" 2>/dev/null | grep -q .; then
        docker stop $(docker ps -q --filter "name=lightrag") 2>/dev/null || true
        log_success "容器已停止"
        sleep 2
    else
        log_info "没有正在运行的 LightRAG 容器"
    fi
}

# 清理旧容器
clean_old_containers() {
    log_info "清理旧容器..."
    
    if docker ps -a -q --filter "name=lightrag" 2>/dev/null | grep -q .; then
        docker rm $(docker ps -a -q --filter "name=lightrag") 2>/dev/null || true
        log_success "旧容器已清理"
    fi
}

# 构建 WebUI
build_webui() {
    if [ "$BUILD_WEBUI" = false ]; then
        return
    fi
    
    log_info "构建 WebUI..."
    
    if [ ! -d "lightrag_webui" ]; then
        log_error "lightrag_webui 目录不存在"
        exit 1
    fi
    
    cd lightrag_webui
    
    # 检查 bun 或 npm
    if command -v bun &> /dev/null; then
        log_info "使用 Bun 构建..."
        bun install --frozen-lockfile
        bun run build
    elif command -v npm &> /dev/null; then
        log_info "使用 npm 构建..."
        npm install
        npm run build
    else
        log_error "未找到 Bun 或 npm，请先安装其中一个"
        cd ..
        exit 1
    fi
    
    cd ..
    log_success "WebUI 构建完成"
}

# 构建 Docker 镜像
build_docker_image() {
    if [ "$NO_REBUILD" = true ]; then
        log_info "跳过镜像重建 (使用 --no-rebuild 标志)"
        return
    fi
    
    log_info "构建 Docker 镜像..."
    
    docker build -t lightrag:latest \
        -f Dockerfile \
        --progress=plain \
        . || {
        log_error "Docker 镜像构建失败"
        exit 1
    }
    
    log_success "Docker 镜像构建完成"
}

# 启动 Docker 容器
start_docker_container() {
    if [ "$NO_DOCKER" = true ]; then
        log_info "跳过 Docker 容器启动 (使用 --no-docker 标志)"
        return
    fi
    
    log_info "启动 Docker 容器..."
    
    # 读取 .env 文件中的港口配置
    PORT=$(grep "^PORT=" .env | cut -d'=' -f2 || echo "9621")
    PORT=${PORT:-9621}
    
    docker compose up -d --remove-orphans || {
        log_error "启动 Docker 容器失败"
        exit 1
    }
    
    log_success "Docker 容器已启动"
    log_info "等待服务就绪..."
    sleep 3
    
    # 检查服务健康状态
    HEALTH_URL="http://localhost:$PORT/health"
    MAX_ATTEMPTS=30
    ATTEMPT=0
    
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
            log_success "服务已就绪 ($HEALTH_URL)"
            log_info "✨ LightRAG API 地址: http://localhost:$PORT"
            log_info "📊 WebUI 地址: http://localhost:$PORT/docs"
            return
        fi
        
        ATTEMPT=$((ATTEMPT + 1))
        sleep 1
    done
    
    log_warning "服务启动可能未完成，但容器已运行"
    log_info "✨ LightRAG API 地址: http://localhost:$PORT"
    log_info "📊 WebUI 地址: http://localhost:$PORT/docs"
}

# 启动开发服务器
start_dev_server() {
    if [ "$DEV_SERVER" = false ]; then
        return
    fi
    
    log_info "启动开发服务器..."
    
    # 激活虚拟环境
    if [ -f ".venv/bin/activate" ]; then
        source ".venv/bin/activate"
    elif [ -f "venv/bin/activate" ]; then
        source "venv/bin/activate"
    else
        log_warning "虚拟环境不存在，跳过激活"
    fi
    
    export PYTHONIOENCODING=utf-8
    
    log_info "启动 LightRAG 开发服务器..."
    $PYTHON_CMD -m lightrag.api.lightrag_server
}

# 显示状态
show_status() {
    log_header "部署状态"
    
    if [ "$NO_DOCKER" = false ]; then
        docker ps --filter "name=lightrag" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        log_info "查看日志命令: docker compose logs -f lightrag"
    fi
}

# 主函数
main() {
    echo ""
    echo -e "${SUCCESS}╔════════════════════════════════════════════╗${NC}"
    echo -e "${SUCCESS}║   LightRAG 一键部署脚本                  ║${NC}"
    echo -e "${SUCCESS}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "部署配置:"
    log_info "  - 重建镜像: $([ "$NO_REBUILD" = true ] && echo '否' || echo '是')"
    log_info "  - Docker: $([ "$NO_DOCKER" = true ] && echo '禁用' || echo '启用')"
    log_info "  - 开发服务器: $([ "$DEV_SERVER" = true ] && echo '是' || echo '否')"
    log_info "  - 构建 WebUI: $([ "$BUILD_WEBUI" = true ] && echo '是' || echo '否')"
    echo ""
    
    # 检查前置条件
    check_prerequisites
    echo ""
    
    # 构建 WebUI (如果需要)
    if [ "$BUILD_WEBUI" = true ]; then
        build_webui
        echo ""
    fi
    
    # 如果不是开发服务器模式，执行 Docker 部署
    if [ "$DEV_SERVER" = false ]; then
        # 停止旧容器
        stop_existing_containers
        echo ""
        
        # 清理旧容器
        clean_old_containers
        echo ""
        
        # 构建镜像
        build_docker_image
        echo ""
        
        # 启动容器
        start_docker_container
    else
        # 开发模式：直接启动 Python 服务器
        start_dev_server
    fi
    
    # 显示状态
    echo ""
    show_status
    
    echo ""
    log_success "部署完成！"
    echo ""
}

# 捕获错误并显示消息
trap 'log_error "脚本执行出错" >&2' ERR

# 运行主函数
main "$@"
