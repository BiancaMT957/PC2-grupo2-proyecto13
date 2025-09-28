#!/usr/bin/env bats

setup() {
  # Carpeta de salida para logs/CSV si no existe
  mkdir -p out
}

@test "Caso rojo: endpoint que siempre falla" {
  run src/main.sh http://localhost:9999   # puerto cerrado
  [ "$status" -ne 0 ]                     # Debe fallar
}

@test "Caso verde: endpoint falla 1 vez y luego responde" {
  # --- Servidor Python "flaky": 1er request = 500, luego 200 ---
  python3 - <<'EOF' &
from http.server import BaseHTTPRequestHandler, HTTPServer
attempts = {'count': 0}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if attempts['count'] == 0:
            attempts['count'] += 1
            self.send_error(500, "Simulated failure")   # Primera vez falla
        else:
            self.send_response(200)                    # Luego responde OK
            self.end_headers()
            self.wfile.write(b"OK")

HTTPServer(("localhost", 8080), Handler).serve_forever()
EOF
  server_pid=$!
  sleep 1   # da tiempo a levantar el server

  run src/main.sh http://localhost:8080

  kill $server_pid
  wait $server_pid 2>/dev/null || true

  [ "$status" -eq 0 ]     # Debe terminar en éxito tras reintento
}