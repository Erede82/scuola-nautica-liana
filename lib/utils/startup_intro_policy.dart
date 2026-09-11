/// STARTUP.DECISIVE: policy rimozione intro (puro, testabile).
bool shouldRemoveStartupIntro({
  required bool welcomeOrSurfaceReady,
  required bool minimumIntroElapsed,
}) {
  return welcomeOrSurfaceReady && minimumIntroElapsed;
}

/// Durata minima intro Capri (ms).
const int startupIntroMinMs = 1500;
