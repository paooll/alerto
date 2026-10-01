import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme.dart';

/// Listens to foreground FCM messages and shows an animated in-app banner
/// at the top of the screen (system banners only appear when backgrounded).
class AlertBanner extends StatefulWidget {
  const AlertBanner({super.key, required this.child, this.onTap});

  final Widget child;

  /// Called when the user taps the banner (e.g. navigate to the instrument).
  final void Function(String? symbol)? onTap;

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  ForegroundNotification? _current;
  StreamSubscription<ForegroundNotification>? _sub;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(curve);
    _fade = curve;

    _sub = NotificationService.foregroundStream.listen(_show);
  }

  void _show(ForegroundNotification n) {
    _dismissTimer?.cancel();
    setState(() => _current = n);
    _controller.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 4), _hide);
  }

  Future<void> _hide() async {
    await _controller.reverse();
    if (mounted) setState(() => _current = null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Material(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 8,
                      shadowColor: Colors.black54,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          unawaited(_hide());
                          widget.onTap?.call(_current?.payload.symbol);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.notifications_active,
                                    color: AppTheme.gold, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_current!.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    if (_current!.body.isNotEmpty)
                                      Text(_current!.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
