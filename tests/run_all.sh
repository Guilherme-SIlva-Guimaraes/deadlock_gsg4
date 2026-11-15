#!/bin/bash
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
SAN="gcc -Wall -Wextra -std=c11 -g -fsanitize=address,undefined"
status=0

cd "$ROOT" || exit 1
make -s || exit 1
$SAN -o "$TMP/banker_asan" "$ROOT/banker.c" || exit 1
$SAN -I"$ROOT" -o "$TMP/teste_estado" "$ROOT/tests/teste_estado.c" || exit 1

echo "##### is_safe (AddressSanitizer e UBSan)"
"$TMP/teste_estado" | tail -2
[ "${PIPESTATUS[0]}" -eq 0 ] || status=1

for bin in "$ROOT/banker" "$TMP/banker_asan"; do
    for t in testes_entradas testes_execucao; do
        echo "##### $t com $(basename "$bin")"
        BIN=$bin bash "$ROOT/tests/$t.sh" | grep -E "FALHOU|RESUMO|Sanitizer|runtime error"
        [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
    done
done

if [ "$status" -eq 0 ]; then
    echo "##### TUDO OK"
else
    echo "##### HOUVE FALHAS"
fi
exit "$status"
