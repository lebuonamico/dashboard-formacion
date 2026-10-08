import 'package:flutter/material.dart';

const areasInk = Color(0xFF0F172A);
const areasMuted = Color(0xFF64748B);
const areasBorder = Color(0xFFE2E8F0);
const areasBackground = Color(0xFFF8FAFC);
const areasBrand = Color(0xFF0D53C3);

BoxDecoration areasPanelDecoration({bool withShadow = false}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: areasBorder),
    boxShadow: withShadow
        ? const [
            BoxShadow(
              color: Color(0x090F172A),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ]
        : null,
  );
}
