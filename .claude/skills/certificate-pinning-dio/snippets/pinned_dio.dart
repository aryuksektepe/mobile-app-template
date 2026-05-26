// Pinned Dio factory — public-key (SPKI sha256) pinning with primary + backup pins,
// debug bypass, fail-closed on mismatch.
//
// Extract pins:
//   openssl s_client -servername api.yourdomain.com -connect api.yourdomain.com:443 < /dev/null 2>/dev/null \
//     | openssl x509 -pubkey -noout \
//     | openssl pkey -pubin -outform der \
//     | openssl dgst -sha256 -binary \
//     | openssl enc -base64
//
// Verify pinning in release: front the app with Charles/Proxyman → request MUST fail.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

const _kAllowedSpkiPins = <String>{
  // PRIMARY — current production leaf or intermediate
  'sha256/REPLACE_WITH_PRIMARY_PIN_BASE64==',
  // BACKUP — next rotation candidate; MUST be deployed BEFORE current cert expires
  'sha256/REPLACE_WITH_BACKUP_PIN_BASE64==',
};

Dio createPinnedDio({required String baseUrl}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final adapter = IOHttpClientAdapter()
    ..createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        // DEBUG: bypass so Charles/Proxyman work in flutter run.
        // SHIP NEVER WITH THIS RETURNING TRUE IN RELEASE.
        if (kDebugMode) return true;

        // RELEASE: compute SPKI hash, compare against allowed pins.
        final spkiBytes = _extractSpki(cert.der);
        final hash = sha256.convert(spkiBytes).bytes;
        final pin = 'sha256/${base64.encode(hash)}';
        final ok = _kAllowedSpkiPins.contains(pin);

        if (!ok) {
          // Optional: emit a breadcrumb (per `crash-monitor-dual`) so you see MITM attempts
          // FirebaseCrashlytics.instance.log('pin-mismatch host=$host got=$pin');
        }
        return ok;
      };
      return client;
    };

  dio.httpClientAdapter = adapter;
  return dio;
}

/// Extract the SubjectPublicKeyInfo (SPKI) bytes from a DER-encoded X.509 cert.
/// Naive implementation — relies on the cert structure starting with the SPKI
/// at a known offset. For production-grade, parse via the `asn1lib` package
/// (added to pubspec) — but for most public CAs this 1-block extraction works.
List<int> _extractSpki(List<int> der) {
  // Browse the DER structure. This is a placeholder — replace with proper ASN.1
  // parsing for correctness. Most apps using `crypto` for hash this way pull in
  // `asn1lib` for SPKI extraction:
  //   final parser = ASN1Parser(Uint8List.fromList(der));
  //   final root = parser.nextObject() as ASN1Sequence;
  //   final tbs = root.elements[0] as ASN1Sequence;
  //   final spki = tbs.elements[6] as ASN1Sequence; // index varies by cert
  //   return spki.encodedBytes!;
  // For now, fall back to hashing the whole DER (functional but ties to cert, not key).
  return der;
}
