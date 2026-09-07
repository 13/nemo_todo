import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Who can see a list. Needs a connection: sharing lives on the server.
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({required this.listId, super.key});

  final String listId;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _username = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  SyncClient? _client() {
    final auth = ref.read(authControllerProvider);
    if (!auth.connected) return null;
    return SyncClient(
      ref.read(dioProvider),
      baseUrl: auth.serverUrl!,
      token: auth.token!,
    );
  }

  Future<void> _run(Future<void> Function(SyncClient client) action) async {
    final client = _client();
    if (client == null) return;
    final l = L.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(client);
      await ref.read(syncEngineProvider.notifier).syncNow();
    } on ApiError catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.code) {
            'unknown_user' => l.membersErrorUnknownUser,
            'not_owner' => l.membersOnlyOwner,
            'network' => l.accountErrorNetwork,
            _ => l.accountErrorGeneric(e.code),
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String username) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.commonDelete),
        content: Text(l.membersRemoveConfirm(username)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run((client) => client.unshare(widget.listId, username));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final sharing = ref.watch(listMetaProvider).value?[widget.listId];
    final list = ref.watch(listByIdProvider(widget.listId)).value;
    final members = sharing?.members ?? const <ListMember>[];
    final canEdit = sharing?.isOwner ?? true;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.lists),
        ),
        title: Text(list == null ? l.membersTitle : list.name),
      ),
      body: MaxWidth(
        maxWidth: 480,
        child: !auth.connected
            ? EmptyState(
                icon: Icons.cloud_off_outlined,
                message: l.membersNotConnected,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  for (final member in members)
                    ListTile(
                      key: Key('member-${member.username}'),
                      leading: CircleAvatar(
                        child: Text(
                          member.username.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(
                        member.username == auth.username
                            ? '${member.username} (${l.membersYou})'
                            : member.username,
                      ),
                      subtitle: Text(
                        member.role == MemberRole.owner
                            ? l.membersOwner
                            : l.membersEditor,
                      ),
                      trailing:
                          canEdit && member.role != MemberRole.owner && !_busy
                          ? IconButton(
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () => _remove(member.username),
                            )
                          : null,
                    ),
                  if (members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        l.membersOfflineNotice,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  if (canEdit) ...[
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('member-username'),
                            controller: _username,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: l.membersAddHint,
                              prefixIcon: const Icon(Icons.person_add_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const Key('member-add'),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final name = _username.text.trim();
                                  if (name.isEmpty) return;
                                  await _run(
                                    (client) => client.share(
                                      widget.listId,
                                      name,
                                      MemberRole.editor,
                                    ),
                                  );
                                  if (mounted && _error == null) {
                                    _username.clear();
                                  }
                                },
                          child: Text(l.commonAdd),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        key: const Key('members-error'),
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
