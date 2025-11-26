import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/invitation.dart';
import '../services/api_client.dart';
import '../services/household_service.dart';
import '../services/invitation_service.dart';
import '../state/accounts_state.dart';
import '../state/transactions_state.dart';
import '../state/household_state.dart';
import '../storage/auth_storage.dart';

class HouseholdInvitationsPage extends StatefulWidget {
  const HouseholdInvitationsPage({super.key});

  @override
  State<HouseholdInvitationsPage> createState() =>
      _HouseholdInvitationsPageState();
}

class _HouseholdInvitationsPageState extends State<HouseholdInvitationsPage> {
  final InvitationService _invitationService = InvitationService();
  final HouseholdService _householdService = HouseholdService();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>(
    debugLabel: 'household_invitation_form',
  );

  bool _isLoading = true;
  bool _isSending = false;
  String? _pageError;
  String? _sendError;
  String? _householdId;
  String? _acceptingInvitationId;

  List<Invitation> _householdInvitations = [];
  List<Invitation> _pendingInvitations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _pageError = null;
      });
    } else {
      setState(() {
        _pageError = null;
      });
    }

    try {
      final householdId = await _ensureHouseholdId();
      final outgoing = await _invitationService.fetchHouseholdInvitations(
        householdId: householdId,
      );
      final pending = await _invitationService.fetchPendingInvitations();

      if (!mounted) return;
      setState(() {
        _householdId = householdId;
        _householdInvitations = outgoing;
        _pendingInvitations = pending;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageError = e.toString();
      });
    } finally {
      if (showSpinner && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _ensureHouseholdId() async {
    var householdId = await AuthStorage.getHouseholdId();
    if (householdId != null && householdId.isNotEmpty) {
      return householdId;
    }

    final households = await _householdService.fetchHouseholds();
    if (households.isEmpty) {
      throw Exception('No households found for this user.');
    }

    householdId = households.first.id;
    await AuthStorage.setHouseholdId(householdId);
    return householdId;
  }

  Future<void> _sendInvitation() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_householdId == null || _householdId!.isEmpty) {
      setState(() {
        _sendError = 'Unable to determine active household.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _sendError = null;
    });

    try {
      final invitation = await _invitationService.sendInvitation(
        email: _emailController.text.trim(),
        householdId: _householdId!,
      );

      if (!mounted) return;
      setState(() {
        _householdInvitations = [invitation, ..._householdInvitations];
      });
      _emailController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation sent. Share the token manually.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _acceptInvitation(Invitation invitation) async {
    if (invitation.token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This invitation does not have a token to accept.'),
        ),
      );
      return;
    }

    setState(() {
      _acceptingInvitationId = invitation.id;
    });

    try {
      final result = await _invitationService.acceptInvitation(
        token: invitation.token,
      );

      await AuthStorage.setHouseholdId(result.household.id);
      ApiClient.clearAllCache();

      if (mounted) {
        final accountsState = context.read<AccountsState>();
        final transactionsState = context.read<TransactionsState>();
        final householdState = context.read<HouseholdState>();
        await accountsState.refresh();
        await transactionsState.refresh();
        await householdState.refresh();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Joined ${result.household.name} as ${result.membershipRole}.',
          ),
        ),
      );

      await _loadData(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _acceptingInvitationId = null;
        });
      }
    }
  }

  void _copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Token copied to clipboard.')));
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('MMM d, yyyy h:mm a');
    return formatter.format(date.toLocal());
  }

  Color _statusColor(Invitation invitation, BuildContext context) {
    switch (invitation.status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'ACCEPTED':
        return Colors.green;
      case 'EXPIRED':
        return Colors.grey;
      case 'CANCELLED':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household Invitations')),
      body: RefreshIndicator(
        onRefresh: () => _loadData(showSpinner: false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_pageError != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _pageError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Invitation',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Owners can invite others by email. No email delivery occurs; share the generated token manually.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Invitee Email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!value.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          if (_sendError != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _sendError!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSending ? null : _sendInvitation,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                _isSending ? 'Sending...' : 'Send Invite',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _buildHouseholdInvitesSection(context),
              const SizedBox(height: 16),
              _buildPendingInvitesSection(context),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdInvitesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Household Invites',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Existing invites for the active household. Tap the copy icon to share the token manually.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_householdInvitations.isEmpty)
              Text(
                'No invitations have been sent yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (var i = 0; i < _householdInvitations.length; i++) ...[
                    _InvitationTile(
                      invitation: _householdInvitations[i],
                      formatDate: _formatDate,
                      statusColor: (inv) => _statusColor(inv, context),
                      onCopyToken: _copyToken,
                    ),
                    if (i != _householdInvitations.length - 1)
                      const Divider(height: 24),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingInvitesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Pending Invites',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'These invites match your email and are still pending. Accepting an invite switches your active household.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_pendingInvitations.isEmpty)
              Text(
                'No pending invites.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (var i = 0; i < _pendingInvitations.length; i++) ...[
                    _PendingInvitationTile(
                      invitation: _pendingInvitations[i],
                      formatDate: _formatDate,
                      statusColor: (inv) => _statusColor(inv, context),
                      onAccept: () => _acceptInvitation(_pendingInvitations[i]),
                      accepting:
                          _acceptingInvitationId == _pendingInvitations[i].id,
                    ),
                    if (i != _pendingInvitations.length - 1)
                      const Divider(height: 24),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final Invitation invitation;
  final String Function(DateTime) formatDate;
  final Color Function(Invitation) statusColor;
  final void Function(String token) onCopyToken;

  const _InvitationTile({
    required this.invitation,
    required this.formatDate,
    required this.statusColor,
    required this.onCopyToken,
  });

  @override
  Widget build(BuildContext context) {
    final status = invitation.status.toUpperCase();
    final expires = formatDate(invitation.expiresAt);
    final color = statusColor(invitation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                invitation.email,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Chip(
              label: Text(status),
              backgroundColor: color.withValues(alpha: 0.15),
              labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Expires ${invitation.isExpired ? '(Expired)' : ''} $expires',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        if (invitation.invitedBy != null)
          Text(
            'Invited by ${invitation.invitedBy!.name.isEmpty ? invitation.invitedBy!.email : invitation.invitedBy!.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  invitation.token,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Copy token',
                icon: const Icon(Icons.copy),
                onPressed: invitation.token.isEmpty
                    ? null
                    : () => onCopyToken(invitation.token),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingInvitationTile extends StatelessWidget {
  final Invitation invitation;
  final String Function(DateTime) formatDate;
  final Color Function(Invitation) statusColor;
  final VoidCallback onAccept;
  final bool accepting;

  const _PendingInvitationTile({
    required this.invitation,
    required this.formatDate,
    required this.statusColor,
    required this.onAccept,
    required this.accepting,
  });

  @override
  Widget build(BuildContext context) {
    final status = invitation.status.toUpperCase();
    final expires = formatDate(invitation.expiresAt);
    final color = statusColor(invitation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                invitation.household?.name ?? 'Unknown Household',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Chip(
              label: Text(status),
              backgroundColor: color.withValues(alpha: 0.15),
              labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Invited by ${invitation.invitedBy?.name.isNotEmpty == true ? invitation.invitedBy!.name : invitation.invitedBy?.email ?? 'Unknown'}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text('Expires $expires', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: accepting ? null : onAccept,
                icon: accepting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(accepting ? 'Accepting...' : 'Accept Invitation'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
