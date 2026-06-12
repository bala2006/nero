enum ToolType {
  generateDocx,
  generateXlsx,
  generateReportPdf,
  materializeProjectTree,
  writeProjectFiles,
  packageZip,
  validateProject,
  openArtifact,
  shareArtifact,
  createTextFile,
  editTextFile,
}

extension ToolTypeX on ToolType {
  String get name => switch (this) {
        ToolType.generateDocx => 'generate_docx',
        ToolType.generateXlsx => 'generate_xlsx',
        ToolType.generateReportPdf => 'generate_report_pdf',
        ToolType.materializeProjectTree => 'materialize_project_tree',
        ToolType.writeProjectFiles => 'write_project_files',
        ToolType.packageZip => 'package_zip',
        ToolType.validateProject => 'validate_project',
        ToolType.openArtifact => 'open_artifact',
        ToolType.shareArtifact => 'share_artifact',
        ToolType.createTextFile => 'create_text_file',
        ToolType.editTextFile => 'edit_text_file',
      };

  String get label => switch (this) {
        ToolType.generateDocx => 'Generate DOCX',
        ToolType.generateXlsx => 'Generate XLSX',
        ToolType.generateReportPdf => 'Generate PDF Report',
        ToolType.materializeProjectTree => 'Materialize Project',
        ToolType.writeProjectFiles => 'Write Project Files',
        ToolType.packageZip => 'Package as ZIP',
        ToolType.validateProject => 'Validate Project',
        ToolType.openArtifact => 'Open Artifact',
        ToolType.shareArtifact => 'Share Artifact',
        ToolType.createTextFile => 'Create Text File',
        ToolType.editTextFile => 'Edit Text File',
      };

  static ToolType? fromName(String name) {
    return switch (name) {
      'generate_docx' => ToolType.generateDocx,
      'generate_xlsx' => ToolType.generateXlsx,
      'generate_report_pdf' => ToolType.generateReportPdf,
      'materialize_project_tree' => ToolType.materializeProjectTree,
      'write_project_files' => ToolType.writeProjectFiles,
      'package_zip' => ToolType.packageZip,
      'validate_project' => ToolType.validateProject,
      'open_artifact' => ToolType.openArtifact,
      'share_artifact' => ToolType.shareArtifact,
      'create_text_file' => ToolType.createTextFile,
      'edit_text_file' => ToolType.editTextFile,
      _ => null,
    };
  }
}
