# ========================
# Makefile - Proyecto 13
# Sprint 1
# ========================

# Variables
SRC=src/main.sh
OUT_DIR=out
DIST_DIR=dist

.PHONY: tools build run test clean help

# tools: valida las dependencias.
tools:
	@echo "==> Verificando dependencias..."
	@command -v curl >/dev/null 2>&1 || { echo "Error: falta 'curl'"; exit 1; }
	@command -v awk >/dev/null 2>&1 || { echo "Error: falta 'awk'"; exit 1; }
	@command -v sed >/dev/null 2>&1 || { echo "Error: falta 'sed'"; exit 1; }
	@command -v bats >/dev/null 2>&1 || { echo "Error: falta 'bats'"; exit 1; }
	@echo "Todas las dependencias están disponibles."

# build: crea los directorios out/ y dist/ si no estan creados.
build:
	@echo "==> Preparando directorios..."
	mkdir -p $(OUT_DIR) $(DIST_DIR)
	@echo "Build completado." | tee $(OUT_DIR)/build.log
	@echo "Evidencia generada en: $(OUT_DIR)/build.log"

# run: usa bash para ejecutar el script
run:
	@echo "==> Ejecutando flujo principal..."
	@bash $(SRC) || { echo "Ejecución falló"; exit 1; }

# test: ejecuta pruebas automatizadas
test:
	@echo "==> Ejecutando pruebas con Bats..."
	bats tests/

# clean: elimina los archivos creados out/ y dist/
clean:
	@echo "==> Limpiando..."
	rm -rf $(OUT_DIR) $(DIST_DIR)
	@echo "Limpieza completada."

# help: lista los targets y sus descripciones
help:
	@echo "Targets disponibles:"
	@echo "  make tools   -> valida dependencias (curl, awk, sed, bats)"
	@echo "  make build   -> prepara artefactos intermedios en out/"
	@echo "  make run     -> ejecuta flujo principal (CLI con reintentos)"
	@echo "  make test    -> corre la suite Bats"
	@echo "  make clean   -> borra out/ y dist/"
	@echo "  make help    -> muestra esta ayuda"