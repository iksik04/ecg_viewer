import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onSettingsTap;

  const CustomDrawer({
    super.key,
    required this.onHomeTap,
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
          ListTile(
            title: const Text('100'),
            onTap: () {
              Navigator.pop(context);
              onHomeTap();
            },
          ),
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