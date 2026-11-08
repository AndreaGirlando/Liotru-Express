import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.section,
    this.onSettings,
    this.showBack = false,
    this.actions = const [],
    super.key,
  });
  final String section;
  final VoidCallback? onSettings;
  final bool showBack;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(76);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 76,
    automaticallyImplyLeading: showBack,
    titleSpacing: showBack ? 0 : 22,
    title: Row(
      children: [
        Image.asset(
          'assets/branding/liotru.png',
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Liotru Express',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                section,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      ...actions,
      if (onSettings != null)
        IconButton(
          tooltip: 'Impostazioni',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      const SizedBox(width: 12),
    ],
  );
}
