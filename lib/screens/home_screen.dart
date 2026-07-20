import 'package:flutter/material.dart';
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
      backgroundColor: const Color.fromRGBO(239, 239, 239, 1),
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
      title: const Text(
        'Визуализация работы QRS-детектора',
        style: TextStyle(color: Colors.white, fontSize: 20),
      ),
      backgroundColor: const Color.fromRGBO(52, 179, 171, 1),
      iconTheme: const IconThemeData(
        color: Colors.white,
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
          return Text('Ошибка загрузки данных: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('Нет данных ECG');
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