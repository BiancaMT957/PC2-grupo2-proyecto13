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




## Métricas exportadas
Al finalizar:
- Calcula la **latencia total** (`LATENCY_MS`) y el número real de **reintentos** realizados.
- Escribe una línea en `out/metricas.csv` con: endpoint latencia_ms reintentos estado_final
**Contenido de cada columna:**

- **endpoint**: URL objetivo utilizada en la prueba.  
- **latencia_ms**: tiempo total transcurrido desde el inicio de la primera petición (`START_MS`) hasta el final del proceso (`END_MS`), expresado en milisegundos. Esta métrica refleja el impacto de los reintentos y permite evaluar el costo temporal de la estrategia de backoff.  
- **reintentos**: número real de intentos adicionales realizados antes de obtener una respuesta satisfactoria o de agotar el máximo permitido (`MAX_RETRIES`). Un valor alto puede indicar un endpoint poco confiable.  
- **estado_final**: resultado global de la ejecución:
  - `OK` → se alcanzó una respuesta exitosa dentro de los reintentos permitidos.
  - `FAIL` → se agotaron los reintentos sin obtener éxito.

Cada nueva ejecución del script agrega una línea al CSV, lo que permite ir construyendo un **histórico de pruebas**.  
Este histórico puede exportarse a otras herramientas (por ejemplo, para graficar en hojas de cálculo) y sirve de base para:
- **Analizar tendencias de disponibilidad** de distintos endpoints a lo largo del tiempo.
- **Detectar falsos positivos** en escenarios de alta variabilidad de red.
- Evaluar el **rendimiento de la política de backoff** (impacto de los parámetros `BACKOFF_MS` y `JITTER_PCT`).

El código de salida del script complementa estas métricas:
- `0` → reintento exitoso.
- `1` → fallo tras agotar reintentos.

---
#### Ejecución

Para las buenas prácticas:

```
make run
```


#### Evidencias 

En la consola:

```
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ make run
==> Ejecutando flujo principal...
```



Dentro de `log-intentos.txt` :

2025-09-27 10:54:25 Inicio de evaluación: URL=http://localhost:8080, MAX_RETRIES=3, BACKOFF_MS=500ms, JITTER=20%
2025-09-27 10:54:25 Intento 1: HTTP=500 (timeout=3s)
2025-09-27 10:54:25 Reintento programado en 444 ms (±20%). Durmiendo 0.444s…
2025-09-27 10:54:25 Intento 2: HTTP=200 (timeout=3s)
2025-09-27 10:54:25 Éxito en intento 2.





Dentro de `out/metricas.csv`:

```
endpoint	latencia_ms	reintentos	estado_final
http://localhost:9999	3698	3	FAIL
http://localhost:8080	706	1	OK
```

### **Pruebas automatizadas: `tests/test_reintentos.bats`**

Se utilizó **Bats (Bash Automated Testing System)** bajo el enfoque **AAA/RGR** (*Arrange-Act-Assert / Red-Green-Refactor*).

#### Casos de prueba

- **Caso rojo: endpoint que siempre falla**  
- Ejecuta `src/main.sh` apuntando a un puerto cerrado (`http://localhost:9999`).  
- Se espera que el script termine con un código distinto de `0`.  
- Demuestra el comportamiento ante fallos permanentes.

- **Caso verde: endpoint que falla una vez y luego responde**  
- Lanza un pequeño servidor Python “flaky” que:
  1. En el primer request devuelve HTTP 500 (falla simulada).
  2. En el segundo request responde HTTP 200 con “OK”.
- El script debe **reintentar automáticamente** y finalizar con código `0`.

---

### **Integración con Makefile**

Se añadió un target `test`:

```make
test:
  @echo "==> Ejecutando pruebas con Bats..."
  @set -o pipefail; bats -r $(TEST_DIR) --formatter pretty | tee out/test-result-s1.log
```

#### Ejecucion:

```
make test
```

#### Evidencias
Se crea un archivo dentro de out/log-intentos.txt con las siguientes descripciones y se ve que los 2 tests efectivamente pasan:

```
test_reintentos.bats
   Caso rojo: endpoint que siempre falla                                1/2
 ✓ Caso rojo: endpoint que siempre falla
   Caso verde: endpoint falla 1 vez y luego responde                  2/2
 ✓ Caso verde: endpoint falla 1 vez y luego responde

2 tests, 0 failures
```




En la consola:


```
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ make test
==> Ejecutando pruebas con Bats...
test_reintentos.bats
 ✓ Caso rojo: endpoint que siempre falla
 ✓ Caso verde: endpoint falla 1 vez y luego responde

2 tests, 0 failures
```




