// lib/services/invitation_service.dart
import 'dart:convert';

import 'api_client.dart';
import '../models/invitation.dart';

class InvitationService {
  Future<Invitation> sendInvitation({
    required String email,
    required String householdId,
  }) async {
    final res = await ApiClient.post('/api/invitations', {
      'email': email,
      'householdId': householdId,
    });

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Invitation.fromJson(json);
  }

  Future<List<Invitation>> fetchHouseholdInvitations({
    required String householdId,
  }) async {
    final query = Uri(
      queryParameters: {'householdId': householdId},
    ).query; // encoded
    final endpoint = '/api/invitations?$query';
    final res = await ApiClient.get(endpoint, useCache: false);

    final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;
    return jsonList
        .map((item) => Invitation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Invitation>> fetchPendingInvitations() async {
    final res = await ApiClient.get(
      '/api/invitations/pending',
      useCache: false,
    );
    final List<dynamic> jsonList = jsonDecode(res.body) as List<dynamic>;
    return jsonList
        .map((item) => Invitation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AcceptedInvitationResult> acceptInvitation({
    required String token,
  }) async {
    final res = await ApiClient.post('/api/invitations/accept', {
      'token': token,
    });

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return AcceptedInvitationResult.fromJson(json);
  }
}
