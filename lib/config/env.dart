class Env {
  // Provide your Google Maps/Directions API key here or via --dart-define=GOOGLE_MAPS_API_KEY=...
  static const String googleApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
}
