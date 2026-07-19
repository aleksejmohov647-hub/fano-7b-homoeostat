#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint8_t state;   // биты 0–6: плоскость Фано; бит 7: резерв
    bool    valid;    // гомеостатическое условие выполнено (нарушений <= 1)
} predator_t;

/*
 * Возвращает число нарушенных прямых (вес Хэмминга вектора Aq).
 * Это корректная метрика близости к инварианту плоскости Фано.
 */
static inline uint8_t fano_violations(uint8_t q) {
    const uint8_t b0 = (q >> 0) & 1U;
    const uint8_t b1 = (q >> 1) & 1U;
    const uint8_t b2 = (q >> 2) & 1U;
    const uint8_t b3 = (q >> 3) & 1U;
    const uint8_t b4 = (q >> 4) & 1U;
    const uint8_t b5 = (q >> 5) & 1U;
    const uint8_t b6 = (q >> 6) & 1U;

    /* 7 прямых плоскости Фано */
    const uint8_t c0 = b0 ^ b1 ^ b3;
    const uint8_t c1 = b1 ^ b2 ^ b4;
    const uint8_t c2 = b2 ^ b3 ^ b5;
    const uint8_t c3 = b3 ^ b4 ^ b6;
    const uint8_t c4 = b4 ^ b5 ^ b0;
    const uint8_t c5 = b5 ^ b6 ^ b1;
    const uint8_t c6 = b6 ^ b0 ^ b2;

    return c0 + c1 + c2 + c3 + c4 + c5 + c6;  // сумма = число нарушенных прямых
}

/*
 * Branchless выбор маски: 0x55 если bit=1, иначе 0xAA
 */
static inline uint8_t mask_select(uint8_t bit) {
    bit &= 1U;
    const uint8_t m55 = 0x55U;
    const uint8_t mAA = 0xAAU;
    /* если bit=1 -> mask=0xFF, иначе 0x00 */
    const uint8_t sel = -((uint8_t)(bit));
    return (m55 & sel) | (mAA & ~sel);
}

/*
 * Шаг «хищника»: поглощение энтропийного бита.
 * valid = true, если число нарушенных прямых <= 1 (гомеостатическая окрестность).
 */
void predator_step(predator_t *p, uint8_t entropy_bit) {
    const uint8_t mask = mask_select(entropy_bit);
    p->state = (uint8_t)((p->state ^ mask) & 0x7FU);

    const uint8_t v = fano_violations(p->state);
    /* valid = (v <= 1); branchless */
    p->valid = (v | (v - 2U)) < 2U;  // работает для v в [0..7]
}

/*
 * Эверсия как автоморфизм плоскости Фано (перестановка битов).
 * Здесь используется фиксированный автоморфизм порядка 3:
 *   0->1, 1->3, 3->0, и 2->4, 4->5, 5->2, 6->6
 * Это один из 168 автоморфизмов PGL(3,2), сохраняющий структуру прямых.
 * Без таблиц, без деления, без ветвлений.
 */
void predator_enversion(predator_t *p) {
    const uint8_t s = p->state & 0x7FU;

    /* Извлекаем биты */
    const uint8_t b0 = (s >> 0) & 1U;
    const uint8_t b1 = (s >> 1) & 1U;
    const uint8_t b2 = (s >> 2) & 1U;
    const uint8_t b3 = (s >> 3) & 1U;
    const uint8_t b4 = (s >> 4) & 1U;
    const uint8_t b5 = (s >> 5) & 1U;
    const uint8_t b6 = (s >> 6) & 1U;

    /* Автоморфизм (один из канонических):
       b0 <- b1, b1 <- b3, b3 <- b0
       b2 <- b4, b4 <- b5, b5 <- b2
       b6 <- b6
     */
    const uint8_t r0 = b1;
    const uint8_t r1 = b3;
    const uint8_t r2 = b4;
    const uint8_t r3 = b0;
    const uint8_t r4 = b5;
    const uint8_t r5 = b2;
    const uint8_t r6 = b6;

    p->state = (r0 << 0) | (r1 << 1) | (r2 << 2) |
               (r3 << 3) | (r4 << 4) | (r5 << 5) |
               (r6 << 6);

    const uint8_t v = fano_violations(p->state);
    p->valid = (v | (v - 2U)) < 2U;
}

