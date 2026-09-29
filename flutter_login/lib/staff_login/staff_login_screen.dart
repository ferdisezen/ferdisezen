import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_colors.dart';

/// PIN doğrulama sonucu. `true` dönerse giriş başarılı sayılır.
typedef PinSubmitCallback = Future<bool> Function(String pin);

/// Karttaki bilgi kutusunda gösterilecek mesaj.
class LoginNotice {
  const LoginNotice({required this.title, required this.message, this.icon = Icons.logout_rounded});

  final String title;
  final String message;
  final IconData icon;

  static const loggedOut = LoginNotice(
    title: 'Oturum kapatıldı',
    message: 'Sıradaki personel PIN kodunu girebilir.',
  );
}

/// VelarMenu POS personel PIN giriş ekranı.
class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({
    super.key,
    required this.onSubmit,
    this.businessName = 'Müdavim',
    this.registerName = 'Ana Kasa',
    this.terminalId = 'POS-01',
    this.appVersion = 'v1.0.0',
    this.isConnected = true,
    this.connectionLabel = 'Edge sunucusuna bağlı',
    this.lastSyncLabel = 'Az önce',
    this.supportPhone,
    this.pinLength = 4,
    this.initialNotice = LoginNotice.loggedOut,
    this.onHelp,
    this.onSettings,
  });

  final PinSubmitCallback onSubmit;
  final String businessName;
  final String registerName;
  final String terminalId;
  final String appVersion;
  final bool isConnected;
  final String connectionLabel;
  final String lastSyncLabel;
  final String? supportPhone;
  final int pinLength;
  final LoginNotice? initialNotice;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> with SingleTickerProviderStateMixin {
  static const _errorNotice = LoginNotice(
    title: 'Hatalı PIN',
    message: 'Lütfen PIN kodunuzu kontrol edip tekrar deneyin.',
    icon: Icons.error_outline_rounded,
  );

  final _focusNode = FocusNode(debugLabel: 'pin-input');
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  String _pin = '';
  bool _hasError = false;
  bool _busy = false;
  String? _flashKey;
  Timer? _flashTimer;
  late LoginNotice? _notice = widget.initialNotice;

  bool get _isComplete => _pin.length == widget.pinLength;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _shake.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _press(String key) {
    if (_busy) return;
    setState(() {
      if (_hasError) {
        _hasError = false;
        _notice = widget.initialNotice;
      }
      switch (key) {
        case 'clear':
          _pin = '';
        case 'back':
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        default:
          if (_pin.length < widget.pinLength) _pin += key;
      }
    });
  }

  Future<void> _submit() async {
    if (!_isComplete || _busy) return;
    setState(() => _busy = true);
    bool ok;
    try {
      ok = await widget.onSubmit(_pin);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      if (!ok) {
        _hasError = true;
        _notice = _errorNotice;
      }
    });
    if (!ok) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final logical = event.logicalKey;
    String? key;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      key = char;
    } else if (logical == LogicalKeyboardKey.backspace) {
      key = 'back';
    } else if (logical == LogicalKeyboardKey.escape || logical == LogicalKeyboardKey.delete) {
      key = 'clear';
    } else if (logical == LogicalKeyboardKey.enter || logical == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == null) return KeyEventResult.ignored;
    _press(key);
    _flashTimer?.cancel();
    setState(() => _flashKey = key);
    _flashTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _flashKey = null);
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final brand = _BrandPanel(
      businessName: widget.businessName,
      registerName: widget.registerName,
      terminalId: widget.terminalId,
      appVersion: widget.appVersion,
      isConnected: widget.isConnected,
      connectionLabel: widget.connectionLabel,
      lastSyncLabel: widget.lastSyncLabel,
    );
    final card = _PinCard(
      pin: _pin,
      pinLength: widget.pinLength,
      hasError: _hasError,
      busy: _busy,
      notice: _notice,
      shake: _shake,
      flashKey: _flashKey,
      onKey: _press,
      onSubmit: _submit,
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        // Ekrana tıklanınca klavye odağı geri gelsin.
        behavior: HitTestBehavior.translucent,
        onTap: _focusNode.requestFocus,
        child: Scaffold(
          backgroundColor: LoginColors.surface,
          body: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 900;
              final workArea = _WorkArea(
                card: card,
                compact: compact,
                supportPhone: widget.supportPhone,
                onHelp: widget.onHelp,
                onSettings: widget.onSettings,
              );
              if (compact) {
                return SingleChildScrollView(
                  child: Column(children: [brand, workArea]),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: math.max(440, c.maxWidth * 0.42), child: brand),
                  Expanded(child: workArea),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sol marka paneli
// ---------------------------------------------------------------------------

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({
    required this.businessName,
    required this.registerName,
    required this.terminalId,
    required this.appVersion,
    required this.isConnected,
    required this.connectionLabel,
    required this.lastSyncLabel,
  });

  final String businessName;
  final String registerName;
  final String terminalId;
  final String appVersion;
  final bool isConnected;
  final String connectionLabel;
  final String lastSyncLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = !c.hasBoundedHeight;
      final pad = compact ? const EdgeInsets.fromLTRB(20, 24, 20, 24) : const EdgeInsets.fromLTRB(48, 40, 48, 36);

      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const _BrandMark(),
          if (compact) const SizedBox(height: 28) else const Spacer(),
          const _EyebrowText('VARDİYA TERMİNALİ'),
          const SizedBox(height: 12),
          _Clock(compact: compact),
          SizedBox(height: compact ? 24 : 40),
          _InfoGrid(items: [
            _InfoItem('İşletme', businessName, Icons.storefront_outlined),
            _InfoItem('Kasa', registerName, Icons.point_of_sale_outlined),
            _InfoItem('Terminal', terminalId, Icons.desktop_windows_outlined),
            _InfoItem('Son senkron', lastSyncLabel, Icons.sync_rounded),
          ]),
          if (compact) const SizedBox(height: 24) else const Spacer(),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ConnectionBadge(connected: isConnected, label: connectionLabel),
                ),
              ),
              const SizedBox(width: 12),
              Text(appVersion, style: const TextStyle(color: LoginColors.panelDim, fontSize: 12)),
            ],
          ),
        ],
      );

      return DecoratedBox(
        decoration: const BoxDecoration(color: LoginColors.panel),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _PanelBackdropPainter())),
            Padding(padding: pad, child: content),
          ],
        ),
      );
    });
  }
}

/// Hafif ızgara ve köşe ışımaları.
class _PanelBackdropPainter extends CustomPainter {
  const _PanelBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1.1, -1.1),
          radius: 1.3,
          colors: [LoginColors.accent.withValues(alpha: 0.28), LoginColors.accent.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(1.2, 1.2),
          radius: 1.0,
          colors: [const Color(0xFFD9A441).withValues(alpha: 0.10), const Color(0x00D9A441)],
        ).createShader(rect),
    );

    const step = 44.0;
    final fade = size.height * 0.7;
    for (double y = 0; y < fade; y += step) {
      final a = 0.06 * (1 - y / fade);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = Colors.white.withValues(alpha: a));
    }
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, fade),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(x, 0, 1, fade)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LoginColors.accentGlow, LoginColors.accentStrong],
            ),
            boxShadow: [
              BoxShadow(color: LoginColors.accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'V',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1),
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VelarMenu',
                style: TextStyle(
                  color: LoginColors.panelText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Restoran Yönetim Sistemi',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: LoginColors.panelMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EyebrowText extends StatelessWidget {
  const _EyebrowText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: LoginColors.accentGlow,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _Clock extends StatefulWidget {
  const _Clock({required this.compact});

  final bool compact;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  static const _days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (now.minute != _now.minute || now.day != _now.day) setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${two(_now.hour)}:${two(_now.minute)}',
          style: TextStyle(
            color: LoginColors.panelText,
            fontSize: widget.compact ? 52 : 84,
            fontWeight: FontWeight.w600,
            letterSpacing: widget.compact ? -2 : -3.5,
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_now.day} ${_months[_now.month - 1]} ${_now.year}, ${_days[_now.weekday - 1]}',
          style: const TextStyle(color: LoginColors.panelMuted, fontSize: 16),
        ),
      ],
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    const divider = BorderSide(color: LoginColors.panelLine);
    Widget cell(_InfoItem item, {bool right = false, bool bottom = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            border: Border(
              right: right ? divider : BorderSide.none,
              bottom: bottom ? divider : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, size: 18, color: LoginColors.panelMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label.toUpperCase(),
                      style: const TextStyle(
                        color: LoginColors.panelDim,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LoginColors.panelText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        decoration: BoxDecoration(
          color: LoginColors.panelRaised.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LoginColors.panelLine),
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(children: [cell(items[0], right: true, bottom: true), cell(items[1], bottom: true)]),
            ),
            IntrinsicHeight(
              child: Row(children: [cell(items[2], right: true), cell(items[3])]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.connected, required this.label});

  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = connected ? LoginColors.success : LoginColors.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 3)],
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color.lerp(color, Colors.white, 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sağ çalışma alanı
// ---------------------------------------------------------------------------

class _WorkArea extends StatelessWidget {
  const _WorkArea({
    required this.card,
    required this.compact,
    required this.supportPhone,
    required this.onHelp,
    required this.onSettings,
  });

  final Widget card;
  final bool compact;
  final String? supportPhone;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? 16.0 : 32.0;
    final topBar = Padding(
      padding: EdgeInsets.fromLTRB(hPad, compact ? 12 : 22, hPad, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _TopBarButton(icon: Icons.help_outline_rounded, label: 'Yardım', onPressed: onHelp),
          const SizedBox(width: 4),
          _TopBarButton(icon: Icons.settings_outlined, label: 'Ayarlar', onPressed: onSettings),
        ],
      ),
    );
    final footer = Padding(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, compact ? 16 : 20),
      child: Row(
        children: [
          const Text('© VelarMenu', style: TextStyle(color: LoginColors.textDim, fontSize: 12)),
          const Spacer(),
          if (supportPhone != null)
            Text('Destek: $supportPhone', style: const TextStyle(color: LoginColors.textDim, fontSize: 12)),
        ],
      ),
    );
    final cardArea = Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 404), child: card)),
    );

    if (compact) return Column(children: [topBar, cardArea, footer]);
    return Column(
      children: [
        topBar,
        Expanded(child: SingleChildScrollView(clipBehavior: Clip.none, child: cardArea)),
        footer,
      ],
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: LoginColors.textMuted,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.pin,
    required this.pinLength,
    required this.hasError,
    required this.busy,
    required this.notice,
    required this.shake,
    required this.flashKey,
    required this.onKey,
    required this.onSubmit,
  });

  final String pin;
  final int pinLength;
  final bool hasError;
  final bool busy;
  final LoginNotice? notice;
  final Animation<double> shake;
  final String? flashKey;
  final ValueChanged<String> onKey;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 26),
      decoration: BoxDecoration(
        color: LoginColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LoginColors.cardLine),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1B2420), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x1F1B2420), blurRadius: 48, spreadRadius: -12, offset: Offset(0, 18)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: LoginColors.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: LoginColors.accent, size: 24),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Personel Girişi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LoginColors.text,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Devam etmek için $pinLength haneli PIN kodunuzu girin',
            textAlign: TextAlign.center,
            style: const TextStyle(color: LoginColors.textMuted, fontSize: 14),
          ),
          if (notice != null) ...[
            const SizedBox(height: 20),
            _NoticeBox(notice: notice!, isError: hasError),
          ],
          const SizedBox(height: 26),
          AnimatedBuilder(
            animation: shake,
            builder: (context, child) {
              final t = shake.value;
              final dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: _PinDots(length: pinLength, filled: pin.length, error: hasError),
          ),
          const SizedBox(height: 24),
          _Keypad(onKey: onKey, flashKey: flashKey, enabled: !busy),
          const SizedBox(height: 18),
          _SubmitButton(enabled: pin.length == pinLength && !busy, busy: busy, onPressed: onSubmit),
          const SizedBox(height: 16),
          const _ShortcutHint(),
        ],
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.notice, required this.isError});

  final LoginNotice notice;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final fg = isError ? LoginColors.danger : LoginColors.textMuted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isError ? LoginColors.dangerSoft : LoginColors.key,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? LoginColors.dangerLine : LoginColors.cardLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(notice.icon, size: 18, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: TextStyle(
                    color: isError ? LoginColors.danger : LoginColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(notice.message, style: TextStyle(color: fg, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.filled, required this.error});

  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? (error ? LoginColors.danger : LoginColors.text) : Colors.transparent,
                border: Border.all(
                  width: 2,
                  color: error
                      ? LoginColors.danger
                      : i < filled
                          ? LoginColors.text
                          : const Color(0xFFCFCCC4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.flashKey, required this.enabled});

  final ValueChanged<String> onKey;
  final String? flashKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget key(String k, {Widget? child, bool muted = false, String? semantics}) {
      return Expanded(
        child: _PinKey(
          flashing: flashKey == k,
          muted: muted,
          semanticsLabel: semantics ?? k,
          onTap: enabled ? () => onKey(k) : null,
          child: child ??
              Text(
                k,
                style: const TextStyle(
                  color: LoginColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
        ),
      );
    }

    Widget row(List<Widget> keys) => Row(
          children: [keys[0], const SizedBox(width: 10), keys[1], const SizedBox(width: 10), keys[2]],
        );

    return Column(
      children: [
        row([key('1'), key('2'), key('3')]),
        const SizedBox(height: 10),
        row([key('4'), key('5'), key('6')]),
        const SizedBox(height: 10),
        row([key('7'), key('8'), key('9')]),
        const SizedBox(height: 10),
        row([
          key(
            'clear',
            muted: true,
            semantics: 'Temizle',
            child: const Text(
              'TEMİZLE',
              style: TextStyle(
                color: LoginColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          key('0'),
          key(
            'back',
            muted: true,
            semantics: 'Sil',
            child: const Icon(Icons.backspace_outlined, size: 22, color: LoginColors.textMuted),
          ),
        ]),
      ],
    );
  }
}

class _PinKey extends StatefulWidget {
  const _PinKey({
    required this.child,
    required this.onTap,
    required this.flashing,
    required this.muted,
    required this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool flashing;
  final bool muted;
  final String semanticsLabel;

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _down || widget.flashing;
    final Color bg;
    if (pressed) {
      bg = LoginColors.keyPressed;
    } else if (_hover) {
      bg = LoginColors.keyHover;
    } else {
      bg = widget.muted ? Colors.transparent : LoginColors.key;
    }
    final border = widget.muted && !_hover && !pressed ? Colors.transparent : LoginColors.cardLine;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: MouseRegion(
        cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) {
            setState(() => _down = false);
            widget.onTap?.call();
          },
          child: AnimatedScale(
            scale: pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 70),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.enabled, required this.busy, required this.onPressed});

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: LoginColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: LoginColors.keyHover,
          disabledForegroundColor: LoginColors.textDim,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return busy ? LoginColors.accent : LoginColors.keyHover;
            }
            if (states.contains(WidgetState.hovered)) return LoginColors.accentStrong;
            return LoginColors.accent;
          }),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Giriş Yap'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: LoginColors.textDim, fontSize: 12);
    Widget kbd(String s) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: LoginColors.key,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: LoginColors.cardLine),
          ),
          child: Text(s, style: const TextStyle(color: LoginColors.textMuted, fontSize: 11)),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        const Text('Klavye ile de girebilirsiniz ·', style: style),
        kbd('Enter'),
        const Text('giriş ·', style: style),
        kbd('Esc'),
        const Text('temizle', style: style),
      ],
    );
  }
}
