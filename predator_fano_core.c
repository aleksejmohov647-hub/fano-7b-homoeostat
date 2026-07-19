#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint8_t state;   // 7 бит: биты 0–6; бит 7 — резерв
    bool    valid;
} predator_t;

// Проверка инварианта плоскости Фано (7 точек, 7 прямых)
// Возвращает 1, если все 7 уравнений чётности равны 0 (допустимое состояние)
static inline uint8_t fano_check_7b(uint8_t q) {
    const uint8_t l0 = (q >> 0) & 1U;
    const uint8_t l1 = (q >> 1) & 1U;
    const uint8_t l2 = (q >> 2) & 1U;
    const uint8_t l3 = (q >> 3) & 1U;
    const uint8_t l4 = (q >> 4) & 1U;
    const uint8_t l5 = (q >> 5) & 1U;
    const uint8_t l6 = (q >> 6) & 1U;

    // Уравнения чётности для 7 прямых плоскости Фано
    const uint8_t c0 = l0 ^ l1 ^ l3;
    const uint8_t c1 = l1 ^ l2 ^ l4;
    const uint8_t c2 = l2 ^ l3 ^ l5;
    const uint8_t c3 = l3 ^ l4 ^ l6;
    const uint8_t c4 = l4 ^ l5 ^ l0;
    const uint8_t c5 = l5 ^ l6 ^ l1;
    const uint8_t c6 = l6 ^ l0 ^ l2;

    // Валидно, если все c0..c6 равны 0
    return ((c0 | c1 | c2 | c3 | c4 | c5 | c6) == 0U) ? 1U : 0U;
}

// Поглощение внешнего энтропийного шума через кососимметричные маски
void predator_step(predator_t *p, uint8_t entropy_bit) {
    // Ветвление только по 1 биту: маска 0x55 или 0xAA
    const uint8_t mask = (entropy_bit & 1U) ? 0x55U : 0xAAU;
    p->state = (p->state ^ mask) & 0x7FU;  // Строгая 7‑битная граница
    p->valid = (fano_check_7b(p->state) == 1U);
}

// Оператор эверсии (фрактальный поворот структуры)
void predator_enversion(predator_t *p, uint8_t shift_bits) {
    const uint8_t s = shift_bits % 7U;  // Калибровка по 7 координатам Фано
    if (s == 0) {
        p->valid = (fano_check_7b(p->state) == 1U);
        return;
    }
    const uint8_t rotated = ((p->state << s) | (p->state >> (7U - s))) & 0x7FU;
    p->state = rotated;
    p->valid = (fano_check_7b(p->state) == 1U);
}
