// lib/constants/app_constants.dart

import 'package:flutter/material.dart';

/// Цвета приложения
class AppColors {
  // Основные цвета
  static const Color primary = Color.fromRGBO(52, 179, 171, 1);
  static const Color background = Color.fromRGBO(239, 239, 239, 1);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  
  // Цвета для графиков
  static const Color ecgLine = Colors.blue;
  static const Color peakLine = Colors.red;
  
  // Цвета для текста
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.black;
}

/// Стили текста
class AppTextStyles {
  // Заголовки
  static const TextStyle appBarTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle drawerTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w500,
  );
  
  // Подписи осей
  static const TextStyle axisLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 20,
    fontWeight: FontWeight.w400,
  );
  
  // Значения на осях
  static const TextStyle axisValue = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w400,
  );
  
  // Сообщения об ошибках и статусах
  static const TextStyle errorMessage = TextStyle(
    color: Colors.red,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle infoMessage = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
}

/// Текстовые строки приложения
class AppStrings {
  // Заголовки
  static const String appTitle = 'Визуализация работы QRS-детектора';
  static const String drawerTitle = 'Доступные записи:';
  
  // Пункты меню
  static const String menuHome = 'Главная';
  static const String menuSettings = 'Настройки';
  
  // Подписи осей
  static const String axisTime = 'Время, сек';
  static const String axisVoltage = 'Напряжение, мВ';
  
  // Сообщения
  static const String loadingData = 'Загрузка данных...';
  static const String noData = 'Нет данных ECG';
  static const String errorLoading = 'Ошибка загрузки данных:';
  
  // Пути к файлам 
  static const String dataFilePath = 'assets/data/';
  static const String peaksFilePath = 'assets/true_peaks/';
}