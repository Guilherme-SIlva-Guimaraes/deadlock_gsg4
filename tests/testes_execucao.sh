#!/bin/bash
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OFC="$ROOT/tests/exemplo"
BIN=${BIN:-$ROOT/banker}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1
pass=0
bad=0

veredito() {
    if [ "$1" = OK ]; then pass=$((pass + 1)); else bad=$((bad + 1)); fi
}

caso() {
    local nome=$1 args=$2 cust=$3 cmds=$4 esperado=$5
    rm -f result.txt out.txt err.txt
    printf '%b' "$cust" > customer.txt
    printf '%b' "$cmds" > commands.txt
    printf '%b' "$esperado" > esperado.txt
    $BIN $args > out.txt 2> err.txt
    local rc=$?
    local ok=OK
    [ "$rc" -ne 0 ] && ok=FALHOU
    [ -s out.txt ] && ok=FALHOU
    [ -s err.txt ] && ok=FALHOU
    if [ ! -e result.txt ] || ! cmp -s result.txt esperado.txt; then ok=FALHOU; fi
    printf '[%s] %s | %s %s | exit=%s\n' "$ok" "$nome" "$BIN" "$args" "$rc"
    if [ "$ok" != OK ]; then
        echo "   --- obtido:"; cat -A result.txt 2>/dev/null | sed 's/^/   /'
        echo "   --- esperado:"; cat -A esperado.txt | sed 's/^/   /'
        sed 's/^/   stderr: /' err.txt
    fi
    veredito "$ok"
}

erro_execucao() {
    local nome=$1 args=$2 cust=$3 cmds=$4 trecho=$5
    rm -f result.txt out.txt err.txt
    printf '%b' "$cust" > customer.txt
    printf '%b' "$cmds" > commands.txt
    $BIN $args > out.txt 2> err.txt
    local rc=$?
    local ok=OK
    [ "$rc" -ne 1 ] && ok=FALHOU
    [ -e result.txt ] && ok=FALHOU
    [ -s out.txt ] && ok=FALHOU
    grep -q "$trecho" err.txt || ok=FALHOU
    printf '[%s] %s | %s %s | exit=%s | result.txt=%s\n' "$ok" "$nome" "$BIN" "$args" "$rc" "$([ -e result.txt ] && echo sim || echo nao)"
    sed 's/^/        stderr: /' err.txt
    veredito "$ok"
}

echo "=== Exemplo oficial do enunciado, saida completa ==="
cp "$OFC/customer.txt" "$OFC/commands.txt" .
rm -f result.txt
$BIN 10 5 7 > out.txt 2> err.txt
rc=$?
cp "$OFC/result.txt" esperado.txt
ok=OK
[ "$rc" -ne 0 ] && ok=FALHOU
[ -s out.txt ] && ok=FALHOU
[ -s err.txt ] && ok=FALHOU
cmp -s result.txt esperado.txt || ok=FALHOU
printf '[%s] oficial completo, cmp byte a byte contra o result.txt do professor | exit=%s\n' "$ok" "$rc"
cmp result.txt "$OFC/result.txt" && echo "        cmp: sem diferencas ($(wc -c < result.txt) bytes)"
if [ "$ok" != OK ]; then diff result.txt esperado.txt | cat -A | head -20; fi
veredito "$ok"

echo "=== Casos limite de RQ e RL ==="
caso "RQ igual ao need (borda D == P)" "5" "5\n" "RQ 0 5\n" "Allocate to customer 0 the resources 5\n"
caso "RQ maior que o need por 1" "9" "5\n" "RQ 0 6\n" "The customer 0 request 6 was denied because exceed its maximum allocation\n"
caso "RQ igual ao disponivel" "3" "3\n" "RQ 0 3\n" "Allocate to customer 0 the resources 3\n"
caso "RQ maior que o disponivel mas dentro do need" "4" "4\n4\n" "RQ 0 3\nRQ 1 2\n" "Allocate to customer 0 the resources 3\nThe resources 1 are not enough to customer 1 request 2 \n"
caso "RQ que deixa estado inseguro" "10" "10\n10\n" "RQ 0 5\nRQ 1 5\n" "Allocate to customer 0 the resources 5\nThe customer 1 request 5 was denied because result in an unsafe state\n"
caso "estado volta ao normal apos negar por inseguro" "10" "10\n10\n" "RQ 0 5\nRQ 1 5\nRL 0 5\nRQ 1 5\n" "Allocate to customer 0 the resources 5\nThe customer 1 request 5 was denied because result in an unsafe state\nRelease from customer 0 the resources 5\nAllocate to customer 1 the resources 5\n"
caso "pedido de zero" "5" "5\n" "RQ 0 0\n" "Allocate to customer 0 the resources 0\n"
caso "liberacao de zero" "5" "5\n" "RL 0 0\n" "Release from customer 0 the resources 0\n"
caso "duas instancias seguidas do mesmo pedido" "5" "5\n" "RQ 0 1\nRQ 0 1\n" "Allocate to customer 0 the resources 1\nAllocate to customer 0 the resources 1\n"
caso "RL exatamente o que possui" "5" "5\n" "RQ 0 3\nRL 0 3\nRQ 0 5\n" "Allocate to customer 0 the resources 3\nRelease from customer 0 the resources 3\nAllocate to customer 0 the resources 5\n"
caso "dois recursos, exceder o maximo" "3 3" "3,3\n" "RQ 0 4 0\n" "The customer 0 request 4 0 was denied because exceed its maximum allocation\n"
caso "dois recursos, um recurso insuficiente" "2 5" "2,5\n2,5\n" "RQ 0 2 0\nRQ 1 1 0\n" "Allocate to customer 0 the resources 2 0\nThe resources 0 5 are not enough to customer 1 request 1 0 \n"
caso "valores perto de INT_MAX" "2147483647" "2147483647\n" "RQ 0 2147483647\nRL 0 2147483647\n" "Allocate to customer 0 the resources 2147483647\nRelease from customer 0 the resources 2147483647\n"
caso "commands vazio gera result.txt vazio" "5" "5\n" "" ""
caso "exceder o maximo tem prioridade sobre faltar recurso" "2" "3\n" "RQ 0 4\n" "The customer 0 request 4 was denied because exceed its maximum allocation\n"
caso "customer.txt oficial sem newline final" "10 5 7" "7,5,3\n3,2,2\n9,0,2\n2,2,2\n4,3,3" "RQ 0 0 2 1" "Allocate to customer 0 the resources 0 2 1\n"

echo "=== Comando * ==="
CAB='MAXIMUM   |   ALLOCATION  |   NEED\n'
OFI='7,5,3\n3,2,2\n9,0,2\n2,2,2\n4,3,3\n'
caso "* no inicio (nada alocado)" "10 5 7" "$OFI" "*\n" "${CAB}7 5 3     |   0 0 0       |   7 5 3 \n3 2 2     |   0 0 0       |   3 2 2 \n9 0 2     |   0 0 0       |   9 0 2 \n2 2 2     |   0 0 0       |   2 2 2 \n4 3 3     |   0 0 0       |   4 3 3 \nAVAILABLE 10 5 7 \n"
caso "* dois seguidos" "5" "5\n" "*\n*\n" "${CAB}5     |   0       |   5 \nAVAILABLE 5 \n${CAB}5     |   0       |   5 \nAVAILABLE 5 \n"
caso "* depois de pedido negado por inseguro (estado revertido)" "10" "10\n10\n" "RQ 0 5\nRQ 1 5\n*\n" "Allocate to customer 0 the resources 5\nThe customer 1 request 5 was denied because result in an unsafe state\n${CAB}10     |   5       |   5 \n10     |   0       |   10 \nAVAILABLE 5 \n"
caso "* depois de pedido negado por exceder o maximo" "10" "4\n" "RQ 0 9\n*\n" "The customer 0 request 9 was denied because exceed its maximum allocation\n${CAB}4     |   0       |   4 \nAVAILABLE 10 \n"
caso "* depois de RL" "5" "5\n" "RQ 0 3\nRL 0 1\n*\n" "Allocate to customer 0 the resources 3\nRelease from customer 0 the resources 1\n${CAB}5     |   2       |   3 \nAVAILABLE 3 \n"
caso "* como unico comando entre dois pedidos" "5 5" "5,5\n" "RQ 0 1 2\n*\nRQ 0 1 2\n" "Allocate to customer 0 the resources 1 2\n${CAB}5 5     |   1 2       |   4 3 \nAVAILABLE 4 3 \nAllocate to customer 0 the resources 1 2\n"
caso "* com valores grandes" "2147483647" "2147483647\n" "RQ 0 2147483647\n*\n" "Allocate to customer 0 the resources 2147483647\n${CAB}2147483647     |   2147483647       |   0 \nAVAILABLE 0 \n"

echo "=== Erro durante a execucao ==="
erro_execucao "RL maior que o alocado" "5" "5\n" "RQ 0 2\nRL 0 3\n" "tenta liberar"
erro_execucao "RL sem ter nada alocado" "5" "5\n" "RL 0 1\n" "tenta liberar"
erro_execucao "RL maior em apenas um dos recursos" "5 5" "5,5\n" "RQ 0 2 2\nRL 0 2 3\n" "tenta liberar"

echo
echo "RESUMO: $pass OK, $bad FALHOU"
rm -f out.txt err.txt customer.txt commands.txt esperado.txt result.txt
[ "$bad" -eq 0 ]
