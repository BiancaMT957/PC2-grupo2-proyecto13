#  Sprint 2 – Políticas por método e idempotencia  

## 1. Descripción del problema
En este sprint se definió la política de **reintentos diferenciada por método HTTP**, considerando el criterio de idempotencia:  

- **GET y PUT**: reintentos permitidos libremente.  
- **POST**: bloqueados por defecto, debido al riesgo de duplicar efectos en operaciones no idempotentes.  
- **POST con `--allow-post-retries`**: se habilitan los reintentos únicamente con este flag para escenarios de prueba controlados.  

---

## 2. Implementación en `src/main.sh`
- Se agregó un **bloque condicional** que detecta el método HTTP (`GET`, `PUT`, `POST`).  
- La lógica de reintentos quedó así:
  - `GET` y `PUT`: utilizan la política de reintentos ya existente (backoff exponencial + jitter).  
  - `POST`: por defecto ejecuta **un solo intento**.  
  - `POST --allow-post-retries`: habilita el ciclo de reintentos, aplicando el mismo algoritmo que GET/PUT.  
- Se añadió **registro detallado en logs** para indicar la política aplicada (ej. “Política: POST con flag --allow-post-retries → reintentos habilitados”).  
- Se mantiene compatibilidad con las métricas (`metrics.csv`) y los archivos de salida en `out/`.  

---

## 3. Ejecucion
```bash

Desde la raiz del proyecto:

# GET → reintentos habilitados por defecto
./src/main.sh GET https://example.com

# PUT → reintentos habilitados por defecto
./src/main.sh PUT https://example.com/resource

# POST → bloquea reintentos, solo intenta una vez
./src/main.sh POST https://example.com

# POST con flag → habilita reintentos
./src/main.sh POST https://example.com --allow-post-retries
```

## Archivos generados

En out/out.log : registro detallado de ejecución, incluyendo políticas aplicadas, intentos, latencias y estados.

En out/metrics.csv : tabla acumulada de métricas con los campos, que ahora se le agrego la columna `method`

```
method, endpoint, latencia_ms, reintentos, estado_final
```

## Ejemplos de salida:

En out/metricas.csv se tiene ahora:

```
GET	https://example.com	2889	0	OK
PUT	https://example.com/resource	13340	3	FAIL
POST	https://example.com	2679	0	FAIL
POST	https://example.com	12780	3	FAIL
```

## En la consola :
```
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ ./src/main.sh GET https://example.com
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ ./src/main.sh PUT https://example.com
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ ./src/main.sh POST https://example.com
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ ./src/main.sh POST https://example.com --allow-post-retries
```

## Ejemlos de salida en el out/log-intentos.txt:



** Para GET  la salida de out/log-intentos-txt:


2025-09-30 11:33:42 Política: GET es idempotente → reintentos habilitados (MAX_RETRIES=3).
2025-09-30 11:33:42 Inicio de evaluación: METHOD=GET, URL=https://example.com, MAX_RETRIES=3, BACKOFF_MS=500ms, JITTER=20%
2025-09-30 11:33:45 Intento 1: HTTP=200 (timeout=3s)
2025-09-30 11:33:45 Éxito en intento 1.

** Para PUT:

2025-09-30 11:35:17 Política: PUT es idempotente → reintentos habilitados (MAX_RETRIES=3).
2025-09-30 11:35:18 Inicio de evaluación: METHOD=PUT, URL=https://example.com/resource, MAX_RETRIES=3, BACKOFF_MS=500ms, JITTER=20%
2025-09-30 11:35:20 Intento 1: HTTP=501 (timeout=3s)
2025-09-30 11:35:20 Reintento programado en 479 ms (±20%). Durmiendo 0.479s…
2025-09-30 11:35:24 Intento 2: HTTP=501 (timeout=3s)
2025-09-30 11:35:24 Reintento programado en 896 ms (±20%). Durmiendo 0.896s…
2025-09-30 11:35:27 Intento 3: HTTP=501 (timeout=3s)
2025-09-30 11:35:27 Reintento programado en 2232 ms (±20%). Durmiendo 2.232s…
2025-09-30 11:35:32 Intento 4: HTTP=501 (timeout=3s)
2025-09-30 11:35:32 Fallo final: agotados 4 intentos.

**Para POST, con intentos deshabilitados:

2025-09-30 11:36:55 Política: POST sin flag → reintentos deshabilitados.
2025-09-30 11:36:55 Inicio de evaluación: METHOD=POST, URL=https://example.com, MAX_RETRIES=3, BACKOFF_MS=500ms, JITTER=20%
2025-09-30 11:36:57 Intento 1: HTTP=411 (timeout=3s)
2025-09-30 11:36:57 No se permiten reintentos adicionales para POST. Abortando.
2025-09-30 11:36:57 Fallo final: agotados 1 intentos.

**Para POST, con intentos habilitados con --allow-post-retries :

2025-09-30 11:38:17 Política: POST con flag --allow-post-retries → reintentos habilitados.
2025-09-30 11:38:17 Inicio de evaluación: METHOD=POST, URL=https://example.com, MAX_RETRIES=3, BACKOFF_MS=500ms, JITTER=20%
2025-09-30 11:38:19 Intento 1: HTTP=411 (timeout=3s)
2025-09-30 11:38:19 Reintento programado en 418 ms (±20%). Durmiendo 0.418s…
2025-09-30 11:38:23 Intento 2: HTTP=411 (timeout=3s)
2025-09-30 11:38:23 Reintento programado en 1174 ms (±20%). Durmiendo 1.174s…
2025-09-30 11:38:26 Intento 3: HTTP=411 (timeout=3s)
2025-09-30 11:38:26 Reintento programado en 1650 ms (±20%). Durmiendo 1.650s…
2025-09-30 11:38:30 Intento 4: HTTP=411 (timeout=3s)
2025-09-30 11:38:30 Fallo final: agotados 4 intentos.

## Sprint 2: Manejo de fallos y codigos de salida diferenciados.

### 1. Descripcion
En esta issue se solicitaba implementar el manejo de fallos en las llamadas HTTP del script, con clasificacion de los errores y con codigos de salida diferenciados.
- Exito (2xx) : salida 0
- Fallo de red/timeout : salida 2
- Fallo HTTP (3xx, 4xx, 5xx) : salida 4

Ademas, se debe generar el archivo fallos.csv dentro del directorio `out/`, con los siguientes encabezados: codigo HTPP, codigo curl, motivo del fallo.

### 2. Implementacion en `src/main.sh`

Se añadieron las funciones auxiliares:
- `motivos()` : nos da el motivo de fallo. Lo clasifica segun el `HTPP_CODE` (que nos brinda los codigos de error HTTP) y `CURL_EXIT` (nos da el valor de curl, 28 en caso de timeout), luego asigna `REASON` con el motivo de fallo y `FINAL_EXIT` con el codigo de salida diferenciado (0, 2, 4).
- `fallos()` : crea el archivo `out/fallos.csv` si no esta creado, e imprime dentro los encabezados y cuerpo.
```sql
method  endpoint  motivo_fallo  http_code curl_exit
GET	http://localhost:9999	connect_error	000	7
```
- Flujo principal:
  - Si los intentos fallan, se invoca a `motivos`, para determinar el motivo (`REASON`) y el codigo de salida (`FINAL_EXIT`).
  - Se registra la fila correspondiente en `fallos.csv`.
  - Se finaliza el script con el codigo de salida 2 o 4 segun corresponda.

### 3. Ejecucion
Ejemplos de salida del proyecto:
- Fallo por timeout, simula un host inexistente en red interna, registra `timeout` en `fallos.csv`.
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ URL=http://10.255.255.1 TIMEOUT_S=2 MAX_RETRIES=0 make run
==> Ejecutando flujo principal...
curl: (28) Connection timed out after 2003 milliseconds
make: *** [Makefile:32: run] Error 2
```
- Fallo de red (DNS invalido), el DNS falla al resolverse, registra `dns_error` en `fallos.csv`.
```bash
uis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ URL=http://no-existe-este-host.invalid MAX_RETRIES=0 make run
==> Ejecutando flujo principal...
curl: (6) Could not resolve host: no-existe-este-host.invalid
make: *** [Makefile:32: run] Error 2
```
- Fallo HTTP 500, servicio que responde siempre 500. Devuelve error `4` y registra como motivo `http_5xx` en `fallos.csv`.
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ URL=http://httpbin.org/status/500 MAX_RETRIES=0 make run
==> Ejecutando flujo principal...
make: *** [Makefile:32: run] Error 4
```
- Fallo HTTP 404, servicio responde 404, y registra como motivo `http_4xx` en `fallos.csv`.
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ URL=http://httpbin.org/status/404 MAX_RETRIES=0 make run
==> Ejecutando flujo principal...
make: *** [Makefile:32: run] Error 4
```
### 4. Registro de fallos en `fallos.csv`
Ahora veamos las salidas en el archivo `fallos.csv`:
```bash
method	endpoint	motivo_fallo	http_code	curl_exit
GET	http://10.255.255.1	timeout	000	28
GET	http://no-existe-este-host.invalid	dns_error	000	6
GET	http://httpbin.org/status/500	http_5xx	500	0
GET	http://httpbin.org/status/404	http_4xx	404	0
```