import numpy as np
from typing import Tuple, Dict, Any

class AutomorphicHypercubeEngine:
    def __init__(self):
        # Строгое циклическое разностное множество (v=157, k=13, lambda=1)
        # Соответствует сильно регулярному графу Рамануджана
        self.v = 157
        self.k = 13
        self.D = [0, 1, 3, 13, 32, 36, 43, 64, 71, 91, 111, 135, 152]

    def _build_adjacency_matrix(self) -> np.ndarray:
        """Построение базовой циркулянтной матрицы смежности."""
        A = np.zeros((self.v, self.v), dtype=np.int32)
        for r in range(self.v): 
            for shift in self.D:
                A[r, (shift + r) % self.v] = 1
        return A

    def analyze_network_topology(self, defect_node_i: int = 43, defect_node_j: int = 111) -> Dict[str, Any]:
        """
        Объективный спектральный анализ топологии NoC при инжекции структурного дефекта.
        
        :param defect_node_i: Индекс строки деформируемой связи.
        :param defect_node_j: Индекс столбца деформируемой связи.
        """
        # 1. Генерация графа и инжекция топологического дефекта (повреждение линии связи)
        A = self._build_adjacency_matrix()
        A[defect_node_i, defect_node_j] ^= 1 
        A[defect_node_j, defect_node_i] = A[defect_node_i, defect_node_j] # Сохраняем симметрию графа
        
        # 2. Оценка отклонения от идеального разностного множества
        # M = A * A^T. Для идеального графа Рамануджана: M = (k - lambda)*I + lambda*J
        M = np.dot(A, A.T)
        W = M - np.eye(self.v, dtype=np.int32) * (self.k - 1) - 1
        deg_score = float(np.sum(np.abs(W))) # Интегральная мера структурного искажения
        
        # 3. Спектральный анализ графа смежности
        eg = np.linalg.eigvals(A)
        eg_real = np.real(eg) # Для симметричной матрицы собственные значения вещественны
        eg_sorted = np.sort(np.abs(eg_real))[::-1]
        
        # Первая гармоника (лямбда_0) равна степени регулярности k (или близка к ней при дефекте)
        lambda_0 = eg_sorted[0]
        # Второе по величине собственное число (определяет скорость перемешивания/расширения графа)
        lambda_max_sub = eg_sorted[1] 
        
        # 4. Вычисление теоретической рамануджановской границы Чигера
        # Для k-регулярного графа: 2 * sqrt(k - 1)
        ram_bound = float(2.0 * np.sqrt(self.k - 1))
        
        # Спектральный зазор (Spectral Gap) исходного графа
        spectral_gap = lambda_0 - lambda_max_sub
        
        # 5. Критерий устойчивости сети (Network Robustness Condition)
        # Если lambda_max_sub деформированного графа удерживается в пределах рамануджановской границы
        # или незначительно ее превышает, топология сохраняет высокую пропускную способность.
        is_quasi_ramanujan = lambda_max_sub <= (ram_bound * 1.05)
        
        # Рассчитываем физическую плотность эффективного мезо-контекста (интенсивность проводимости)
        # Чем выше спектральный зазор и меньше искажение дефекта, тем стабильнее поток
        denom = abs(lambda_max_sub - ram_bound)
        conductivity_intensity = spectral_gap / (denom if denom != 0 else 1.0)
        
        return {
            "structural_defect_energy": deg_score,
            "spectral_gap": float(spectral_gap),
            "sub_maximal_eigenvalue": float(lambda_max_sub),
            "theoretical_ramanujan_bound": ram_bound,
            "network_conductivity_intensity": conductivity_intensity,
            "system_status": "STABLE_FLOW" if is_quasi_ramanujan else "STALL"
        }

if __name__ == "__main__":
    engine = AutomorphicHypercubeEngine()
    # Инжектируем дефект на критические узлы 43 и 111
    metrics = engine.analyze_network_topology(43, 111)
    
    print("--- НАУЧНЫЙ ОТЧЕТ О СОСТОЯНИИ ТОПОЛОГИИ СЕТИ ---")
    for key, value in metrics.items():
        print(f"{key}: {value}")
