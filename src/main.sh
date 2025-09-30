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

mkdir -p "$OUT_DIR"
: > "$LOG_FILE"

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

# -------- Flujo principal con métricas --------
START_MS=$(date +%s%3N)
success=0

log "Inicio de evaluación: METHOD=$METHOD, URL=$URL, MAX_RETRIES=$MAX_RETRIES, BACKOFF_MS=${BACKOFF_MS}ms, JITTER=${JITTER_PCT}%"

for attempt in $(seq 1 $((MAX_RETRIES + 1))); do
  http_code="$(curl -sS -o /dev/null -w '%{http_code}' -X "$METHOD" --max-time "$TIMEOUT_S" "$URL" || echo '000')"
  log "Intento ${attempt}: HTTP=$http_code (timeout=${TIMEOUT_S}s)"

  if echo "$http_code" | grep -q '^2..$'; then
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
STATE="FAIL"
[[ $success -eq 1 ]] && STATE="OK"

METRICS_FILE="$OUT_DIR/metricas.csv"
if [[ ! -f "$METRICS_FILE" ]]; then
    echo -e "method\tendpoint\tlatencia_ms\treintentos\testado_final" > "$METRICS_FILE"
fi
echo -e "$METHOD\t$URL\t$LATENCY_MS\t$RETRIES\t$STATE" >> "$METRICS_FILE"

[[ $success -eq 1 ]] && exit 0 || exit 1


