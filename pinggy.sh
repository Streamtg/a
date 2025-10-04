#!/bin/bash

# CONFIGURACIÓN
LOCAL_PROXY_PORT=8080
PINGGY_USER="BkPJOM3hqWT"
PINGGY_HOST="us.pro.pinggy.io"
CHECK_INTERVAL=5

declare -A SERVICES       # Puertos detectados
declare -A PORT_BYTES     # Bytes transferidos por puerto
declare -A PORT_REQUESTS  # Requests por puerto

# -----------------------------
# Función: convertir bytes a tamaño legible
# -----------------------------
format_bytes() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        echo "$((bytes / 1073741824))GB"
    elif (( bytes >= 1048576 )); then
        echo "$((bytes / 1048576))MB"
    elif (( bytes >= 1024 )); then
        echo "$((bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}

# -----------------------------
# Función: generar barra ASCII proporcional
# -----------------------------
ascii_bar() {
    local value=$1
    local max=$2
    local width=50
    local fill=$((value * width / max))
    local bar=""
    for ((i=0;i<fill;i++)); do
        bar+="#"
    done
    for ((i=fill;i<width;i++)); do
        bar+=" "
    done
    echo "[$bar]"
}

# -----------------------------
# Función: iniciar proxy FastAPI integrado
# -----------------------------
start_proxy() {
    PROXY_FILE=$(mktemp /tmp/proxy_XXXX.py)
    cat > "$PROXY_FILE" << 'EOF'
from fastapi import FastAPI, Request
import httpx
import asyncio
import os

app = FastAPI()
SERVICES = {}
PORT_BYTES = {}
PORT_REQUESTS = {}

async def detect_services():
    while True:
        import subprocess
        result = subprocess.run(
            ["lsof","-n","-P","-iTCP","-sTCP:LISTEN","-u", os.environ.get("USER")],
            capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")[1:]
        for line in lines:
            parts = line.split()
            port = parts[8].split(":")[-1]
            if port not in SERVICES:
                SERVICES[port] = int(port)
                PORT_BYTES[port] = 0
                PORT_REQUESTS[port] = 0
        await asyncio.sleep(5)

@app.on_event("startup")
async def startup_event():
    import asyncio
    asyncio.create_task(detect_services())

@app.api_route("/{path:path}", methods=["GET","POST","PUT","DELETE"])
async def proxy(path: str, request: Request):
    if not SERVICES:
        return {"error": "No hay servicios locales detectados"}
    port = list(SERVICES.values())[0]
    async with httpx.AsyncClient() as client:
        body = await request.body()
        resp = await client.request(
            request.method,
            f"http://127.0.0.1:{port}/{path}",
            content=body,
            headers=dict(request.headers)
        )
        PORT_BYTES[str(port)] += len(body) + len(resp.content)
        PORT_REQUESTS[str(port)] += 1
    return resp.content
EOF

    uvicorn "$PROXY_FILE":app --host 0.0.0.0 --port $LOCAL_PROXY_PORT &
    PROXY_PID=$!
    echo "[INFO] Proxy FastAPI iniciado en localhost:$LOCAL_PROXY_PORT (PID $PROXY_PID)"
}

# -----------------------------
# Función: iniciar Pinggy (un solo túnel)
# -----------------------------
start_pinggy() {
    while true; do
        ssh -p 443 \
            -R0:localhost:$LOCAL_PROXY_PORT \
            -Rstreammgram.a.pinggy.link:0:localhost:$LOCAL_PROXY_PORT \
            -o StrictHostKeyChecking=no \
            -o ServerAliveInterval=30 \
            $PINGGY_USER@$PINGGY_HOST
        echo "[WARN] Pinggy desconectado, reconectando en 5s..."
        sleep 5
    done &
    PINGGY_PID=$!
}

# -----------------------------
# Función: mostrar dashboard
# -----------------------------
show_dashboard() {
    clear
    echo -e "\e[1;34m=============================="
    echo " Pinggy-ngrok integrated dashboard "
    echo "==============================\e[0m"

    echo "Servicios locales detectados:"
    total_bytes=0
    total_requests=0
    max_bytes=1

    # Calculamos el máximo de bytes para escalar barras
    for port in "${!PORT_BYTES[@]}"; do
        (( PORT_BYTES[$port] > max_bytes )) && max_bytes=${PORT_BYTES[$port]}
    done

    for port in "${!PORTES[@]}"; do :; done

    for port in "${!SERVICES[@]}"; do
        bytes=${PORT_BYTES[$port]:-0}
        requests=${PORT_REQUESTS[$port]:-0}
        bar=$(ascii_bar $bytes $max_bytes)
        size=$(format_bytes $bytes)
        echo -e "🌐 localhost:$port -> $size | Requests: $requests\n    $bar"
        (( total_bytes+=bytes ))
        (( total_requests+=requests ))
    done

    echo -e "\nResumen total:"
    echo "📊 Bytes totales: $(format_bytes $total_bytes)"
    echo "📈 Requests totales: $total_requests"

    echo -e "\nProxy principal: localhost:$LOCAL_PROXY_PORT"
    echo "Expuesto a Internet (Pinggy): http://streammgram.a.pinggy.link"
    echo -e "=============================="
}

# -----------------------------
# MAIN
# -----------------------------
start_proxy
start_pinggy

while true; do
    show_dashboard
    sleep $CHECK_INTERVAL
done
