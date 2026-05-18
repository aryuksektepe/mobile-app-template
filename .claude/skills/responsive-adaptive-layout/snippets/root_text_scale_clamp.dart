import 'package:flutter/material.dart';

/// Root text-scale clamp. Honors the user's OS font-size preference (do NOT
/// disable it) but bounds it so an extreme setting cannot shatter the UI.
///
/// 1.3 is the safe starting default; raise maxScaleFactor as the design is
/// verified at larger scales (golden matrix proves it). minScaleFactor 1.0
/// keeps text from being shrunk below design size.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.3, // TODO(executor): raise once design verified higher
      child: MaterialApp.router(
        routerConfig: appRouter,
        theme: lightTheme,
        darkTheme: darkTheme,
        // builder: not needed — withClampedTextScaling wraps everything,
        // including dialogs/overlays from this MaterialApp.
      ),
    );
  }
}

// Equivalent manual form if you must clamp inside a builder:
//   builder: (context, child) {
//     final mq = MediaQuery.of(context);
//     return MediaQuery(
//       data: mq.copyWith(
//         textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3),
//       ),
//       child: child!,
//     );
//   }
