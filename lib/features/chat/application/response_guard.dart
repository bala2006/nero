class ValidatedResponse {
  const ValidatedResponse({
    required this.content,
    required this.didMutate,
  });

  final String content;
  final bool didMutate;
}

class ResponseGuard {
  const ResponseGuard();

  ValidatedResponse validate(String raw) {
    var content = raw.trimRight();
    var didMutate = false;

    final normalized = content
        .replaceAll('**Code**\n', '')
        .replaceAll('**Diagram**\n', '')
        .replaceAll('Code Solution:\n', '')
        .replaceAll('Visual Diagram:\n', '');
    if (normalized != content) {
      content = normalized;
      didMutate = true;
    }

    final codeFenceCount = RegExp(r'```').allMatches(content).length;
    if (codeFenceCount.isOdd) {
      content = '$content\n```';
      didMutate = true;
    }

    final opens = RegExp(r'\[\[NERO_BLOCK:[^\]]+\]\]').allMatches(content).length;
    final closes = RegExp(r'\[\[/NERO_BLOCK\]\]').allMatches(content).length;
    if (opens > closes) {
      content = '$content\n[[/NERO_BLOCK]]';
      didMutate = true;
    }

    return ValidatedResponse(
      content: content,
      didMutate: didMutate,
    );
  }
}
