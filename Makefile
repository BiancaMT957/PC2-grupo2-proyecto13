# Makefile - Proyecto 13

SHELL := /usr/bin/env bash

# Variables
VERSION ?= 1.0.0
NAME = proyecto13
SRC=src/main.sh
OUT_DIR=out
DIST_DIR=dist
TEST_DIR ?= tests
PKG = $(DIST_DIR)/$(NAME)-v$(VERSION).tar.gz

.PHONY: tools build run pack test clean help


tools:
	@echo "==> Verificando dependencias..."
	@command -v curl >/dev/null 2>&1 || { echo "Error: falta 'curl'"; exit 1; }
	@command -v awk >/dev/null 2>&1 || { echo "Error: falta 'awk'"; exit 1; }
	@command -v sed >/dev/null 2>&1 || { echo "Error: falta 'sed'"; exit 1; }
	@command -v bats >/dev/null 2>&1 || { echo "Error: falta 'bats'"; exit 1; }
	@echo "Todas las dependencias están disponibles."


build:
	@echo "==> Preparando directorios..."
	mkdir -p $(OUT_DIR) $(DIST_DIR)
	@echo "Build completado." | tee $(OUT_DIR)/build.log
	@echo "Evidencia generada en: $(OUT_DIR)/build.log"


run:
	@echo "==> Ejecutando flujo principal..."
	@bash $(SRC)

pack: clean build
	@echo "==> Empaquetando version $(VERSION)..."
	tar --sort=name --mtime="2025-01-01 00:00Z" --owner=0 --group=0 --numeric-owner -czf $(PKG) Makefile src tests docs
	sha256sum $(PKG) | tee $(OUT_DIR)/sha256-$(NAME)-v$(VERSION).txt
	@echo "Paquete generado: $(PKG)"
	@echo "Hash reproducible en: $(OUT_DIR)/sha256-$(NAME)-v$(VERSION).txt"


test:
	@echo "==> Ejecutando pruebas con Bats..."

	@set -o pipefail; bats -r $(TEST_DIR) --formatter pretty | tee out/test-result-s2.log
	


clean:
	@echo "==> Limpiando..."
	rm -rf $(OUT_DIR) $(DIST_DIR)
	@echo "Limpieza completada."


help:
	@echo "Targets disponibles:"
	@echo "  make tools   -> valida dependencias (curl, awk, sed, bats)"
	@echo "  make build   -> prepara artefactos intermedios en out/"
	@echo "  make run     -> ejecuta flujo principal (CLI con reintentos)"
	@echo "  make test    -> corre la suite Bats"
	@echo "  make clean   -> borra out/ y dist/"
	@echo "  make help    -> muestra esta ayuda"