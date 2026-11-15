#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CUSTOMER_FILE "customer.txt"
#define COMMANDS_FILE "commands.txt"

typedef enum { CMD_RQ, CMD_RL, CMD_STATUS } CmdType;

typedef struct {
    CmdType type;
    int customer;
    int *amount;
} Command;

typedef struct {
    int num_resources;
    int *total;
    int num_customers;
    int *max;
    int num_commands;
    Command *commands;
} Input;

typedef struct {
    int num_resources;
    int num_customers;
    const int *max;
    int *available;
    int *allocation;
    int *need;
} State;

static int fail(const char *fmt, ...)
{
    va_list ap;

    fputs("Erro: ", stderr);
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
    return -1;
}

static void free_input(Input *in)
{
    int i;

    for (i = 0; i < in->num_commands; i++)
        free(in->commands[i].amount);
    free(in->commands);
    free(in->max);
    free(in->total);
}

static void state_free(State *s)
{
    free(s->available);
    free(s->allocation);
    free(s->need);
}

static int state_init(State *s, const Input *in)
{
    size_t r = (size_t)in->num_resources;
    size_t cells = (size_t)in->num_customers * r;

    s->num_resources = in->num_resources;
    s->num_customers = in->num_customers;
    s->max = in->max;
    s->available = malloc(r * sizeof(int));
    s->allocation = calloc(cells, sizeof(int));
    s->need = malloc(cells * sizeof(int));
    if (s->available == NULL || s->allocation == NULL || s->need == NULL) {
        state_free(s);
        return fail("memoria insuficiente");
    }
    memcpy(s->available, in->total, r * sizeof(int));
    memcpy(s->need, in->max, cells * sizeof(int));
    return 0;
}

int is_safe(const State *s)
{
    size_t r = (size_t)s->num_resources;
    long long *work = malloc(r * sizeof(long long));
    char *finished = calloc((size_t)s->num_customers, 1);
    int count = 0;
    int progress;
    int fits;
    int i;
    int j;
    int ret = -1;

    if (work == NULL || finished == NULL)
        goto done;
    for (j = 0; j < s->num_resources; j++)
        work[j] = s->available[j];
    do {
        progress = 0;
        for (i = 0; i < s->num_customers; i++) {
            if (finished[i])
                continue;
            fits = 1;
            for (j = 0; j < s->num_resources; j++) {
                if (s->need[i * s->num_resources + j] > work[j]) {
                    fits = 0;
                    break;
                }
            }
            if (!fits)
                continue;
            for (j = 0; j < s->num_resources; j++)
                work[j] += s->allocation[i * s->num_resources + j];
            finished[i] = 1;
            count++;
            progress = 1;
        }
    } while (progress && count < s->num_customers);
    ret = (count == s->num_customers);
done:
    free(work);
    free(finished);
    return ret;
}

static int parse_number(char **p, char sep, int *out)
{
    char *end;
    long v;

    if (!isdigit((unsigned char)**p))
        return -1;
    errno = 0;
    v = strtol(*p, &end, 10);
    if (errno == ERANGE || v > INT_MAX)
        return -1;
    if (*end != sep)
        return -1;
    *out = (int)v;
    *p = end;
    if (sep != '\0')
        (*p)++;
    return 0;
}

static int read_line(FILE *f, char *buf, size_t cap)
{
    size_t len;
    int c;

    if (fgets(buf, (int)cap, f) == NULL)
        return 0;
    len = strlen(buf);
    if (len > 0 && buf[len - 1] == '\n') {
        buf[len - 1] = '\0';
        return 1;
    }
    if (len == cap - 1) {
        c = fgetc(f);
        if (c != EOF) {
            ungetc(c, f);
            return -1;
        }
    }
    return 1;
}

static int read_customers(Input *in)
{
    FILE *f;
    char *buf;
    char *p;
    char sep;
    size_t cap;
    int status;
    int rows_cap = 0;
    int new_cap;
    int blank = 0;
    int line_no = 0;
    int ret = -1;
    int i;
    int *tmp;

    f = fopen(CUSTOMER_FILE, "r");
    if (f == NULL)
        return fail("nao foi possivel abrir %s", CUSTOMER_FILE);
    cap = (size_t)(in->num_resources + 2) * 24 + 16;
    buf = malloc(cap);
    if (buf == NULL) {
        fclose(f);
        return fail("memoria insuficiente");
    }
    while ((status = read_line(f, buf, cap)) != 0) {
        line_no++;
        if (status < 0) {
            fail("%s linha %d: linha longa demais", CUSTOMER_FILE, line_no);
            goto done;
        }
        if (buf[0] == '\0') {
            blank = 1;
            continue;
        }
        if (blank) {
            fail("%s: linha em branco antes da linha %d", CUSTOMER_FILE, line_no);
            goto done;
        }
        if (in->num_customers == rows_cap) {
            new_cap = rows_cap == 0 ? 8 : rows_cap * 2;
            tmp = realloc(in->max, (size_t)new_cap * (size_t)in->num_resources * sizeof(int));
            if (tmp == NULL) {
                fail("memoria insuficiente");
                goto done;
            }
            in->max = tmp;
            rows_cap = new_cap;
        }
        p = buf;
        for (i = 0; i < in->num_resources; i++) {
            sep = (i == in->num_resources - 1) ? '\0' : ',';
            if (parse_number(&p, sep, &in->max[in->num_customers * in->num_resources + i]) < 0) {
                fail("%s linha %d: formato invalido, esperado %d numeros inteiros nao negativos separados por virgula, sem espacos",
                     CUSTOMER_FILE, line_no, in->num_resources);
                goto done;
            }
        }
        in->num_customers++;
    }
    if (ferror(f)) {
        fail("falha ao ler %s", CUSTOMER_FILE);
        goto done;
    }
    if (in->num_customers == 0) {
        fail("%s nao contem nenhum cliente", CUSTOMER_FILE);
        goto done;
    }
    ret = 0;
done:
    free(buf);
    fclose(f);
    return ret;
}

static int parse_command(const Input *in, char *line, Command *cmd)
{
    char *p = line;
    char sep;
    int i;

    cmd->amount = NULL;
    cmd->customer = 0;
    if (strcmp(line, "*") == 0) {
        cmd->type = CMD_STATUS;
        return 0;
    }
    if (strncmp(line, "RQ ", 3) == 0)
        cmd->type = CMD_RQ;
    else if (strncmp(line, "RL ", 3) == 0)
        cmd->type = CMD_RL;
    else
        return -1;
    p += 3;
    if (parse_number(&p, ' ', &cmd->customer) < 0)
        return -1;
    if (cmd->customer >= in->num_customers)
        return -2;
    cmd->amount = malloc((size_t)in->num_resources * sizeof(int));
    if (cmd->amount == NULL)
        return -3;
    for (i = 0; i < in->num_resources; i++) {
        sep = (i == in->num_resources - 1) ? '\0' : ' ';
        if (parse_number(&p, sep, &cmd->amount[i]) < 0) {
            free(cmd->amount);
            cmd->amount = NULL;
            return -1;
        }
    }
    return 0;
}

static int read_commands(Input *in)
{
    FILE *f;
    char *buf;
    size_t cap;
    int status;
    int rows_cap = 0;
    int new_cap;
    int blank = 0;
    int line_no = 0;
    int ret = -1;
    int code;
    Command *tmp;
    Command cmd;

    f = fopen(COMMANDS_FILE, "r");
    if (f == NULL)
        return fail("nao foi possivel abrir %s", COMMANDS_FILE);
    cap = (size_t)(in->num_resources + 2) * 24 + 16;
    buf = malloc(cap);
    if (buf == NULL) {
        fclose(f);
        return fail("memoria insuficiente");
    }
    while ((status = read_line(f, buf, cap)) != 0) {
        line_no++;
        if (status < 0) {
            fail("%s linha %d: linha longa demais", COMMANDS_FILE, line_no);
            goto done;
        }
        if (buf[0] == '\0') {
            blank = 1;
            continue;
        }
        if (blank) {
            fail("%s: linha em branco antes da linha %d", COMMANDS_FILE, line_no);
            goto done;
        }
        code = parse_command(in, buf, &cmd);
        if (code == -1) {
            fail("%s linha %d: comando invalido, esperado \"*\", \"RQ cliente r1 ...\" ou \"RL cliente r1 ...\" com %d recursos separados por um espaco",
                 COMMANDS_FILE, line_no, in->num_resources);
            goto done;
        }
        if (code == -2) {
            fail("%s linha %d: cliente %d nao existe (clientes de 0 a %d)",
                 COMMANDS_FILE, line_no, cmd.customer, in->num_customers - 1);
            goto done;
        }
        if (code == -3) {
            fail("memoria insuficiente");
            goto done;
        }
        if (in->num_commands == rows_cap) {
            new_cap = rows_cap == 0 ? 16 : rows_cap * 2;
            tmp = realloc(in->commands, (size_t)new_cap * sizeof(Command));
            if (tmp == NULL) {
                free(cmd.amount);
                fail("memoria insuficiente");
                goto done;
            }
            in->commands = tmp;
            rows_cap = new_cap;
        }
        in->commands[in->num_commands++] = cmd;
    }
    if (ferror(f)) {
        fail("falha ao ler %s", COMMANDS_FILE);
        goto done;
    }
    ret = 0;
done:
    free(buf);
    fclose(f);
    return ret;
}

int main(int argc, char **argv)
{
    Input in = {0};
    State st = {0};
    char *p;
    int i;
    int v;

    if (argc < 2) {
        fail("uso: %s <instancias do recurso 0> <instancias do recurso 1> ...", argv[0]);
        return 1;
    }
    in.num_resources = argc - 1;
    in.total = malloc((size_t)in.num_resources * sizeof(int));
    if (in.total == NULL) {
        fail("memoria insuficiente");
        return 1;
    }
    for (i = 0; i < in.num_resources; i++) {
        p = argv[i + 1];
        if (parse_number(&p, '\0', &v) < 0) {
            fail("argumento invalido \"%s\", esperado inteiro nao negativo", argv[i + 1]);
            free_input(&in);
            return 1;
        }
        in.total[i] = v;
    }
    if (read_customers(&in) < 0 || read_commands(&in) < 0) {
        free_input(&in);
        return 1;
    }
    if (state_init(&st, &in) < 0) {
        free_input(&in);
        return 1;
    }
    state_free(&st);
    free_input(&in);
    return 0;
}
