import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A page that slides in from the right (the design's `mb-screen` motion).
CustomTransitionPage<T> slidePage<T>(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.22, 1, 0.36, 1),
        reverseCurve: Curves.easeIn,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// A page that fades in (used for splash / auth roots).
CustomTransitionPage<T> fadePage<T>(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
