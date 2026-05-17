import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// A [PageRoute] that uses [SharedAxisTransition] with horizontal axis.
/// Use in place of [MaterialPageRoute] for consistent slide transitions.
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  SharedAxisPageRoute({
    required WidgetBuilder builder,
    SharedAxisTransitionType transitionType =
        SharedAxisTransitionType.horizontal,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: transitionType,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}
