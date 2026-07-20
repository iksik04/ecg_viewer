import wfdb
import pandas as pd
import numpy as np
import os
import sys
import argparse
from pathlib import Path

def convert_first_channel_to_csv(dat_file_path, output_dir):
    """
    Конвертирует .dat+.hea файлы в CSV, сохраняя только время и первый канал.
    
    Параметры:
    ----------
    dat_file_path : str
        Путь к .dat файлу (или к файлу без расширения)
    output_dir : str
        Директория для сохранения CSV файла
    """
    
    # Преобразуем путь к файлу
    dat_path = Path(dat_file_path)
    
    # Если указан .dat файл, убираем расширение
    if dat_path.suffix == '.dat':
        record_path = dat_path.with_suffix('')
    else:
        record_path = dat_path
    
    # Проверяем существование файлов
    if not record_path.with_suffix('.dat').exists():
        print(f"Ошибка: Файл {record_path}.dat не найден")
        return None
    
    if not record_path.with_suffix('.hea').exists():
        print(f"Ошибка: Файл {record_path}.hea не найден")
        return None
    
    try:
        # Создаем выходную директорию
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        print(f"Чтение записи: {record_path.name}")
        
        # Чтение сигналов
        record = wfdb.rdrecord(str(record_path), physical=True)
        
        # Получаем сигналы
        if hasattr(record, 'p_signal'):
            signals = record.p_signal
        elif hasattr(record, 'd_signal'):
            signals = record.d_signal
        else:
            print("Ошибка: Не удалось получить сигналы из записи")
            return None
        
        # Проверяем, есть ли хотя бы один канал
        if signals.shape[1] < 1:
            print("Ошибка: Запись не содержит сигналов")
            return None
        
        print(f"Количество сигналов: {signals.shape[1]}")
        print(f"Длина сигналов: {signals.shape[0]}")
        print(f"Частота дискретизации: {record.fs} Гц")
        
        # Создаем DataFrame только с временем и первым каналом
        # Время в секундах
        time_seconds = np.arange(signals.shape[0]) / record.fs
        
        # Первый канал (индекс 0)
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
        output_file = output_path / f"{record_path.name}_channel1.csv"
        df.to_csv(output_file, index=False, float_format='%.6f')
        
        print(f"\nФайл успешно сохранен: {output_file}")
        print(f"Размер данных: {df.shape[0]} строк, {df.shape[1]} столбцов")
        print(f"Диапазон времени: {df['time_seconds'].min():.3f} - {df['time_seconds'].max():.3f} сек")
        print(f"Диапазон сигнала: {df[channel_name].min():.3f} - {df[channel_name].max():.3f}")
        
        # Показываем первые 5 строк
        print("\nПервые 5 строк данных:")
        print(df.head())
        
        return df
        
    except Exception as e:
        print(f"Ошибка при обработке файла: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    parser = argparse.ArgumentParser(
        description='Конвертация всех .dat+.hea файлов из директории в CSV (только время и первый канал)'
    )
    parser.add_argument(
        'output_dir', 
        help='Директория для сохранения CSV файлов'
    )
    parser.add_argument(
        'source_dir', 
        help='Директория с .dat файлами'
    )
    
    args = parser.parse_args()
    
    # Проверяем аргументы
    if not args.output_dir:
        print("Ошибка: Не указана директория сохранения")
        sys.exit(1)
    
    if not args.source_dir:
        print("Ошибка: Не указана директория источник")
        sys.exit(1)
    
    # Проверяем существование директории источника
    source_path = Path(args.source_dir)
    if not source_path.exists():
        print(f"Ошибка: Директория {args.source_dir} не существует")
        sys.exit(1)
    
    if not source_path.is_dir():
        print(f"Ошибка: {args.source_dir} не является директорией")
        sys.exit(1)
    
    # Находим все .dat файлы в директории источника
    dat_files = list(source_path.glob("*.dat"))
    
    if not dat_files:
        print(f"Предупреждение: В директории {args.source_dir} не найдено .dat файлов")
        sys.exit(0)
    
    print(f"Найдено {len(dat_files)} .dat файлов")
    print("-" * 50)
    
    # Конвертируем каждый файл
    success_count = 0
    for dat_file in dat_files:
        print(f"\nОбработка: {dat_file.name}")
        result = convert_first_channel_to_csv(str(dat_file), args.output_dir)
        if result is not None:
            success_count += 1
        print("-" * 50)
    
    print(f"\nКонвертация завершена!")
    print(f"Успешно обработано: {success_count} из {len(dat_files)} файлов")
    
    if success_count == 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()