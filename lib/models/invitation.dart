// lib/models/invitation.dart
import 'household.dart';

class Invitation {
  final String id;
  final String email;
  final String status;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final String token;
  final Household? household;
  final InvitationUserSummary? invitedBy;

  Invitation({
    required this.id,
    required this.email,
    required this.status,
    required this.expiresAt,
    this.createdAt,
    required this.token,
    this.household,
    this.invitedBy,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Invitation.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expiresAt']?.toString();
    final createdAtRaw = json['createdAt']?.toString();
    final householdJson = json['household'];
    final invitedByJson = json['invitedBy'];

    return Invitation(
      id: json['id']?.toString() ?? '',
      email:
          json['email']?.toString() ?? json['inviteeEmail']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      expiresAt: expiresAtRaw != null
          ? DateTime.tryParse(expiresAtRaw) ?? DateTime.now()
          : DateTime.now(),
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
      token: json['token']?.toString() ?? '',
      household: householdJson is Map<String, dynamic>
          ? Household.fromJson(householdJson)
          : null,
      invitedBy: invitedByJson is Map<String, dynamic>
          ? InvitationUserSummary.fromJson(invitedByJson)
          : null,
    );
  }
}

class InvitationUserSummary {
  final String id;
  final String name;
  final String email;

  InvitationUserSummary({
    required this.id,
    required this.name,
    required this.email,
  });

  factory InvitationUserSummary.fromJson(Map<String, dynamic> json) {
    return InvitationUserSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

class AcceptedInvitationResult {
  final Household household;
  final String membershipRole;
  final DateTime membershipCreatedAt;

  AcceptedInvitationResult({
    required this.household,
    required this.membershipRole,
    required this.membershipCreatedAt,
  });

  factory AcceptedInvitationResult.fromJson(Map<String, dynamic> json) {
    final householdJson =
        (json['household'] ?? json['membership']?['household'])
            as Map<String, dynamic>?;
    if (householdJson == null) {
      throw Exception('Missing household details in invitation response.');
    }

    final membershipJson =
        json['membership'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final role =
        membershipJson['role']?.toString() ??
        json['role']?.toString() ??
        'MEMBER';
    final joinedRaw =
        membershipJson['createdAt']?.toString() ??
        json['membershipCreatedAt']?.toString();

    return AcceptedInvitationResult(
      household: Household.fromJson(householdJson),
      membershipRole: role,
      membershipCreatedAt: joinedRaw != null
          ? DateTime.tryParse(joinedRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
