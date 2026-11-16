# Banker

Implementacao do algoritmo do banqueiro (Silberschatz, Operating System Concepts, 10a edicao, p. P-45) da Implementacao 5 de Infraestrutura de Software, CESAR School. Login: gsg4.

O numero de recursos vem dos argumentos do programa e o numero de clientes vem do numero de linhas do customer.txt, entao nenhum dos dois esta fixo no codigo.

## Compilar

Precisa de gcc e make (Linux, Unix ou macOS).

```
make
```

Isso gera o executavel `banker`. Para apagar ele:

```
make clean
```

## Executar

Cada argumento e a quantidade de instancias de um tipo de recurso. Por exemplo, tres recursos com 10, 5 e 7 instancias:

```
./banker 10 5 7
```

O programa le o `customer.txt` e o `commands.txt` da pasta atual e escreve o `result.txt` nela tambem.

customer.txt tem uma linha por cliente, com o maximo de cada recurso separado por virgula e sem espaco:

```
7,5,3
3,2,2
9,0,2
2,2,2
4,3,3
```

commands.txt tem um comando por linha, separado por um espaco. Os clientes comecam em 0.

```
RQ 0 0 2 1
RL 0 0 1 1
*
```

`RQ` pede recursos, `RL` devolve recursos e `*` escreve a tabela com o estado atual.

Os dois arquivos so aceitam numeros inteiros sem sinal. Pode ser fim de linha LF ou CRLF. A ultima linha nao precisa de quebra de linha, e linhas em branco so sao aceitas no final do arquivo. Qualquer outro caractere fora do formato (espaco sobrando, `\r` no meio da linha, byte nulo) e erro.

## Saida

Para cada `RQ` o programa confere, nesta ordem:

1. Se o pedido e maior que o NEED do cliente: `The customer 0 request 0 2 0 was denied because exceed its maximum allocation`
2. Se nao tem instancias livres suficientes: `The resources 3 3 2 are not enough to customer 4 request 4 0 0 ` (com um espaco no final, igual ao result.txt do professor)
3. Se atender o pedido deixa o sistema em estado inseguro: `The customer 0 request 0 2 0 was denied because result in an unsafe state` (o estado volta ao que era antes)
4. Se passou em tudo: `Allocate to customer 0 the resources 0 2 1`

O `RL` escreve `Release from customer 0 the resources 0 1 1`.

O `*` escreve a tabela abaixo. Cada linha de dados e a linha do AVAILABLE terminam com um espaco, que nao da pra ver aqui.

```
MAXIMUM   |   ALLOCATION  |   NEED
7 5 3     |   0 1 0       |   7 4 3
3 2 2     |   2 0 0       |   1 2 2
AVAILABLE 3 3 2
```

Os espacos da tabela estao fixos no codigo. Conferi com o resultado do professor, que tem 3 recursos. Com outra quantidade de recursos a tabela sai com os mesmos separadores, sem alinhar.

## Erros

Antes de calcular qualquer coisa o programa confere os argumentos e os dois arquivos. Se algo estiver errado ele escreve `Erro: ...` no stderr (com o arquivo e a linha, quando faz sentido), termina com codigo 1 e nao mexe no `result.txt`. Isso vale para:

- nenhum argumento, ou argumento que nao e inteiro sem sinal
- customer.txt ou commands.txt que nao existe, nao abre ou esta vazio (no caso do customer.txt)
- linha com quantidade de campos diferente da quantidade de recursos dos argumentos
- valor mal formatado, comando desconhecido, cliente que nao existe, linha em branco no meio, linha grande demais

Tem um erro que so aparece rodando: um `RL` que devolve mais do que o cliente tem. O enunciado nao diz o que fazer nesse caso. Eu escolhi encerrar com erro (codigo 1 e a linha do commands.txt na mensagem) e apagar o `result.txt` que ja tinha sido escrito, para nao ficar um resultado pela metade.

## Testes

```
make test
```

Compila o programa e uma segunda versao com AddressSanitizer e UBSan e roda tudo da pasta `tests` nas duas:

- `testes_entradas.sh`: argumentos e arquivos invalidos, CRLF, byte nulo, tamanho maximo de linha.
- `testes_execucao.sh`: compara byte a byte a saida do exemplo do enunciado com `tests/exemplo/result.txt` (tambem com as entradas em CRLF) e testa os limites de RQ, RL e `*`.
- `teste_estado.c`: teste da funcao que verifica se o estado e seguro.
- `testes_aleatorios.sh` e `teste_aleatorio.py`: gera entradas aleatorias e compara o resultado com um modelo escrito a parte em Python (que testa todas as ordens possiveis de clientes para decidir se o estado e seguro). Tambem estraga bytes de entradas validas para ver se o programa nunca quebra. Precisa de python3, sem ele essa parte e pulada.

O `make test` termina com codigo diferente de zero se algum teste falhar. Os arquivos em `tests/exemplo` sao uma copia do exemplo do enunciado.

O `evidencias.log` tem as sessoes de teste gravadas com `script -a`, uma antes de cada commit.
