Este documento define los archivos de salida que genera el sistema y cómo validarlos.

---

## 1. Archivos generados
- `out/metricas-final.csv`  
  Consolidado de todas las ejecuciones exitosas o fallidas.  
  **Columnas:**
  - `method` → Método HTTP (GET, POST, PUT, etc.)
  - `endpoint` → URL probada
  - `latencia_ms` → Tiempo de respuesta en milisegundos
  - `intentos` → Número de reintentos realizados
  - `estado_final` → OK o FAIL
  - `motivo_fallo` → vacío si es OK, valor si es FAIL (`timeout`, `dns_error`, `http_5xx`, `http_4xx`, etc.)
  - `http_code` → Código HTTP devuelto (ej. 200, 500, 404)
  - `curl_exit` → Código de salida de curl

- `out/fallos.csv`  
  Registro específico de fallos, con las mismas columnas pero solo para casos `FAIL`.

---

## 2. Validaciones rápidas
- Ver solo las filas con fallos:
```bash
grep FAIL out/metricas-final.csv
```

Contar cuántos fueron 5xx:


```
grep http_5xx out/metricas-final.csv | wc -l
```



Calcular promedio de latencias:


```
awk -F, '{if(NR>1) {sum+=$3; n++}} END {print "Promedio latencia:", sum/n}' out/metricas-final.csv
```



Verificar endpoints únicos registrados:


```
awk -F, '{print $2}' out/metricas-final.csv | sort | uniq
```


##  Criterio de aceptación

* out/metricas-final.csv existe y contiene todas las ejecuciones.

* Los fallos están trazados en out/fallos.csv.

* Ambos son validados mediante los comandos anteriores.


---

## out/metricas-final.csv (consolidado)
Ejemplo de consolidado que combina `metricas.csv` y `fallos.csv`:


```csv
method	endpoint	latencia_ms	intentos	estado_final	motivo_fallo	http_code	curl_exit
GET	https://example.com	1808	0	OK		200	0
GET	https://httpbin.org/status/	25216	5	FAIL		0	0
GET	https://httpbin.org/status/	28294	5	FAIL		0	0
GET	https://example.com	1369	0	OK		200	0
GET	https://example.com	1244	0	OK		200	0
GET	https://httpbin.org/status/	30538	5	FAIL		0	0
GET	https://example.com	1407	0	OK		200	0
GET	https://httpbin.org/status/	31066	5	FAIL		0	0
GET	https://httpbin.org/status/	34618	5	FAIL		0	0
GET	https://httpbin.org/status/			FAIL	http_5xx	503	0
GET	https://httpbin.org/status/			FAIL	http_5xx	503	0
GET	https://httpbin.org/status/			FAIL	timeout	000	28
GET	https://httpbin.org/status/			FAIL	timeout	000	28
GET	https://httpbin.org/status/			FAIL	timeout	000	28
```

