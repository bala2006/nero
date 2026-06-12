import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/runtime/application/request_classifier.dart';

void main() {
  const classifier = RequestClassifier();

  test('artifact capability question stays direct and side-effect free', () {
    final classification = classifier.classify('Can you create doc and pdf?');

    expect(classification.requestKind.name, 'directAnswer');
    expect(classification.isArtifactCapabilityQuestion, isTrue);
    expect(classification.requiresSideEffect, isFalse);
    expect(classification.artifactKind.name, 'none');
    expect(classification.fallbackPolicy.name, 'repairDirectAnswer');
  });

  test('simple direct question stays non-research and side-effect free', () {
    final classification = classifier.classify('What is recursion?');

    expect(classification.requestKind.name, 'directAnswer');
    expect(classification.requiresExternalContext, isFalse);
    expect(classification.requiresSideEffect, isFalse);
  });

  test('hybrid research artifact request stays hybrid with strict artifact policy', () {
    final classification = classifier.classify(
      'Research current Flutter testing guidance and create a docx report',
    );

    expect(classification.requestKind.name, 'hybrid');
    expect(classification.requiresExternalContext, isTrue);
    expect(classification.requiresSideEffect, isTrue);
    expect(classification.artifactKind.name, 'docx');
    expect(classification.fallbackPolicy.name, 'artifactStrictError');
  });
}
