import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/file_service.dart';

class CustomDrawer extends StatefulWidget {
  final Function(String) onNumberTap;
  final VoidCallback onSettingsTap;

  const CustomDrawer({
    super.key,
    required this.onNumberTap,
    required this.onSettingsTap,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final FileService _fileService = FileService();
  List<String> _availableFiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final files = await _fileService.getAvailableFiles(forceRefresh: forceRefresh);
      setState(() {
        _availableFiles = files;
        _isLoading = false;
        
        // Если список пуст, показываем сообщение
        if (files.isEmpty) {
          _errorMessage = 'Файлы не найдены. Проверьте папку assets/data/';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки файлов: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 65,
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child:Text(
                      AppStrings.drawerTitle,
                      style: AppTextStyles.drawerTitle,
                    ),
            ),
          ),
          _buildFileList(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text(AppStrings.menuSettings),
            onTap: () {
              Navigator.pop(context);
              widget.onSettingsTap();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Сканирование файлов...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _availableFiles.map((number) {
        return ListTile(
          leading: const Icon(Icons.folder, color: AppColors.grey, size: 20),
          title: Text(
            'Запись #$number',
            style: const TextStyle(fontSize: 16),
          ),
          onTap: () {
            Navigator.pop(context);
            widget.onNumberTap(number);
          },
        );
      }).toList(),
    );
  }
}