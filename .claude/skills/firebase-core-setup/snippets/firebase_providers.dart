// Riverpod core providers for any Firebase product. Add a provider per
// product as you depend on it (auth/firestore/messaging/etc.).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAppProvider = Provider<FirebaseApp>((_) => Firebase.app());

// Example for downstream services — add as needed:
// import 'package:firebase_auth/firebase_auth.dart';
// final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
