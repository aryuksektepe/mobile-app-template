// android/app/src/main/kotlin/<your/package>/MainActivity.kt
//
// MUST extend FlutterFragmentActivity (NOT FlutterActivity) for local_auth's
// biometric prompt sheet to render. Without this, calls to
// LocalAuthentication.authenticate() throw "no_fragment_activity".

package com.acme.myapp

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
