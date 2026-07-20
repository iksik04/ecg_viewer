import 'package:flutter/material.dart';
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
  int _currentNumber = 100;

  @override
  void initState() {
    super.initState();
    _loadData(_currentNumber);
  }

  void _loadData(int number) {
    setState(() {
      _currentNumber = number;
      _futureData = _ecgService.loadECGData(number);
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
          // TODO: Реализовать настройки
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
              Text(
                'Запись #$_currentNumber',
                style: const TextStyle(
                  fontSize: 20,
                  color: AppColors.primary
                ),
              ),
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

        return InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          constrained: false,
          child: SizedBox(
            height: 600,
            width: snapshot.data!.spots.length.toDouble(),
            child: ECGChart(data: snapshot.data!),
          ),
        );
      },
    );
  }
}