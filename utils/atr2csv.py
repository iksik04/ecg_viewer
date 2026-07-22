import wfdb
import pandas as pd
import os
import sys
import argparse
from pathlib import Path

# Возможные расширения файлов аннотаций WFDB
WFDB_ANNOTATION_EXTENSIONS = ['.atr', '.ann', '.ari', '.qrs', '.ecg', '.art']

def find_annotation_files_recursive(source_dir, extensions=None):
    """
    Рекурсивно находит все файлы аннотаций WFDB в директории и поддиректориях.
    
    Параметры:
    ----------
    source_dir : str
        Базовая директория для поиска
    extensions : list
        Список расширений для поиска (по умолчанию все известные)
    
    Возвращает:
    --------
    list: Список путей к файлам аннотаций
    """
    if extensions is None:
        extensions = WFDB_ANNOTATION_EXTENSIONS
    
    source_path = Path(source_dir)
    annotation_files = []
    found_records = set()  # Для отслеживания уникальных записей
    
    # Рекурсивный обход всех директорий
    for root, dirs, files in os.walk(source_path):
        for file in files:
            file_path = Path(root) / file
            # Проверяем, является ли файл файлом аннотаций
            if file_path.suffix.lower() in extensions:
                # Проверяем наличие соответствующего .hea файла
                hea_file = file_path.with_suffix('.hea')
                if hea_file.exists():
                    # Используем базовое имя без расширения как идентификатор записи
                    record_name = file_path.stem
                    # Добавляем только если запись еще не добавлена
                    if record_name not in found_records:
                        found_records.add(record_name)
                        annotation_files.append(file_path)
    
    return annotation_files

def extract_peaks_from_annotation(annotation_path, verbose=False):
    """
    Извлекает индексы пиков из файла аннотаций.
    
    Параметры:
    ----------
    annotation_path : str или Path
        Путь к файлу аннотаций
    verbose : bool
        Подробный вывод
    
    Возвращает:
    --------
    list: Список индексов пиков
    """
    annotation_path = Path(annotation_path)
    record_name = annotation_path.stem
    record_dir = annotation_path.parent
    record_path = record_dir / record_name
    
    try:
        # Читаем аннотации
        annotation = wfdb.rdann(str(record_path), annotation_path.suffix[1:])
        
        if verbose:
            print(f"  Тип аннотации: {annotation_path.suffix}")
            print(f"  Количество аннотаций: {len(annotation.sample)}")
            
            # Показываем первые несколько аннотаций
            if len(annotation.sample) > 0:
                print(f"  Первые 5 аннотаций: {annotation.sample[:5]}")
                if hasattr(annotation, 'symbol'):
                    print(f"  Символы: {annotation.symbol[:5] if len(annotation.symbol) > 0 else 'Нет'}")
        
        # Проверяем, есть ли аннотации
        if len(annotation.sample) == 0:
            if verbose:
                print("  Предупреждение: Аннотации отсутствуют")
            return []
        
        # Если есть поле symbol, можно фильтровать только QRS-комплексы
        # Но по умолчанию возвращаем все аннотации
        if hasattr(annotation, 'symbol') and len(annotation.symbol) > 0:
            # Фильтруем только пики QRS (обычно обозначаются 'N', 'V', 'S', 'F', 'Q', 'E', 'A', 'J')
            qrs_symbols = {'N', 'V', 'S', 'F', 'Q', 'E', 'A', 'J', 'R', 'L', 'B'}
            peaks = []
            for i, symbol in enumerate(annotation.symbol):
                if symbol in qrs_symbols:
                    peaks.append(annotation.sample[i])
            
            if verbose:
                print(f"  Найдено QRS-пиков: {len(peaks)} (из {len(annotation.sample)} аннотаций)")
            
            # Если не найдено QRS-пиков, возвращаем все аннотации
            if len(peaks) == 0:
                if verbose:
                    print("  QRS-пики не найдены, возвращаем все аннотации")
                return annotation.sample.tolist()
            return peaks
        else:
            # Если нет символов, возвращаем все образцы
            return annotation.sample.tolist()
            
    except Exception as e:
        if verbose:
            print(f"  Ошибка при чтении аннотаций: {e}")
            import traceback
            traceback.print_exc()
        return None

def convert_annotation_to_csv(annotation_file_path, output_dir, source_dir, verbose=False):
    """
    Конвертирует файл аннотаций WFDB в CSV с индексами пиков.
    
    Параметры:
    ----------
    annotation_file_path : str или Path
        Путь к файлу аннотаций
    output_dir : str
        Базовая директория для сохранения CSV файлов
    source_dir : str
        Базовая директория источника (для сохранения структуры)
    verbose : bool
        Подробный вывод
    """
    
    # Преобразуем пути
    file_path = Path(annotation_file_path)
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
            print(f"  Файл аннотаций: {file_path.name}")
        
        # Извлекаем пики
        peaks = extract_peaks_from_annotation(file_path, verbose)
        
        if peaks is None:
            if verbose:
                print("  Ошибка при извлечении пиков")
            return None
        
        if len(peaks) == 0:
            if verbose:
                print("  Предупреждение: Нет пиков для сохранения")
            # Сохраняем пустой файл
            df = pd.DataFrame(columns=['peaks'])
        else:
            # Создаем DataFrame
            df = pd.DataFrame({'peaks': peaks})
        
        # Сохраняем в CSV
        output_file = output_subdir / f"{record_name}_peaks.csv"
        df.to_csv(output_file, index=False)
        
        if verbose:
            print(f"  Файл сохранен: {output_file}")
            print(f"  Количество пиков: {len(peaks)}")
            if len(peaks) > 0:
                print(f"  Диапазон индексов: {min(peaks)} - {max(peaks)}")
                print(f"  Первые 10 пиков: {peaks[:10]}")
        
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
            if item.suffix.lower() in WFDB_ANNOTATION_EXTENSIONS + ['.hea', '.dat', '.mwd', '.mld']:
                print(f"  {prefix}{'└── ' if is_last else '├── '}{item.name}")

def main():
    parser = argparse.ArgumentParser(
        description='Конвертация всех файлов аннотаций WFDB из директории и поддиректорий в CSV (только индексы пиков)'
    )
    parser.add_argument(
        'source_dir', 
        help='Директория с файлами аннотаций WFDB (рекурсивный обход)'
    )
    parser.add_argument(
        'output_dir', 
        help='Директория для сохранения CSV файлов'
    )
    parser.add_argument(
        '--extensions', '-e',
        nargs='+',
        default=WFDB_ANNOTATION_EXTENSIONS,
        help=f'Расширения файлов аннотаций для поиска (по умолчанию: {", ".join(WFDB_ANNOTATION_EXTENSIONS)})'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Подробный вывод'
    )
    parser.add_argument(
        '--all-annotations', '-a',
        action='store_true',
        help='Сохранять все аннотации, а не только QRS-пики'
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
    
    # Рекурсивно находим все файлы аннотаций WFDB
    print(f"\nПоиск файлов аннотаций WFDB в: {args.source_dir}")
    print(f"   Расширения: {', '.join(args.extensions)}")
    
    annotation_files = find_annotation_files_recursive(args.source_dir, args.extensions)
    
    if not annotation_files:
        print(f"Предупреждение: В директории {args.source_dir} и поддиректориях не найдено файлов аннотаций WFDB")
        print("   Проверьте, что файлы имеют одно из расширений:", ', '.join(args.extensions))
        sys.exit(0)
    
    print(f"Найдено {len(annotation_files)} файлов аннотаций WFDB")
    print("=" * 60)
    
    # Конвертируем каждый файл
    success_count = 0
    error_files = []
    
    for i, annotation_file in enumerate(annotation_files, 1):
        print(f"\n[{i}/{len(annotation_files)}] Обработка: {annotation_file}")
        print("-" * 40)
        result = convert_annotation_to_csv(str(annotation_file), args.output_dir, args.source_dir, args.verbose)
        if result is not None:
            success_count += 1
        else:
            error_files.append(annotation_file)
        print("-" * 40)
    
    # Итоговый отчет
    print(f"\n" + "=" * 60)
    print(f"ОТЧЕТ О КОНВЕРТАЦИИ")
    print(f"Успешно обработано: {success_count} из {len(annotation_files)} файлов")
    
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