import itertools
import os
import random
import subprocess
import sys
import tempfile

BIN = os.environ.get("BIN", os.path.abspath("banker"))
SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 12345
DIFERENCIAL = int(sys.argv[2]) if len(sys.argv) > 2 else 400
ROBUSTEZ = int(sys.argv[3]) if len(sys.argv) > 3 else 600

CABECALHO = "MAXIMUM   |   ALLOCATION  |   NEED\n"
INTERESSANTES = b"\r\n ,-+*0123456789RQLxX\x00\xff\t."
ARGS_RUINS = ["-1", "+3", "abc", "", "99999999999", "1e3", "0x10", " 5", "5 ", "2147483648"]


def vetor(v):
    return " ".join(str(x) for x in v)


def vetor_espacado(v):
    return "".join("%d " % x for x in v)


def seguro(disponivel, alocado, precisa):
    n = len(alocado)
    for ordem in itertools.permutations(range(n)):
        trabalho = list(disponivel)
        ok = True
        for i in ordem:
            if any(precisa[i][j] > trabalho[j] for j in range(len(trabalho))):
                ok = False
                break
            trabalho = [trabalho[j] + alocado[i][j] for j in range(len(trabalho))]
        if ok:
            return True
    return False


class Modelo:
    def __init__(self, total, maximo):
        self.r = len(total)
        self.n = len(maximo)
        self.maximo = maximo
        self.disp = list(total)
        self.aloc = [[0] * self.r for _ in range(self.n)]
        self.prec = [list(linha) for linha in maximo]
        self.saida = []
        self.erro = False

    def mover(self, c, v, sinal):
        for j in range(self.r):
            self.disp[j] -= sinal * v[j]
            self.aloc[c][j] += sinal * v[j]
            self.prec[c][j] -= sinal * v[j]

    def aplicar(self, cmd):
        if self.erro:
            return
        if cmd[0] == "*":
            self.saida.append(CABECALHO)
            for i in range(self.n):
                self.saida.append(vetor_espacado(self.maximo[i]) + "    |   " + vetor_espacado(self.aloc[i]) +
                                  "      |   " + vetor_espacado(self.prec[i]) + "\n")
            self.saida.append("AVAILABLE " + vetor_espacado(self.disp) + "\n")
            return
        tipo, c, v = cmd
        if tipo == "RL":
            if any(v[j] > self.aloc[c][j] for j in range(self.r)):
                self.erro = True
                return
            self.mover(c, v, -1)
            self.saida.append("Release from customer %d the resources %s\n" % (c, vetor(v)))
            return
        if any(v[j] > self.prec[c][j] for j in range(self.r)):
            self.saida.append("The customer %d request %s was denied because exceed its maximum allocation\n" % (c, vetor(v)))
            return
        if any(v[j] > self.disp[j] for j in range(self.r)):
            self.saida.append("The resources %s are not enough to customer %d request %s \n" % (vetor(self.disp), c, vetor(v)))
            return
        self.mover(c, v, 1)
        if seguro(self.disp, self.aloc, self.prec):
            self.saida.append("Allocate to customer %d the resources %s\n" % (c, vetor(v)))
        else:
            self.mover(c, v, -1)
            self.saida.append("The customer %d request %s was denied because result in an unsafe state\n" % (c, vetor(v)))

    def esperado(self):
        return None if self.erro else "".join(self.saida)


def gerar(rng):
    r = rng.randint(1, 3)
    n = rng.randint(1, 4)
    teto = rng.choice([2, 4, 7])
    total = [rng.randint(0, teto) for _ in range(r)]
    maximo = [[rng.randint(0, teto) for _ in range(r)] for _ in range(n)]
    modelo = Modelo(total, maximo)
    comandos = []
    for _ in range(rng.randint(0, 14)):
        sorteio = rng.random()
        c = rng.randrange(n)
        if sorteio < 0.12:
            cmd = ("*",)
        elif sorteio < 0.70:
            v = [rng.randint(0, modelo.prec[c][j]) for j in range(r)]
            if rng.random() < 0.15:
                v[rng.randrange(r)] += 1
            cmd = ("RQ", c, v)
        else:
            v = [rng.randint(0, modelo.aloc[c][j]) for j in range(r)]
            if rng.random() < 0.04:
                v[rng.randrange(r)] += 1
            cmd = ("RL", c, v)
        comandos.append(cmd)
        modelo.aplicar(cmd)
    return total, maximo, comandos, modelo.esperado()


def texto_customer(maximo, rng):
    texto = "\n".join(",".join(str(x) for x in linha) for linha in maximo)
    return texto + ("\n" if rng.random() < 0.7 else "")


def texto_commands(comandos, rng):
    linhas = []
    for cmd in comandos:
        if cmd[0] == "*":
            linhas.append("*")
        else:
            linhas.append("%s %d %s" % (cmd[0], cmd[1], vetor(cmd[2])))
    texto = "\n".join(linhas)
    if linhas and rng.random() < 0.7:
        texto += "\n"
    return texto


def executar(argumentos, customer, commands, trabalho):
    caminho = os.path.join(trabalho, "result.txt")
    if os.path.exists(caminho):
        os.remove(caminho)
    with open(os.path.join(trabalho, "customer.txt"), "wb") as f:
        f.write(customer)
    with open(os.path.join(trabalho, "commands.txt"), "wb") as f:
        f.write(commands)
    proc = subprocess.run([BIN] + argumentos, cwd=trabalho, capture_output=True, timeout=20)
    resultado = None
    if os.path.exists(caminho):
        with open(caminho, "rb") as f:
            resultado = f.read()
    return proc.returncode, proc.stdout, proc.stderr, resultado


def mutar(dados, rng):
    dados = bytearray(dados)
    for _ in range(rng.randint(1, 3)):
        acao = rng.randrange(5)
        if acao == 0 and dados:
            del dados[rng.randrange(len(dados))]
        elif acao == 1:
            dados.insert(rng.randint(0, len(dados)), rng.choice(INTERESSANTES))
        elif acao == 2 and dados:
            dados[rng.randrange(len(dados))] = rng.choice(INTERESSANTES)
        elif acao == 3 and dados:
            dados = dados[:rng.randrange(len(dados))]
        elif acao == 4 and dados:
            ini = rng.randrange(len(dados))
            dados[ini:ini] = dados[ini:ini + rng.randint(1, 8)]
    return bytes(dados)


def main():
    rng = random.Random(SEED)
    ok = 0
    falhas = 0
    cobertura = {"Allocate": 0, "Release": 0, "exceed": 0, "not enough": 0, "unsafe": 0, "MAXIMUM": 0, "erro RL": 0}
    with tempfile.TemporaryDirectory() as trabalho:
        for k in range(DIFERENCIAL):
            total, maximo, comandos, esperado = gerar(rng)
            if esperado is None:
                cobertura["erro RL"] += 1
            else:
                for chave in cobertura:
                    cobertura[chave] += esperado.count(chave)
            texto_c = texto_customer(maximo, rng)
            texto_m = texto_commands(comandos, rng)
            if rng.random() < 0.3:
                texto_c = texto_c.replace("\n", "\r\n")
            if rng.random() < 0.3:
                texto_m = texto_m.replace("\n", "\r\n")
            rc, out, err, resultado = executar([str(x) for x in total],
                                               texto_c.encode(), texto_m.encode(), trabalho)
            if esperado is None:
                bom = rc == 1 and resultado is None and out == b"" and err.startswith(b"Erro: ")
            else:
                bom = rc == 0 and out == b"" and err == b"" and resultado == esperado.encode()
            if bom:
                ok += 1
            else:
                falhas += 1
                print("[FALHOU] diferencial caso %d seed %d: total=%s maximo=%s comandos=%s rc=%s" %
                      (k, SEED, total, maximo, comandos, rc))
                print("   esperado: %r" % esperado)
                print("   obtido:   %r | stderr=%r" % (resultado, err[:200]))
    print("   respostas esperadas cobertas: " + ", ".join("%s=%d" % (c, v) for c, v in cobertura.items()))
    print("RESUMO diferencial: %d OK, %d FALHOU (seed %d)" % (ok, falhas, SEED))

    falhas_diferencial = falhas
    ok = 0
    falhas = 0
    validos = 0
    with tempfile.TemporaryDirectory() as trabalho:
        for k in range(ROBUSTEZ):
            total, maximo, comandos, _ = gerar(rng)
            argumentos = [str(x) for x in total]
            customer = texto_customer(maximo, rng).encode()
            commands = texto_commands(comandos, rng).encode()
            alvo = rng.randrange(3)
            if alvo == 0:
                customer = mutar(customer, rng)
            elif alvo == 1:
                commands = mutar(commands, rng)
            else:
                argumentos[rng.randrange(len(argumentos))] = rng.choice(ARGS_RUINS)
            rc, out, err, resultado = executar(argumentos, customer, commands, trabalho)
            bom = rc in (0, 1) and out == b""
            bom = bom and b"Sanitizer" not in err and b"runtime error" not in err
            if b"\0" in customer or b"\0" in commands:
                bom = bom and rc == 1
            if rc == 0:
                validos += 1
                bom = bom and resultado is not None and err == b""
            else:
                bom = bom and resultado is None and err.startswith(b"Erro: ")
            if bom:
                ok += 1
            else:
                falhas += 1
                print("[FALHOU] robustez caso %d seed %d: args=%s rc=%s" % (k, SEED, argumentos, rc))
                print("   customer=%r" % customer)
                print("   commands=%r" % commands)
                print("   stderr=%r" % err[:300])
    print("RESUMO robustez: %d OK, %d FALHOU (seed %d, %d entradas ainda validas)" % (ok, falhas, SEED, validos))
    return 1 if falhas or falhas_diferencial else 0


sys.exit(main())
