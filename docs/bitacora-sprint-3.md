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

## Issue 9: Empaquetado reproducible y tagging de release
### 1. Descripcion
Se implementa un mecanismo de empaquetado reproducible del proyecto, de modo que el archivo generado sea identico en distintas maquinas (mismo hash). Ademas, se implementa la creacion de un tag firmado en git para versionar releases.

### 2. Implementacion en Makefile
Se añade el target `pack` en el `Makefile`, con la siguiente logica:
- Dependencias: ejecuta `clean` y `build` antes de emparquetar.
- Paquete final: genera `dist/proyecto13-vX.Y.Z.tar.gz`.
- Configuracion `tar` para reproducibilidad:
  - `--sort=name` : ordena los archivos.
  - `--mtime="2025-01-01 00:00Z"` : fija fecha de modificacion (para que el codigo hash no varie por este indicador).
  - `--owner=0 --group=0 --numeric-owner` : neutraliza diferencias de usuario/sistemas.

Codigo agregado:
```bash
# Añadimos las variables
VERSION ?= 1.0.0
NAME = proyecto13
PKG = $(DIST_DIR)/$(NAME)-v$(VERSION).tar.gz

# Añadimos pack al .PHONY

# Creamos el target pack con dependencia a clean y build
pack: clean build
	@echo "==> Empaquetando version $(VERSION)..."
	tar --sort=name --mtime="2025-01-01 00:00Z" --owner=0 --group=0 --numeric-owner -czf $(PKG) Makefile src tests docs
	sha256sum $(PKG) | tee $(OUT_DIR)/sha256-$(NAME)-v$(VERSION).txt
	@echo "Paquete generado: $(PKG)"
	@echo "Hash reproducible en: $(OUT_DIR)/sha256-$(NAME)-v$(VERSION).txt"
```

### 3. Ejecucion
Ejecutamos `make test` con la siguiente salida:
```bash
luis@LAPTOP-LC:/mnt/c/Users/Luis/Documents/PC2-grupo2-proyecto13$ make pack
==> Limpiando...
rm -rf out dist
Limpieza completada.
==> Preparando directorios...
mkdir -p out dist
Build completado.
Evidencia generada en: out/build.log
==> Empaquetando version 1.0.0...
tar --sort=name --mtime="2025-01-01 00:00Z" --owner=0 --group=0 --numeric-owner -czf dist/proyecto13-v1.0.0.tar.gz Makefile src tests docs
sha256sum dist/proyecto13-v1.0.0.tar.gz | tee out/sha256-proyecto13-v1.0.0.txt
1c96f65672c4c403e7f1fce75f8d3369592ac3cc936dbd580d3a1f474266423c  dist/proyecto13-v1.0.0.tar.gz
Paquete generado: dist/proyecto13-v1.0.0.tar.gz
Hash reproducible en: out/sha256-proyecto13-v1.0.0.txt
```
Notamos la correcta ejecucion de las dependencias, y la generacion el codigo hash del archivo. Al volver a ejecutar obtenemos el mismo codigo hash, con lo cual queda comprobada la reproducibilidad.

### Tagging del realese
Se necesitaba marcar la version del proyecto mediante un tag en git, asociado al commit final que contiene el empaquetado reproducible. El tag se firmara con GPG (-s) y subido al repositorio remoto para que quede disponible en GitHub.

### Flujo realizado
- Primero subimos los archivos modificados con `git add` y su respectivo commit. Y lo enviamos al repositorio remoto.
```bash
git add <archivos-modificados>
git commit -m "Implementa empaquetado reproducible"
git push origin develop
```
- Localmente creamos el tag, firmado sobre el commit más reciente.
```bash
git tag -s v1.0.0 -m "Release v1.0.0: empaquetado reproducible"
```
- Finalmente, subimos el tag al remoto.
```bash
git push origin v1.0.0
```
Esto permite que el tag aparezca en la sección Tags / Releases del repositorio remoto.

### 4. Conclusion del Issue
- Versionado formal del proyecto, empaquetado reproducible.
- Garantizamos la autenticidad del release, usando el tag firmado por el autor.





## Bitácora y contrato de salidas
Documentar los pasos realizados durante la ejecución de pruebas con reintentos y fallos de red, incluyendo comandos ejecutados, resultados observados y análisis de falsos positivos.

---

### Ejecución de pruebas

#### 1. Pruebas sobre endpoints válidos
```bash
./src/main.sh GET https://example.com
./src/main.sh PUT https://example.com/resource
./src/main.sh POST https://example.com
./src/main.sh POST https://example.com --allow-post-retries
```


#### 2. Resultados registrados en metricas.csv:

GET   https://example.com              2889   0   OK
PUT   https://example.com/resource    13340   3   FAIL
POST  https://example.com              2679   0   FAIL
POST  https://example.com             12780   3   FAIL

#### 3. Pruebas sobre endpoints con fallo de red

URL=http://10.255.255.1 TIMEOUT_S=2 MAX_RETRIES=0 make run
URL=http://no-existe-este-host.invalid MAX_RETRIES=0 make run
URL=http://httpbin.org/status/500 MAX_RETRIES=0 make run
URL=http://httpbin.org/status/404 MAX_RETRIES=0 make run


#### 4.Resultados registrados en fallos.csv:

GET http://10.255.255.1              timeout    000   28
GET http://no-existe-este-host.invalid dns_error 000   6
GET http://httpbin.org/status/500    http_5xx   500   0
GET http://httpbin.org/status/404    http_4xx   404   0


Comandos de validación

Buscar errores:


```
grep FAIL out/metricas-final.csv
```



Calcular promedio de latencias:



```
awk -F, '{sum+=$3; n++} END {print "Promedio:", sum/n}' out/metricas-final.csv
```



#### Análisis de falsos positivos

* Note que algunos intentos iniciales fallaron, pero el estado final fue exitoso (ejemplo: GET a example.com : OK en el intento final).

* Esto genera falsos positivos si se cuenta todos los intentos.

* Decisión: en el CSV final solo se registra estado_final, no los intermedios.

#### Conclusiones

En este proyecto se ejecutaron pruebas en escenarios de éxito, reintentos y fallos reales.

Los resultados quedaron trazados en out/metricas-final.csv y out/fallos.csv.

El sistema maneja tanto reintentos controlados como errores de red.




