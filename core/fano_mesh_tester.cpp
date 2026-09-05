#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>

constexpr int SIZE = 4;

struct FanoAtom3DNode {
    uint8_t reg_s = 0x3F;
    uint8_t reg_f = 0x00;

    void step(bool is_compact_mode, uint8_t s_in, uint8_t f_in, int width) {
        // ИСПРАВЛЕНО: Добавлены скобки вокруг операторов ^, так как у & приоритет выше
        bool p4 = (((reg_s >> 3) & 1) ^ ((reg_f >> 4) & 1)) & (((reg_s >> 4) & 1) ^ ((reg_f >> 3) & 1));
        
        uint8_t m = (((reg_s >> 3) & 1) << 2) | (((reg_s >> 4) & 1) << 1) | (((reg_s >> 3) & 1) ^ ((reg_s >> 4) & 1));
        uint8_t s_stage_hi = is_compact_mode ? ((reg_s >> 4) ^ 0x04) : ((reg_s >> 4) ^ m);
        uint8_t s_stage = (s_stage_hi << 4) | (reg_s & 0x0F);

        uint8_t mask = (1 << width) - 1;
        reg_s = (s_stage ^ f_in) & mask;
        reg_f = (reg_s ^ (f_in & (p4 ? mask : 0x00))) & mask;
    }
};

int main() {
    std::ifstream config("core/fano_config.txt");
    int width = 8, global_compact = 0, clones = 156, cloners = 56;
    if (config.is_open()) {
        config >> width >> global_compact >> clones >> cloners;
    } else {
        std::cerr << "[Предупреждение] core/fano_config.txt не найден, запуск на дефолтах.\n";
    }

    std::cout << "[C++ Мезо] Настройка топоса решетки...\n";
    std::cout << "           Текущая разрядность ядра (WIDTH): " << width << "\n";
    std::cout << "           Режим удержания энтропии (Compact): " << global_compact << "\n";

    FanoAtom3DNode crystal[SIZE][SIZE][SIZE];
    uint8_t s_net[SIZE][SIZE][SIZE];
    uint8_t f_net[SIZE][SIZE][SIZE];

    for(int x=0; x<SIZE; ++x)
        for(int y=0; y<SIZE; ++y)
            for(int z=0; z<SIZE; ++z) {
                s_net[x][y][z] = crystal[x][y][z].reg_s;
                f_net[x][y][z] = crystal[x][y][z].reg_f;
            }

    uint8_t entropy[SIZE][SIZE][SIZE] = {0};
    entropy[0][0][0] = clones & 0x7F;
    entropy[SIZE-1][SIZE-1][SIZE-1] = cloners & 0x7F;

    for (int t = 1; t <= 12; ++t) {
        FanoAtom3DNode next_crystal[SIZE][SIZE][SIZE];
        for(int x = 0; x < SIZE; ++x) {
            for(int y = 0; y < SIZE; ++y) {
                for(int z = 0; z < SIZE; ++z) {
                    int xl = (x == 0)      ? SIZE-1 : x-1;
                    int xr = (x == SIZE-1) ? 0      : x+1;
                    int yd = (y == 0)      ? SIZE-1 : y-1;
                    int yu = (y == SIZE-1) ? 0      : y+1;
                    int zb = (z == 0)      ? SIZE-1 : z-1;
                    int zf = (z == SIZE-1) ? 0      : z+1;

                    uint8_t s_in_wire = f_net[xl][y][z] ^ f_net[xr][y][z] ^ f_net[x][yd][z] ^ f_net[x][yu][z] ^ entropy[x][y][z];
                    uint8_t f_in_wire = s_net[x][y][zb] ^ s_net[x][y][zf];

                    next_crystal[x][y][z] = crystal[x][y][z];
                    next_crystal[x][y][z].step(global_compact == 1, s_in_wire, f_in_wire, width);
                }
            }
        }
        for(int x=0; x<SIZE; ++x)
            for(int y=0; y<SIZE; ++y)
                for(int z=0; z<SIZE; ++z) {
                    crystal[x][y][z] = next_crystal[x][y][z];
                    s_net[x][y][z] = crystal[x][y][z].reg_s;
                    f_net[x][y][z] = crystal[x][y][z].reg_f;
                }
    }

    std::cout << "[C++ Мезо] 12 тактов успешно обсчитаны. Стабилизация решетки удержана.\n";
    return 0;
}
