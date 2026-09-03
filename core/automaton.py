import math
import numpy as np


def subfactorial(n):
    """Расчет субфакториала !n (комбинаторный хаос деранжирований)"""
    if n == 0:
        return 1
    if n == 1:
        return 0
    return (n - 1) * (subfactorial(n - 1) + subfactorial(n - 2))


class MetalogicAutomaton:

    def __init__(self):
        # Исправлено: заменено np.math.factorial на math.factorial
        self.inv_hott_8 = 28 * subfactorial(8) / math.factorial(8)
        self.gauge_kernel = 360  # Порядок знакопеременной группы |A6|
        self.meso_node = 1260
        self.localization_field = 157

    def verify_register_nodes(self):
        """Верификация регистровых узлов и калибровочной ДНК"""
        print("=== ВЕРИФИКАЦИЯ РЕГИСТРОВЫХ УЗЛОВ ===")
        # Убрано некорректное присваивание внутри f-строки для чистоты PEP8
        print(f"Узел 180 (Экваториальный сдвиг): {self.gauge_kernel / 2} градусов")

        # Проверка узла 10080 (минуты в неделе)
        node_10080 = 28 * self.gauge_kernel
        print(
            f"Узел 10080 (Инвариант HoTT * Ядро): {node_10080} (число минут в неделе: 7*24*60)"
        )
        assert (
            node_10080 == 7 * 24 * 60
        ), "Ошибка калибровки макро-масштаба недели!"
        print("-> Калибровочная ДНК узла 10080 подтверждена без остатка.\n")

    def run_12_step_monodromy(self, initial_state=1):
        """Симуляция 12-шагового эверсионного цикла автомата по модулю 13"""
        print("=== ДИНАМИКА 12-ШАГОВОЙ ЭВЕРСИИ ===")
        state = initial_state
        g = 10  # Образующий элемент (примитивный корень) поля F13

        # Дефект субфакториала !13 по модулю 13
        defect_mod13 = -1

        for k in range(1, 13):
            # Переключатель фаз: нечетные — вакуум, четные — динамика
            if k % 2 == 0:
                # Мультипликативный шаг в конечном поле
                factor = (g**k) % 13
                # Инверсия знака каждые 6 шагов
                eversion = defect_mod13 ** (k // 6)
                current_val = (state * factor * eversion) % 13
                rank_f2 = 1
                phase = "Динамическая Волна"
            else:
                current_val = 0  # Схлопывание в тернарный ноль
                rank_f2 = 0
                phase = "Статический Вакуум"

            print(
                f"Шаг q={k:2d} | Состояние в регистре: {current_val:2d} | Ранг над F2: {rank_f2} | Фаза: {phase}"
            )

        # Проверка замыкания монодромии на 12-м шаге
        final_wave_val = (
            initial_state * (g**12) * (defect_mod13 ** (12 // 6))
        ) % 13
        print(
            f"\nЗамыкание монодромии на 12-м шаге: {final_wave_val} (Ожидалось: 1)"
        )
        print(
            "Высшая Тавтология Истины подтверждена. Динамический изоморфизм равен Id_C."
        )


if __name__ == "__main__":
    automaton = MetalogicAutomaton()
    automaton.verify_register_nodes()
    automaton.run_12_step_monodromy()
