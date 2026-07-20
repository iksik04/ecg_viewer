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

  @override
  void initState() {
    super.initState();
    _futureData = _ecgService.loadECGData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: CustomDrawer(
        onHomeTap: () {},
        onSettingsTap: () {},
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: _buildECGContent(),
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
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text(
            '${AppStrings.errorLoading} ${snapshot.error}',
            style: AppTextStyles.errorMessage,
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(
            AppStrings.noData,
            style: AppTextStyles.infoMessage,
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