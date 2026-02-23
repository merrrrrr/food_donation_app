import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LoadingOverlay
//  Stacks a semi-transparent scrim + spinner on top of a child widget.
//  Set [isLoading] = true to activate; the child remains rendered underneath
//  so there is no layout jump when loading ends.
//
//  Usage:
//    LoadingOverlay(
//      isLoading: provider.isLoading,
//      child: MyScreen(),
//    )
// ─────────────────────────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Color barrierColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.barrierColor = const Color(0x66000000), // 40% black
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: barrierColor,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}
