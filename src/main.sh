#!/usr/bin/env bash
set -euo pipefail

# Proyecto 13 - Sprint 2
# Reintentos con backoff exponencial + jitter + políticas por método

# -------- Config por entorno (12-Factor III) --------
METHOD="${1:-${METHOD:-GET}}"                # Método HTTP (GET, POST, PUT)
URL="${2:-${URL:-https://example.com}}"      # Endpoint objetivo
ALLOW_POST_RETRIES=0                         # Flag por defecto (deshabilitado)
MAX_RETRIES="${MAX_RETRIES:-3}"              # Número de reintentos (no incluye el intento inicial)
BACKOFF_MS="${BACKOFF_MS:-500}"              # Retardo base en milisegundos
JITTER_PCT="${JITTER_PCT:-20}"               # Porcentaje de jitter (+/-)
TIMEOUT_S="${TIMEOUT_S:-3}"                  # Tiempo máx por request (segundos)
OUT_DIR="${OUT_DIR:-out}"                    # Directorio de evidencias
LOG_FILE="${LOG_FILE:-$OUT_DIR/log-intentos.txt}"

# Procesar argumentos extra (para flag --allow-post-retries)
for arg in "$@"; do
  if [[ "$arg" == "--allow-post-retries" ]]; then
    ALLOW_POST_RETRIES=1
  fi
done

# -------- Utilidades --------
now() { date '+%Y-%m-%d %H:%M:%S'; }

calc_delay_ms(){
    local k="$1"
    local base_ms=$(( BACKOFF_MS * (2 ** (k-1)) ))  
    local jr=$(( base_ms * JITTER_PCT / 100 ))
    if (( jr > 0 )); then
        local span=$(( 2*jr + 1 ))
        local off=$(( RANDOM % span - jr ))
        echo $(( base_ms + off ))
    else
        echo "$base_ms"
    fi
}

# Funcion que verifica la existencia del directorio.
check_dir(){
  local dir="$1"
  mkdir -p "$dir"
}

log() {
  printf "%s %s\n" "$(now)" "$*" | tee -a "$LOG_FILE" >/dev/null
}

# -------- Política de idempotencia --------
case "$METHOD" in
  GET|PUT)
    RETRIES_ENABLED=1
    log "Política: $METHOD es idempotente → reintentos habilitados (MAX_RETRIES=$MAX_RETRIES)."
    ;;
  POST)
    if [[ $ALLOW_POST_RETRIES -eq 1 ]]; then
      RETRIES_ENABLED=1
      log "Política: POST con flag --allow-post-retries → reintentos habilitados."
    else
      RETRIES_ENABLED=0
      log "Política: POST sin flag → reintentos deshabilitados."
    fi
    ;;
  *)
    log "Método $METHOD no reconocido. Abortando."
    exit 1
    ;;
esac

# Metricas
metricas(){
  local file="$OUT_DIR/metricas.csv"
  [[ -f "$file" ]] || echo -e "method\tendpoint\tlatencia_ms\treintentos\testado_final" > "$file"
  echo -e "$METHOD\t$URL\t$LATENCY_MS\t$RETRIES\t$STATE" >> "$file"
}

fallos(){
  local file="$OUT_DIR/fallos.csv"
  [[ -f "$file" ]] || echo -e "method\tendpoint\tmotivo_fallo\thttp_code\tcurl_exit" > "$file"
  echo -e "$METHOD\t$URL\t$REASON\t$HTTP_CODE\t$CURL_EXIT" >> "$file"
}

# Clasificacion de errores.
motivos() {
  # usa HTTP_CODE y CURL_EXIT del entorno
  if [[ "${CURL_EXIT:-0}" -ne 0 ]]; then
    case "$CURL_EXIT" in
      6)  REASON="dns_error" ;;
      7)  REASON="connect_error" ;;
      28) REASON="timeout" ;;
      35) REASON="ssl_error" ;;
      *)  REASON="net_error" ;;
    esac
    FINAL_EXIT=2; return
  fi

  if [[ "${HTTP_CODE:-000}" == 2?? ]]; then
    REASON="ok"; FINAL_EXIT=0; return
  fi

  case "${HTTP_CODE:-000}" in
    5??) REASON="http_5xx"; FINAL_EXIT=4 ;;
    4??) REASON="http_4xx"; FINAL_EXIT=4 ;;
    3??) REASON="http_3xx"; FINAL_EXIT=4 ;; # si no sigues -L
    [0-9][0-9][0-9]) REASON="http_other"; FINAL_EXIT=4 ;;
    *) REASON="net_error"; FINAL_EXIT=2 ;;
  esac
}


# -------- Flujo principal con métricas --------
check_dir "$OUT_DIR"    # Verificamos la exitencia del directorio out
check_dir "$(dirname "$LOG_FILE")"

log "Inicio de evaluación: METHOD=$METHOD, URL=$URL, MAX_RETRIES=$MAX_RETRIES, BACKOFF_MS=${BACKOFF_MS}ms, JITTER=${JITTER_PCT}%"
START_MS=$(date +%s%3N)
success=0
HTTP_CODE=000
CURL_EXIT=0

for attempt in $(seq 1 $((MAX_RETRIES + 1))); do
  set +e   # desactiva "exit on error" temporalmente
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' -X "$METHOD" --max-time "$TIMEOUT_S" "$URL")"
  CURL_EXIT=$?   # captura código de salida real de curl
  set -e   # vuelve a activar "exit on error"
  log "Intento ${attempt}: HTTP=$HTTP_CODE (timeout=${TIMEOUT_S}s)"

  if echo "$HTTP_CODE" | grep -q '^2..$'; then
    success=1
    break
  fi

  # Control de reintentos según política
  if (( attempt < MAX_RETRIES + 1 )); then
    if [[ $RETRIES_ENABLED -eq 1 ]]; then
      delay_ms="$(calc_delay_ms "$attempt")"
      delay_s="$(awk -v ms="$delay_ms" 'BEGIN{printf "%.3f", ms/1000}')"
      log "Reintento programado en ${delay_ms} ms (±${JITTER_PCT}%). Durmiendo ${delay_s}s…"
      sleep "$delay_s"
    else
      log "No se permiten reintentos adicionales para $METHOD. Abortando."
      break
    fi
  fi
done

if [[ $success -eq 1 ]]; then
  log "Éxito en intento ${attempt}."
else
  log "Fallo final: agotados ${attempt} intentos."
fi

END_MS=$(date +%s%3N)

# -------- Métricas --------
LATENCY_MS=$((END_MS - START_MS))
RETRIES=$((attempt - 1))
STATE="FAIL"; [[ $success -eq 1 ]] && STATE="OK"

metricas
if [[ $success -eq 1 ]]; then
  exit 0
else
  motivos         # setea REASON y FINAL_EXIT
  fallos           # usa REASON/HTTP_CODE/CURL_EXIT
  exit "$FINAL_EXIT"
fi