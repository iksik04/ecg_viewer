import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// Глобальная переменная для пути к утилитам WFDB
/// По умолчанию пустая строка - утилиты ищутся в PATH
/// Можно задать полный путь, например: '/usr/local/bin/' или 'C:\\WFDB\\bin\\'
String wfdbBinPath = 'C:/Instruments/wfdb_utils/wfdb-software-package-10.6.2/build/bin';

class PanTompkinsQRS {
  List<double> bandPassFilter(List<double> signal) {
    List<double> sig = List.from(signal);
    List<double> result = <double>[
      for (double i = 0; i < signal.length; i++) i
    ];

    for (int index = 0; index < signal.length; index++) {
      sig[index] = signal[index];

      if (index >= 1) {
        sig[index] += 2 * sig[index - 1];
      }

      if (index >= 2) {
        sig[index] -= sig[index - 2];
      }

      if (index >= 6) {
        sig[index] -= 2 * signal[index - 6];
      }

      if (index >= 12) {
        sig[index] += signal[index - 12];
      }
    }

    result = List.from(sig);

    for (int index = 0; index < signal.length; index++) {
      result[index] = -1 * sig[index];

      if (index >= 1) {
        result[index] -= result[index - 1];
      }

      if (index >= 16) {
        result[index] += 32 * sig[index - 16];
      }

      if (index >= 32) {
        result[index] += sig[index - 32];
      }
    }

    double maxVal = max(result.reduce(max), -result.reduce(min));
    result = result.map((val) => val / maxVal).toList();

    return result;
  }

  List<double> derivative(List<double> signal, double fs) {
    List<double> result = <double>[
      for (double i = 0; i < signal.length; i++) i
    ];

    for (int index = 0; index < signal.length; index++) {
      result[index] = 0;

      if (index >= 1) {
        result[index] -= 2 * signal[index - 1];
      }

      if (index >= 2) {
        result[index] -= signal[index - 2];
      }

      if (index >= 2 && index <= signal.length - 2) {
        result[index] += 2 * signal[index + 1];
      }

      if (index >= 2 && index <= signal.length - 3) {
        result[index] += signal[index + 2];
      }

      result[index] = (result[index] * fs) / 8;
    }
    return result;
  }

  List<double> squaring(List<double> signal) {
    List<double> result = <double>[
      for (double i = 0; i < signal.length; i++) i
    ];

    for (int index = 0; index < signal.length; index++) {
      result[index] = signal[index] * signal[index];
    }

    return result;
  }

  List<double> movingWindowIntegration(List<double> signal, double fs) {
    List<double> result = <double>[
      for (double i = 0; i < signal.length; i++) i
    ];
    int winSize = (0.150 * fs).round();
    double sum = 0;

    for (int j = 0; j < winSize; j++) {
      sum += signal[j] / winSize;
      result[j] = sum;
    }

    for (int index = winSize; index < signal.length; index++) {
      sum += signal[index] / winSize;
      sum -= signal[index - winSize] / winSize;
      result[index] = sum;
    }

    return result;
  }

  (double, List<int>) solve(List<double> signal, int fs) {
    List<double> inputSignal = List.from(signal);
    List<double> bpass = bandPassFilter(inputSignal);
    List<double> der = derivative(bpass, fs.toDouble());
    List<double> sqr = squaring(der);
    List<double> mwin = movingWindowIntegration(sqr, fs.toDouble());
    List<int> peaks = detectPeaks(
        ecgSingal: signal,
        fs: fs,
        integration_signal: mwin,
        band_pass_signal: bpass);
    double heartRate = (60 * fs) / average(diff(peaks.sublist(1)));
    return (heartRate, peaks);
  }

  List<int> detectPeaks(
      {required List<double> ecgSingal,
      required int fs,
      required List<double> integration_signal,
      required List<double> band_pass_signal}) {
    List<int> possible_peaks = [];
    List<int> signal_peaks = [];
    List<int> r_peaks = [];
    double SPKI = 0;
    double SPKF = 0;
    double NPKI = 0;
    double NPKF = 0;
    List rr_avg_one = [];
    double THRESHOLDI1 = 0;
    double THRESHOLDF1 = 0;
    List<double> rr_avg_two = [];
    double THRESHOLDI2 = 0;
    double THRESHOLDF2 = 0;
    int is_T_found = 0;
    double current_slope = 0;
    double previous_slope = 0;
    int window = (0.15 * fs).round();
    List FM_peaks = [];
    List<double> integration_signal_smooth =
        convolution([...integration_signal]);
    List localDiff = diff([...integration_signal_smooth]);
    double RR_LOW_LIMIT = -999;
    double RR_HIGH_LIMIT = 999;
    double RR_MISSED_LIMIT = 0;

    for (int i = 1; i < localDiff.length; i++) {
      if (i - 1 > 2 * fs && localDiff[i - 1] > 0 && localDiff[i] < 0) {
        FM_peaks.add(i - 1);
      }
    }
    for (int index = 0; index < FM_peaks.length; index++) {
      int current_peak = FM_peaks[index];
      int left_limit = max(current_peak - window, 0);
      int right_limit = min(current_peak + window + 1, band_pass_signal.length);
      int max_index = -1;
      double max_value = -999999;
      for (int i = left_limit; i < right_limit; i++) {
        if (band_pass_signal[i] > max_value) {
          max_value = band_pass_signal[i];
          max_index = i;
        }
      }
      if (max_index != -1) {
        possible_peaks.add(max_index);
      }
      if (index == 0 || index > possible_peaks.length) {
        if (integration_signal[current_peak] >= THRESHOLDI1) {
          SPKI = 0.125 * integration_signal[current_peak] + 0.875 * SPKI;
          if (possible_peaks[index] > THRESHOLDF1) {
            SPKF = 0.125 * band_pass_signal[index] + 0.875 * SPKF;
            signal_peaks.add(possible_peaks[index]);
          } else {
            NPKF = 0.125 * band_pass_signal[index] + 0.875 * NPKF;
          }
        } else if ((integration_signal[current_peak] > THRESHOLDI2 &&
                integration_signal[current_peak] < THRESHOLDI1) ||
            (integration_signal[current_peak] < THRESHOLDI2)) {
          NPKI = 0.125 * integration_signal[current_peak] + 0.875 * NPKI;
          NPKF = 0.125 * band_pass_signal[index] + 0.875 * NPKF;
        }
      } else {
        List RRAVERAGE1 = divideList(
            diff(FM_peaks.sublist(max(0, index - 8), index + 1)), fs);
        double rr_one_mean = average(RRAVERAGE1);
        rr_avg_one.add(rr_one_mean);
        double limit_factor = rr_one_mean;

        if (index >= 8) {
          for (double RR in RRAVERAGE1) {
            if (RR > RR_LOW_LIMIT && RR < RR_HIGH_LIMIT) {
              rr_avg_two.add(RR);
              if (rr_avg_two.length == 9) {
                rr_avg_two.removeAt(0);
                limit_factor = average(rr_avg_two);
              }
            }
          }
          if (rr_avg_two.length == 8 || index < 8) {
            RR_LOW_LIMIT = 0.92 * limit_factor;
            RR_HIGH_LIMIT = 1.16 * limit_factor;
            RR_MISSED_LIMIT = 1.66 * limit_factor;
            RR_MISSED_LIMIT = 1.66 * limit_factor;
          }
          if (rr_avg_one[rr_avg_one.length - 1] < RR_LOW_LIMIT ||
              rr_avg_one[rr_avg_one.length - 1] > RR_MISSED_LIMIT) {
            THRESHOLDI1 = THRESHOLDI1 / 2;
            THRESHOLDF1 = THRESHOLDF1 / 2;
          }

          double curr_rr_interval = RRAVERAGE1[RRAVERAGE1.length - 1];
          int search_back_window = (curr_rr_interval * fs).round();
          if (curr_rr_interval > RR_MISSED_LIMIT) {
            left_limit = current_peak - search_back_window + 1;
            right_limit = current_peak + 1;
            int search_back_max_index = -1;
            max_value = -999999;
            for (int i = left_limit; i < right_limit; i++) {
              if (integration_signal[i] > THRESHOLDI1 &&
                  integration_signal[i] > max_value) {
                max_value = integration_signal[i];
                search_back_max_index = i;
              }
            }
            if (search_back_max_index != -1) {
              SPKI = 0.25 *
                      integration_signal[search_back_max_index < 0
                          ? integration_signal.length + search_back_max_index
                          : search_back_max_index] +
                  0.75 * SPKI;
              THRESHOLDI1 = NPKI + 0.25 * (SPKI - NPKI);
              THRESHOLDI2 = 0.5 * THRESHOLDI1;

              left_limit = search_back_max_index - (0.15 * fs).round();
              right_limit = min(band_pass_signal.length, search_back_max_index);

              int search_back_max_index2 = -1;
              max_value = -999999;

              for (int i = left_limit; i < right_limit; i++) {
                if (band_pass_signal[i] > THRESHOLDF1 &&
                    band_pass_signal[i] > max_value) {
                  max_value = band_pass_signal[i];
                  search_back_max_index2 = i;
                }
              }

              if (search_back_max_index2 != -1 &&
                  band_pass_signal[search_back_max_index2 < 0
                      ? integration_signal.length + search_back_max_index2
                      : search_back_max_index2] > THRESHOLDF2) {
                SPKF = 0.25 *
                        band_pass_signal[search_back_max_index2 < 0
                            ? integration_signal.length + search_back_max_index2
                            : search_back_max_index2] +
                    0.75 * SPKF;
                THRESHOLDF1 = NPKF + 0.25 * (SPKF - NPKF);
                THRESHOLDF2 = 0.5 * THRESHOLDF1;
                signal_peaks.add(search_back_max_index2);
              }
            }
          }
          if (integration_signal[current_peak] >= THRESHOLDI1) {
            if (curr_rr_interval > 0.20 &&
                curr_rr_interval < 0.36 &&
                index > 0) {
              current_slope = geMax(diff(integration_signal.sublist(
                  current_peak - (fs * 0.075).round(), current_peak + 1)));

              previous_slope = geMax(diff(integration_signal.sublist(
                  FM_peaks[index - 1] - (fs * 0.075).round(),
                  FM_peaks[index - 1] + 1)));
              if (current_slope < 0.5 * previous_slope) {
                NPKI = 0.125 * integration_signal[current_peak] + 0.875 * NPKI;
                is_T_found = 1;
              }
            }

            if (is_T_found == 0) {
              SPKI = 0.125 * integration_signal[current_peak] + 0.875 * SPKI;

              if (possible_peaks[index] > THRESHOLDF1) {
                SPKF = 0.125 * band_pass_signal[index] + 0.875 * SPKF;
                signal_peaks.add(possible_peaks[index]);
              } else {
                NPKF = 0.125 * band_pass_signal[index] + 0.875 * NPKF;
              }
            }
          } else if ((integration_signal[current_peak] > THRESHOLDI1 &&
                  integration_signal[current_peak] < THRESHOLDI2) ||
              (integration_signal[current_peak] < THRESHOLDI1)) {
            NPKI = 0.125 * integration_signal[current_peak] + 0.875 * NPKI;
            NPKF = 0.125 * band_pass_signal[index] + 0.875 * NPKF;
          }

          THRESHOLDI1 = NPKI + 0.25 * (SPKI - NPKI);
          THRESHOLDF1 = NPKF + 0.25 * (SPKF - NPKF);
          THRESHOLDI2 = 0.5 * THRESHOLDI1;
          THRESHOLDF2 = 0.5 * THRESHOLDF1;
          is_T_found = 0;
        }
      }
    }
    for (int i in unique(signal_peaks)) {
      int window = (0.2 * fs).round();
      int left_limit = i - window;
      double right_limit = min(i + window + 1, ecgSingal.length.toDouble());
      double max_value = -double.infinity;
      int max_index = -1;
      for (int i = left_limit; i < right_limit; i++) {
        if (ecgSingal[i] > max_value) {
          max_value = ecgSingal[i];
          max_index = i;
        }
      }
      r_peaks.add(max_index);
    }

    return r_peaks;
  }
}

/// Вспомогательные функции
List<double> convolution(List<double> signal) {
  List<double> sig1 = [...signal];
  List<double> sig2 = [for (int i = 0; i < 20; i++) 0.05];
  List<double> conv = [for (int i = 0; i < (sig1.length - sig2.length); i++) 0];
  for (int l = 0; l < conv.length; l++) {
    for (int i = 0; i < sig2.length; i++) {
      conv[l] += sig1[l - i + sig2.length] * sig2[i];
    }
  }

  List<double> d = [for (int i = 0; i < signal.length; i++) 0];
  for (int l = 0; l < conv.length; l++) {
    d[l + 11] = conv[l];
  }
  return d;
}

double geMax(List signal) {
  double largestGeekValue = signal[0];

  for (var i = 0; i < signal.length; i++) {
    if (signal[i] > largestGeekValue) {
      largestGeekValue = signal[i];
    }
  }
  return largestGeekValue;
}

List diff(List signal) {
  List out = [];
  if (signal.length < 2) {
    return [];
  }
  for (int i = 0; i < signal.length - 1; i++) {
    out.add(signal[i + 1] - signal[i]);
  }
  return out;
}

List unique(List arr) {
  arr.sort();
  List unique_list = [];

  var last_added;

  for (var element in arr) {
    if (element != last_added) {
      unique_list.add(element);
      last_added = element;
    }
  }
  return unique_list;
}

List divideList(List signal, int divider) {
  List out = [];
  for (int i = 0; i < signal.length; i++) {
    out.add(signal[i] / divider);
  }
  return out;
}

double average(List signal) {
  double summ = 0;
  for (int i = 0; i < signal.length; i++) {
    summ += signal[i];
  }
  return summ / signal.length;
}

/// Получить полный путь к утилите WFDB
String getWfdbCommand(String command) {
  if (wfdbBinPath.isEmpty) {
    return command;
  }
  // Добавляем разделитель пути, если его нет в конце
  String path = wfdbBinPath;
  if (!path.endsWith(Platform.pathSeparator)) {
    path += Platform.pathSeparator;
  }
  // На Windows добавляем .exe если нужно
  if (Platform.isWindows && !command.endsWith('.exe')) {
    return path + command + '.exe';
  }
  return path + command;
}

/// Чтение частоты дискретизации из файла .hea
Future<double> getSampleRate(String filePath) async {
  try {
    final heaFile = File(filePath + '.hea');
    if (!await heaFile.exists()) {
      print('Предупреждение: файл .hea не найден, используется частота по умолчанию 360');
      return 360.0;
    }

    final content = await heaFile.readAsString();
    final lines = content.split('\n');
    
    // Первая строка содержит информацию о записи
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        // Третье число - частота дискретизации
        final sampleRate = double.tryParse(parts[2]);
        if (sampleRate != null && sampleRate > 0) {
          return sampleRate;
        }
      }
      // После первой строки идут описания каналов, поэтому выходим
      break;
    }

    print('Предупреждение: не удалось определить частоту дискретизации, используется 360');
    return 360.0;
  } catch (e) {
    print('Ошибка чтения файла .hea: $e');
    return 360.0;
  }
}

/// Загрузка данных ЭКГ с помощью rdsamp
Future<List<double>> loadECGDataWithRDSamp(String filePath, int channel) async {
  try {
    final datFile = File(filePath + '.dat');
    if (!await datFile.exists()) {
      print('Ошибка: файл .dat не найден: $filePath.dat');
      return [];
    }

    final rdsampCmd = getWfdbCommand('rdsamp');
    final process = await Process.start(
      rdsampCmd,
      ['-r', filePath, '-f', '0', '-t', 'end', '-p', '-v'],
      mode: ProcessStartMode.normal,
    );

    final output = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      print('Ошибка выполнения rdsamp (код $exitCode): $stderr');
      return [];
    }

    return _parseRDSampOutput(output, channel);
  } catch (e) {
    print('Ошибка выполнения rdsamp: $e');
    return [];
  }
}

List<double> _parseRDSampOutput(String output, int channel) {
  final lines = output.split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();

  if (lines.isEmpty) {
    print('Вывод rdsamp пуст');
    return [];
  }

  final signal = <double>[];

  for (final line in lines) {
    try {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < channel + 2) continue;

      final value = double.parse(parts[channel + 1]);

      if (value.isFinite) {
        signal.add(value);
      }
    } catch (e) {
      continue;
    }
  }
  return signal;
}

/// Запись пиков в аннотационный файл с помощью wrann
Future<void> writePeaksWithWRAnn(String filePath, List<int> peaks, int fs) async {
  try {
    final datFile = File(filePath + '.dat');
    if (!await datFile.exists()) {
      print('Ошибка: файл .dat не найден: $filePath.dat');
      return;
    }

    // Формируем содержимое аннотации в правильном формате для wrann
    final content = StringBuffer();
    for (int peak in peaks) {
      // Преобразуем номер выборки во время
      double timeInSeconds = peak / fs;
      int minutes = timeInSeconds ~/ 60;
      double seconds = timeInSeconds % 60;
      int wholeSeconds = seconds.floor();
      int milliseconds = ((seconds - wholeSeconds) * 1000).round();
      
      // Формат: MM:SS.mmm SAMPLE_NUMBER N
      // Пример: "0:02.072       518     N"
      String formattedTime = '${minutes.toString().padLeft(1, '0')}:${wholeSeconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
      content.writeln('$formattedTime       $peak     N');
    }
    
    // Запускаем процесс
    final wrannCmd = getWfdbCommand('wrann');
    final process = await Process.start(
      wrannCmd,
      ['-r', filePath, '-a', 'gqrs'],
      mode: ProcessStartMode.normal,
    );

    // Передаем данные в stdin
    process.stdin.write(content.toString());
    await process.stdin.close();

    final output = await process.stdout.transform(utf8.decoder).join();
    final stderr = await process.stderr.transform(utf8.decoder).join();

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      print('Ошибка wrann (код $exitCode): $stderr');
      if (stderr.isNotEmpty) {
        print('stderr: $stderr');
      }
      if (output.isNotEmpty) {
        print('stdout: $output');
      }
      return;
    }
  } catch (e) {
    print('Ошибка записи аннотационного файла: $e');
  }
}

/// Проверка доступности rdsamp
Future<bool> isRDSampAvailable() async {
  try {
    final cmd = getWfdbCommand('rdsamp');
    final result = await Process.run(cmd, ['-v']);
    return true;
  } catch (e) {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['rdsamp']);
        return result.exitCode == 0;
      } else {
        final result = await Process.run('which', ['rdsamp']);
        return result.exitCode == 0;
      }
    } catch (e2) {
      return false;
    }
  }
}

/// Проверка доступности wrann
Future<bool> isWRAnnAvailable() async {
  try {
    final cmd = getWfdbCommand('wrann');
    final result = await Process.run(cmd, ['-v']);
    return true;
  } catch (e) {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', ['wrann']);
        return result.exitCode == 0;
      } else {
        final result = await Process.run('which', ['wrann']);
        return result.exitCode == 0;
      }
    } catch (e2) {
      return false;
    }
  }
}

/// Обработка одной записи
Future<void> processRecording(String folderPath, String recordNumber, int channel) async {

  print('Обработка: $folderPath, запись $recordNumber, канал $channel');


  /*// Проверяем доступность утилит
  if (!await isRDSampAvailable()) {
    print('Ошибка: rdsamp не найден. Установите WFDB toolkit.');
    print('Проверьте, что rdsamp доступен в командной строке.');
    print('Или установите переменную wfdbBinPath в коде.');
    return;
  }
  
  if (!await isWRAnnAvailable()) {
    print('Ошибка: wrann не найден. Установите WFDB toolkit.');
    print('Проверьте, что wrann доступен в командной строке.');
    print('Или установите переменную wfdbBinPath в коде.');
    return;
  }*/

  // Путь к файлам записи (без расширения)
  final filePath = '$folderPath/$recordNumber';
  
  // Проверяем существование .dat файла
  final datFile = File(filePath + '.dat');
  if (!await datFile.exists()) {
    print('Ошибка: файл $filePath.dat не найден');
    return;
  }

  // Получаем частоту дискретизации
  final sampleRate = await getSampleRate(filePath);
  final fs = sampleRate.round();

  // Загружаем данные через rdsamp
  final ecgData = await loadECGDataWithRDSamp(filePath, channel);
  if (ecgData.isEmpty) {
    print('Ошибка: данные не загружены');
    return;
  }

  print('Загружено ${ecgData.length} отсчётов, частота $fs Гц');

  // Применяем фильтры
  List<double> filteredData = [for (double i in ecgData) applyHighPassFilter(i)];
  filteredData = [for (double i in filteredData) applyLowPassFilter(i)];

  // Детектируем пики
  final detector = PanTompkinsQRS();
  late List<int> peaks;
  late double heartRate;
  (heartRate, peaks) = detector.solve(filteredData, fs);
  
  print('Результаты: ${heartRate.toStringAsFixed(2)} BPM, ${peaks.length} пиков');

  // Сохраняем пики в .gqrs аннотацию
  await writePeaksWithWRAnn(filePath, peaks, fs);

  // Сбрасываем состояние фильтров
  hprevFilterd = 0.0;
  hprevUnFiltered = 0.0;
  hprevprevUnfiltered = 0.0;
  hprevprevFilterd = 0.0;
  lprevFilterd = 0.0;
  lprevUnFiltered = 0.0;
  lprevprevUnfiltered = 0.0;
  lprevprevFilterd = 0.0;
}

void main(List<String> args) async {
  // Проверяем аргументы командной строки
  if (args.length < 3) {
    print('Использование: dart pan-tompkins.dart <путь_к_папке> <номер_записи> <канал>');
    print('Пример: dart pan-tompkins.dart ./assets/ECG_DB/AHADB 1201 1');
    print('');
    print('Аргументы:');
    print('  путь_к_папке   - Путь к папке с файлами записи');
    print('  номер_записи   - Номер записи (например, 1201)');
    print('  канал          - Номер канала (0 или 1)');
    print('');
    print('Программа:');
    print('  - Загружает данные через rdsamp');
    print('  - Детектирует R-пики алгоритмом Pan-Tompkins');
    print('  - Сохраняет пики в .gqrs аннотацию с помощью wrann');
    print('');
    print('Для указания пути к утилитам WFDB установите переменную wfdbBinPath');
    print('Например: wfdbBinPath = "C:/WFDB/bin/";');
    exit(1);
  }

  final folderPath = args[0];
  final recordNumber = args[1];
  final channel = int.parse(args[2]);

  await processRecording(folderPath, recordNumber, channel);
}

/// Переменные для фильтра высоких частот
double hprevFilterd = 0.0;
double hprevUnFiltered = 0.0;
double hprevprevUnfiltered = 0.0;
double hprevprevFilterd = 0.0;

//fs = 125 Hz
//List<double> bhp = [0.9736978852077434, -1.9473957704154865, 0.9736978852077433];
//List<double> ahp = [1.9467038494842983, -0.9480876913466759];

//fs = 250 Hz
List<double> bhp = [0.98413352, -1.96826703, 0.98413352];
List<double> ahp = [1.96801527, -0.96851879];

/// Переменные для фильтра низких частот
double lprevFilterd = 0.0;
double lprevUnFiltered = 0.0;
double lprevprevUnfiltered = 0.0;
double lprevprevFilterd = 0.0;


//fs = 125 Hz
//List<double> blp = [0.2564056711091054, 0.5128113422182107, 0.2564056711091051];
//List<double> alp = [0.14992656822522105, -0.1755492526616423];

//fs = 250 Hz
List<double> blp = [0.10655456, 0.21310912, 0.10655456];
List<double> alp = [0.88854742, -0.31476566];

/// Фильтр низких частот
double applyLowPassFilter(double val) {
  double y = blp[0] * val +
      alp[0] * lprevFilterd +
      blp[1] * lprevUnFiltered +
      alp[1] * lprevprevFilterd +
      blp[2] * lprevprevUnfiltered;
  lprevprevFilterd = lprevFilterd;
  lprevFilterd = y;
  lprevprevUnfiltered = lprevUnFiltered;
  lprevUnFiltered = val;
  return y;
}

/// Фильтр высоких частот
applyHighPassFilter(double val) {
  double y = bhp[0] * val +
      ahp[0] * hprevFilterd +
      bhp[1] * hprevUnFiltered +
      ahp[1] * hprevprevFilterd +
      bhp[2] * hprevprevUnfiltered;
  hprevprevFilterd = hprevFilterd;
  hprevFilterd = y;
  hprevprevUnfiltered = hprevUnFiltered;
  hprevUnFiltered = val;
  return y;
}