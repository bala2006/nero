class ArtifactReference {
  const ArtifactReference({
    required this.artifactId,
    required this.title,
    required this.kind,
    this.localPath,
    this.sourceUri,
  });

  final String artifactId;
  final String title;
  final String kind;
  final String? localPath;
  final String? sourceUri;
}
