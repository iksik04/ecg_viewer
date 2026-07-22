import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import '../constants/app_constants.dart';
import '../services/ecg_service.dart';
import '../widgets/ecg_chart.dart';
import '../widgets/custom_drawer.dart';
import '../models/ecg_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ECGService _ecgService = ECGService();
  Future<ECGData>? _futureData;
  String _currentFolder = 'MITDB';
  String _currentNumber = '100';
  
  int _currentStartIndex = 0;
  int _pointsPerScreen = 200;
  double _targetSecondsPerScreen = 10.0; // Добавлено: текущее значение targetSecondsPerScreen

  @override
  void initState() {
    super.initState();
    _loadData(_currentFolder, _currentNumber);
  }

  void _loadData(String folder, String number) {
    setState(() {
      _currentFolder = folder;
      _currentNumber = number;
      _currentStartIndex = 0;
      _futureData = _ecgService.loadECGData(folder, number);
    });
  }

  int _calculatePointsPerScreen(double containerWidth, List<FlSpot> spots, double targetSecondsPerScreen) {
    if (spots.isEmpty) return 200;
    
    final double timeStep = spots.length > 1 ? spots[1].x - spots[0].x : 0.01; 
    int pointsByTime = (targetSecondsPerScreen / timeStep).round();
    return pointsByTime > 0 ? pointsByTime : 200;
  }

  void _goToNextPage(int totalPoints) {
    final maxStart = totalPoints - _pointsPerScreen;
    if (_currentStartIndex + _pointsPerScreen < totalPoints) {
      setState(() {
        _currentStartIndex += _pointsPerScreen;
        if (_currentStartIndex > maxStart) {
          _currentStartIndex = maxStart > 0 ? maxStart : 0;
        }
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentStartIndex > 0) {
      setState(() {
        _currentStartIndex -= _pointsPerScreen;
        if (_currentStartIndex < 0) {
          _currentStartIndex = 0;
        }
      });
    }
  }

  void _handleScrollZoom(ScrollDirection direction) {
    setState(() {
      if (direction == ScrollDirection.forward) {
        // Увеличиваем масштаб (уменьшаем targetSecondsPerScreen)
        _targetSecondsPerScreen = (_targetSecondsPerScreen * 0.8).clamp(2.0, 30.0);
      } else {
        // Уменьшаем масштаб (увеличиваем targetSecondsPerScreen)
        _targetSecondsPerScreen = (_targetSecondsPerScreen * 1.25).clamp(2.0, 30.0);
      }
      
      // Пересчитываем количество точек на экране
      _futureData?.then((data) {
        if (data.spots.isNotEmpty) {
          final pointsPerScreen = _calculatePointsPerScreen(
            MediaQuery.of(context).size.width - 40, // учитываем padding
            data.spots,
            _targetSecondsPerScreen
          );
          setState(() {
            _pointsPerScreen = pointsPerScreen;
            // Корректируем текущую позицию, если она выходит за пределы
            final totalPoints = data.spots.length;
            final maxStart = totalPoints - _pointsPerScreen;
            if (_currentStartIndex > maxStart) {
              _currentStartIndex = maxStart > 0 ? maxStart : 0;
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: CustomDrawer(
        onNumberTap: _loadData,
        onSettingsTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Настройки в разработке')),
          );
        },
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: _buildECGContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_currentFolder - Запись #$_currentNumber',
                style: const TextStyle(
                  fontSize: 20,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Масштаб: ${_targetSecondsPerScreen.toStringAsFixed(1)} сек/экран',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildPageInfo(),
            ),
            const SizedBox(width: 10),
            _buildNavigationButtons(),
          ],
        ),
      ],
    );
  }

  Widget _buildPageInfo() {
    return FutureBuilder<ECGData>(
      future: _futureData,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'Нет данных',
            style: TextStyle(fontSize: 14, color: AppColors.primary),
          );
        }
        final totalPoints = snapshot.data!.spots.length;
        final currentPage = (_currentStartIndex / _pointsPerScreen).floor() + 1;
        final totalPages = (totalPoints / _pointsPerScreen).ceil();
        return Text(
          'Страница $currentPage из $totalPages',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: _currentStartIndex > 0 ? _goToPreviousPage : null,
          color: AppColors.primary,
        ),
        FutureBuilder<ECGData>(
          future: _futureData,
          builder: (context, snapshot) {
            final totalPoints = snapshot.data?.spots.length ?? 0;
            final canGoNext = _currentStartIndex + _pointsPerScreen < totalPoints;
            return IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20),
              onPressed: canGoNext ? () => _goToNextPage(totalPoints) : null,
              color: AppColors.primary,
            );
          },
        ),
      ],
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        AppStrings.appTitle,
        style: AppTextStyles.appBarTitle,
      ),
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(
        color: AppColors.white,
        size: 24.0,
      ),
    );
  }

  Widget _buildECGContent() {
    return FutureBuilder<ECGData>(
      future: _futureData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Загрузка данных...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${AppStrings.errorLoading} ${snapshot.error}',
              style: AppTextStyles.errorMessage,
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              AppStrings.noData,
              style: AppTextStyles.infoMessage,
            ),
          );
        }

        final data = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final pointsPerScreen = _calculatePointsPerScreen(
              constraints.maxWidth, 
              data.spots, 
              _targetSecondsPerScreen
            );
            
            if (pointsPerScreen != _pointsPerScreen) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _pointsPerScreen = pointsPerScreen;
                });
              });
            }

            return Column(
              children: [
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        // Определяем направление прокрутки
                        final scrollDirection = event.scrollDelta.dy > 0 
                            ? ScrollDirection.backward 
                            : ScrollDirection.forward;
                        _handleScrollZoom(scrollDirection);
                      }
                    },
                    child: ECGChart(
                      data: data,
                      startIndex: _currentStartIndex,
                      pointsPerScreen: _pointsPerScreen,
                      targetSecondsPerScreen: _targetSecondsPerScreen, // Передаем значение
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildScrollBar(data.spots.length, _pointsPerScreen),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScrollBar(int totalPoints, int pointsPerScreen) {
    final progress = totalPoints > 0 
        ? _currentStartIndex / totalPoints 
        : 0;
    
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Text('◀', style: TextStyle(fontSize: 12)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: progress.toDouble(),
                min: 0,
                max: 1,
                onChanged: (value) {
                  final newIndex = (value * totalPoints).round();
                  final maxStart = totalPoints - pointsPerScreen;
                  setState(() {
                    _currentStartIndex = newIndex.clamp(0, maxStart > 0 ? maxStart : 0);
                  });
                },
                activeColor: AppColors.primary,
                inactiveColor: AppColors.grey,
              ),
            ),
          ),
          const Text('▶', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// Добавлен enum для направления прокрутки
enum ScrollDirection {
  forward,
  backward,
}