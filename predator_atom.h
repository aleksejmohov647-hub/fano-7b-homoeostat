#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint8_t state;   // биты 0–6: плоскость Фано; бит 7: всегда 0
    bool    valid;    // гомеостатическое условие: нарушений <= 1
} predator_t;

void predator_step(predator_t *p, uint8_t entropy_bit);
void predator_enversion(predator_t *p);
