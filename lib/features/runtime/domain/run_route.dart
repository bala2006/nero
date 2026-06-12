enum RunRoute {
  direct,
  researchFirst,
  artifactFirst,
  workflowFirst,
  skillFirst,
}

String runRouteToJson(RunRoute route) {
  return switch (route) {
    RunRoute.direct => 'direct',
    RunRoute.researchFirst => 'researchFirst',
    RunRoute.artifactFirst => 'artifactFirst',
    RunRoute.workflowFirst => 'workflowFirst',
    RunRoute.skillFirst => 'skillFirst',
  };
}

RunRoute runRouteFromJson(String? value) {
  return switch (value) {
    'researchFirst' => RunRoute.researchFirst,
    'artifactFirst' => RunRoute.artifactFirst,
    'workflowFirst' => RunRoute.workflowFirst,
    'skillFirst' => RunRoute.skillFirst,
    _ => RunRoute.direct,
  };
}

enum RunQualityMode { fast, balanced, highAccuracy, artifactCritical }

String runQualityModeToJson(RunQualityMode mode) {
  return switch (mode) {
    RunQualityMode.fast => 'fast',
    RunQualityMode.balanced => 'balanced',
    RunQualityMode.highAccuracy => 'highAccuracy',
    RunQualityMode.artifactCritical => 'artifactCritical',
  };
}

RunQualityMode runQualityModeFromJson(String? value) {
  return switch (value) {
    'fast' => RunQualityMode.fast,
    'highAccuracy' => RunQualityMode.highAccuracy,
    'artifactCritical' => RunQualityMode.artifactCritical,
    _ => RunQualityMode.balanced,
  };
}

class RunRouteSelection {
  const RunRouteSelection({
    required this.route,
    required this.qualityMode,
    required this.reason,
    this.metadata = const <String, Object?>{},
  });

  final RunRoute route;
  final RunQualityMode qualityMode;
  final String reason;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'route': runRouteToJson(route),
    'qualityMode': runQualityModeToJson(qualityMode),
    'reason': reason,
    'metadata': metadata,
  };
}
