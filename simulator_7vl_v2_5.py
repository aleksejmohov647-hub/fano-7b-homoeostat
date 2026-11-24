"""
Симулятор проективно-аффинной динамики и циклов Зингера в модели 7VL (редакция v2.5).
Реализует:
1. Детерминированный расчёт инвариантов PG(2, q), каналов W_fwd/W_bwd и квантов времени.
2. Микро- и макродинамику диполя Зингера (инверсия за 24 такта и вихрь Фано за 168 тактов при q=2).
3. Проверку резонансных уровней целочисленного замыкания (Теорема 3.2 и Следствие 3.1).
4. Стохастический марковский ансамбль переходов q <-> q+1 для проверки стрелы времени chi(q).
5. Проверку покрытия разностного множества Зингера (q=2) и многофазную развёртку для запрещённого q=6.
"""

import math
import random
from dataclasses import dataclass
from typing import List, Tuple, Dict, Set


@dataclass
class LevelInvariants:
    q: int
    N: int
    Phi: int
    T0: int
    W_fwd: float
    W_bwd: float
    chi: float
    delta_asym: float
    delta_asym_tilde: float
    tau_life_step: int
    basis_B: int
    tau_life_macro: float
    tau_vortex_macro: float
    delta_tau_metric: float
    q_delta_tau: float


def compute_invariants(q: int) -> LevelInvariants:
    """Вычисляет точные аналитические инварианты уровня PG(2, q) (редакция v2.5)."""
    N = q**2 + q + 1
    N_next = (q + 1)**2 + (q + 1) + 1  # N(q+1) = q^2 + 3q + 3
    Phi = N - 1  # q(q + 1)
    T0 = 2 * Phi

    aff_vol = (q + 2)**2
    W_fwd = N_next / aff_vol
    W_bwd = N_next / (aff_vol - 1)
    chi = W_bwd / W_fwd

    delta_asym = N_next / (aff_vol * (aff_vol - 1))
    delta_asym_tilde = 1.0 / (aff_vol * (aff_vol - 1))

    # Теорема 3.2: полное число элементарных фазовых шагов до инверсии
    tau_life_step = (q + 1) * aff_vol * (aff_vol - 1)
    basis_B = q * (q + 1) * (2 * q + 1)
    tau_life_macro = tau_life_step / basis_B
    tau_vortex_macro = 7.0 * tau_life_macro

    alpha = (N_next - q) / Phi
    delta_tau_metric = math.log((N / (q**2)) * (chi ** (-alpha)))
    q_delta_tau = q * delta_tau_metric

    return LevelInvariants(
        q=q,
        N=N,
        Phi=Phi,
        T0=T0,
        W_fwd=W_fwd,
        W_bwd=W_bwd,
        chi=chi,
        delta_asym=delta_asym,
        delta_asym_tilde=delta_asym_tilde,
        tau_life_step=tau_life_step,
        basis_B=basis_B,
        tau_life_macro=tau_life_macro,
        tau_vortex_macro=tau_vortex_macro,
        delta_tau_metric=delta_tau_metric,
        q_delta_tau=q_delta_tau,
    )


def simulate_singer_dipole(q: int = 2, max_macro_ticks: int = 168) -> List[Dict]:
    """
    Симулирует детерминированное накопление удельного фазового дефекта
    в диполе Зингера D+ <-> D- на уровне q.
    ИСПРАВЛЕНО (v2.5): учтена нормировка на тактовый период T0(q).
    """
    inv = compute_invariants(q)
    C_reset = 1.0 / (2 * q)

    # За 1 макротакт проходит B(q) микрошагов, распределённых по циклу T0(q)
    defect_per_macro_tick = (inv.delta_asym_tilde * inv.basis_B) / inv.T0

    defect = 0.0
    polarity = +1  # +1 для D+, -1 для D-
    inversions = 0
    history = []

    for tick in range(1, max_macro_ticks + 1):
        defect += defect_per_macro_tick
        inverted_now = False

        if defect >= C_reset - 1e-12:
            polarity *= -1
            defect = 0.0
            inversions += 1
            inverted_now = True

        history.append({
            "tick": tick,
            "polarity": "D+" if polarity > 0 else "D-",
            "defect": round(defect, 6),
            "threshold": C_reset,
            "inverted": inverted_now,
            "total_inversions": inversions,
            "fano_vortex_cycles": inversions // 7,
        })

    return history


def simulate_markov_arrow_of_time(q: int = 2, num_trajectories: int = 100_000, seed: int = 42) -> Dict:
    """
    Монте-Карло симуляция двунаправленного цикла обмена q <-> q+1
    для верификации коэффициента нарушения детального баланса chi(q) = W_bwd / W_fwd.
    """
    rng = random.Random(seed)
    inv = compute_invariants(q)

    fwd_retained = 0
    bwd_retained = 0

    for _ in range(num_trajectories):
        if rng.random() < inv.W_fwd:
            fwd_retained += 1
        if rng.random() < inv.W_bwd:
            bwd_retained += 1

    emp_W_fwd = fwd_retained / num_trajectories
    emp_W_bwd = bwd_retained / num_trajectories
    emp_chi = emp_W_bwd / emp_W_fwd

    return {
        "q": q,
        "trajectories": num_trajectories,
        "W_fwd_theory": inv.W_fwd,
        "W_fwd_empirical": emp_W_fwd,
        "W_bwd_theory": inv.W_bwd,
        "W_bwd_empirical": emp_W_bwd,
        "chi_theory": inv.chi,
        "chi_empirical": emp_chi,
        "relative_error_pct": abs(emp_chi - inv.chi) / inv.chi * 100.0,
    }


def get_pairwise_differences(D: List[int], N: int) -> Set[int]:
    """Возвращает множество ненулевых попарных разностей (x - y) mod N."""
    diffs = set()
    for x in D:
        for y in D:
            if x != y:
                diff = (x - y) % N
                if diff != 0:
                    diffs.add(diff)
    return diffs


def check_singer_difference_set(D: List[int], N: int) -> Tuple[bool, int]:
    """Проверяет полноту покрытия Z_N* разностным множеством D."""
    diffs = get_pairwise_differences(D, N)
    missing = (N - 1) - len(diffs)
    return (missing == 0), missing


def simulate_multiphase_cover(D_low: List[int], N: int, multipliers: List[int]) -> Dict:
    """
    Моделирует многофазную развёртку D_t = (a_t * D_low) mod N (Теорема 3.1)
    для устранения синдромного дефицита на запрещённом уровне N.
    """
    covered_diffs = set()
    phase_logs = []

    for phase_idx, a_t in enumerate(multipliers, start=1):
        D_t = [(a_t * x) % N for x in D_low]
        phase_diffs = get_pairwise_differences(D_t, N)
        covered_diffs.update(phase_diffs)
        missing_now = (N - 1) - len(covered_diffs)
        phase_logs.append({
            "phase": phase_idx,
            "multiplier": a_t,
            "covered_count": len(covered_diffs),
            "missing_count": missing_now,
        })

    return {
        "N": N,
        "target_directions": N - 1,
        "total_phases": len(multipliers),
        "fully_covered": len(covered_diffs) == (N - 1),
        "phases": phase_logs,
    }


if __name__ == "__main__":
    print("=" * 78)
    print("1. ВЕРИФИКАЦИЯ ИНВАРИАНТОВ МАСШТАБИРОВАНИЯ PG(2, q) [v2.5]")
    print("=" * 78)
    header = f"{'q':>6} | {'N(q)':>11} | {'T0(q)':>11} | {'chi(q)':>10} | {'q*dtau':>8} | {'tau_2':>8} | {'tau_7':>8}"
    print(header)
    print("-" * len(header))
    for q_val in [2, 3, 4, 6, 7, 10, 12, 168, 169, 10_000]:
        res = compute_invariants(q_val)
        print(
            f"{res.q:>6} | {res.N:>11} | {res.T0:>11} | "
            f"{res.chi:>10.6f} | {res.q_delta_tau:>8.6f} | "
            f"{res.tau_life_macro:>8.2f} | {res.tau_vortex_macro:>8.2f}"
        )

    print("\n" + "=" * 78)
    print("2. ЦИКЛЫ ЗИНГЕРА И ВИХРЬ ФАНО НА БАЗОВОМ УРОВНЕ q = 2 (ИСПРАВЛЕНО)")
    print("=" * 78)
    dipole_log = simulate_singer_dipole(q=2, max_macro_ticks=168)
    inversion_ticks = [row["tick"] for row in dipole_log if row["inverted"]]
    print(f"Такты взаимной инверсии D+ <-> D- : {inversion_ticks}")
    print(f"Период полуцикла диполя          : {inversion_ticks[0]} такта")
    print(f"Число инверсий за вихрь Фано     : {len(inversion_ticks)}")
    print(f"Полный 7-цикловый вихрь |PSL(2,7)|: {inversion_ticks[-1]} тактов")

    print("\n" + "=" * 78)
    print("3. СТОХАСТИЧЕСКАЯ ПРОВЕРКА СТРЕЛЫ ВРЕМЕНИ (МОНТЕ-КАРЛО)")
    print("=" * 78)
    for q_val in [2, 3, 6]:
        mc = simulate_markov_arrow_of_time(q=q_val, num_trajectories=100_000)
        print(
            f"q = {mc['q']}: chi_теор = {mc['chi_theory']:.6f} | "
            f"chi_эмп = {mc['chi_empirical']:.6f} "
            f"(погрешность {mc['relative_error_pct']:.3f}%)"
        )

    print("\n" + "=" * 78)
    print("4. СИНДРОМНЫЙ ДЕФИЦИТ И МНОГОФАЗНАЯ РАЗВЁРТКА (ТЕОРЕМА 3.1)")
    print("=" * 78)
    # Разностное множество Зингера для q=2 (N=7): D = {1, 2, 4}
    ok_2, miss_2 = check_singer_difference_set([1, 2, 4], N=7)
    print(f"q = 2 (PG(2,2), N=7), D={{1,2,4}}: полное покрытие = {ok_2}, дыр = {miss_2}")

    # Запрещённый уровень q=6 (N=43), скелет q_low=5: D = {0, 1, 3, 8, 12, 18}
    D_low_5 = [0, 1, 3, 8, 12, 18]
    ok_6, miss_6 = check_singer_difference_set(D_low_5, N=43)
    print(f"q = 6 (запрещён, N=43), 1 фаза (M=1): полное покрытие = {ok_6}, дыр Delta_hole = {miss_6}")

    # Многофазная развёртка за M=3 фазы с множителями a_t in {1, 2, 5} mod 43
    mp_res = simulate_multiphase_cover(D_low_5, N=43, multipliers=[1, 2, 5])
    for p in mp_res["phases"]:
        print(f"  -> Фаза {p['phase']} (a={p['multiplier']}): покрыто {p['covered_count']}/42 направлений, осталось дыр: {p['missing_count']}")
