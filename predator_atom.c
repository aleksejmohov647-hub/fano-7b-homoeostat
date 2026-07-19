#include "predator_atom.h"

static inline uint8_t fano_violations(uint8_t q) {
    const uint8_t b0 = (q >> 0) & 1U;
    const uint8_t b1 = (q >> 1) & 1U;
    const uint8_t b2 = (q >> 2) & 1U;
    const uint8_t b3 = (q >> 3) & 1U;
    const uint8_t b4 = (q >> 4) & 1U;
    const uint8_t b5 = (q >> 5) & 1U;
    const uint8_t b6 = (q >> 6) & 1U;

    const uint8_t c0 = b0 ^ b1 ^ b3;
    const uint8_t c1 = b1 ^ b2 ^ b4;
    const uint8_t c2 = b2 ^ b3 ^ b5;
    const uint8_t c3 = b3 ^ b4 ^ b6;
    const uint8_t c4 = b4 ^ b5 ^ b0;
    const uint8_t c5 = b5 ^ b6 ^ b1;
    const uint8_t c6 = b6 ^ b0 ^ b2;

    return (uint8_t)(c0 + c1 + c2 + c3 + c4 + c5 + c6);
}

static inline uint8_t mask_select(uint8_t bit) {
    const uint8_t clean_bit = bit & 1U;
    const uint8_t sel = (uint8_t)(0U - clean_bit);
    const uint8_t m55 = 0x55U;
    const uint8_t m2A = 0x2AU;
    return (uint8_t)((m55 & sel) | (m2A & ~sel));
}

void predator_step(predator_t *p, uint8_t entropy_bit) {
    const uint8_t mask = mask_select(entropy_bit);
    p->state = (uint8_t)((p->state ^ mask) & 0x7FU);
    p->valid = (fano_violations(p->state) <= 1U);
}

void predator_enversion(predator_t *p) {
    const uint8_t s = p->state;

    const uint8_t b0 = (s >> 0) & 1U;
    const uint8_t b1 = (s >> 1) & 1U;
    const uint8_t b2 = (s >> 2) & 1U;
    const uint8_t b3 = (s >> 3) & 1U;
    const uint8_t b4 = (s >> 4) & 1U;
    const uint8_t b5 = (s >> 5) & 1U;
    const uint8_t b6 = (s >> 6) & 1U;

    const uint8_t r0 = b1;
    const uint8_t r1 = b3;
    const uint8_t r2 = b4;
    const uint8_t r3 = b0;
    const uint8_t r4 = b5;
    const uint8_t r5 = b2;
    const uint8_t r6 = b6;

    p->state = (uint8_t)((r0 << 0) | (r1 << 1) | (r2 << 2) |
                         (r3 << 3) | (r4 << 4) | (r5 << 5) |
                         (r6 << 6));

    p->valid = (fano_violations(p->state) <= 1U);
}
