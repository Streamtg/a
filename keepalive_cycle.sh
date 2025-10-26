#!/usr/bin/env bash
# keepalive_cycle.sh
# Mantiene la máquina "activa" durante 2 minutos cada 5 horas sin root.
# Genera carga de CPU y red local (loopback) de forma segura.

set -euo pipefail

CPU_WORKERS=${CPU_WORKERS:-2}        # núm. procesos CPU
CPU_INTENSITY=${CPU_INTENSITY:-0.9}  # carga CPU (0–1)
NET_WORKERS=${NET_WORKERS:-2}        # núm. procesos red
NET_RATE=${NET_RATE:-10}             # reqs/s por worker
HTTP_PORT=${HTTP_PORT:-8081}         # puerto local
DURATION=${DURATION:-120}            # 2 minutos (segundos)
INTERVAL=${INTERVAL:-18000}          # 5 horas (segundos)

WORKDIR="/tmp/keepalive_cycle"
mkdir -p "$WORKDIR"

CPU_SCRIPT="$WORKDIR/cpu_worker.py"
NET_SCRIPT="$WORKDIR/net_worker.sh"
SERVER_SCRIPT="$WORKDIR/server.py"

# ---------- Genera scripts auxiliares ----------
cat > "$SERVER_SCRIPT" <<'PY'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"ok"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, format, *args): return
if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8081
    HTTPServer(("127.0.0.1", port), H).serve_forever()
PY

cat > "$CPU_SCRIPT" <<'PY'
#!/usr/bin/env python3
import hashlib, os, time, sys
intensity = float(sys.argv[1]) if len(sys.argv) > 1 else 0.9
busy, idle = intensity * 0.1, max(0.00001, (1 - intensity) * 0.1)
data = os.urandom(1024)
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

chmod +x "$SERVER_SCRIPT" "$CPU_SCRIPT" "$NET_SCRIPT"

# ---------- Ciclo principal ----------
echo "Iniciando ciclo keepalive (cada 5h por 2min)..."
while true; do
  echo "[*] $(date '+%F %T') Iniciando carga por ${DURATION}s..."
  
  python3 "$SERVER_SCRIPT" "$HTTP_PORT" &
  SERVER_PID=$!
  
  PIDS=()
  for i in $(seq 1 $CPU_WORKERS); do
    python3 "$CPU_SCRIPT" "$CPU_INTENSITY" &
    PIDS+=($!)
  done
  for i in $(seq 1 $NET_WORKERS); do
    bash "$NET_SCRIPT" "$HTTP_PORT" "$NET_RATE" &
    PIDS+=($!)
  done

  sleep "$DURATION"
  kill "$SERVER_PID" >/dev/null 2>&1 || true
  for pid in "${PIDS[@]}"; do kill "$pid" >/dev/null 2>&1 || true; done
  echo "[*] $(date '+%F %T') Carga detenida. Próxima en 5 horas."
  sleep "$INTERVAL"
done
