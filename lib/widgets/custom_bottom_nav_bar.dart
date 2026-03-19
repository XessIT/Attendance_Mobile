import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomAnimatedBottomBar extends StatefulWidget {
  const CustomAnimatedBottomBar({
    super.key,
    this.containerHeight = 56,
    this.backgroundColor = Colors.white,
    this.animationDuration = const Duration(milliseconds: 270),
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    required this.items,
    required this.onItemSelected,
    this.selectedIndex = 0,
    this.curve = Curves.linear,
    this.showElevation = true,
    this.itemCornerRadius = 50,
    this.containerPadding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    this.margin = const EdgeInsets.all(8),
  });

  final double containerHeight;
  final Color backgroundColor;
  final Duration animationDuration;
  final MainAxisAlignment mainAxisAlignment;
  final List<BottomNavyBarItem> items;
  final ValueChanged<int> onItemSelected;
  final int selectedIndex;
  final Curve curve;
  final bool showElevation;
  final double itemCornerRadius;
  final EdgeInsets containerPadding;
  final EdgeInsets margin;

  @override
  State<CustomAnimatedBottomBar> createState() => _CustomAnimatedBottomBarState();
}

class _CustomAnimatedBottomBarState extends State<CustomAnimatedBottomBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: widget.showElevation
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: widget.containerHeight,
          child: Padding(
            padding: widget.containerPadding,
            child: Row(
              mainAxisAlignment: widget.mainAxisAlignment,
              children: widget.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = widget.selectedIndex == index;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onItemSelected(index),
                      borderRadius: BorderRadius.circular(widget.itemCornerRadius),
                      highlightColor: Colors.transparent,
                      splashColor: item.activeColor.withOpacity(0.1),
                      child: _buildItem(item, isSelected),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BottomNavyBarItem item, bool isSelected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final iconSize = isSelected 
            ? (availableHeight * 0.5).clamp(20.0, 28.0)
            : (availableHeight * 0.4).clamp(16.0, 24.0);
        final fontSize = isSelected 
            ? (availableHeight * 0.15).clamp(8.0, 12.0)
            : 0.0;
        
        return AnimatedContainer(
          duration: widget.animationDuration,
          curve: widget.curve,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 4 : 2,
            vertical: 2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: widget.animationDuration,
                curve: widget.curve,
                width: isSelected ? iconSize * 1.2 : iconSize,
                height: isSelected ? iconSize * 1.2 : iconSize,
                decoration: BoxDecoration(
                  color: isSelected ? item.activeColor : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.activeColor.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  item.icon,
                  color: isSelected ? Colors.white : item.inactiveColor,
                  size: iconSize * 0.8,
                ),
              ),
              if (isSelected && fontSize > 0)
                SizedBox(height: availableHeight * 0.05),
              if (isSelected && fontSize > 0)
                AnimatedContainer(
                  duration: widget.animationDuration,
                  curve: widget.curve,
                  child: DefaultTextStyle.merge(
                    style: GoogleFonts.poppins(
                      color: item.activeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize,
                    ),
                    child: FittedBox(
                      child: item.title,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class BottomNavyBarItem {
  BottomNavyBarItem({
    required this.icon,
    required this.title,
    this.activeColor = Colors.blue,
    this.textAlign,
    this.inactiveColor = Colors.grey,
  });

  final IconData icon;
  final Widget title;
  final Color activeColor;
  final Color inactiveColor;
  final TextAlign? textAlign;
}
