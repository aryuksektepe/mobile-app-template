// PermissionService — single point for all OS permissions.
// Per-permission Riverpod provider exposes status; widgets watch + react.
//
// Pattern:
//   1. Build a soft-ask widget for the permission you need.
//   2. On CTA tap, call `service.requestWithRationale(Permission.camera)`.
//   3. On `permanentlyDenied`, show settings deep-link modal.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Returns the resolved status after requesting. UI should branch on it.
  Future<PermissionStatus> request(Permission permission) async {
    final current = await permission.status;
    if (current.isGranted || current.isLimited) return current;
    if (current.isPermanentlyDenied) return current;  // request() won't re-prompt; UI shows settings modal
    return permission.request();
  }

  /// Convenience: open the OS settings page for this app.
  Future<bool> openSettings() => openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>((_) => PermissionService());

// Per-permission status providers (rebuild on resume to catch settings changes)
final cameraStatusProvider = FutureProvider<PermissionStatus>((_) => Permission.camera.status);
final photosStatusProvider = FutureProvider<PermissionStatus>((_) => Permission.photos.status);
final locationStatusProvider = FutureProvider<PermissionStatus>((_) => Permission.locationWhenInUse.status);
final microphoneStatusProvider = FutureProvider<PermissionStatus>((_) => Permission.microphone.status);
final contactsStatusProvider = FutureProvider<PermissionStatus>((_) => Permission.contacts.status);

// Permanent-denial modal — call after request() returns isPermanentlyDenied
Future<void> showPermissionSettingsModal(
  BuildContext context, {
  required String permissionName,
  required String reason,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$permissionName izni gerekli'),
      content: Text('$reason\n\nİzin daha önce kalıcı reddedilmiş. Lütfen ayarlardan aç.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await openAppSettings();
          },
          child: const Text('Ayarları aç'),
        ),
      ],
    ),
  );
}
