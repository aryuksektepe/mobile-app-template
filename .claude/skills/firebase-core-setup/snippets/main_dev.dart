// Flavor entrypoint — dev. Mirror this file as main_stg.dart and main_prod.dart,
// each importing the corresponding firebase_options_<flavor>.dart.
//
// Run with:
//   flutter run --flavor dev -t lib/main_dev.dart

import 'firebase_options_dev.dart';
import 'bootstrap.dart';

void main() => bootstrap(DefaultFirebaseOptions.currentPlatform);
