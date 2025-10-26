#!/usr/bin/env bash
# keepalive_cycle_io.sh
# Mantiene la máquina activa (CPU + red + disco) 2 min cada 5 h sin root.

set -euo pipefail

# ⚙️ Parámetros configurables
CPU_WORKERS=${CPU_WORKERS:-2}
CPU_INTENSITY=${CPU_INTENSITY:-0.9}
NET_WORKERS=${NET_WORKERS:-2}
NET_RATE=${NET_RATE:-10}
IO_WORKERS=${IO_WORKERS:-2}
IO_FILE_SIZE_MB=${IO_FILE_SIZE_MB:-10}
DURATION=${DURATION:-120}        # 2 minutos
INTERVAL=${INTERVAL:-18000}      # 5 horas
HTTP_PORT=${HTTP_PORT:-8082}
WORKDIR="/tmp/keepalive_cycle_io"

mkdir -p "$WORKDIR"

# --- Generar scripts auxiliares ---
CPU_SCRIPT="$WORKDIR/cpu_worker.py"
NET_SCRIPT="$WORKDIR/net_worker.sh"
SERVER_SCRIPT="$WORKDIR/server.py"
IO_SCRIPT="$WORKDIR/io_worker.sh"

cat > "$SERVER_SCRIPT" <<'PY'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        msg = b"ok"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(msg)))
        self.end_headers()
        self.wfile.write(msg)
    def log_message(self, *args): pass
if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8082
    HTTPServer(("127.0.0.1", port), H).serve_forever()
PY

cat > "$CPU_SCRIPT" <<'PY'
#!/usr/bin/env python3
import hashlib, os, time, sys
intensity = float(sys.argv[1]) if len(sys.argv) > 1 else 0.9
busy, idle = intensity * 0.1, max(0.0001, (1 - intensity) * 0.1)
data = os.urandom(4096)
while True:
    t0 = time.time()
    while time.time() - t0 < busy:
        hashlib.sha256(data).digest()
    time.sleep(idle)
PY

cat > "$NET_SCRIPT" <<'SH'
#!/usr/bin/env bash
port=$1; rate=$2
interval=$(awk "BEGIN {print 1.0 / ($rate)}")
url="http://127.0.0.1:${port}/"
while true; do
  curl --silent --max-time 3 --output /dev/null "$url" || true
  sleep "$interval"
done
SH

cat > "$IO_SCRIPT" <<'SH'
#!/usr/bin/env bash
# io_worker.sh <file> <size_MB>
FILE=$1
SIZE_MB=${2:-10}
BLOCKS=$((SIZE_MB * 256)) # 256 * 4KB = 1MB aprox
while true; do
  dd if=/dev/urandom of="$FILE" bs=4K count=$BLOCKS conv=fsync >/dev/null 2>&1
  dd if="$FILE" of=/dev/null bs=4K >/dev/null 2>&1
  sleep 1
done
SH

chmod +x "$SERVER_SCRIPT" "$CPU_SCRIPT" "$NET_SCRIPT" "$IO_SCRIPT"

# --- Bucle principal ---
echo "[*] KeepAlive+IO iniciado (cada 5h por 2min)..."

while true; do
  echo "[$(date '+%F %T')] 🔄 Iniciando carga..."

  # Servidor local
  python3 "$SERVER_SCRIPT" "$HTTP_PORT" &
  SERVER_PID=$!

  # Procesos CPU
  PIDS=()
  for i in $(seq 1 $CPU_WORKERS); do
    python3 "$CPU_SCRIPT" "$CPU_INTENSITY" &
    PIDS+=($!)
  done

  # Procesos red
  for i in $(seq 1 $NET_WORKERS); do
    bash "$NET_SCRIPT" "$HTTP_PORT" "$NET_RATE" &
    PIDS+=($!)
  done

  # Procesos I/O (disco)
  for i in $(seq 1 $IO_WORKERS); do
    bash "$IO_SCRIPT" "$WORKDIR/io_tmp_$i.bin" "$IO_FILE_SIZE_MB" &
    PIDS+=($!)
  done

  # Esperar 2 minutos
  sleep "$DURATION"

  # Finalizar todo
  kill "$SERVER_PID" >/dev/null 2>&1 || true
  for pid in "${PIDS[@]}"; do kill "$pid" >/dev/null 2>&1 || true; done
  rm -f "$WORKDIR"/io_tmp_*.bin 2>/dev/null || true

  echo "[$(date '+%F %T')] ✅ Carga detenida. Próxima en 5h."
  sleep "$INTERVAL"
done
