#!/bin/bash
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OFC="$ROOT/tests/exemplo"
BIN=${BIN:-$ROOT/banker}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1
pass=0
bad=0

setup() {
    rm -rf result.txt customer.txt commands.txt out.txt err.txt
    cp "$OFC/customer.txt" "$OFC/commands.txt" .
}

run() {
    local name=$1 exp=$2
    shift 2
    "$BIN" "$@" > out.txt 2> err.txt
    local rc=$?
    local lines
    lines=$(wc -l < out.txt)
    local res=nao
    [ -e result.txt ] && res=sim
    local ok=OK
    [ "$rc" -ne "$exp" ] && ok=FALHOU
    [ "$lines" -ne 0 ] && ok=FALHOU
    [ "$exp" -ne 0 ] && [ "$res" = sim ] && ok=FALHOU
    [ "$exp" -eq 0 ] && [ "$res" = nao ] && ok=FALHOU
    if [ "$exp" -ne 0 ] && [ ! -s err.txt ]; then ok=FALHOU; fi
    if [ "$exp" -eq 0 ] && [ -s err.txt ]; then ok=FALHOU; fi
    printf '[%s] %s | %s %s | exit=%s | stdout=%s linhas | result.txt=%s\n' "$ok" "$name" "$BIN" "$*" "$rc" "$lines" "$res"
    [ -s err.txt ] && sed 's/^/        stderr: /' err.txt
    if [ "$ok" = OK ]; then pass=$((pass + 1)); else bad=$((bad + 1)); fi
}

echo "=== Entradas validas ==="
setup; run "oficial" 0 10 5 7
setup; printf '7,5,3\n3,2,2\n9,0,2\n2,2,2\n4,3,3\n' > customer.txt; run "customer com newline final" 0 10 5 7
setup; printf '7,5,3\n3,2,2\n\n\n' > customer.txt; printf 'RQ 1 0 0 0\n' > commands.txt; run "linhas em branco no fim do customer" 0 10 5 7
setup; : > commands.txt; run "commands vazio" 0 10 5 7
setup; printf 'RQ 4 0 0 0\n' > commands.txt; run "cliente na borda (ultimo)" 0 10 5 7
setup; { head -c 130 /dev/zero | tr '\0' '0'; printf '7,5,3\n3,2,2\n9,0,2\n2,2,2\n4,3,3\n'; } > customer.txt; run "linha com exatamente o limite de tamanho" 0 10 5 7
setup; printf 'RQ 0 0 0 0\n*\n\n' > commands.txt; run "commands com branco no fim" 0 10 5 7
setup; run "argumento INT_MAX" 0 2147483647 5 7
setup; printf 'RQ 0 0 0 0\n' > commands.txt; run "argumento zero" 0 0 0 0
setup; printf '7,5\n3,2\n' > customer.txt; printf 'RQ 1 0 1\n*\n' > commands.txt; run "2 recursos" 0 10 5
setup; printf '7\n3\n' > customer.txt; printf 'RQ 1 2\nRL 1 2\n' > commands.txt; run "1 recurso" 0 10

echo "=== Erros de argumento ==="
setup; run "sem argumentos" 1
setup; run "argumento letras" 1 abc 5 7
setup; run "argumento negativo" 1 -1 5 7
setup; run "argumento com lixo" 1 5x 5 7
setup; run "argumento vazio" 1 "" 5 7
setup; run "argumento gigante" 1 99999999999999999999 5 7
setup; run "argumento INT_MAX+1" 1 2147483648 5 7
setup; run "argumento com sinal mais" 1 +5 5 7
setup; run "argumento decimal" 1 5.5 5 7
setup; run "poucos argumentos" 1 10 5
setup; run "argumentos demais" 1 10 5 7 1

echo "=== Erros em customer.txt ==="
setup; rm customer.txt; run "customer ausente" 1 10 5 7
setup; : > customer.txt; run "customer vazio" 1 10 5 7
setup; printf '\n' > customer.txt; run "customer so linha em branco" 1 10 5 7
setup; rm customer.txt; mkdir customer.txt; run "customer e diretorio" 1 10 5 7; rmdir customer.txt
setup; printf '7, 5,3\n' > customer.txt; run "espaco depois da virgula" 1 10 5 7
setup; printf '7,5,3 \n' > customer.txt; run "espaco no fim" 1 10 5 7
setup; printf ' 7,5,3\n' > customer.txt; run "espaco no inicio" 1 10 5 7
setup; printf '7,5,3,1\n' > customer.txt; run "campo sobrando" 1 10 5 7
setup; printf '7,5\n' > customer.txt; run "campo faltando" 1 10 5 7
setup; printf '7,5,3,\n' > customer.txt; run "virgula final" 1 10 5 7
setup; printf ',7,5,3\n' > customer.txt; run "virgula inicial" 1 10 5 7
setup; printf '7,,3\n' > customer.txt; run "campo vazio" 1 10 5 7
setup; printf '7,-5,3\n' > customer.txt; run "valor negativo" 1 10 5 7
setup; printf '7,a,3\n' > customer.txt; run "valor letra" 1 10 5 7
setup; printf '7,5,3\r\n3,2,2\r\n' > customer.txt; run "CRLF" 1 10 5 7
setup; printf '7,5,3\n\n3,2,2\n' > customer.txt; run "linha em branco no meio" 1 10 5 7
setup; printf '7,5,3\n3,2,2\n9,0\n' > customer.txt; run "erro so na ultima linha" 1 10 5 7
setup; printf '7;5;3\n' > customer.txt; run "separador ponto e virgula" 1 10 5 7
setup; printf '99999999999999999999,5,3\n' > customer.txt; run "valor gigante" 1 10 5 7
setup; head -c 5000 /dev/zero | tr '\0' '7' > customer.txt; run "linha longa" 1 10 5 7
setup; { head -c 131 /dev/zero | tr '\0' '0'; printf '7,5,3\n3,2,2\n9,0,2\n2,2,2\n4,3,3\n'; } > customer.txt; run "linha com 1 caractere acima do limite" 1 10 5 7
setup; printf '7,5,3\n3,2,2\n9,0,2\n2,2,2\n4,3,3\0\n' > customer.txt; run "byte NUL no fim da linha" 1 10 5 7
setup; printf '7,5,3\n3,2,2\0lixo\n9,0,2\n2,2,2\n4,3,3\n' > customer.txt; run "byte NUL no meio da linha" 1 10 5 7
setup; printf '7,5,3\n3,2,2\n9,0,2\n2,2,2\n4,3,3\n\0\n' > customer.txt; run "linha so com byte NUL" 1 10 5 7

echo "=== Erros em commands.txt ==="
setup; rm commands.txt; run "commands ausente" 1 10 5 7
setup; rm commands.txt; mkdir commands.txt; run "commands e diretorio" 1 10 5 7; rmdir commands.txt
setup; printf 'XX 0 1 2 3\n' > commands.txt; run "comando desconhecido" 1 10 5 7
setup; printf 'rq 0 1 2 3\n' > commands.txt; run "minusculo" 1 10 5 7
setup; printf 'RQ 0 1 2\n' > commands.txt; run "campo faltando" 1 10 5 7
setup; printf 'RQ 0 1 2 3 4\n' > commands.txt; run "campo sobrando" 1 10 5 7
setup; printf 'RQ 5 0 0 0\n' > commands.txt; run "cliente 5 (nao existe)" 1 10 5 7
setup; printf 'RQ 99999 0 0 0\n' > commands.txt; run "cliente muito alto" 1 10 5 7
setup; printf 'RQ -1 0 0 0\n' > commands.txt; run "cliente negativo" 1 10 5 7
setup; printf 'RQ  0 1 2 3\n' > commands.txt; run "espaco duplo" 1 10 5 7
setup; printf 'RQ 0 1 2 3 \n' > commands.txt; run "espaco no fim" 1 10 5 7
setup; printf 'RQ\t0 1 2 3\n' > commands.txt; run "tab no lugar do espaco" 1 10 5 7
setup; printf '* \n' > commands.txt; run "asterisco com espaco" 1 10 5 7
setup; printf '*x\n' > commands.txt; run "asterisco com lixo" 1 10 5 7
setup; printf '**\n' > commands.txt; run "dois asteriscos" 1 10 5 7
setup; printf 'RL\n' > commands.txt; run "RL sem nada" 1 10 5 7
setup; printf 'RQ 0 1 -2 3\n' > commands.txt; run "valor negativo" 1 10 5 7
setup; printf 'RQ 0 1 a 3\n' > commands.txt; run "valor letra" 1 10 5 7
setup; printf 'RQ 0 1 2 3\r\n' > commands.txt; run "CRLF" 1 10 5 7
setup; printf 'RQ 0 1 2 3\n\nRL 0 1 1 1\n' > commands.txt; run "linha em branco no meio" 1 10 5 7
setup; printf 'RQ 0 0 0 0\nRQ 0 0 0 0\nRQ 0 0 0\n' > commands.txt; run "erro so na ultima linha" 1 10 5 7
setup; printf 'RQ 0 0 0 0\nRQ 0 0 0 0\n*\n*\nRL 0 0 0 0\nRQ 1 0 0 0\nRQ 5 0 0 0\n' > commands.txt; run "cliente invalido depois de varios validos" 1 10 5 7
setup; printf 'RQ 0 0 0 99999999999999999999\n' > commands.txt; run "valor gigante" 1 10 5 7
setup; head -c 5000 /dev/zero | tr '\0' 'R' > commands.txt; run "linha longa" 1 10 5 7
setup; printf 'RQ 0 1 2 3\0\n' > commands.txt; run "byte NUL no fim da linha" 1 10 5 7
setup; printf 'RQ 0 1 2 3\0lixo\n' > commands.txt; run "byte NUL no meio da linha" 1 10 5 7
setup; printf 'RQ 0 1 2 3\n\0\n' > commands.txt; run "linha so com byte NUL" 1 10 5 7

echo
echo "RESUMO: $pass OK, $bad FALHOU"
rm -f out.txt err.txt customer.txt commands.txt
[ "$bad" -eq 0 ]
