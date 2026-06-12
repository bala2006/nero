import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/verifier/verifier.dart';

void main() {
  const verifier = ToolIntentVerifier();

  test('valid output tool arguments are accepted', () {
    final report = verifier.verify(
      const ToolIntentVerificationRequest(
        toolIntents: <ToolIntent>[
          ToolIntent(
            id: 'call_1',
            name: 'generate_docx',
            arguments: <String, Object?>{
              'title': 'Nero Tools',
              'markdown_content': '# Tools\n\nContent',
            },
          ),
        ],
      ),
    );

    expect(report.isAccepted, isTrue);
    expect(report.acceptedIntents, hasLength(1));
    expect(report.rejectedIntents, isEmpty);
  });

  test('malformed output tool arguments are blocked', () {
    final report = verifier.verify(
      const ToolIntentVerificationRequest(
        toolIntents: <ToolIntent>[
          ToolIntent(
            id: 'call_1',
            name: 'generate_report_pdf',
            arguments: <String, Object?>{'title': 'Tools'},
          ),
        ],
      ),
    );

    expect(report.isAccepted, isFalse);
    expect(
      report.blockingIssues.map((issue) => issue.code),
      contains('tool.intent.missing_required'),
    );
  });

  test('single-use output tools cannot be reused', () {
    final report = verifier.verify(
      const ToolIntentVerificationRequest(
        toolIntents: <ToolIntent>[
          ToolIntent(
            id: 'call_1',
            name: 'generate_docx',
            arguments: <String, Object?>{
              'title': 'Nero Tools',
              'markdown_content': '# Tools',
            },
          ),
          ToolIntent(
            id: 'call_2',
            name: 'generate_docx',
            arguments: <String, Object?>{
              'title': 'Nero Tools Again',
              'markdown_content': '# Tools',
            },
          ),
        ],
        consumedSingleUseToolNames: <String>['generate_docx'],
      ),
    );

    expect(report.isAccepted, isFalse);
    expect(
      report.blockingIssues.map((issue) => issue.code),
      contains('tool.intent.single_use_reuse'),
    );
    expect(report.acceptedIntents, isEmpty);
    expect(report.rejectedIntents, hasLength(2));
  });

  test('unknown tools fail closed', () {
    final report = verifier.verify(
      const ToolIntentVerificationRequest(
        toolIntents: <ToolIntent>[
          ToolIntent(
            id: 'call_1',
            name: 'generate_pptx',
            arguments: <String, Object?>{},
          ),
        ],
      ),
    );

    expect(report.isAccepted, isFalse);
    expect(
      report.blockingIssues.map((issue) => issue.code),
      contains('tool.intent.unknown_tool'),
    );
  });

  test('spreadsheet arguments must match the declared structure', () {
    final report = verifier.verify(
      const ToolIntentVerificationRequest(
        toolIntents: <ToolIntent>[
          ToolIntent(
            id: 'call_1',
            name: 'generate_xlsx',
            arguments: <String, Object?>{
              'title': 'Workbook',
              'sheets': <Object?>[
                <String, Object?>{
                  'name': 'Sheet 1',
                  'rows': <Object?>[
                    <Object?>['A', 'B'],
                    'not-a-row',
                  ],
                },
              ],
            },
          ),
        ],
      ),
    );

    expect(report.isAccepted, isFalse);
    expect(
      report.blockingIssues.map((issue) => issue.code),
      contains('tool.intent.invalid_type'),
    );
  });
}
