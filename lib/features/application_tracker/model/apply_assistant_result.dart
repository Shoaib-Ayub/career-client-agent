class ApplyAssistantResult {
  const ApplyAssistantResult({
    required this.cvChanges,
    required this.coverLetterDraft,
    required this.outreachMessageDraft,
    required this.requiredDocuments,
  });

  final List<String> cvChanges;
  final String coverLetterDraft;
  final String outreachMessageDraft;
  final List<String> requiredDocuments;
}
