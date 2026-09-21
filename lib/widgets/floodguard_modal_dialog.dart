import 'package:flutter/material.dart';

enum FloodGuardModalVariant {
  destructive,
  warning,
  success,
  info,
}

/// Standardized centered modal dialog matching FloodGuard UI specifications
/// inspired by modern clean alert modals with circular icon badge, clear typography,
/// and side-by-side action buttons.
class FloodGuardModalDialog extends StatelessWidget {
  final String title;
  final String message;
  final Widget? content;
  final FloodGuardModalVariant variant;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDarkMode;
  final bool isLoading;

  const FloodGuardModalDialog({
    super.key,
    required this.title,
    required this.message,
    this.content,
    this.variant = FloodGuardModalVariant.info,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.isDarkMode = false,
    this.isLoading = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    Widget? content,
    FloodGuardModalVariant variant = FloodGuardModalVariant.info,
    String? confirmLabel,
    String? cancelLabel,
    bool isDarkMode = false,
    bool isLoading = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FloodGuardModalDialog(
        title: title,
        message: message,
        content: content,
        variant: variant,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDarkMode: isDarkMode,
        isLoading: isLoading,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final msgColor = isDarkMode ? Colors.white70 : const Color(0xFF475569);

    final config = _resolveVariantConfig();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Circular Badge with Semantic Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: config.badgeBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: config.badgeBorder, width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    config.icon,
                    size: 32,
                    color: config.accentColor,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 10),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: msgColor,
                  height: 1.45,
                ),
              ),

              if (content != null) ...[
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: content!,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Side-by-side or stacked action buttons
              Row(
                children: [
                  if (cancelLabel != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDarkMode ? Colors.white70 : const Color(0xFF475569),
                            side: BorderSide(
                              color: isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isLoading ? null : (onCancel ?? () => Navigator.of(context).pop(false)),
                          child: Text(
                            cancelLabel!,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isLoading ? null : (onConfirm ?? () => Navigator.of(context).pop(true)),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                confirmLabel ?? 'OK',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ModalVariantConfig _resolveVariantConfig() {
    switch (variant) {
      case FloodGuardModalVariant.destructive:
        return _ModalVariantConfig(
          icon: Icons.delete_outline_rounded,
          accentColor: const Color(0xFFDC2626),
          badgeBg: const Color(0xFFFEF2F2),
          badgeBorder: const Color(0xFFFECACA),
        );
      case FloodGuardModalVariant.warning:
        return _ModalVariantConfig(
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFEA580C),
          badgeBg: const Color(0xFFFFF7ED),
          badgeBorder: const Color(0xFFFED7AA),
        );
      case FloodGuardModalVariant.success:
        return _ModalVariantConfig(
          icon: Icons.check_circle_outline_rounded,
          accentColor: const Color(0xFF16A34A),
          badgeBg: const Color(0xFFF0FDF4),
          badgeBorder: const Color(0xFFBBF7D0),
        );
      case FloodGuardModalVariant.info:
        return _ModalVariantConfig(
          icon: Icons.shield_outlined,
          accentColor: const Color(0xFF0284C7),
          badgeBg: const Color(0xFFF0F9FF),
          badgeBorder: const Color(0xFFBAE6FD),
        );
    }
  }
}

class _ModalVariantConfig {
  final IconData icon;
  final Color accentColor;
  final Color badgeBg;
  final Color badgeBorder;

  _ModalVariantConfig({
    required this.icon,
    required this.accentColor,
    required this.badgeBg,
    required this.badgeBorder,
  });
}
