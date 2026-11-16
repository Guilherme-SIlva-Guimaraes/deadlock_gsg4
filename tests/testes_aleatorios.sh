#!/bin/bash
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN=${BIN:-$ROOT/banker}

if ! command -v python3 > /dev/null 2>&1; then
    echo "RESUMO: python3 nao encontrado, testes aleatorios ignorados"
    exit 0
fi
BIN=$BIN python3 "$ROOT/tests/teste_aleatorio.py" "$@"
