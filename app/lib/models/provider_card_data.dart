class ProviderCardData {
  final String uid;
  final String fullName;
  final String photoUrl;
  final double rating;
  final int reviewCount;
  final List<String> services;
  final double distanceMeters;
  final int gigCountThisMonth;
  final int gigCountTotal;
  final String dateJoined;
  final String workspaceAddress;
  final bool isActive;

  const ProviderCardData({
    required this.uid,
    required this.fullName,
    required this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.services,
    required this.distanceMeters,
    required this.gigCountThisMonth,
    required this.gigCountTotal,
    required this.dateJoined,
    required this.workspaceAddress,
    required this.isActive,
  });
}
