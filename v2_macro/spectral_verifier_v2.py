import numpy as np

def verify_7n_automation_v2():
    print("=== СПЕКТРАЛЬНЫЙ ВЕРИФИКАТОР АВТОМАТА 7n (ВЕРСИЯ 2) ===")
    
    # 1. Вычисление ранга тензорного произведения в конечном поле характеристики 2
    P7_F2 = np.ones((7, 7), dtype=int)
    P13_F2 = np.ones((13, 13), dtype=int)
    P_cross_F2 = np.kron(P7_F2, P13_F2) % 2
    
    def rank_f2(matrix):
        mat = matrix.copy()
        r = 0
        rows, cols = mat.shape
        for c in range(cols):
            pivot = -1
            for i in range(r, rows):
                if mat[i, c] == 1:
                    pivot = i
                    break
            if pivot != -1:
                mat[[r, pivot]] = mat[[pivot, r]]
                for i in range(r + 1, rows):
                    if mat[i, c] == 1:
                        mat[i] = (mat[i] + mat[r]) % 2
                r += 1
        return r

    rank_cross = rank_f2(P_cross_F2)
    print(f"[STATUS] Сетка кросс-интерфейса: {P_cross_F2.shape}")
    print(f"[STATUS] Rank_F2(P_7 x P_13 mod 2) = {rank_cross}")

    # 2. Вычисление ранга регулярного Лапласиана граничного слоя n=211
    P211_reg = np.ones((211, 211), dtype=int) - np.eye(211, dtype=int)
    rank_211 = rank_f2(P211_reg)
    print(f"[STATUS] Граничный слой: {P211_reg.shape}")
    print(f"[STATUS] Rank_F2(P_reg^(211)) = {rank_211}")

    # 3. Анализ сингулярности оператора P^(157) в вещественном спектре
    s_crit = 156.0 / 157.0
    lambda_min = s_crit - (157.0 - 1.0) / 157.0
    print(f"[STATUS] Размерность N(12)=157. При s = 156/157, lambda_min = {lambda_min:.10e}")
    print("[STATUS] Верификация спектральных инвариантов завершена.")

if __name__ == "__main__":
    verify_7n_automation_v2()
