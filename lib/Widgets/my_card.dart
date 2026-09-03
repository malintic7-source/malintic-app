import 'package:flutter/material.dart';
import 'package:gestion_formations/config/theme.dart';

Widget myCard(
  String title,
  String subtitle,
  IconData icon,
  Color iconColor,
  Color cardColor,
  Color titleColor,
  Color subTitleColor,
  double iconSize,
  double cardWidth,
  double cardHeight,
  void Function()? onPressed,
) {
  return InkWell(
    splashColor: AppTheme.primary.withValues(alpha: 0.12),
    hoverColor: AppTheme.primary.withValues(alpha: 0.04),
    radius: 12,
    borderRadius: BorderRadius.circular(10),
    onTap: onPressed,
    child: Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: subTitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
        ],
      ),
    ),
  );
}
