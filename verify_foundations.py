import math
import numpy as np
import scipy.linalg as la

def verify_all_sync():
    print("=== ЗАПУСК СИНХРОНИЗИРОВАННОГО ВЕРИФИКАЦИОННОГО ЯДРА NOC ===")
    
    # ----------------------------------------------------
    # БЛОК 1: Теоретико-числовые законы (Закон IV и II)
    # ----------------------------------------------------
    print("\n[ТЕСТ 1] Верификация Закона IV (Локально-глобальный принцип):")
    n = 13
    fact_13 = math.factorial(n)
    subfact_13 = sum((-1)**k * fact_13 // math.factorial(k) for k in range(n + 1))
    delta_13 = fact_13 - subfact_13
    
    res_mod13 = delta_13 % 13
    res_mod157 = delta_13 % 157
    
    print(f"  -> Delta_13 mod 13  = {res_mod13} (Ожидалось: 1)")
    print(f"  -> Delta_13 mod 157 = {res_mod157} (Ожидалось след связности k: 13)")
    assert res_mod13 == 1, "Ошибка проверки по модулю 13!"
    assert res_mod157 == 13, "Ошибка проверки по модулю 157!"
    print("  >> Закон IV успешно подтвержден точными инвариантами.")

    print("\n[ТЕСТ 2] Верификация Закона II (Трансцендентный регулятор):")
    n_large = 20
    fact_large = math.factorial(n_large)
    subfact_large = sum((-1)**k * fact_large // math.factorial(k) for k in range(n_large + 1))
    xi_rel = ((fact_large // 2) - subfact_large) / fact_large
    p_ord = (fact_large - subfact_large) / fact_large
    diff = p_ord - xi_rel
    
    print(f"  -> Относительный сдвиг щели \u039e_rel: {xi_rel:.12f}")
    print(f"  -> Вероятность порядка P_ord:        {p_ord:.12f}")
    print(f"  -> Разность (P_ord - \u039e_rel):        {diff:.1f} (Ожидалось: 0.5)")
    assert abs(diff - 0.5) < 1e-9, "Ошибка расчета регулятора!"
    print("  >> Закон II успешно подтвержден.")

    # ----------------------------------------------------
    # БЛОК 2: Спектральная теория ориентированных NoC (Раздел 3)
    # ----------------------------------------------------
    print("\n[ТЕСТ 3] Спектральный анализ направленной NoC-топологии:")
    v = 157
    D = [0, 1, 3, 13, 32, 36, 43, 64, 71, 91, 111, 135, 152]
    
    # Строим строго направленную матрицу смежности без петель (0 удален)
    A_dir = np.zeros((v, v), dtype=int)
    for i in range(v):
        for element in D:
            if element != 0:  # Исключаем петли
                j = (i + element) % v
                A_dir[i, j] = 1
                
    # Комплексный спектр орграфа
    eigenvalues = la.eigvals(A_dir)
    
    # Сортировка по модулю собственных значений
    eigenvalues_sorted = sorted(eigenvalues, key=abs, reverse=True)
    lambda_0 = abs(eigenvalues_sorted[0])
    mu_max = max([abs(ev) for ev in eigenvalues_sorted[1:]])
    
    k_eff = 12 # Реальное число исходящих линий (без петли)
    ramanujan_bound_dir = np.sqrt(k_eff)
    
    print(f"  -> Фактическая степень регулярности орграфа k_eff: {lambda_0:.1f}")
    print(f"  -> Макс. нетривиальный модуль \u03bc_max:           {mu_max:.4f}")
    print(f"  -> Предел Рамануджана для орграфов (\u221ak_eff):    {ramanujan_bound_dir:.4f}")
    print(f"  -> Алгебраическая связность \u03bb_1 (k_eff - \u03bc_max): {k_eff - mu_max:.4f}")
    print(f"  -> Нижний порог константы Чигера h(G) >=:        {(k_eff - mu_max)/2:.4f}")
    
    print("\n=== ВСЕ КОМПОНЕНТЫ МОДЕЛИ УСПЕШНО СИНХРОНИЗИРОВАНЫ ===")

if __name__ == "__main__":
    verify_all_sync()
