## Issue 8: Parametrización por variables de entorno

### 1. Descripción
Se debe reemplazar valores fijos del script `src/main.sh` por variables de entorno, de acuerdo con el principio **12-Factor (III - Config)**.  
Asi, el comportamiento de los reintentos, el tiempo base de backoff y la variación de jitter podrán configurarse desde la terminal o consola, sin hacer cambios en  el código fuente.

### 2. Alcance y criterios de aceptación
- Variables a parametrizar:
  - `MAX_RETRIES`: número máximo de reintentos antes de fallar.
  - `BACKOFF_MS`: tiempo base del backoff exponencial (ms).
  - `JITTER_PCT`: porcentaje de variación aleatoria en el backoff.
- Procedimiento:
  - Al ejecutar el script `main.sh` con diferentes configuraciones en consola, los valores impactan  sus cambios en el número de reintentos y latencia total.
  - Documente en   `docs/README.md` la tabla de variables \ efecto \ejemplo.


### 3. Funcionamiento en `src/main.sh`
Las siguientes líneas del script implementan la lectura de variables de entorno con valores por defecto:

```bash
MAX_RETRIES="${MAX_RETRIES:-3}"      # Número de reintentos (no tiene intento inicial)
BACKOFF_MS="${BACKOFF_MS:-500}"      # demora  base en milisegundos
JITTER_PCT="${JITTER_PCT:-20}"       # Porcentaje de jitter (+/-)
TIMEOUT_S="${TIMEOUT_S:-3}"          # Tiempo máx por request (segundos)
OUT_DIR="${OUT_DIR:-out}"            # Directorio de evidencias
LOG_FILE="${LOG_FILE:-$OUT_DIR/log-intentos.txt}"
```


#### Caso 1: MAX_RETRIES=5

* En la consola:

```
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ MAX_RETRIES=5 ./src/main.sh GET https://httpbin.org/status/
curl: (28) Operation timed out after 3000 milliseconds with 0 bytes received
curl: (28) Operation timed out after 3000 milliseconds with 0 bytes received
curl: (28) Operation timed out after 3001 milliseconds with 0 bytes received
curl: (28) Operation timed out after 3002 milliseconds with 0 bytes received
curl: (28) Operation timed out after 3002 milliseconds with 0 bytes received
curl: (28) Operation timed out after 3000 milliseconds with 0 bytes received
```


* En log-intentos.txt:

```
2025-10-02 10:11:00 Política: GET es idempotente → reintentos habilitados (MAX_RETRIES=5).
2025-10-02 10:11:00 Inicio de evaluación: METHOD=GET, URL=https://httpbin.org/status/, MAX_RETRIES=5, BACKOFF_MS=500ms, JITTER=20%
2025-10-02 10:11:04 Intento 1: HTTP=000 (curl_exit=28, timeout=3s)
2025-10-02 10:11:04 Reintento programado en 486 ms (±20%). Durmiendo 0.486s…
2025-10-02 10:11:07 Intento 2: HTTP=000 (curl_exit=28, timeout=3s)
2025-10-02 10:11:07 Reintento programado en 1117 ms (±20%). Durmiendo 1.117s…
2025-10-02 10:11:11 Intento 3: HTTP=000 (curl_exit=28, timeout=3s)
2025-10-02 10:11:11 Reintento programado en 2206 ms (±20%). Durmiendo 2.206s…
2025-10-02 10:11:17 Intento 4: HTTP=000 (curl_exit=28, timeout=3s)
2025-10-02 10:11:17 Reintento programado en 4187 ms (±20%). Durmiendo 4.187s…
2025-10-02 10:11:24 Intento 5: HTTP=000 (curl_exit=28, timeout=3s)
2025-10-02 10:11:24 Reintento programado en 8517 ms (±20%). Durmiendo 8.517s…
2025-10-02 10:11:35 Intento 6: HTTP=000 (curl_exit=28, timeout=3s)
2025-10-02 10:11:35 Fallo final: agotados 6 intentos.
```



Se ven 6 intentos en total, 5 reintentos.


#### Caso 2: Ejecucion normal
* En la consola:


```
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ ./src/main.sh GET https://httpbin.org/status/
curl: (28) Operation timed out after 3002 milliseconds with 0 bytes received

```



En llog-intentos.txt, debajo de los 6 intentos de la anterior ejecución: 


```
2025-10-02 10:13:15 Inicio de evaluación: METHOD=GET, URL=https://httpbin.org/status/, MAX_RETRIES=3, BACKOFF_MS=500ms, JITTER=20%
2025-10-02 10:13:17 Intento 1: HTTP=404 (curl_exit=0, timeout=3s)
2025-10-02 10:13:17 Reintento programado en 489 ms (±20%). Durmiendo 0.489s…
2025-10-02 10:13:20 Intento 2: HTTP=404 (curl_exit=0, timeout=3s)
2025-10-02 10:13:20 Reintento programado en 933 ms (±20%). Durmiendo 0.933s…
2025-10-02 10:13:24 Intento 3: HTTP=000 (curl_exit=28, timeout=3s)
2025-10-02 10:13:24 Reintento programado en 1865 ms (±20%). Durmiendo 1.865s…
2025-10-02 10:13:28 Intento 4: HTTP=404 (curl_exit=0, timeout=3s)
2025-10-02 10:13:28 Fallo final: agotados 4 intentos.
```


* En métricas.csv al final para los 2: 


```
method	endpoint	latencia_ms	reintentos	estado_final
GET	https://httpbin.org/status/	35015	5	FAIL
GET	https://httpbin.org/status/	12734	3	FAIL
```



#### Caso 3: MAX_RETRIES=5, JITTER_PCT=30

En la consola:

```
bianca007@MSI:/mnt/c/Users/Bianca/Documents/PC2-grupo2-proyecto13$ MAX_RETRIES=5 BACKOFF_MS=200 JITTER_PCT=30 ./src/main.sh GET https://example.com
```


En log-intentos.txt:


```
Para MAX_RETRIES=5 BACKOFF_MS=200 JITTER_PCT=30 ./src/main.sh GET https://example.com
2025-10-02 10:28:06 Política: GET es idempotente → reintentos habilitados (MAX_RETRIES=5).
2025-10-02 10:28:06 Inicio de evaluación: METHOD=GET, URL=https://example.com, MAX_RETRIES=5, BACKOFF_MS=200ms, JITTER=30%
2025-10-02 10:28:07 Intento 1: HTTP=200 (curl_exit=0, timeout=3s)
2025-10-02 10:28:07 Éxito en intento 1.
```


En métricas.csv para los 3 queda al final:


```
method	endpoint	latencia_ms	reintentos	estado_final
GET	https://httpbin.org/status/	35015	5	FAIL
GET	https://httpbin.org/status/	12734	3	FAIL
GET	https://example.com	1567	0	OK
```