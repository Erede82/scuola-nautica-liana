import 'dart:js_interop';

import '../services/startup_diagnostics.dart';
import 'ios_edge_catcher_gesture.dart';

const String _catcherId = 'liana-ios-edge-catcher';

bool _installed = false;
int _installCount = 0;
double _confirmDeltaPx = 72;
String _backEventName = 'liana-internal-login-back';
void Function()? _onBack;

JSFunction? _touchStart;
JSFunction? _touchMove;
JSFunction? _touchEnd;
JSFunction? _touchCancel;
_HtmlEl? _catcherEl;

double? _startX;
double? _startY;
bool _fired = false;

void installIosEdgeCatcher({
  required double edgeZonePx,
  required double confirmDeltaPx,
  required String backEventName,
  required void Function() onBack,
}) {
  if (_installed) return;
  _installed = true;
  _installCount += 1;
  _confirmDeltaPx = confirmDeltaPx;
  _backEventName = backEventName;
  _onBack = onBack;
  _startX = null;
  _startY = null;
  _fired = false;

  final el = _document.createElement('div');
  el.id = _catcherId;
  el.style
    ..setProperty('position', 'fixed')
    ..setProperty('left', '0')
    ..setProperty('top', '0')
    ..setProperty('bottom', '0')
    ..setProperty('width', '${edgeZonePx}px')
    ..setProperty('z-index', '2147483647')
    ..setProperty('background', 'transparent')
    ..setProperty('touch-action', 'none')
    ..setProperty('-webkit-user-select', 'none')
    ..setProperty('user-select', 'none');

  _touchStart = _onTouchStart.toJS;
  _touchMove = _onTouchMove.toJS;
  _touchEnd = _onTouchEnd.toJS;
  _touchCancel = _onTouchCancel.toJS;

  final opts = _ListenerOpts(capture: true, passive: false);
  el.addEventListener('touchstart', _touchStart!, opts);
  el.addEventListener('touchmove', _touchMove!, opts);
  el.addEventListener('touchend', _touchEnd!, opts);
  el.addEventListener('touchcancel', _touchCancel!, opts);

  _document.body.appendChild(el);
  _catcherEl = el;
  StartupDiagnostics.log('IOS_EDGE_CATCHER install');
}

void uninstallIosEdgeCatcher() {
  if (!_installed) return;

  final el = _catcherEl;
  if (el != null) {
    final opts = _ListenerOpts(capture: true);
    if (_touchStart != null) {
      el.removeEventListener('touchstart', _touchStart!, opts);
    }
    if (_touchMove != null) {
      el.removeEventListener('touchmove', _touchMove!, opts);
    }
    if (_touchEnd != null) {
      el.removeEventListener('touchend', _touchEnd!, opts);
    }
    if (_touchCancel != null) {
      el.removeEventListener('touchcancel', _touchCancel!, opts);
    }
    el.remove();
  }

  _catcherEl = null;
  _touchStart = null;
  _touchMove = null;
  _touchEnd = null;
  _touchCancel = null;
  _onBack = null;
  _startX = null;
  _startY = null;
  _fired = false;
  _installed = false;
  StartupDiagnostics.log('IOS_EDGE_CATCHER remove');
}

bool get isIosEdgeCatcherInstalled => _installed;

int get iosEdgeCatcherInstallCount => _installCount;

void _onTouchStart(JSAny event) {
  final te = event as _TouchEvent;
  te.preventDefault();
  te.stopPropagation();
  if (te.touches.length != 1) return;
  final touch = te.touches.item(0);
  if (touch == null) return;
  _startX = touch.clientX;
  _startY = touch.clientY;
  _fired = false;
}

void _onTouchMove(JSAny event) {
  final te = event as _TouchEvent;
  te.preventDefault();
  te.stopPropagation();
  if (_fired || _startX == null || _startY == null) return;
  if (te.touches.length != 1) return;
  final touch = te.touches.item(0);
  if (touch == null) return;
  final dx = touch.clientX - _startX!;
  final dy = touch.clientY - _startY!;
  if (!iosEdgeCatcherShouldConfirmBack(
    deltaX: dx,
    deltaY: dy,
    confirmDeltaPx: _confirmDeltaPx,
  )) {
    return;
  }
  _fired = true;
  _dispatchBack();
}

void _onTouchEnd(JSAny event) {
  final te = event as _TouchEvent;
  te.preventDefault();
  te.stopPropagation();
  _startX = null;
  _startY = null;
}

void _onTouchCancel(JSAny event) {
  final te = event as _TouchEvent;
  te.preventDefault();
  te.stopPropagation();
  _startX = null;
  _startY = null;
  _fired = false;
}

void _dispatchBack() {
  StartupDiagnostics.log('IOS_EDGE_CATCHER back');
  _window.dispatchEvent(_CustomEvent(_backEventName));
  final cb = _onBack;
  if (cb != null) cb();
}

@JS('document')
external _Doc get _document;

@JS('window')
external _Win get _window;

extension type _Doc(JSObject _) implements JSObject {
  external _HtmlEl createElement(String tag);
  external _Body get body;
}

extension type _Body(JSObject _) implements JSObject {
  external void appendChild(JSObject child);
}

extension type _HtmlEl(JSObject _) implements JSObject {
  external set id(String value);
  external _CssStyle get style;
  external void addEventListener(
    String type,
    JSFunction listener,
    JSAny options,
  );
  external void removeEventListener(
    String type,
    JSFunction listener,
    JSAny options,
  );
  external void remove();
}

extension type _CssStyle(JSObject _) implements JSObject {
  external void setProperty(String name, String value);
}

extension type _Win(JSObject _) implements JSObject {
  external void dispatchEvent(JSObject event);
}

@JS('CustomEvent')
extension type _CustomEvent._(JSObject _) implements JSObject {
  external factory _CustomEvent(String type);
}

@JS()
@anonymous
extension type _ListenerOpts._(JSObject _) implements JSObject {
  external factory _ListenerOpts({
    bool? capture,
    bool? passive,
  });
}

extension type _TouchEvent(JSObject _) implements JSObject {
  external _TouchList get touches;
  external void preventDefault();
  external void stopPropagation();
}

extension type _TouchList(JSObject _) implements JSObject {
  external int get length;
  external _Touch? item(int index);
}

extension type _Touch(JSObject _) implements JSObject {
  external double get clientX;
  external double get clientY;
}
