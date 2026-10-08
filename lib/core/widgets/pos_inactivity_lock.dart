import 'package:flutter/material.dart';

/// PosInactivityLockWrapper has been disabled/removed per project requirements.
/// This widget acts as a clean pass-through with no timers or standby logic.
class PosInactivityLockWrapper extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return child;
  }
}