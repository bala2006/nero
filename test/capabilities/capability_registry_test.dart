import 'package:flutter_test/flutter_test.dart';

import 'package:nero/features/capabilities/capabilities.dart';

void main() {
  test('registry exposes the current runtime tool surface', () {
    expect(CapabilityRegistry.all, hasLength(10));
    expect(
      CapabilityRegistry.modelToolNames(),
      containsAllInOrder(<String>[
        'search_web',
        'read_url',
        'extract_article',
        'generate_docx',
        'generate_xlsx',
        'generate_report_pdf',
        'create_text_file',
        'edit_text_file',
        'write_project_files',
        'package_zip',
      ]),
    );
  });

  test('search web is read-only and model-visible', () {
    final capability = CapabilityRegistry.byToolName('search_web');
    expect(capability, isNotNull);
    expect(capability, same(CapabilityRegistry.searchWeb));
    expect(capability!.key, 'web.search');
    expect(capability.category, CapabilityCategory.read);
    expect(capability.sideEffectPolicy, CapabilitySideEffectPolicy.readOnly);
    expect(capability.singleUse, isFalse);
    expect(capability.reliabilityClass, CapabilityReliabilityClass.medium);
    expect(capability.modelExposure, CapabilityModelExposure.visible);
    expect(capability.toolDescriptor!.parameters['required'], ['query']);
  });

  test('output tools are single-use build capabilities', () {
    final docx = CapabilityRegistry.byToolName('generate_docx');
    final xlsx = CapabilityRegistry.byToolName('generate_xlsx');
    final pdf = CapabilityRegistry.byToolName('generate_report_pdf');

    for (final capability in <CapabilityDefinition?>[docx, xlsx, pdf]) {
      expect(capability, isNotNull);
      expect(capability!.category, CapabilityCategory.build);
      expect(
        capability.sideEffectPolicy,
        CapabilitySideEffectPolicy.localArtifactWrite,
      );
      expect(capability.singleUse, isTrue);
      expect(capability.reliabilityClass, CapabilityReliabilityClass.high);
      expect(capability.modelExposure, CapabilityModelExposure.preferred);
      expect(capability.exposedToModel, isTrue);
    }
  });

  test('tool descriptors preserve the runtime-facing payload shape', () {
    final docx = CapabilityRegistry.byToolName('generate_docx')!;
    final descriptor = docx.toolDescriptor!;

    expect(descriptor.name, 'generate_docx');
    expect(descriptor.description, contains('Word document'));
    expect(descriptor.description, contains('planning text'));
    expect(descriptor.parameters['type'], 'object');
    expect(descriptor.parameters['required'], ['title', 'markdown_content']);
    expect(descriptor.examples, isNotEmpty);
    expect(descriptor.toMap()['examples'], isA<List>());
    expect(
      CapabilityRegistry.modelToolDescriptors().map((tool) => tool.name),
      containsAllInOrder(<String>[
        'search_web',
        'read_url',
        'extract_article',
        'generate_docx',
        'generate_xlsx',
        'generate_report_pdf',
      ]),
    );
    expect(
      CapabilityRegistry.modelToolPayloads().map((tool) => tool['name']),
      containsAllInOrder(<String>[
        'search_web',
        'read_url',
        'extract_article',
        'generate_docx',
        'generate_xlsx',
        'generate_report_pdf',
      ]),
    );
  });

  test('model-visible tool payloads include selection examples', () {
    final payloads = CapabilityRegistry.modelToolPayloads();
    final searchPayload = payloads.firstWhere(
      (payload) => payload['name'] == 'search_web',
    );
    final docxPayload = payloads.firstWhere(
      (payload) => payload['name'] == 'generate_docx',
    );

    expect(searchPayload['examples'], isA<List>());
    expect(
      (searchPayload['examples'] as List).join(' '),
      contains('Latest AI news today'),
    );
    expect(docxPayload['examples'], isA<List>());
    expect(
      (docxPayload['examples'] as List).join(' '),
      contains('Create a DOCX proposal'),
    );
  });

  test('category filters are stable', () {
    expect(
      CapabilityRegistry.capabilitiesInCategory(
        CapabilityCategory.read,
      ).map((capability) => capability.toolName),
      containsAllInOrder(<String>['search_web', 'read_url', 'extract_article']),
    );
    expect(
      CapabilityRegistry.singleUseCapabilities().map(
        (capability) => capability.toolName,
      ),
      containsAllInOrder(<String>[
        'generate_docx',
        'generate_xlsx',
        'generate_report_pdf',
      ]),
    );
  });
}
