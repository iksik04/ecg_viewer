import wfdb
import pandas as pd
import numpy as np
import os
import sys
import argparse
from pathlib import Path

# Возможные расширения файлов данных WFDB
WFDB_DATA_EXTENSIONS = ['.dat', '.mwd', '.mld', '.ecg', '.sig', '.bin']

def find_wfdb_files_recursive(source_dir, extensions=None):
    """
    Рекурсивно находит все файлы данных WFDB в директории и поддиректориях.
    
    Параметры:
    ----------
    source_dir : str
        Базовая директория для поиска
    extensions : list
        Список расширений для поиска (по умолчанию все известные)
    
    Возвращает:
    --------
    list: Список путей к файлам данных
    """
    if extensions is None:
        extensions = WFDB_DATA_EXTENSIONS
    
    source_path = Path(source_dir)
    data_files = []
    found_records = set()  # Для отслеживания уникальных записей
    
    # Рекурсивный обход всех директорий
    for root, dirs, files in os.walk(source_path):
        for file in files:
            file_path = Path(root) / file
            # Проверяем, является ли файл файлом данных
            if file_path.suffix.lower() in extensions:
                # Проверяем наличие соответствующего .hea файла
                hea_file = file_path.with_suffix('.hea')
                if hea_file.exists():
                    # Используем базовое имя без расширения как идентификатор записи
                    record_name = file_path.stem
                    # Добавляем только если запись еще не добавлена
                    if record_name not in found_records:
                        found_records.add(record_name)
                        data_files.append(file_path)
    
    return data_files

def detect_data_file(record_path):
    """
    Определяет, какое расширение данных использовать для записи.
    
    Параметры:
    ----------
    record_path : Path
        Путь к файлу записи без расширения
    
    Возвращает:
    --------
    Path: Путь к файлу данных с правильным расширением
    """
    # Проверяем все возможные расширения
    for ext in WFDB_DATA_EXTENSIONS:
        test_file = record_path.with_suffix(ext)
        if test_file.exists():
            return test_file
    return None

def convert_first_channel_to_csv(record_file_path, output_dir, source_dir, verbose=False):
    """
    Конвертирует файлы WFDB (в любом формате) в CSV, сохраняя только время и первый канал.
    
    Параметры:
    ----------
    record_file_path : str или Path
        Путь к файлу данных (с любым расширением)
    output_dir : str
        Базовая директория для сохранения CSV файлов
    source_dir : str
        Базовая директория источника (для сохранения структуры)
    verbose : bool
        Подробный вывод
    """
    
    # Преобразуем пути
    file_path = Path(record_file_path)
    source_path = Path(source_dir)
    output_base = Path(output_dir)
    
    # Получаем базовое имя записи (без расширения)
    record_name = file_path.stem
    record_dir = file_path.parent
    record_path = record_dir / record_name
    
    # Проверяем существование .hea файла
    hea_file = record_path.with_suffix('.hea')
    if not hea_file.exists():
        if verbose:
            print(f"  Предупреждение: Файл {hea_file} не найден")
        return None
    
    # Определяем, какой файл данных использовать
    data_file = detect_data_file(record_path)
    if not data_file:
        if verbose:
            print(f"  Предупреждение: Не найден файл данных для записи {record_name}")
        return None
    
    try:
        # Определяем относительный путь от source_dir
        try:
            rel_path = record_dir.relative_to(source_path)
        except ValueError:
            rel_path = Path('.')
        
        # Создаем выходную директорию с сохранением структуры
        output_subdir = output_base / rel_path
        output_subdir.mkdir(parents=True, exist_ok=True)
        
        if verbose:
            print(f"  Исходная папка: {record_dir}")
            print(f"  Выходная папка: {output_subdir}")
            print(f"  Файл данных: {data_file.name}")
            print(f"  Файл заголовка: {hea_file.name}")
        
        # Чтение сигналов
        record = wfdb.rdrecord(str(record_path), physical=True)
        
        # Получаем сигналы
        if hasattr(record, 'p_signal'):
            signals = record.p_signal
        elif hasattr(record, 'd_signal'):
            signals = record.d_signal
        else:
            if verbose:
                print("  Ошибка: Не удалось получить сигналы из записи")
            return None
        
        # Проверяем, есть ли хотя бы один канал
        if signals.shape[1] < 1:
            if verbose:
                print("  Ошибка: Запись не содержит сигналов")
            return None
        
        if verbose:
            print(f"  Количество каналов: {signals.shape[1]}")
            print(f"  Длина сигналов: {signals.shape[0]} отсчетов")
            print(f"  Частота дискретизации: {record.fs} Гц")
        
        # Создаем DataFrame только с временем и первым каналом
        time_seconds = np.arange(signals.shape[0]) / record.fs
        first_channel = signals[:, 0]
        
        # Получаем имя первого канала
        if hasattr(record, 'sig_name') and record.sig_name and len(record.sig_name) > 0:
            channel_name = record.sig_name[0]
        else:
            channel_name = "channel_1"
        
        # Создаем DataFrame
        df = pd.DataFrame({
            'time_seconds': time_seconds,
            channel_name: first_channel
        })
        
        # Сохраняем в CSV
        output_file = output_subdir / f"{record_name}_channel1.csv"
        df.to_csv(output_file, index=False, float_format='%.6f')
        
        if verbose:
            print(f"  Файл сохранен: {output_file}")
            print(f"  Размер: {df.shape[0]} строк, {df.shape[1]} столбцов")
            print(f"  Диапазон времени: {df['time_seconds'].min():.3f} - {df['time_seconds'].max():.3f} сек")
            print(f"  Диапазон сигнала: {df[channel_name].min():.3f} - {df[channel_name].max():.3f}")
        
        return df
        
    except Exception as e:
        if verbose:
            print(f"  Ошибка при обработке файла: {e}")
            import traceback
            traceback.print_exc()
        return None

def print_directory_tree(base_path, prefix="", max_depth=2, current_depth=0):
    """Выводит структуру директорий для отладки"""
    if current_depth > max_depth:
        return
    
    base_path = Path(base_path)
    if not base_path.exists():
        print(f"  Директория не существует: {base_path}")
        return
    
    items = sorted(base_path.iterdir())
    # Показываем только первые 20 элементов для краткости
    display_items = items[:20]
    if len(items) > 20:
        display_items.append(None)  # Маркер "и еще..."
    
    for i, item in enumerate(display_items):
        if item is None:
            print(f"  {prefix}└── ... и еще {len(items) - 20} элементов")
            continue
            
        is_last = (i == len(display_items) - 1 or display_items[i+1] is None)
        if item.is_dir():
            print(f"  {prefix}{'└── ' if is_last else '├── '}{item.name}/")
            if current_depth < max_depth:
                print_directory_tree(item, prefix + ("    " if is_last else "│   "), max_depth, current_depth + 1)
        else:
            # Показываем только файлы с определенными расширениями
            if item.suffix.lower() in WFDB_DATA_EXTENSIONS + ['.hea', '.atr', '.xyz']:
                print(f"  {prefix}{'└── ' if is_last else '├── '}{item.name}")

def main():
    parser = argparse.ArgumentParser(
        description='Конвертация всех файлов WFDB (любого формата) из директории и поддиректорий в CSV (только время и первый канал)'
    )
    parser.add_argument(
        'source_dir', 
        help='Директория с файлами WFDB (рекурсивный обход)'
    )
    parser.add_argument(
        'output_dir', 
        help='Директория для сохранения CSV файлов'
    )
    parser.add_argument(
        '--extensions', '-e',
        nargs='+',
        default=WFDB_DATA_EXTENSIONS,
        help=f'Расширения файлов данных для поиска (по умолчанию: {", ".join(WFDB_DATA_EXTENSIONS)})'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Подробный вывод'
    )
    
    args = parser.parse_args()
    
    # Проверяем аргументы
    if not args.source_dir:
        print("Ошибка: Не указана директория источник")
        sys.exit(1)
    
    if not args.output_dir:
        print("Ошибка: Не указана директория сохранения")
        sys.exit(1)
    
    # Проверяем существование директории источника
    source_path = Path(args.source_dir)
    if not source_path.exists():
        print(f"Ошибка: Директория {args.source_dir} не существует")
        sys.exit(1)
    
    if not source_path.is_dir():
        print(f"Ошибка: {args.source_dir} не является директорией")
        sys.exit(1)
    
    # Показываем структуру источника
    print(f"\nСтруктура исходной директории (первые {2} уровня):")
    print_directory_tree(source_path, max_depth=2)
    print("\n" + "=" * 60)
    
    # Рекурсивно находим все файлы данных WFDB
    print(f"\nПоиск файлов WFDB в: {args.source_dir}")
    print(f"   Расширения: {', '.join(args.extensions)}")
    
    data_files = find_wfdb_files_recursive(args.source_dir, args.extensions)
    
    if not data_files:
        print(f"Предупреждение: В директории {args.source_dir} и поддиректориях не найдено файлов данных WFDB")
        print("   Проверьте, что файлы имеют одно из расширений:", ', '.join(args.extensions))
        sys.exit(0)
    
    print(f"Найдено {len(data_files)} файлов данных WFDB")
    print("=" * 60)
    
    # Конвертируем каждый файл
    success_count = 0
    error_files = []
    
    for i, data_file in enumerate(data_files, 1):
        print(f"\n[{i}/{len(data_files)}] Обработка: {data_file}")
        print("-" * 40)
        result = convert_first_channel_to_csv(str(data_file), args.output_dir, args.source_dir, args.verbose)
        if result is not None:
            success_count += 1
        else:
            error_files.append(data_file)
        print("-" * 40)
    
    # Итоговый отчет
    print(f"\n" + "=" * 60)
    print(f"ОТЧЕТ О КОНВЕРТАЦИИ")
    print(f"Успешно обработано: {success_count} из {len(data_files)} файлов")
    
    if error_files:
        print(f"Ошибки при обработке {len(error_files)} файлов:")
        for err_file in error_files[:10]:  # Показываем первые 10 ошибок
            print(f"  - {err_file}")
        if len(error_files) > 10:
            print(f"  ... и еще {len(error_files) - 10} файлов")
    
    # Показываем структуру выходной директории
    output_path = Path(args.output_dir)
    if output_path.exists():
        print(f"\nСтруктура выходной директории:")
        print_directory_tree(output_path, max_depth=2)
    
    if success_count == 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()