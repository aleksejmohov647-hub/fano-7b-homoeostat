import numpy as np

class GaugeFieldCore7n:
    def __init__(self, p=17, n=4, beta=2.0, theta=0.0):
        """
        Мультимасштабное калибровочное ядро на конечных полях GF(p) с квантованием Монте-Карло.
        
        p     : Простое число (требуется p ≡ 1 mod 4 для C-симметрии)
        n     : Внутренний масштаб калибровочной модуляции (размер тора Калуцы-Клейна)
        beta  : Обратная квантовая температура (1/hbar). Управляет силой флуктуаций.
        theta : Угол тета-вакуума для моделирования CP-нарушения.
        """
        if p % 4 != 1: 
            raise ValueError(f"p={p} не удовлетворяет С-симметрии (требуется p ≡ 1 mod 4).")
        
        self.p = p
        self.n = n
        self.beta = beta
        self.theta = theta
        self.group_order = p - 1
        
        # Нахождение делителей порядка группы для поиска первообразного корня
        go = self.group_order
        temp_n, fs = go, []
        for d in range(2, int(temp_n**0.5) + 1):
            if not temp_n % d: 
                fs.append(d)
                while not temp_n % d: temp_n //= d
        if temp_n > 1: fs.append(temp_n)
        
        # Генератор циклической группы (первообразный корень)
        self.g = next(r for r in range(2, p) if all(pow(r, go//f, p) != 1 for f in fs))
        
        # Инвариантные подложки
        self.t = np.arange(p)
        self.gtp = np.array([pow(self.g, int(x), self.p) for x in self.t], dtype=np.int64)
        self.chi = np.array([self._chi(x) for x in self.t], dtype=np.int64)
        
        # Нелинейная геометрия (кручение внутреннего пространства)
        self.m = np.array([pow(self.g, (int(ti) * (self.n - int(ti))) % self.n, self.p) for ti in self.t], dtype=np.int64)
        self.classical_chi = np.where(self.chi != 0, (self.chi * self.m) % self.p, 0)
        
        self.I = self.g % self.p
        self.classical_pot = np.where(self.classical_chi != 0, (self.I * self.classical_chi) % self.p, self.I)

    def _chi(self, t):
        """ Топологический заряд вакуума (Символ Лежандра) """
        v = pow(int(t) % self.p, (self.p - 1) // 2, self.p)
        return 0 if v == 0 else (1 if v == 1 else -1)

    def get_topological_sector(self):
        """ Вычисляет индекс инстантона K = 7n mod p """
        return (7 * self.n) % self.p

    def calculate_action(self, pot_configuration):
        """ Калибровочное действие Уилсона S[A] + топологический тета-термин """
        diff = (pot_configuration - self.classical_pot) % self.p
        # Проекция поля Галуа на компактную U(1) окружность
        gauge_energy = np.sum(1.0 - np.cos(2 * np.pi * diff / self.p))
        
        # Эмерджентный топологический заряд текущей конфигурации
        K_eff = self.get_topological_sector()
        theta_term = -self.theta * K_eff
        
        return gauge_energy + theta_term

    def sample_vacuum(self, sweep_steps=1000):
        """ Квантование вакуума методом Монте-Карло (алгоритм Метрополиса) """
        current_pot = np.random.randint(0, self.p, size=self.p).astype(np.int64)
        current_action = self.calculate_action(current_pot)
        history = []
        
        for _ in range(sweep_steps):
            for site in range(self.p):
                old_val = current_pot[site]
                new_val = np.random.randint(0, self.p)
                
                current_pot[site] = new_val
                new_action = self.calculate_action(current_pot)
                
                dS = new_action - current_action
                if dS <= 0 or np.random.rand() < np.exp(-self.beta * dS):
                    current_action = new_action
                else:
                    current_pot[site] = old_val
                    
            history.append(current_pot.copy())
        return np.array(history)

    def analyze(self, ensemble):
        """ Измерение физических наблюдаемых по квантовому ансамблю """
        trajectories = np.array([(self.gtp * pot * 1) % self.p for pot in ensemble])
        vac_exp = np.mean(trajectories, axis=0)
        
        # Коррелятор Грина на пространственно-временном торе
        correlator = np.mean([np.corrcoef(tr, np.roll(tr, 1))[0,1] for tr in trajectories])
        # Заполнение фазового объема (Индекс энтропии Минковского)
        unique_elements = len(np.unique(trajectories))
        d_h = np.log(unique_elements) / np.log(self.p)
        
        return vac_exp, correlator, d_h

if __name__ == "__main__":
    print("=== GaugeFieldCore7n: Запуск квантово-полевой симуляции ===")
    p_field = 17
    # Найдем масштабы для секторов K=1 и K=2 через модулярное деление
    # 7*n ≡ K mod p
    # Для p=17 инверсия 7^-1 mod 17 = 5 (так как 7*5=35 ≡ 1)
    # n_k1 = (1 * 5) % 17 = 5
    # n_k2 = (2 * 5) % 17 = 10
    
    for k_target, n_scale in [("1 (Синглет)", 5), ("2 (Дублет)", 10)]:
        sim = GaugeFieldCore7n(p=p_field, n=n_scale, beta=4.0, theta=0.5)
        ensemble = sim.sample_vacuum(sweep_steps=1500)[500:] # Отсекаем термализацию
        vac_exp, corr, entropy = sim.analyze(ensemble)
        
        print(f"\n▶ Топологический сектор K = {k_target} [Масштаб n = {n_scale}]:")
        print(f"  Действительный индекс K: {sim.get_topological_sector()}")
        print(f"  Коррелятор Грина (периодичность тора): {corr:.4f}")
        print(f"  Индекс плотности орбит (D_H): {entropy:.4f}")
