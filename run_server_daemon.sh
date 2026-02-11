#!/usr/bin/env bash
# Godot 无头模式（守护进程）启动脚本，日志输出到文件
# 用法: ./run_server_daemon.sh  或  bash run_server_daemon.sh

set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
STDOUT_LOG="$LOG_DIR/server_stdout.log"
STDERR_LOG="$LOG_DIR/server_stderr.log"
PID_FILE="$LOG_DIR/server.pid"

mkdir -p "$LOG_DIR"

# 使用 PATH 中的 godot；若用指定路径可改下面变量，例如 "/usr/bin/godot" 或 "$HOME/Godot/Godot"
GODOT_CMD="${GODOT_CMD:-godot}"

echo "Starting Godot headless server (daemon)..."
echo "  Project: $PROJECT_DIR"
echo "  Stdout:  $STDOUT_LOG"
echo "  Stderr:  $STDERR_LOG"
echo "  Engine file log: ~/.local/share/godot/app_userdata/yearend/logs/godot.log"
echo ""

# 后台运行，标准输出/错误重定向到 logs，与当前 shell 分离
nohup "$GODOT_CMD" --headless --server --path "$PROJECT_DIR" >> "$STDOUT_LOG" 2>> "$STDERR_LOG" &
PID=$!
echo $PID > "$PID_FILE"
echo "Server started in background. PID: $PID"
echo "  Stop: kill \$(cat $PID_FILE)"
echo "  Tail log: tail -f $STDOUT_LOG"
