import os

def inject():
    slice_path = "core/crystal_slice.txt"
    readme_path = "README.md"
    
    if not os.path.exists(slice_path) or not os.path.exists(readme_path):
        print("[!] Файлы для инжекции не найдены.")
        return

    with open(slice_path, "r") as f:
        matrix_data = f.read().strip()

    with open(readme_path, "r", encoding="utf-8") as f:
        readme_content = f.read()

    start_marker = "<!-- FANO_CRYSTAL_START -->"
    end_marker = "<!-- FANO_CRYSTAL_END -->"

    if start_marker not in readme_content or end_marker not in readme_content:
        print("[!] Маркеры затвора не найдены в README.md.")
        return

    # Формируем красивый блок для инжекции
    injection_block = f"""{start_marker}
### 🔮 Текущее состояние 3D-кристалла 7n (Срез Z=0)
```text
{matrix_data}
```
*Размерность ядра WIDTH=8 | Фаза автомата обсчитана успешно.*
{end_marker}"""

    # Режем README по маркерам и вставляем обновленный кусок
    parts = readme_content.split(start_marker)
    pre_content = parts[0]
    post_content = parts[1].split(end_marker)[1]

    new_readme = pre_content + injection_block + post_content

    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(new_readme)
    print("[Успех] Срез кристалла успешно инжектирован в README.md.")

if __name__ == "__main__":
    inject()
