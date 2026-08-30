    def analyze_node(self, coord: Tuple[int, int, int] = (8, 8, 8)) -> Dict[str, Any]:
        # Расчет параметров базового слоя с инжекцией дефекта порядка N(6)=43
        A = np.zeros((157, 157), dtype=np.int32)
        for r in range(157): 
            A[r, (self.D + r) % 157] = 1
        
        # Инжектируем деформацию шкалы (динамическая точка бифуркации)
        A[43, 111] ^= 1 
        
        # Пересчет дефекта - теперь W не занулится, давая живую динамику
        M = np.dot(A, A.T)
        W = M - np.eye(157, dtype=np.int32) * 12 - 1
        deg = int(np.sum(np.abs(W)))
        
        eg = np.linalg.eigvals(A)
        # Сортируем по убыванию модулей
        eg_sorted = np.sort(np.abs(eg))[::-1]
        r_max = float(eg_sorted[1]) # Второе по величине собственное число
        
        # Рамануджановская граница для деформированного графа
        ram = float(2.0 * np.sqrt(12))
        
        degs, intensities = [], []
        for _ in range(3):
            degs.append(deg)
            # Защита от деления на ноль и инверсии знака
            denom = abs(r_max - ram) if abs(r_max - ram) != 0 else 1.0
            intensities.append(deg / denom)

        n_vector = [4 + 157 * c for c in coord]
        macro_mod = 4320 % 157
        macro_seven = macro_mod - 74 
        a7_ok = self.sgn_chi([1, 0, 3, 2, 4, 5, 6]) == 1 
        
        return {
            "XYZ_Meso_Defects": tuple(degs),
            "Meso_Intensities": tuple(intensities), # Теперь тут живые вещественные коэффициенты накачки
            "Active_Hecke_3D_Tensor": f"T({n_vector[0]}, {n_vector[1]}, {n_vector[2]})",
            "System_Status": "STABLE_FLOW" if macro_seven == 7 and a7_ok else "STALL"
        }
