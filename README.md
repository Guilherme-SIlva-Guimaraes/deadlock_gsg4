# Algoritmo de Banker

Implementacao do algoritmo de Banker (Silberschatz, Operating System Concepts, 10a edicao, p. P-45) para a disciplina de Infraestrutura de Software, CESAR School.

O numero de clientes e o numero de tipos de recursos nao sao fixos: o numero de recursos vem dos argumentos do programa e o numero de clientes vem do numero de linhas do arquivo customer.txt.

## Compilar

```
make
```

Gera o executavel `banker`. Para remover o executavel:

```
make clean
```

## Executar

Cada argumento e o numero de instancias de um tipo de recurso. Exemplo com tres tipos de recurso (10, 5 e 7 instancias):

```
./banker 10 5 7
```

O programa le dois arquivos do diretorio atual:

- `customer.txt`: uma linha por cliente, com o maximo de cada recurso separado por virgula. Exemplo: `7,5,3`.
- `commands.txt`: um comando por linha. `RQ <cliente> <r1> <r2> ...` pede recursos, `RL <cliente> <r1> <r2> ...` libera recursos e `*` imprime o estado atual.

O resultado e gravado em `result.txt`.

## Erros

Em caso de erro (numero de argumentos diferente do numero de colunas dos arquivos, arquivo inexistente ou com formato invalido) o programa escreve a mensagem em stderr, termina com codigo diferente de zero e nao cria `result.txt`.

Se um `RL` tentar liberar mais recursos do que o cliente possui, o programa tambem encerra com erro e remove o `result.txt` ja gravado.

## Testes

```
make test
```

Compila o programa, compila uma versao com AddressSanitizer e UBSan e roda, com as duas, os scripts da pasta `tests`:

- `tests/testes_entradas.sh`: argumentos invalidos, `customer.txt` e `commands.txt` ausentes ou mal formatados, casos limite.
- `tests/testes_execucao.sh`: comparacao byte a byte da saida do exemplo do enunciado com `tests/exemplo/result.txt`, casos limite de `RQ`, `RL` e `*`, e erros durante a execucao.
- `tests/teste_estado.c`: teste unitario da verificacao de estado seguro.
- `tests/testes_aleatorios.sh` e `tests/teste_aleatorio.py`: gera entradas aleatorias (semente fixa) e compara o `result.txt` com um modelo independente em Python, que decide a seguranca do estado testando todas as ordens possiveis de clientes. Tambem altera bytes de entradas validas para conferir que o programa nunca quebra nem deixa `result.txt` quando termina com erro. Precisa de `python3`; sem ele esta etapa e ignorada.

O comando termina com codigo diferente de zero se algum teste falhar.

Para repetir so a parte aleatoria com outra semente (numero de casos diferenciais e de robustez opcionais):

```
bash tests/testes_aleatorios.sh 999 400 600
```

## Status

Em desenvolvimento. Este README sera completado nos proximos commits.
