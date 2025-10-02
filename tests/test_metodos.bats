#!/usr/bin/env bats

# === Helpers para un servidor local de pruebas ===
# Inicia un servidor en 127.0.0.1:PORT con modos de respuesta (flip|always500|always200).
start_server() {
  local mode="$1"
  local port="$2"
  PYCODE=$(cat <<'PY'
import http.server, socketserver, threading, sys
PORT = int(sys.argv[2])
MODE = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    hit = 0
    def do_GET(self):
        Handler.hit += 1
        if MODE in ("flip", "500-then-200"):
            code = 500 if Handler.hit == 1 else 200
        elif MODE == "always500":
            code = 500
        else:
            code = 200
        self.send_response(code)
        self.end_headers()
        self.wfile.write(b"ok")

    def do_POST(self):
        # Igual política de respuesta que GET
        Handler.hit += 1
        if MODE in ("flip", "500-then-200"):
            code = 500 if Handler.hit == 1 else 200
        elif MODE == "always500":
            code = 500
        else:
            code = 200
        self.send_response(code)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, format, *args):
        return  # silenciar logs

with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
PY
)
  python3 -c "$PYCODE" "$mode" "$port" &
  SRV_PID=$!
  # Espera breve a que el puerto esté listo
  for _ in {1..20}; do
    nc -z 127.0.0.1 "$port" 2>/dev/null && break
    sleep 0.1
  done
}

stop_server() {
  [[ -n "${SRV_PID:-}" ]] && kill "$SRV_PID" 2>/dev/null || true
}

setup() {
  mkdir -p out
  rm -f out/log-intentos.txt out/metricas.csv out/fallos.csv
}

teardown() {
  stop_server
}

# --- Caso positivo: GET con fallo inicial → éxito tras reintento ---
@test "GET: falla primero (500), luego éxito tras reintento" {
  start_server "flip" 18080

  # Ejecuta el script con reintentos rápidos
  METHOD=GET URL="http://127.0.0.1:18080" MAX_RETRIES=2 BACKOFF_MS=10 TIMEOUT_S=2 OUT_DIR=out \
    run ./src/main.sh

  # Debe terminar OK
  [ "$status" -eq 0 ]

  # Valida que hubo al menos 2 intentos y que se registró el 500 antes del 200
  grep -q "Intento 1: HTTP=500" out/log-intentos.txt
  grep -q "Intento 2: HTTP=200" out/log-intentos.txt

  # Métricas con estado OK
  grep -q "^GET,http://127.0.0.1:18080,[0-9]\+,[01],OK$" <(tr '\t' ',' < out/metricas.csv)
}

# --- Caso negativo: POST duplicado → sin reintentos por defecto ---
@test "POST: por defecto NO reintenta (siempre 500) y falla" {
  start_server "always500" 18081

  METHOD=POST URL="http://127.0.0.1:18081" MAX_RETRIES=3 BACKOFF_MS=10 TIMEOUT_S=2 OUT_DIR=out \
    run ./src/main.sh

  # Política: salida 4 para HTTP 4xx/5xx
  [ "$status" -eq 4 ]

  # Debe registrar que no se permiten reintentos y solo 1 intento
  grep -q "Política: POST sin flag → reintentos deshabilitados." out/log-intentos.txt
  # Solo debe aparecer una línea de "Intento X"
  [ "$(grep -c '^.*Intento .*HTTP=' out/log-intentos.txt)" -eq 1 ]

  # fallos.csv: motivo http_5xx, curl_exit=0
  awk -F'\t' 'NR>1{print $3,$4,$5}' out/fallos.csv | grep -q "http_5xx 500 0"
}

# --- Caso negativo convertido a positivo: POST con flag permite reintento ---
@test "POST: con --allow-post-retries reintenta y puede tener éxito" {
  start_server "flip" 18082

  MAX_RETRIES=2 BACKOFF_MS=10 TIMEOUT_S=2 OUT_DIR=out \
    run ./src/main.sh POST http://127.0.0.1:18082 --allow-post-retries

  [ "$status" -eq 0 ]
  grep -q "Política: POST con flag --allow-post-retries → reintentos habilitados." out/log-intentos.txt
  grep -q "Intento 1: HTTP=500" out/log-intentos.txt
  grep -q "Intento 2: HTTP=200" out/log-intentos.txt
}