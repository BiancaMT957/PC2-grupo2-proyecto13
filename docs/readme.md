# Proyecto 13 - Sprint 2

## Variables de entorno (parametrización)

El script `src/main.sh` soporta configuración por variables de entorno siguiendo el principio **12-Factor (Config en entorno)**.  
Esto permite cambiar el comportamiento sin modificar el código fuente.

| Variable      | Efecto                                                 | Ejemplo |
|---------------|--------------------------------------------------------|---------|
| `MAX_RETRIES` | Número máximo de reintentos antes de fallar            | `5`     |
| `BACKOFF_MS`  | Tiempo base del backoff exponencial (milisegundos)     | `200`   |
| `JITTER_PCT`  | Porcentaje de variación aleatoria en el backoff        | `20`    |
| `TIMEOUT_S`   | Tiempo máximo por request en segundos                  | `3`     |
| `OUT_DIR`     | Directorio donde se guardan métricas y logs            | `out`   |
| `LOG_FILE`    | Ruta del archivo de log de intentos                    | `out/log-intentos.txt` |


### Ejemplo de uso

```bash
# Cambiar reintentos y jitter sin tocar el código
MAX_RETRIES=5 BACKOFF_MS=200 JITTER_PCT=30 ./src/main.sh GET https://example.com


