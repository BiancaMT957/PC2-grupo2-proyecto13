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




