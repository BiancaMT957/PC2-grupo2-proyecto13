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