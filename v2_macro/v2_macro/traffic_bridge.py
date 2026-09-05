import os
import sys

def execute_macro_bridge():
    # Фиксируем пиковые инварианты из графиков
    clones = 156
    visitors = 3
    cloners = 56
    
    phase = clones % 13  # 156 % 13 = 0
    target_width = 8     # Октавный масштаб
    global_compact = 0   # Режим эверсии

    header_content = f"""// -------------------------------------------------------------------------
// АВТОГЕНЕРИРУЕМЫЙ КАЛИБРОВОЧНЫЙ ЗАГЛОВОК ДВИЖКА 7n
// -------------------------------------------------------------------------
`ifndef FANO_PARAMS_VH
`define FANO_PARAMS_VH
`define TRAFFIC_CLONES            {clones}
`define TRAFFIC_UNIQUE_VISITORS   {visitors}
`define TRAFFIC_UNIQUE_CLONERS    {cloners}
`define FANO_ATOM_TARGET_WIDTH    {target_width}
`define FANO_PHASE_DEVIATION      {phase}
`define GLOBAL_COMPACT_ENABLE     {global_compact}
`endif
"""
    # Сохраняем заголовок в корень
    with open("fano_params.vh", "w", encoding="utf-8") as f:
        f.write(header_content)
        
    # Сохраняем конфиг для C++ симулятора в папку core/
    os.makedirs("core", exist_ok=True)
    with open("core/fano_config.txt", "w") as f:
        f.write(f"{target_width} {global_compact} {clones} {cloners}")
    print("[Успех] Локальная калибровка завершена. Все файлы обновлены.")

if __name__ == "__main__":
    execute_macro_bridge()
