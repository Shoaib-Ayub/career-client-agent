import 'dart:async';

abstract final class AsyncGuard {
  static Future<void> wait(Duration duration) => Future<void>.delayed(duration);
}
