import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;

import '../../../platform/database/app_database.dart';
import '../../../platform/storage/json_file_store.dart';
import '../domain/chat_conversation.dart';
import '../domain/chat_message.dart';

class ChatHistoryController extends ChangeNotifier {
  ChatHistoryController({
    AppDatabase? database,
    JsonFileStore? store,
  })  : _database = database ?? AppDatabase.instance,
        _store = store ?? JsonFileStore.system();

  static const String _storageFileName = 'chat_history.json';
  static const String _activeConversationKey = 'active_conversation_id';

  final AppDatabase _database;
  final JsonFileStore _store;
  final List<ChatConversation> _conversations = <ChatConversation>[];
  bool _loaded = false;
  String? _activeConversationId;

  List<ChatConversation> get conversations =>
      List<ChatConversation>.unmodifiable(_conversations);
  bool get isLoaded => _loaded;
  String? get activeConversationId => _activeConversationId;

  ChatConversation? get activeConversation {
    final id = _activeConversationId;
    if (id == null) {
      return null;
    }
    for (final conversation in _conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> load() async {
    try {
      await _migrateLegacyJsonIfNeeded();
      final records = await (_database.select(_database.chatConversationEntries)
            ..orderBy([
              (table) => drift.OrderingTerm.desc(table.updatedAtEpochMs),
            ]))
          .get();
      _conversations
        ..clear()
        ..addAll(records.map(_conversationFromRowOrNull).nonNulls);
      _activeConversationId = await _readMetadata(_activeConversationKey);
      if (_conversations.isEmpty) {
        await createConversation();
      } else if (activeConversation == null) {
        _activeConversationId = _conversations.first.id;
        await _persistActiveConversationId();
      }
      _loaded = true;
      notifyListeners();
    } on FormatException {
      await recoverWithEmptyState();
    } catch (error) {
      // Only wipe on corruption-class errors. Transient IO errors
      // should not destroy chat history.
      final message = error.toString().toLowerCase();
      if (message.contains('corrupt') ||
          message.contains('database') ||
          message.contains('malformed')) {
        await recoverWithEmptyState();
      } else {
        rethrow;
      }
    }
  }

  Future<void> recoverWithEmptyState() async {
    _conversations.clear();
    _activeConversationId = null;
    await _database.batch((batch) {
      batch.deleteAll(_database.chatConversationEntries);
      batch.deleteWhere(
        _database.appMetadataEntries,
        (table) => table.key.equals(_activeConversationKey),
      );
    });
    _loaded = true;
    notifyListeners();
    await createConversation();
  }

  Future<ChatConversation> createConversation() async {
    final conversation = ChatConversation(
      id: 'chat_${DateTime.now().microsecondsSinceEpoch}',
      title: 'New chat',
      messages: const <ChatMessage>[],
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    _conversations.insert(0, conversation);
    _activeConversationId = conversation.id;
    await _persistConversationState(conversation);
    notifyListeners();
    return conversation;
  }

  Future<void> setActiveConversation(String conversationId) async {
    if (_activeConversationId == conversationId) {
      return;
    }
    _activeConversationId = conversationId;
    await _persistActiveConversationId();
    notifyListeners();
  }

  /// Deletes a conversation and everything referencing it. When the deleted
  /// conversation was active, the most recent remaining one becomes active
  /// (or a fresh empty one is created, so the screen is never stuck).
  Future<void> deleteConversation(String conversationId) async {
    _conversations.removeWhere(
      (conversation) => conversation.id == conversationId,
    );
    await _database.batch((batch) {
      batch.deleteWhere(
        _database.chatConversationEntries,
        (table) => table.id.equals(conversationId),
      );
      // Entries that only existed to serve this conversation go with it; the
      // stores below treat unknown conversation ids as no-ops, so removing the
      // rows here is purely hygiene.
      batch.deleteWhere(
        _database.agentTaskEntries,
        (table) => table.conversationId.equals(conversationId),
      );
    });
    if (_activeConversationId == conversationId) {
      if (_conversations.isNotEmpty) {
        _activeConversationId = _conversations.first.id;
      } else {
        await createConversation();
        return;
      }
      await _persistActiveConversationId();
    }
    notifyListeners();
  }

  Future<void> upsertConversationMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final index =
        _conversations.indexWhere((conversation) => conversation.id == conversationId);
    final title = _deriveTitle(messages);
    late final ChatConversation conversation;
    if (index == -1) {
      conversation = ChatConversation(
        id: conversationId,
        title: title,
        messages: List<ChatMessage>.from(messages),
        updatedAtEpochMs: now,
      );
      _conversations.insert(0, conversation);
    } else {
      conversation = _conversations[index].copyWith(
        title: title,
        messages: List<ChatMessage>.from(messages),
        updatedAtEpochMs: now,
      );
      _conversations.removeAt(index);
      _conversations.insert(0, conversation);
    }
    _activeConversationId = conversationId;
    await _persistConversationState(conversation);
    notifyListeners();
  }

  String _deriveTitle(List<ChatMessage> messages) {
    for (final message in messages) {
      if (message.role != ChatRole.user) {
        continue;
      }
      final normalized = message.content.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty) {
        continue;
      }
      const maxLength = 36;
      if (normalized.length <= maxLength) {
        return normalized;
      }
      return '${normalized.substring(0, maxLength - 1).trimRight()}…';
    }
    return 'Untitled';
  }

  Future<void> _persistConversationState(ChatConversation conversation) async {
    final conversationEntry = _conversationToCompanion(conversation);
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _database.chatConversationEntries,
        <ChatConversationEntriesCompanion>[conversationEntry],
      );
      batch.insertAllOnConflictUpdate(
        _database.appMetadataEntries,
        <AppMetadataEntriesCompanion>[
          AppMetadataEntriesCompanion(
            key: const drift.Value(_activeConversationKey),
            value: drift.Value(_activeConversationId),
          ),
        ],
      );
    });
  }

  Future<void> _persistActiveConversationId() async {
    await _database
        .into(_database.appMetadataEntries)
        .insertOnConflictUpdate(
      AppMetadataEntriesCompanion(
        key: const drift.Value(_activeConversationKey),
        value: drift.Value(_activeConversationId),
      ),
    );
  }

  Future<String?> _readMetadata(String key) async {
    final query = _database.select(_database.appMetadataEntries)
      ..where((table) => table.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  Future<void> _migrateLegacyJsonIfNeeded() async {
    final existingCount = await _countConversations();
    if (existingCount > 0) {
      return;
    }

    final json = await _store.readObject(
      _storageFileName,
      fallback: const <String, dynamic>{},
    );
    final rawConversations = json['conversations'];
    final conversations = rawConversations is List
        ? rawConversations
            .whereType<Map>()
            .map(
              (item) => ChatConversation.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <ChatConversation>[];
    if (conversations.isEmpty) {
      return;
    }

    await _database.batch((batch) {
      batch.insertAll(
        _database.chatConversationEntries,
        conversations
            .map(_conversationToCompanion)
            .toList(growable: false),
      );
      batch.insert(
        _database.appMetadataEntries,
        AppMetadataEntriesCompanion(
          key: const drift.Value(_activeConversationKey),
          value: drift.Value(json['activeConversationId']?.toString()),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
    });
  }

  ChatConversation? _conversationFromRowOrNull(ChatConversationEntry row) {
    try {
      final rawMessages = jsonDecode(row.messagesJson);
      final messages = rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map(
                (item) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ChatMessage>[];
      return ChatConversation(
        id: row.id,
        title: row.title,
        messages: messages,
        updatedAtEpochMs: row.updatedAtEpochMs,
      );
    } catch (_) {
      return null;
    }
  }

  ChatConversationEntriesCompanion _conversationToCompanion(
    ChatConversation conversation,
  ) {
    return ChatConversationEntriesCompanion(
      id: drift.Value(conversation.id),
      title: drift.Value(conversation.title),
      messagesJson: drift.Value(
        jsonEncode(
          conversation.messages.map((message) => message.toJson()).toList(),
        ),
      ),
      updatedAtEpochMs: drift.Value(conversation.updatedAtEpochMs),
    );
  }

  Future<int> _countConversations() async {
    final query = _database.selectOnly(_database.chatConversationEntries)
      ..addColumns([_database.chatConversationEntries.id.count()]);
    final row = await query.getSingle();
    return row.read(_database.chatConversationEntries.id.count()) ?? 0;
  }
}
