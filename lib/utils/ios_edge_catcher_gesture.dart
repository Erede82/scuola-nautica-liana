/// MOBILE.FINAL: riconoscimento gesture edge → back (puro, testabile).
bool iosEdgeCatcherShouldConfirmBack({
  required double deltaX,
  required double deltaY,
  double confirmDeltaPx = 72,
  double horizontalBias = 1.4,
}) {
  if (deltaX < confirmDeltaPx) return false;
  if (deltaX <= 0) return false;
  if (deltaX < deltaY.abs() * horizontalBias) return false;
  return true;
}
