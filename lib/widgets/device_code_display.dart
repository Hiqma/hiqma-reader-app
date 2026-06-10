import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/authentication_service.dart';

/// Widget to display the current device code in the app header
class DeviceCodeDisplay extends StatelessWidget {
  final AuthenticationService authenticationService;
  final bool showCopyButton;
  final TextStyle? textStyle;

  const DeviceCodeDisplay({
    Key? key,
    required this.authenticationService,
    this.showCopyButton = true,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authenticationService,
      builder: (context, child) {
        final deviceCode = authenticationService.currentDeviceCode;
        
        if (deviceCode == null || !authenticationService.isDeviceRegistered) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                deviceCode,
                style: textStyle ?? TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
              if (showCopyButton) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _copyDeviceCode(context, deviceCode),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _copyDeviceCode(BuildContext context, String deviceCode) {
    Clipboard.setData(ClipboardData(text: deviceCode));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device code $deviceCode copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Compact version for use in app bars
class CompactDeviceCodeDisplay extends StatelessWidget {
  final AuthenticationService authenticationService;

  const CompactDeviceCodeDisplay({
    Key? key,
    required this.authenticationService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DeviceCodeDisplay(
      authenticationService: authenticationService,
      showCopyButton: false,
      textStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        fontFamily: 'monospace',
      ),
    );
  }
}

/// Device code chip for settings or profile screens
class DeviceCodeChip extends StatelessWidget {
  final AuthenticationService authenticationService;
  final VoidCallback? onTap;

  const DeviceCodeChip({
    Key? key,
    required this.authenticationService,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authenticationService,
      builder: (context, child) {
        final deviceCode = authenticationService.currentDeviceCode;
        
        if (deviceCode == null || !authenticationService.isDeviceRegistered) {
          return const SizedBox.shrink();
        }

        return ActionChip(
          avatar: Icon(
            Icons.devices,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          label: Text(
            'Device: $deviceCode',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
          onPressed: onTap ?? () => _showDeviceCodeDialog(context, deviceCode),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        );
      },
    );
  }

  void _showDeviceCodeDialog(BuildContext context, String deviceCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.devices),
            SizedBox(width: 8),
            Text('Device Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your device is registered with code:'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Text(
                deviceCode,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This code identifies your device on the learning hub network.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: deviceCode));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Device code copied to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy Code'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}