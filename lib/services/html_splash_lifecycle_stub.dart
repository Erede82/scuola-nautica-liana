bool _visibleLogged = false;
bool _removed = false;
bool _themeApplied = false;

void logHtmlSplashVisibleIfPresent() {
  _visibleLogged = true;
}

void applyWelcomeThemeNavy() {
  _themeApplied = true;
}

void removeSplashDom() {
  _removed = true;
}

/// Legacy no-op: la rimozione è orchestrata da [HtmlSplashLifecycle].
void dispatchSplashReadyEvent(String eventName) {}

void resetHtmlSplashLifecycleForTest() {
  _visibleLogged = false;
  _removed = false;
  _themeApplied = false;
}

bool get welcomeVisualReadyDispatchedForTest => false;

bool get stubSplashRemoved => _removed;

bool get stubThemeNavyApplied => _themeApplied;

bool get stubVisibleLogged => _visibleLogged;
