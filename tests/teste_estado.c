#define main banker_main
#include "banker.c"
#undef main

static int bad;

static void run_case(const char *name, int n, int r, const int *total, const int *max, const int *alloc, int want)
{
    Input in = {0};
    State s = {0};
    int i;
    int j;
    int got;

    in.num_resources = r;
    in.num_customers = n;
    in.total = (int *)total;
    in.max = (int *)max;
    if (state_init(&s, &in) < 0) {
        printf("[FALHOU] %s | state_init falhou\n", name);
        bad++;
        return;
    }
    for (i = 0; i < n; i++) {
        for (j = 0; j < r; j++) {
            s.allocation[i * r + j] = alloc[i * r + j];
            s.need[i * r + j] = max[i * r + j] - alloc[i * r + j];
            s.available[j] -= alloc[i * r + j];
        }
    }
    got = is_safe(&s);
    if (got != want)
        bad++;
    printf("[%s] %s | is_safe=%d esperado=%d\n", got == want ? "OK" : "FALHOU", name, got, want);
    state_free(&s);
}

int main(void)
{
    const int tot3[3] = {10, 5, 7};
    const int max5[15] = {7, 5, 3, 3, 2, 2, 9, 0, 2, 2, 2, 2, 4, 3, 3};
    const int a_livro[15] = {0, 1, 0, 2, 0, 0, 3, 0, 2, 2, 1, 1, 0, 0, 2};
    const int a_c1[15] = {0, 1, 0, 3, 0, 2, 3, 0, 2, 2, 1, 1, 0, 0, 2};
    const int a_c0[15] = {0, 3, 0, 3, 0, 2, 3, 0, 2, 2, 1, 1, 0, 0, 2};
    const int a_zero[15] = {0};
    const int t_a[1] = {3}, m_a[1] = {5}, al_a[1] = {0};
    const int t_b[1] = {10}, m_b[2] = {4, 6}, al_b[2] = {4, 6};
    const int m_c[2] = {10, 10}, al_c[2] = {5, 5};
    const int t_d[1] = {5}, m_d[1] = {5}, al_d[1] = {0};
    const int t_e[1] = {4}, m_e[2] = {3, 3}, al_e[2] = {2, 1};
    const int t_f[1] = {3}, al_f[2] = {1, 1};
    const int t_g[1] = {4}, m_g[3] = {5, 5, 5}, al_g[3] = {1, 1, 1};
    const int t_h[1] = {5}, m_h[3] = {4, 4, 2}, al_h[3] = {1, 1, 1};
    const int t_i[2] = {5, 5}, m_i[2] = {5, 6}, al_i[2] = {0, 0};
    const int t_j[1] = {INT_MAX}, m_j[2] = {INT_MAX, INT_MAX}, al_j[2] = {INT_MAX, 0};
    const int t_k[1] = {INT_MAX}, al_k[2] = {1500000000, 600000000};

    run_case("exemplo do livro (disponivel 3 3 2)", 5, 3, tot3, max5, a_livro, 1);
    run_case("apos conceder 1 0 2 ao cliente 1", 5, 3, tot3, max5, a_c1, 1);
    run_case("apos tentar 0 2 0 no cliente 0 (inseguro)", 5, 3, tot3, max5, a_c0, 0);
    run_case("nada alocado", 5, 3, tot3, max5, a_zero, 1);
    run_case("max maior que o total", 1, 1, t_a, m_a, al_a, 0);
    run_case("todos com o maximo alocado", 2, 1, t_b, m_b, al_b, 1);
    run_case("dois clientes travados", 2, 1, t_b, m_c, al_c, 0);
    run_case("um cliente, need igual ao disponivel", 1, 1, t_d, m_d, al_d, 1);
    run_case("fronteira need == disponivel", 2, 1, t_e, m_e, al_e, 1);
    run_case("need maior por 1", 2, 1, t_f, m_e, al_f, 0);
    run_case("nenhum cliente cabe", 3, 1, t_g, m_g, al_g, 0);
    run_case("so o ultimo cabe primeiro", 3, 1, t_h, m_h, al_h, 1);
    run_case("um recurso insuficiente de dois", 1, 2, t_i, m_i, al_i, 0);
    run_case("valores grandes sem overflow", 2, 1, t_j, m_j, al_j, 1);
    run_case("soma grande perto de INT_MAX", 2, 1, t_k, m_j, al_k, 0);

    printf("\nRESUMO: %d falhas\n", bad);
    return bad != 0;
}
