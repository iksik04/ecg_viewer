import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/file_service.dart';

class CustomDrawer extends StatefulWidget {
  final Function(String, String) onNumberTap; // folder, number
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
  List<String> _folders = [];
  Map<String, List<String>> _filesByFolder = {};
  Map<String, bool> _expandedFolders = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final folders = await _fileService.getAvailableFolders();
      
      // Загружаем файлы для каждой папки
      final Map<String, List<String>> filesMap = {};
      for (final folder in folders) {
        final files = await _fileService.getAvailableFilesForFolder(folder);
        filesMap[folder] = files;
        _expandedFolders[folder] = false; // По умолчанию свернуто
      }
      
      setState(() {
        _folders = folders;
        _filesByFolder = filesMap;
        _isLoading = false;
        
        if (folders.isEmpty) {
          _errorMessage = 'Папки не найдены. Проверьте структуру assets/data/';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleFolder(String folder) {
    setState(() {
      _expandedFolders[folder] = !(_expandedFolders[folder] ?? false);
    });
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
              child: Text(
                AppStrings.drawerTitle,
                style: AppTextStyles.drawerTitle,
              ),
            ),
          ),
          _buildDrawerContent(),
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

  Widget _buildDrawerContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Загрузка...'),
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

    if (_folders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text('Нет доступных папок'),
        ),
      );
    }

    return Column(
      children: _folders.map((folder) {
        final files = _filesByFolder[folder] ?? [];
        final isExpanded = _expandedFolders[folder] ?? false;
        
        return Column(
          children: [
            // Заголовок папки
            ListTile(
              leading: Icon(
                isExpanded ? Icons.folder_open : Icons.folder,
                color: AppColors.primary,
              ),
              title: Text(
                folder,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                isExpanded 
                    ? Icons.expand_less 
                    : Icons.expand_more,
              ),
              onTap: () => _toggleFolder(folder),
            ),
            // Список файлов (если развернуто)
            if (isExpanded) ...[
              if (files.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Нет файлов',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                ...files.map((number) {
                  return ListTile(
                    leading: const Icon(
                      Icons.insert_drive_file,
                      color: AppColors.grey,
                      size: 18,
                    ),
                    title: Text(
                      'Запись #$number',
                      style: const TextStyle(fontSize: 14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNumberTap(folder, number);
                    },
                  );
                }),
            ],
            const Divider(height: 1),
          ],
        );
      }).toList(),
    );
  }
}