/// Lifecycle of a feature, mirrored from docs/FEATURE_MATRIX.md.
///
/// IMPLEMENTED and VERIFIED are deliberately different: a feature only
/// becomes [verified] once automated tests (and, where the roadmap requires
/// it, real-device checks) pass.
enum FeatureStatus {
  planned('PLANNED', 'Not available yet'),
  inProgress('IN PROGRESS', 'In progress'),
  implemented('IMPLEMENTED', 'Implemented, not yet verified'),
  verified('VERIFIED', 'Available'),
  blocked('BLOCKED', 'Blocked');

  const FeatureStatus(this.code, this.userLabel);

  /// Code used in docs/FEATURE_MATRIX.md.
  final String code;

  /// Honest, user-facing label. Never claims availability before [verified].
  final String userLabel;

  /// Whether the UI may expose working controls for this feature.
  bool get isUsable => this == FeatureStatus.verified;
}

/// Product version a screen or feature is scheduled for.
enum ProductVersion {
  v1('V1'),
  v2('V2'),
  v3('V3');

  const ProductVersion(this.label);
  final String label;
}
