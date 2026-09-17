import 'package:flutter/material.dart';
import '../theme/adaptive_icons.dart';
import '../theme/color_tokens.dart';

class DropBasketTarget extends StatefulWidget {
  const DropBasketTarget({
    super.key,
    required this.onUrlDropped,
    required this.onTap,
  });

  final ValueChanged<String> onUrlDropped;
  final VoidCallback onTap;

  @override
  State<DropBasketTarget> createState() => _DropBasketTargetState();
}

class _DropBasketTargetState extends State<DropBasketTarget> {
  bool _isHovering = false;
  Offset _position = const Offset(20, 20);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: _position.dx,
      bottom: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx - details.delta.dx).clamp(10.0, 500.0),
              (_position.dy - details.delta.dy).clamp(10.0, 500.0),
            );
          });
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(32),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ColorTokens.darkBgSurface.withValues(alpha: _isHovering ? 0.95 : 0.75),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isHovering ? ColorTokens.statusActive : ColorTokens.darkBorderSubtle,
                  width: _isHovering ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovering
                        ? ColorTokens.statusActive.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: _isHovering ? 12 : 6,
                    spreadRadius: _isHovering ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                AdaptiveIcons.dropTarget,
                color: ColorTokens.statusActive,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
