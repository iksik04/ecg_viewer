import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class CustomDrawer extends StatelessWidget {
  final Function(int) onNumberTap;
  final VoidCallback onSettingsTap;

  const CustomDrawer({
    super.key,
    required this.onNumberTap,
    required this.onSettingsTap,
  });

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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.drawerTitle,
                  style: AppTextStyles.drawerTitle,
                ),
              ),
            ),
          ),
          // Генерируем кнопки от 100 до 110
          ...List.generate(22, (index) {
            int number = 100 + index;
            return ListTile(
              title: Text(
                number.toString(),
                style: const TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                onNumberTap(number);
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text(AppStrings.menuSettings),
            onTap: () {
              Navigator.pop(context);
              onSettingsTap();
            },
          ),
        ],
      ),
    );
  }
}