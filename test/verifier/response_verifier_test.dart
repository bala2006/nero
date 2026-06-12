import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/verifier/verifier.dart';

void main() {
  const verifier = ResponseVerifier();

  test('empty responses are blocked', () {
    final report = verifier.verify(
      const ResponseVerificationRequest(response: '   '),
    );

    expect(report.isAccepted, isFalse);
    expect(report.blockingIssues.single.code, 'response.empty');
  });

  test('artifact promises without delivery are blocked', () {
    final report = verifier.verify(
      const ResponseVerificationRequest(
        response: "I'll create the document for you.",
        userPrompt: 'Generate a DOCX about your tools',
        expectsArtifact: true,
      ),
    );

    expect(report.isAccepted, isFalse);
    expect(
      report.blockingIssues.map((issue) => issue.code),
      contains('response.promise_only_artifact_reply'),
    );
  });

  test('tool marker leakage is blocked', () {
    final report = verifier.verify(
      const ResponseVerificationRequest(
        response:
            'Here is the result <tool_call>generate_docx</tool_call><arg_key>title</arg_key>',
      ),
    );

    expect(report.isAccepted, isFalse);
    expect(
      report.blockingIssues.map((issue) => issue.code),
      contains('response.tool_marker_leak'),
    );
  });

  test('internal error leakage is blocked', () {
    final report = verifier.verify(
      const ResponseVerificationRequest(
        response: '[Cloud request failed: Bad state: The response is empty.]',
        userPrompt: 'hello',
      ),
    );

    expect(report.isAccepted, isFalse);
    expect(
      report.blockingIssues.map((issue) => issue.code),
      contains('response.internal_error_leak'),
    );
  });

  test('internal error wording is allowed when user is explicitly debugging', () {
    final report = verifier.verify(
      const ResponseVerificationRequest(
        response: 'SocketException: Connection reset by peer (errno = 104)',
        userPrompt: 'debug this error from my logs',
      ),
    );

    expect(report.isAccepted, isTrue);
  });

  test('completed artifact responses can pass without promise language', () {
    final report = verifier.verify(
      const ResponseVerificationRequest(
        response: 'I created the document and attached it above.',
        userPrompt: 'Generate a DOCX about your tools',
        expectsArtifact: true,
      ),
    );

    expect(report.isAccepted, isTrue);
    expect(report.issues, isEmpty);
  });
}
