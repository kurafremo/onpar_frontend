import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Debug modu kontrolü için eklendi

/// Kasa Otomatik Kilit Mekanizması (POS Inactivity Lock)
class PosInactivityLockWrapper extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final String validPin;

  const PosInactivityLockWrapper({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 10),
    this.validPin = "1234",
  });

  @override
  State<PosInactivityLockWrapper> createState() => _PosInactivityLockWrapperState();
}

class _PosInactivityLockWrapperState extends State<PosInactivityLockWrapper> {
  Timer? _inactivityTimer;
  Timer? _lockoutTimer;
  bool _isLocked = false;
  final _pinController = TextEditingController();

  int _failedAttempts = 0;
  int _lockoutSecondsLeft = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    // Profesyonel Çözüm: Debug (Geliştirme) modunda kilit asla devreye girmez!
    if (!kDebugMode && !_isLocked) {
      _inactivityTimer = Timer(widget.timeout, () {
        if (mounted) setState(() => _isLocked = true);
      });
    }
  }

  void _startLockout(int seconds) {
    setState(() {
      _lockoutSecondsLeft = seconds;
      _errorMessage = 'Çok fazla hatalı deneme! Lütfen bekleyin: $_lockoutSecondsLeft sn';
      _pinController.clear();
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockoutSecondsLeft > 1) {
          _lockoutSecondsLeft--;
          _errorMessage = 'Çok fazla hatalı deneme! Lütfen bekleyin: $_lockoutSecondsLeft sn';
        } else {
          _lockoutSecondsLeft = 0;
          _errorMessage = null;
          _failedAttempts = 0;
          timer.cancel();
        }
      });
    });
  }

  void _verifyPin(String pin) {
    if (_lockoutSecondsLeft > 0) return;

    // Master Key (0000) veya Belirlenen PIN
    if (pin == widget.validPin || pin == "0000") {
      setState(() {
        _isLocked = false;
        _failedAttempts = 0;
        _errorMessage = null;
        _pinController.clear();
      });
      _resetTimer();
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _startLockout(60);
      } else {
        setState(() {
          _errorMessage = 'Hatalı PIN! (Kalan deneme hakkı: ${5 - _failedAttempts})';
          _pinController.clear();
        });
      }
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _lockoutTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTemporarilyBlocked = _lockoutSecondsLeft > 0;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: Stack(
        children: [
          widget.child,
          if (_isLocked)
            Material(
              color: Colors.blueGrey[900]!.withValues(alpha: 0.96),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock, size: 70, color: Colors.white70),
                      const SizedBox(height: 16),
                      const Text(
                        'Kasa Otomatik Kilitlendi',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Devam etmek için 4 haneli PIN kodunuzu girin',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _pinController,
                          enabled: !isTemporarilyBlocked,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 10),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: isTemporarilyBlocked ? Colors.white10 : Colors.black26,
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                          onChanged: (pin) {
                            if (pin.length == 4) {
                              _verifyPin(pin);
                            }
                          },
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red[900]!.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}