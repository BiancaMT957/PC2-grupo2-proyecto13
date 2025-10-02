#!/usr/bin/env bats

setup() {
  mkdir -p out
  rm -f out/log-intentos.txt out/metricas.csv out/fallos.csv
}

# --- Timeout local: servidor que tarda más de TIMEOUT_S en responder ---
@test "Timeout: debe registrarse como 'timeout' (net) y salir con 2" {
  # Servidor local: duerme 5s antes de responder 200
  python3 - <<'EOF' &
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        time.sleep(5)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")
    def log_message(self, *a, **k): pass
HTTPServer(("127.0.0.1", 18090), H).serve_forever()
EOF
  srv_pid=$!
  sleep 0.5

  METHOD=GET URL="http://127.0.0.1:18090" MAX_RETRIES=0 TIMEOUT_S=1 OUT_DIR=out \
    run ./src/main.sh

  kill $srv_pid
  wait $srv_pid 2>/dev/null || true

  [ "$status" -eq 2 ]  # net_error (timeout)
  # Leer la primera fila de datos (NR==2): motivo y curl_exit
  read motivo curl_exit < <(awk -F'\t' 'NR==2{gsub(/\r/,""); print $3, $5}' out/fallos.csv)
  [[ "$motivo" = "timeout" ]]
  [[ "$curl_exit" -eq 28 ]]
}

# --- HTTP 500 local: siempre responde 500 ---
@test "HTTP 500: debe registrarse como http_5xx y salir con 4" {
  python3 - <<'EOF' &
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(500)
        self.end_headers()
        self.wfile.write(b"FAIL")
    def log_message(self, *a, **k): pass
HTTPServer(("127.0.0.1", 18091), H).serve_forever()
EOF
  srv_pid=$!
  sleep 0.5

  METHOD=GET URL="http://127.0.0.1:18091" MAX_RETRIES=0 TIMEOUT_S=2 OUT_DIR=out \
    run ./src/main.sh

  kill $srv_pid
  wait $srv_pid 2>/dev/null || true

  [ "$status" -eq 4 ]
  # Leer motivo, http_code y curl_exit de la primera fila de datos
  read motivo http_code curl_exit < <(awk -F'\t' 'NR==2{gsub(/\r/,""); print $3, $4, $5}' out/fallos.csv)
  [[ "$motivo" = "http_5xx" ]]
  [[ "$http_code" -eq 500 ]]
  [[ "$curl_exit" -eq 0 ]]
}