#!/usr/bin/env bash
set -euo pipefail

# Proyecto 13 - Sprint 1

# -------- Config por entorno (12-Factor III) --------
URL="${URL:-https://example.com}"   # Endpoint objetivo
MAX_RETRIES="${MAX_RETRIES:-3}"     # Número de reintentos (no incluye el intento inicial)
BACKOFF_MS="${BACKOFF_MS:-500}"     # Retardo base en milisegundos
JITTER_PCT="${JITTER_PCT:-20}"      # Porcentaje de jitter (+/-)
TIMEOUT_S="${TIMEOUT_S:-3}"         # Tiempo máx por request (segundos)
OUT_DIR="${OUT_DIR:-out}"           # Directorio de evidencias
LOG_FILE="${LOG_FILE:-$OUT_DIR/log-intentos.txt}"

# -------- Utilidades --------
now() { date '+%Y-%m-%d %H:%M:%S'; }

# Calcula retardo (ms) = BACKOFF_MS * 2^(k-1) +/- jitter
# k es el índice de reintento (1..MAX_RETRIES)
calc_delay_ms(){
    local k="$1"
    local base_ms=$(( BACKOFF_MS * (2 ** (k-1)) ))  
    local jr=$(( base_ms * JITTER_PCT / 100 ))
  if (( jr > 0 )); then
    # RANDOM ∈ [0,32767] → mapear a [-jr, +jr]
    local span=$(( 2*jr + 1 ))
    local off=$(( RANDOM % span - jr ))
    echo $(( base_ms + off ))
  else
    echo "$base_ms"
  fi
}

# Asegura directorio de salida
mkdir -p "$OUT_DIR"
# Limpia/crea log (idempotente)
: > "$LOG_FILE"

log() {
  # Imprime en consola y guarda en log
  # (Usamos tee -a de forma segura)
  printf "%s %s\n" "$(now)" "$*" | tee -a "$LOG_FILE"
}

# -------- Flujo principal --------
log "Inicio de evaluación: URL=$URL, MAX_RETRIES=$MAX_RETRIES, BACKOFF_MS=${BACKOFF_MS}ms, JITTER=${JITTER_PCT}%"

for attempt in $(seq 1 $((MAX_RETRIES + 1))); do
  # Ejecuta request (solo código HTTP; si falla, 000)
  http_code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT_S" "$URL" || echo '000')"
  log "Intento ${attempt}: HTTP=$http_code (timeout=${TIMEOUT_S}s)"
  if echo "$http_code" | grep -q '^2..$'; then exit 0; fi
  # si no es el último intento, duerme con backoff:
  if (( attempt < MAX_RETRIES + 1 )); then
    k=$attempt
    delay_ms="$(calc_delay_ms "$k")"
    delay_s="$(awk -v ms="$delay_ms" 'BEGIN{printf "%.3f", ms/1000}')"
    log "Reintento programado en ${delay_ms} ms (±${JITTER_PCT}%). Durmiendo ${delay_s}s…"
    sleep "$delay_s"
  fi
done
log "Fallo final: agotados ${MAX_RETRIES} reintentos."
exit 1
