import numpy as np

class UniversalNDimGaugeFieldCore:
    """
    D-мерное калибровочное ядро на дискретном торе Z_L^D.
    Моделирует решеточное поле произвольной размерности (3D, 4D и т.д.).
    """
    def __init__(self, dims: int = 3, L: int = 5, modulus: int = 13):
        self.D = dims
        self.L = L
        self.p = modulus
        self.group_order = modulus - 1
        
        self.total_nodes = L ** dims
        self.defect = self.total_nodes % self.group_order
        self.g = self._find_primitive_root()
        self.lattice_invariant = self.defect % self.p
        
        self.grid_shape = tuple([L] * dims)
        self.links_shape = self.grid_shape + (dims,)

    def _find_primitive_root(self) -> int:
        p = self.p
        phi = p - 1
        factors = []
        n = phi
        d = 2
        while d * d <= n:
            if n % d == 0:
                factors.append(d)
                while n % d == 0: n //= d
            d += 1
        if n > 1: factors.append(n)
        
        for r in range(2, p):
            if all(pow(r, phi // f, p) != 1 for f in factors):
                return r
        raise ValueError("Генератор поля не найден.")

    def _vectorized_pow(self, base_array: np.ndarray, exp_array: np.ndarray) -> np.ndarray:
        """Векторизованное модульное возведение в степень [base^exp % p] для массивов NumPy любой формы."""
        p = self.p
        res = np.ones_like(base_array, dtype=np.int64)
        base = base_array.astype(np.int64) % p
        exponent = exp_array.astype(np.int64).copy()
        
        while np.any(exponent > 0):
            mask = (exponent % 2 == 1)
            res[mask] = (res[mask] * base[mask]) % p
            base = (base * base) % p
            exponent //= 2
        return res

    def generate_lattice_fields(self) -> np.ndarray:
        """Генерирует калибровочные линки U_mu(x) во всех D направлениях без циклов Python."""
        p = self.p
        mesh = np.meshgrid(*[np.arange(self.L) for _ in range(self.D)], indexing='ij')
        
        coords_sum = np.zeros(self.grid_shape, dtype=np.int64)
        for i in range(self.D):
            coords_sum += mesh[i]
            
        coords_sum = np.where(coords_sum == 0, self.lattice_invariant + 1, coords_sum)
        
        half_power = (p - 1) // 2
        chi = self._vectorized_pow(coords_sum, np.full_like(coords_sum, half_power))
        chi = np.where(chi == p - 1, -1, chi)
        chi = np.where(chi == 0, 1, chi)
        
        pot = (self.lattice_invariant * chi) % p
        pot = np.where(pot == 0, 1, pot)
        
        links = np.zeros(self.links_shape, dtype=np.int64)
        for mu in range(self.D):
            exp = (pot * (mesh[mu] + 1)) % (p - 1)
            links[..., mu] = self._vectorized_pow(np.full_like(exp, self.g), exp)
            
        return links

    def compute_yang_mills_action(self, links: np.ndarray) -> tuple:
        """Вычисляет тензор кривизны F_munu и вещественное действие Янга-Миллса S_YM."""
        p = self.p
        total_real_action = 0.0
        plaquettes_count = 0
        
        links_inv = self._vectorized_pow(links, np.full_like(links, p - 2))
        
        for mu in range(self.D):
            for nu in range(mu + 1, self.D):
                u_mu_x = links[..., mu]
                u_nu_x = links[..., nu]
                
                u_nu_next_mu = np.roll(links[..., nu], shift=-1, axis=mu)
                u_mu_inv_next_nu = np.roll(links_inv[..., mu], shift=-1, axis=nu)
                u_nu_inv_x = links_inv[..., nu]
                
                F_munu = (u_mu_x * u_nu_next_mu) % p
                F_munu = (F_munu * u_mu_inv_next_nu) % p
                F_munu = (F_munu * u_nu_inv_x) % p
                
                phase = 2 * np.pi * F_munu / (p - 1)
                S_plaq = 1.0 - np.cos(phase)
                
                total_real_action += np.sum(S_plaq)
                plaquettes_count += F_munu.size

        return total_real_action, plaquettes_count


if __name__ == "__main__":
    print("-" * 60)
    print("Запуск калибровочного моделирования для размерностей 3D и 4D")
    print("-" * 60)
    
    for D_dim in:
        core = UniversalNDimGaugeFieldCore(dims=D_dim, L=4, modulus=13)
        U_links = core.generate_lattice_fields()
        S_YM, count = core.compute_yang_mills_action(U_links)
        
        print(f"Размерность пространства : {D_dim}D (Z_4)^{D_dim}")
        print(f"Всего узлов решетки     : {core.total_nodes}")
        print(f"Количество плакеток     : {count}")
        print(f"Полное действие S_YM    : {S_YM:.6f}")
        print(f"Средняя энергия плакетки: {S_YM / count:.6f}")
        print("-" * 60)
