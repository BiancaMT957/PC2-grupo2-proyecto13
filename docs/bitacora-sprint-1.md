# Sprint 1: Evaluador de resiliencia de endpoints con reintentos y jitter controlado

## Issue 1: Estructura inicial del proyecto y Makefile inicial

**Objetivos:** Creacion del Makefile con los siguientes targets:
- **tools:** valida dependencias (curl, awk, sed, bats)
- **build:** prepara artefactos intermedios
- **run:** ejecuta flujo principal 
- **test** corre la suite en Bats
- **clean:** borra out/ y dist/
- **help:** muestra explicacion de cada Target

## Metodologia
- En **tools** con `commad -v` verificamos si un comando existe en el PATH del sistema. De no encontrase se muestra un mensaje de error y termina la ejecucion.
- En **build** con `mkdir -p` creamos los directorios intermedios automaticamente y una vez creado se mostrará un mensaje y  `tee $(OUT_DIR)/build.log` creara el archivo `build.log` dentro de `out/` como evidencia del build.
- En **clean** con `rm -rf` borramos los directorios y sus contenidos.

## Evidencias

1. Ejecucion del `make tools`.
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ make tools
==> Verificando dependencias...
Todas las dependencias están disponibles.
```
2. Ejecucion del `make build`.
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ make build
==> Preparando directorios...
mkdir -p out dist
Build completado.
Evidencia generada en: out/build.log
```
3. Ejecucion del `make clean`.
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ make clean
==> Limpiando...
rm -rf out dist
Limpieza completada.
```
4. Ejecucion del `make help`.
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ make help
Targets disponibles:
  make tools   -> valida dependencias (curl, awk, sed, bats)
  make build   -> prepara artefactos intermedios en out/
  make run     -> ejecuta flujo principal (CLI con reintentos)
  make test    -> corre la suite Bats
  make clean   -> borra out/ y dist/
  make help    -> muestra esta ayuda
```

---

## Issue 2: Implementacion de backoff exponencial y jitter controlado

**Objetivos:** 
- Creacion del script Bash principal que reintente request con backoff exponencial.
- Añadir un factor de jitter (aleatoriedad acotada, ej. ±20%).
- Registrar cada intento con timestamp en consola/log.

## Metodologia

### Variables de entorno
Siguiendo la metodologia de los 12 factores, definimos las variables de entorno:
- `URL` como el endpoint obejtivo.
- `MAX_RETRIES` como el numero de reintentos.
- `BACKOFF_MS` como retardo base en milisegundos.
- `JITTER_PCT` como porcentaje de jitter (+/-).
- `TIMEOUT_S` como tiempo maximo por request en segundos.
- `OUT_DIR` como directorio de salidas.
- `LOG_FILE` como archivo de salida, dentro de `OUT_DIR`.

Con esto cumplimos III-Config que nos indica que toda configuracion se inyecta por variables de entorno (valores asignados por Default). Se pueden cambiar al invocar make run.

## Matriz de configuración (variables de entorno)

| Variable         | Descripción                                               | Tipo   | Default                         | Rango / Validez      | Ejemplo override                                                 | Observaciones |
|------------------|-----------------------------------------------------------|--------|----------------------------------|----------------------|------------------------------------------------------------------|---------------|
| `URL`            | Endpoint a evaluar (request HTTP)                         | string | `https://example.com`           | URL válida           | `URL="https://httpbin.org/status/500"`                           | Cambia entre entornos sin tocar código. |
| `MAX_RETRIES`    | Nº de reintentos (no incluye el intento inicial)          | int    | `3`                              | `>= 0`               | `MAX_RETRIES=5`                                                  | Total de intentos = `1 + MAX_RETRIES`. |
| `BACKOFF_MS`     | Retardo base del backoff (milisegundos)                   | int    | `500`                            | `>= 1`               | `BACKOFF_MS=400`                                                 | Backoff exponencial: `BACKOFF_MS * 2^(k-1)`. |
| `JITTER_PCT`     | Porcentaje de jitter (variación ± sobre el backoff)       | int    | `20`                             | `0..100`             | `JITTER_PCT=10`                                                  | Evita reintentos sincronizados (thundering herd). |
| `TIMEOUT_S`      | Timeout por request (segundos)                            | int    | `3`                              | `>= 1`               | `TIMEOUT_S=5`                                                    | Límite por intento en `curl`. |
| `OUT_DIR`        | Carpeta de artefactos/intermedios                         | string | `out`                            | ruta válida          | `OUT_DIR=build/out`                                              | Se crea si no existe. |
| `LOG_FILE`       | Ruta del log de intentos                                  | string | `out/log-intentos.txt`          | ruta válida          | `LOG_FILE=/tmp/intentos.log`                                     | Se sobreescribe al inicio de cada run. |
| `MAX_BACKOFF_MS` | **(Opcional)** Techo máximo de backoff por reintento (ms) | int    | _(sin valor)_                    | `>= 0`               | `MAX_BACKOFF_MS=5000`                                            | Limita sleeps muy largos en k grandes. |

> Uso típico (override en línea):  
> ```bash
> URL="https://httpbin.org/status/500" MAX_RETRIES=4 BACKOFF_MS=400 JITTER_PCT=20 make run
> ```
> O cargar desde `.env` (si tu `make run` lo importa automáticamente).


Implementamos `now()` para el registro del momento de ejecucion y los reintentos.
```bash
now() { date '+%Y-%m-%d %H:%M:%S'; }
```

Implementamos la funcion `calc_delay_ms()` que nos ayuda a calcular el backoff exponencial y el jitter acotado.

```bash
local base_ms=$(( BACKOFF_MS * (2 ** (k-1)) ))  
local jr=$(( base_ms * JITTER_PCT / 100 ))
local span=$(( 2*jr + 1 ))
local off=$(( RANDOM % span - jr ))
echo $(( base_ms + off ))
```
- `base_ms` nos da el credimiento exponencial del backoff.
- `jr` nos da la magnitud del jitter.
- `RANDOM % span` nos genera un numero aleatorio entero entre `[0, 2*jr]` que luego se resta con `jr` obteniendo un numero del intervalo `[-jr,jr]`
- Finalmente se aplica ±jitter al backoff.

Implementamos `log()` para imprimir en consola y guardar en `out/log-intentos.txt`, el archivo de salida.
```bash
log() {
  printf "%s %s\n" "$(now)" "$*" | tee -a "$LOG_FILE"
}
```

## Evidencias
Caso 1: **falla**, se establece la siguiente configuracion `URL="https://httpbin.org/status/500" MAX_RETRIES=3 BACKOFF_MS=400 JITTER_PCT=20 make run` con la salida:
```bash
2025-09-25 22:28:13 Inicio de evaluación: URL=https://httpbin.org/status/500, MAX_RETRIES=3, BACKOFF_MS=400ms, JITTER=20%
2025-09-25 22:28:18 Intento 1: HTTP=500 (timeout=3s)
2025-09-25 22:28:18 Reintento programado en 396 ms (±20%). Durmiendo 0.396s…
2025-09-25 22:28:19 Intento 2: HTTP=500 (timeout=3s)
2025-09-25 22:28:19 Reintento programado en 761 ms (±20%). Durmiendo 0.761s…
2025-09-25 22:28:21 Intento 3: HTTP=500 (timeout=3s)
2025-09-25 22:28:21 Reintento programado en 1887 ms (±20%). Durmiendo 1.887s…
2025-09-25 22:28:23 Intento 4: HTTP=500 (timeout=3s)
2025-09-25 22:28:23 Fallo final: agotados 3 reintentos.
```

Caso 2: **exito**, establecemos la siguiente configuracion `URL="https://httpbin.org/status/200" MAX_RETRIES=3 BACKOFF_MS=400 JITTER_PCT=20 make run` con la salida:
```bash
2025-09-25 23:04:16 Inicio de evaluación: URL=https://httpbin.org/status/200, MAX_RETRIES=3, BACKOFF_MS=400ms, JITTER=20%
2025-09-25 23:04:17 Intento 1: HTTP=200 (timeout=3s)
```