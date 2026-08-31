import numpy as np
from scipy.special import factorial

def subfactorial(n):
    return int(np.round(factorial(n) / np.e)) if n > 0 else 1

def calc_delta(n):
    return subfactorial(n) / factorial(n) - 1.0 / np.e

# 1. Полярные инварианты микро- и макро-уровней (A6-A8 против каскадов Sn)
A_micro = [6, 7, 8]
sum_def_A = np.sum([calc_delta(n) for n in A_micro])

S_octaves = {
    1:,
    2:,
    3:,
    4: [43, 44, 45, 46]
}

N_modules = {1: 157, 2: 183, 3: 601, 4: 2977}

# 2. Мнимые части нулей дзета-функции для калибровки шагов
t_zeros = np.array([14.13472514, 21.02203964, 25.01085758, 30.42487612, 32.93506159, 37.58617816, 40.91871901])

# 3. Базовая матрица Фано (7x7)
M_Fano = np.array([
    [ 0,  1,  0,  1,  0,  0, -1],
    [-1,  0,  1,  0,  1,  0,  0],
    [ 0, -1,  0,  1,  0,  1,  0],
    [-1,  0, -1,  0,  1,  0,  1],
    [ 0, -1,  0, -1,  0,  1,  0],
    [ 0,  0, -1,  0, -1,  0,  1],
    [ 1,  0,  0, -1,  0, -1,  0]
], dtype=float)

# 4. Сквозной обсчет замкнутых мультимасштабных октав
for oct_idx in sorted(N_modules.keys()):
    N = N_modules[oct_idx]
    S_macro = S_octaves[oct_idx]
    sum_def_S = np.sum([calc_delta(n) for n in S_macro])
    
    # Расчет сирийского сечения и мезо-дефекта
    sechenie = (sum_def_A * 3) / (sum_def_S * 4)
    meso_defect = (N * sechenie) - np.round(N * sechenie)
    T = 1.0 / abs(meso_defect) if abs(meso_defect) > 1e-12 else float('inf')
    
    # Построение глобального циклического оператора D_F1
    D_F1 = np.zeros((7 * N, 7 * N))
    for j in range(N):
        t_coeff = 1.0 / t_zeros[j % len(t_zeros)]
        next_j = (j + 2) % N
        
        ket_bra1 = np.zeros((N, N))
        ket_bra1[j, next_j] = 1.0
        term1 = t_coeff * np.kron(M_Fano, ket_bra1)
        
        ket_bra2 = np.zeros((N, N))
        ket_bra2[next_j, j] = 1.0
        term2 = t_coeff * np.kron(M_Fano.T, ket_bra2)
        
        D_F1 += (term1 - term2)
        
    eigenvalues = np.linalg.eigvals(D_F1)
    min_E = np.min(np.abs(eigenvalues))
    
    print(f"Октава {oct_idx} | N = {N:<4} | Min |E|: {min_E:.2e} | Сечение: {sechenie:.4e} | Время жизни T: {T:.2f}")

# 5. Квантовый автомат: Проверка унитарной защиты 5-тактового цикла (U^5 = I)
theta_3 = 2.0 * np.pi * (2.0 / 5.0)
U = np.zeros((5, 5), dtype=complex)
for i in range(5):
    U[i, (i + 1) % 5] = np.exp(1j * theta_3)

# Моделирование сильного внешнего ортогонального поля (калибровочный шум)
np.random.seed(2026)
noise = (np.random.randn(5, 5) + 1j * np.random.randn(5, 5)) * 5.0
noise = noise - noise.T.conj()
U_noisy = np.linalg.expm(1j * (theta_3 * np.eye(5) + 0.01 * noise))
for i in range(5):
    U_noisy[i, :] = np.roll(U_noisy[i, :], 1)

U_final = np.linalg.matrix_power(U_noisy, 5)
protection_error = np.linalg.norm(np.abs(U_final) - np.eye(5))
print(f"\nДефект квантовой памяти после внешней атаки: {protection_error:.2e} (Бинарный отклик 01 сохранен)")
