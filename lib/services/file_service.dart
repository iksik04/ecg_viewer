import 'dart:io';
import 'dart:async';
import '../constants/app_constants.dart';

class FileService {
  static const String _basePath = AppStrings.basePath;
  static Map<String, List<String>>? _cachedRecordsByFolder;
  
  // Получение списка доступных папок (баз данных)
  Future<List<String>> getAvailableFolders() async {
    try {
      final directory = Directory(_basePath);
      if (!await directory.exists()) {
        print('Директория $_basePath не найдена');
        return [];
      }
      
      final folders = <String>[];
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          final folderName = entity.path.split(Platform.pathSeparator).last;
          folders.add(folderName);
        }
      }
      
      folders.sort();
      return folders;
    } catch (e) {
      print('Ошибка загрузки папок: $e');
      return [];
    }
  }
  
  // Получение записей для конкретной папки
  Future<List<String>> getAvailableRecordsForFolder(String folder, {bool forceRefresh = false}) async {
    final cacheKey = 'folder_$folder';
    
    if (_cachedRecordsByFolder != null && 
        _cachedRecordsByFolder!.containsKey(cacheKey) && 
        !forceRefresh) {
      return _cachedRecordsByFolder![cacheKey]!;
    }
    
    try {
      final records = await _scanRecordsInFolder(folder);
      
      if (_cachedRecordsByFolder == null) {
        _cachedRecordsByFolder = {};
      }
      _cachedRecordsByFolder![cacheKey] = records;
      return records;
    } catch (e) {
      print('Ошибка загрузки записей для папки $folder: $e');
      return [];
    }
  }
  
  Future<List<String>> _scanRecordsInFolder(String folder) async {
    final folderPath = '$_basePath${Platform.pathSeparator}$folder';
    final directory = Directory(folderPath);
    
    if (!await directory.exists()) {
      return [];
    }
    
    final Set<String> records = {};
    
    await for (final entity in directory.list()) {
      if (entity is File) {
        final fileName = entity.path.split(Platform.pathSeparator).last;
        
        // Проверяем, что файл имеет расширение .hea (регистронезависимо)
        final lowerFileName = fileName.toLowerCase();
        if (lowerFileName.endsWith('.hea')) {
          // Убираем расширение (все 4 символа, включая точку)
          final recordName = fileName.substring(0, fileName.length - 4);
          if (recordName.isNotEmpty) {
            records.add(recordName);
          }
        }
      }
    }
    
    // Сортируем записи
    final sortedRecords = records.toList();
    sortedRecords.sort((a, b) {
      // Пробуем распарсить как числа
      final aIsNumber = int.tryParse(a) != null;
      final bIsNumber = int.tryParse(b) != null;
      
      if (aIsNumber && bIsNumber) {
        return int.parse(a).compareTo(int.parse(b));
      } else if (aIsNumber) {
        return -1;
      } else if (bIsNumber) {
        return 1;
      } else {
        return a.compareTo(b);
      }
    });
    
    return sortedRecords;
  }
  
  // Проверка существования файла
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
  
  // Получение полного пути к файлу
  String getFilePath(String folder, String record, String extension) {
    return '$_basePath${Platform.pathSeparator}$folder${Platform.pathSeparator}$record.$extension';
  }
  
  // Получение списка всех файлов для записи
  Future<Map<String, bool>> getRecordFiles(String folder, String record) async {
    final extensions = ['aed', 'atr', 'hea', 'dat', 'gqrs'];
    final result = <String, bool>{};
    
    for (final ext in extensions) {
      final filePath = getFilePath(folder, record, ext);
      final exists = await fileExists(filePath);
      result[ext] = exists;
    }
    
    return result;
  }
  
  // Получение содержимого .hea файла (заголовка записи)
  Future<String?> getHeaderContent(String folder, String record) async {
    try {
      final filePath = getFilePath(folder, record, 'hea');
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      print('Ошибка загрузки .hea файла для $folder/$record: $e');
      return null;
    }
  }
  
  // Очистка кэша
  void clearCache() {
    _cachedRecordsByFolder = null;
  }
}