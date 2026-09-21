// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChatConversationEntriesTable extends ChatConversationEntries
    with TableInfo<$ChatConversationEntriesTable, ChatConversationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatConversationEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messagesJsonMeta = const VerificationMeta(
    'messagesJson',
  );
  @override
  late final GeneratedColumn<String> messagesJson = GeneratedColumn<String>(
    'messages_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    messagesJson,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_conversation_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatConversationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('messages_json')) {
      context.handle(
        _messagesJsonMeta,
        messagesJson.isAcceptableOrUnknown(
          data['messages_json']!,
          _messagesJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatConversationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatConversationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      messagesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messages_json'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $ChatConversationEntriesTable createAlias(String alias) {
    return $ChatConversationEntriesTable(attachedDatabase, alias);
  }
}

class ChatConversationEntry extends DataClass
    implements Insertable<ChatConversationEntry> {
  final String id;
  final String title;
  final String messagesJson;
  final int updatedAtEpochMs;
  const ChatConversationEntry({
    required this.id,
    required this.title,
    required this.messagesJson,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['messages_json'] = Variable<String>(messagesJson);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  ChatConversationEntriesCompanion toCompanion(bool nullToAbsent) {
    return ChatConversationEntriesCompanion(
      id: Value(id),
      title: Value(title),
      messagesJson: Value(messagesJson),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory ChatConversationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatConversationEntry(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      messagesJson: serializer.fromJson<String>(json['messagesJson']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'messagesJson': serializer.toJson<String>(messagesJson),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  ChatConversationEntry copyWith({
    String? id,
    String? title,
    String? messagesJson,
    int? updatedAtEpochMs,
  }) => ChatConversationEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    messagesJson: messagesJson ?? this.messagesJson,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  ChatConversationEntry copyWithCompanion(
    ChatConversationEntriesCompanion data,
  ) {
    return ChatConversationEntry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      messagesJson: data.messagesJson.present
          ? data.messagesJson.value
          : this.messagesJson,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatConversationEntry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('messagesJson: $messagesJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, messagesJson, updatedAtEpochMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatConversationEntry &&
          other.id == this.id &&
          other.title == this.title &&
          other.messagesJson == this.messagesJson &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class ChatConversationEntriesCompanion
    extends UpdateCompanion<ChatConversationEntry> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> messagesJson;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const ChatConversationEntriesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.messagesJson = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatConversationEntriesCompanion.insert({
    required String id,
    required String title,
    this.messagesJson = const Value.absent(),
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<ChatConversationEntry> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? messagesJson,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (messagesJson != null) 'messages_json': messagesJson,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatConversationEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? messagesJson,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return ChatConversationEntriesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      messagesJson: messagesJson ?? this.messagesJson,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (messagesJson.present) {
      map['messages_json'] = Variable<String>(messagesJson.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatConversationEntriesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('messagesJson: $messagesJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentTaskEntriesTable extends AgentTaskEntries
    with TableInfo<$AgentTaskEntriesTable, AgentTaskEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentTaskEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    prompt,
    status,
    createdAtEpochMs,
    updatedAtEpochMs,
    stepsJson,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_task_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentTaskEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentTaskEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentTaskEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $AgentTaskEntriesTable createAlias(String alias) {
    return $AgentTaskEntriesTable(attachedDatabase, alias);
  }
}

class AgentTaskEntry extends DataClass implements Insertable<AgentTaskEntry> {
  final String id;
  final String conversationId;
  final String prompt;
  final String status;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final String stepsJson;
  final String? error;
  const AgentTaskEntry({
    required this.id,
    required this.conversationId,
    required this.prompt,
    required this.status,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    required this.stepsJson,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['prompt'] = Variable<String>(prompt);
    map['status'] = Variable<String>(status);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    map['steps_json'] = Variable<String>(stepsJson);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  AgentTaskEntriesCompanion toCompanion(bool nullToAbsent) {
    return AgentTaskEntriesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      prompt: Value(prompt),
      status: Value(status),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
      stepsJson: Value(stepsJson),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory AgentTaskEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentTaskEntry(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      prompt: serializer.fromJson<String>(json['prompt']),
      status: serializer.fromJson<String>(json['status']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'prompt': serializer.toJson<String>(prompt),
      'status': serializer.toJson<String>(status),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'error': serializer.toJson<String?>(error),
    };
  }

  AgentTaskEntry copyWith({
    String? id,
    String? conversationId,
    String? prompt,
    String? status,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    String? stepsJson,
    Value<String?> error = const Value.absent(),
  }) => AgentTaskEntry(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    prompt: prompt ?? this.prompt,
    status: status ?? this.status,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    stepsJson: stepsJson ?? this.stepsJson,
    error: error.present ? error.value : this.error,
  );
  AgentTaskEntry copyWithCompanion(AgentTaskEntriesCompanion data) {
    return AgentTaskEntry(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      status: data.status.present ? data.status.value : this.status,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentTaskEntry(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('prompt: $prompt, ')
          ..write('status: $status, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    prompt,
    status,
    createdAtEpochMs,
    updatedAtEpochMs,
    stepsJson,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentTaskEntry &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.prompt == this.prompt &&
          other.status == this.status &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs &&
          other.stepsJson == this.stepsJson &&
          other.error == this.error);
}

class AgentTaskEntriesCompanion extends UpdateCompanion<AgentTaskEntry> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> prompt;
  final Value<String> status;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<String> stepsJson;
  final Value<String?> error;
  final Value<int> rowid;
  const AgentTaskEntriesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.prompt = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentTaskEntriesCompanion.insert({
    required String id,
    required String conversationId,
    required String prompt,
    required String status,
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.stepsJson = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       prompt = Value(prompt),
       status = Value(status),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<AgentTaskEntry> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? prompt,
    Expression<String>? status,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<String>? stepsJson,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (prompt != null) 'prompt': prompt,
      if (status != null) 'status': status,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentTaskEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? prompt,
    Value<String>? status,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<String>? stepsJson,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return AgentTaskEntriesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      prompt: prompt ?? this.prompt,
      status: status ?? this.status,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      stepsJson: stepsJson ?? this.stepsJson,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentTaskEntriesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('prompt: $prompt, ')
          ..write('status: $status, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsEntriesTable extends AppSettingsEntries
    with TableInfo<$AppSettingsEntriesTable, AppSettingsEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _azureApiKeyMeta = const VerificationMeta(
    'azureApiKey',
  );
  @override
  late final GeneratedColumn<String> azureApiKey = GeneratedColumn<String>(
    'azure_api_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedModelIdMeta = const VerificationMeta(
    'selectedModelId',
  );
  @override
  late final GeneratedColumn<String> selectedModelId = GeneratedColumn<String>(
    'selected_model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, azureApiKey, selectedModelId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('azure_api_key')) {
      context.handle(
        _azureApiKeyMeta,
        azureApiKey.isAcceptableOrUnknown(
          data['azure_api_key']!,
          _azureApiKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_azureApiKeyMeta);
    }
    if (data.containsKey('selected_model_id')) {
      context.handle(
        _selectedModelIdMeta,
        selectedModelId.isAcceptableOrUnknown(
          data['selected_model_id']!,
          _selectedModelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedModelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      azureApiKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}azure_api_key'],
      )!,
      selectedModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_model_id'],
      )!,
    );
  }

  @override
  $AppSettingsEntriesTable createAlias(String alias) {
    return $AppSettingsEntriesTable(attachedDatabase, alias);
  }
}

class AppSettingsEntry extends DataClass
    implements Insertable<AppSettingsEntry> {
  final int id;

  /// Azure AI key. Renamed from `sarvamApiKey` in schema v9; the v9 migration
  /// copies the old column's value across so no credential is lost.
  final String azureApiKey;
  final String selectedModelId;
  const AppSettingsEntry({
    required this.id,
    required this.azureApiKey,
    required this.selectedModelId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['azure_api_key'] = Variable<String>(azureApiKey);
    map['selected_model_id'] = Variable<String>(selectedModelId);
    return map;
  }

  AppSettingsEntriesCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsEntriesCompanion(
      id: Value(id),
      azureApiKey: Value(azureApiKey),
      selectedModelId: Value(selectedModelId),
    );
  }

  factory AppSettingsEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsEntry(
      id: serializer.fromJson<int>(json['id']),
      azureApiKey: serializer.fromJson<String>(json['azureApiKey']),
      selectedModelId: serializer.fromJson<String>(json['selectedModelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'azureApiKey': serializer.toJson<String>(azureApiKey),
      'selectedModelId': serializer.toJson<String>(selectedModelId),
    };
  }

  AppSettingsEntry copyWith({
    int? id,
    String? azureApiKey,
    String? selectedModelId,
  }) => AppSettingsEntry(
    id: id ?? this.id,
    azureApiKey: azureApiKey ?? this.azureApiKey,
    selectedModelId: selectedModelId ?? this.selectedModelId,
  );
  AppSettingsEntry copyWithCompanion(AppSettingsEntriesCompanion data) {
    return AppSettingsEntry(
      id: data.id.present ? data.id.value : this.id,
      azureApiKey: data.azureApiKey.present
          ? data.azureApiKey.value
          : this.azureApiKey,
      selectedModelId: data.selectedModelId.present
          ? data.selectedModelId.value
          : this.selectedModelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsEntry(')
          ..write('id: $id, ')
          ..write('azureApiKey: $azureApiKey, ')
          ..write('selectedModelId: $selectedModelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, azureApiKey, selectedModelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsEntry &&
          other.id == this.id &&
          other.azureApiKey == this.azureApiKey &&
          other.selectedModelId == this.selectedModelId);
}

class AppSettingsEntriesCompanion extends UpdateCompanion<AppSettingsEntry> {
  final Value<int> id;
  final Value<String> azureApiKey;
  final Value<String> selectedModelId;
  const AppSettingsEntriesCompanion({
    this.id = const Value.absent(),
    this.azureApiKey = const Value.absent(),
    this.selectedModelId = const Value.absent(),
  });
  AppSettingsEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String azureApiKey,
    required String selectedModelId,
  }) : azureApiKey = Value(azureApiKey),
       selectedModelId = Value(selectedModelId);
  static Insertable<AppSettingsEntry> custom({
    Expression<int>? id,
    Expression<String>? azureApiKey,
    Expression<String>? selectedModelId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (azureApiKey != null) 'azure_api_key': azureApiKey,
      if (selectedModelId != null) 'selected_model_id': selectedModelId,
    });
  }

  AppSettingsEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? azureApiKey,
    Value<String>? selectedModelId,
  }) {
    return AppSettingsEntriesCompanion(
      id: id ?? this.id,
      azureApiKey: azureApiKey ?? this.azureApiKey,
      selectedModelId: selectedModelId ?? this.selectedModelId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (azureApiKey.present) {
      map['azure_api_key'] = Variable<String>(azureApiKey.value);
    }
    if (selectedModelId.present) {
      map['selected_model_id'] = Variable<String>(selectedModelId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsEntriesCompanion(')
          ..write('id: $id, ')
          ..write('azureApiKey: $azureApiKey, ')
          ..write('selectedModelId: $selectedModelId')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataEntriesTable extends AppMetadataEntries
    with TableInfo<$AppMetadataEntriesTable, AppMetadataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetadataEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AppMetadataEntriesTable createAlias(String alias) {
    return $AppMetadataEntriesTable(attachedDatabase, alias);
  }
}

class AppMetadataEntry extends DataClass
    implements Insertable<AppMetadataEntry> {
  final String key;
  final String? value;
  const AppMetadataEntry({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AppMetadataEntriesCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataEntriesCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AppMetadataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AppMetadataEntry copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AppMetadataEntry(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AppMetadataEntry copyWithCompanion(AppMetadataEntriesCompanion data) {
    return AppMetadataEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetadataEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetadataEntriesCompanion extends UpdateCompanion<AppMetadataEntry> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const AppMetadataEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataEntriesCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AppMetadataEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataEntriesCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return AppMetadataEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogEntriesTable extends AuditLogEntries
    with TableInfo<$AuditLogEntriesTable, AuditLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capabilityKeyMeta = const VerificationMeta(
    'capabilityKey',
  );
  @override
  late final GeneratedColumn<String> capabilityKey = GeneratedColumn<String>(
    'capability_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAtEpochMs,
    capabilityKey,
    title,
    detail,
    status,
    conversationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('capability_key')) {
      context.handle(
        _capabilityKeyMeta,
        capabilityKey.isAcceptableOrUnknown(
          data['capability_key']!,
          _capabilityKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilityKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      capabilityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capability_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
    );
  }

  @override
  $AuditLogEntriesTable createAlias(String alias) {
    return $AuditLogEntriesTable(attachedDatabase, alias);
  }
}

class AuditLogEntry extends DataClass implements Insertable<AuditLogEntry> {
  final String id;
  final int createdAtEpochMs;
  final String capabilityKey;
  final String title;
  final String? detail;
  final String status;
  final String? conversationId;
  const AuditLogEntry({
    required this.id,
    required this.createdAtEpochMs,
    required this.capabilityKey,
    required this.title,
    this.detail,
    required this.status,
    this.conversationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['capability_key'] = Variable<String>(capabilityKey);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    return map;
  }

  AuditLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return AuditLogEntriesCompanion(
      id: Value(id),
      createdAtEpochMs: Value(createdAtEpochMs),
      capabilityKey: Value(capabilityKey),
      title: Value(title),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      status: Value(status),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
    );
  }

  factory AuditLogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogEntry(
      id: serializer.fromJson<String>(json['id']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      capabilityKey: serializer.fromJson<String>(json['capabilityKey']),
      title: serializer.fromJson<String>(json['title']),
      detail: serializer.fromJson<String?>(json['detail']),
      status: serializer.fromJson<String>(json['status']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'capabilityKey': serializer.toJson<String>(capabilityKey),
      'title': serializer.toJson<String>(title),
      'detail': serializer.toJson<String?>(detail),
      'status': serializer.toJson<String>(status),
      'conversationId': serializer.toJson<String?>(conversationId),
    };
  }

  AuditLogEntry copyWith({
    String? id,
    int? createdAtEpochMs,
    String? capabilityKey,
    String? title,
    Value<String?> detail = const Value.absent(),
    String? status,
    Value<String?> conversationId = const Value.absent(),
  }) => AuditLogEntry(
    id: id ?? this.id,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    capabilityKey: capabilityKey ?? this.capabilityKey,
    title: title ?? this.title,
    detail: detail.present ? detail.value : this.detail,
    status: status ?? this.status,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
  );
  AuditLogEntry copyWithCompanion(AuditLogEntriesCompanion data) {
    return AuditLogEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      capabilityKey: data.capabilityKey.present
          ? data.capabilityKey.value
          : this.capabilityKey,
      title: data.title.present ? data.title.value : this.title,
      detail: data.detail.present ? data.detail.value : this.detail,
      status: data.status.present ? data.status.value : this.status,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogEntry(')
          ..write('id: $id, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('capabilityKey: $capabilityKey, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('status: $status, ')
          ..write('conversationId: $conversationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAtEpochMs,
    capabilityKey,
    title,
    detail,
    status,
    conversationId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogEntry &&
          other.id == this.id &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.capabilityKey == this.capabilityKey &&
          other.title == this.title &&
          other.detail == this.detail &&
          other.status == this.status &&
          other.conversationId == this.conversationId);
}

class AuditLogEntriesCompanion extends UpdateCompanion<AuditLogEntry> {
  final Value<String> id;
  final Value<int> createdAtEpochMs;
  final Value<String> capabilityKey;
  final Value<String> title;
  final Value<String?> detail;
  final Value<String> status;
  final Value<String?> conversationId;
  final Value<int> rowid;
  const AuditLogEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.capabilityKey = const Value.absent(),
    this.title = const Value.absent(),
    this.detail = const Value.absent(),
    this.status = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogEntriesCompanion.insert({
    required String id,
    required int createdAtEpochMs,
    required String capabilityKey,
    required String title,
    this.detail = const Value.absent(),
    required String status,
    this.conversationId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAtEpochMs = Value(createdAtEpochMs),
       capabilityKey = Value(capabilityKey),
       title = Value(title),
       status = Value(status);
  static Insertable<AuditLogEntry> custom({
    Expression<String>? id,
    Expression<int>? createdAtEpochMs,
    Expression<String>? capabilityKey,
    Expression<String>? title,
    Expression<String>? detail,
    Expression<String>? status,
    Expression<String>? conversationId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (capabilityKey != null) 'capability_key': capabilityKey,
      if (title != null) 'title': title,
      if (detail != null) 'detail': detail,
      if (status != null) 'status': status,
      if (conversationId != null) 'conversation_id': conversationId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAtEpochMs,
    Value<String>? capabilityKey,
    Value<String>? title,
    Value<String?>? detail,
    Value<String>? status,
    Value<String?>? conversationId,
    Value<int>? rowid,
  }) {
    return AuditLogEntriesCompanion(
      id: id ?? this.id,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      capabilityKey: capabilityKey ?? this.capabilityKey,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      conversationId: conversationId ?? this.conversationId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (capabilityKey.present) {
      map['capability_key'] = Variable<String>(capabilityKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('capabilityKey: $capabilityKey, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('status: $status, ')
          ..write('conversationId: $conversationId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkspaceItemEntriesTable extends WorkspaceItemEntries
    with TableInfo<$WorkspaceItemEntriesTable, WorkspaceItemEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspaceItemEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUriMeta = const VerificationMeta(
    'sourceUri',
  );
  @override
  late final GeneratedColumn<String> sourceUri = GeneratedColumn<String>(
    'source_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extensionMeta = const VerificationMeta(
    'extension',
  );
  @override
  late final GeneratedColumn<String> extension = GeneratedColumn<String>(
    'extension',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    type,
    title,
    createdAtEpochMs,
    updatedAtEpochMs,
    sourceUri,
    localPath,
    mimeType,
    extension,
    sizeBytes,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspace_item_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceItemEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    if (data.containsKey('source_uri')) {
      context.handle(
        _sourceUriMeta,
        sourceUri.isAcceptableOrUnknown(data['source_uri']!, _sourceUriMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('extension')) {
      context.handle(
        _extensionMeta,
        extension.isAcceptableOrUnknown(data['extension']!, _extensionMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkspaceItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceItemEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
      sourceUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_uri'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      extension: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extension'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
    );
  }

  @override
  $WorkspaceItemEntriesTable createAlias(String alias) {
    return $WorkspaceItemEntriesTable(attachedDatabase, alias);
  }
}

class WorkspaceItemEntry extends DataClass
    implements Insertable<WorkspaceItemEntry> {
  final String id;
  final String conversationId;
  final String type;
  final String title;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final String? sourceUri;
  final String? localPath;
  final String? mimeType;
  final String? extension;
  final int? sizeBytes;
  final String? metadataJson;
  const WorkspaceItemEntry({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.title,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.sourceUri,
    this.localPath,
    this.mimeType,
    this.extension,
    this.sizeBytes,
    this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    if (!nullToAbsent || sourceUri != null) {
      map['source_uri'] = Variable<String>(sourceUri);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || extension != null) {
      map['extension'] = Variable<String>(extension);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  WorkspaceItemEntriesCompanion toCompanion(bool nullToAbsent) {
    return WorkspaceItemEntriesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      type: Value(type),
      title: Value(title),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
      sourceUri: sourceUri == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUri),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      extension: extension == null && nullToAbsent
          ? const Value.absent()
          : Value(extension),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory WorkspaceItemEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceItemEntry(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
      sourceUri: serializer.fromJson<String?>(json['sourceUri']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      extension: serializer.fromJson<String?>(json['extension']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
      'sourceUri': serializer.toJson<String?>(sourceUri),
      'localPath': serializer.toJson<String?>(localPath),
      'mimeType': serializer.toJson<String?>(mimeType),
      'extension': serializer.toJson<String?>(extension),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  WorkspaceItemEntry copyWith({
    String? id,
    String? conversationId,
    String? type,
    String? title,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    Value<String?> sourceUri = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<String?> extension = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
  }) => WorkspaceItemEntry(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    type: type ?? this.type,
    title: title ?? this.title,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    sourceUri: sourceUri.present ? sourceUri.value : this.sourceUri,
    localPath: localPath.present ? localPath.value : this.localPath,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    extension: extension.present ? extension.value : this.extension,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
  );
  WorkspaceItemEntry copyWithCompanion(WorkspaceItemEntriesCompanion data) {
    return WorkspaceItemEntry(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
      sourceUri: data.sourceUri.present ? data.sourceUri.value : this.sourceUri,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      extension: data.extension.present ? data.extension.value : this.extension,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceItemEntry(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('localPath: $localPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('extension: $extension, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    type,
    title,
    createdAtEpochMs,
    updatedAtEpochMs,
    sourceUri,
    localPath,
    mimeType,
    extension,
    sizeBytes,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceItemEntry &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.type == this.type &&
          other.title == this.title &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs &&
          other.sourceUri == this.sourceUri &&
          other.localPath == this.localPath &&
          other.mimeType == this.mimeType &&
          other.extension == this.extension &&
          other.sizeBytes == this.sizeBytes &&
          other.metadataJson == this.metadataJson);
}

class WorkspaceItemEntriesCompanion
    extends UpdateCompanion<WorkspaceItemEntry> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> type;
  final Value<String> title;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<String?> sourceUri;
  final Value<String?> localPath;
  final Value<String?> mimeType;
  final Value<String?> extension;
  final Value<int?> sizeBytes;
  final Value<String?> metadataJson;
  final Value<int> rowid;
  const WorkspaceItemEntriesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.sourceUri = const Value.absent(),
    this.localPath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.extension = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspaceItemEntriesCompanion.insert({
    required String id,
    required String conversationId,
    required String type,
    required String title,
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.sourceUri = const Value.absent(),
    this.localPath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.extension = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       type = Value(type),
       title = Value(title),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<WorkspaceItemEntry> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<String>? sourceUri,
    Expression<String>? localPath,
    Expression<String>? mimeType,
    Expression<String>? extension,
    Expression<int>? sizeBytes,
    Expression<String>? metadataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (sourceUri != null) 'source_uri': sourceUri,
      if (localPath != null) 'local_path': localPath,
      if (mimeType != null) 'mime_type': mimeType,
      if (extension != null) 'extension': extension,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspaceItemEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? type,
    Value<String>? title,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<String?>? sourceUri,
    Value<String?>? localPath,
    Value<String?>? mimeType,
    Value<String?>? extension,
    Value<int?>? sizeBytes,
    Value<String?>? metadataJson,
    Value<int>? rowid,
  }) {
    return WorkspaceItemEntriesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      type: type ?? this.type,
      title: title ?? this.title,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      sourceUri: sourceUri ?? this.sourceUri,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      metadataJson: metadataJson ?? this.metadataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (sourceUri.present) {
      map['source_uri'] = Variable<String>(sourceUri.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (extension.present) {
      map['extension'] = Variable<String>(extension.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceItemEntriesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('localPath: $localPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('extension: $extension, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEntriesTable extends MemoryEntries
    with TableInfo<$MemoryEntriesTable, MemoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentJsonMeta = const VerificationMeta(
    'contentJson',
  );
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
    'content_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceEntityTypeMeta = const VerificationMeta(
    'sourceEntityType',
  );
  @override
  late final GeneratedColumn<String> sourceEntityType = GeneratedColumn<String>(
    'source_entity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceEntityIdMeta = const VerificationMeta(
    'sourceEntityId',
  );
  @override
  late final GeneratedColumn<String> sourceEntityId = GeneratedColumn<String>(
    'source_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importanceScoreMeta = const VerificationMeta(
    'importanceScore',
  );
  @override
  late final GeneratedColumn<double> importanceScore = GeneratedColumn<double>(
    'importance_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtEpochMsMeta =
      const VerificationMeta('lastAccessedAtEpochMs');
  @override
  late final GeneratedColumn<int> lastAccessedAtEpochMs = GeneratedColumn<int>(
    'last_accessed_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    scope,
    title,
    contentJson,
    summary,
    tagsJson,
    conversationId,
    taskId,
    sourceEntityType,
    sourceEntityId,
    importanceScore,
    createdAtEpochMs,
    updatedAtEpochMs,
    lastAccessedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content_json')) {
      context.handle(
        _contentJsonMeta,
        contentJson.isAcceptableOrUnknown(
          data['content_json']!,
          _contentJsonMeta,
        ),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('source_entity_type')) {
      context.handle(
        _sourceEntityTypeMeta,
        sourceEntityType.isAcceptableOrUnknown(
          data['source_entity_type']!,
          _sourceEntityTypeMeta,
        ),
      );
    }
    if (data.containsKey('source_entity_id')) {
      context.handle(
        _sourceEntityIdMeta,
        sourceEntityId.isAcceptableOrUnknown(
          data['source_entity_id']!,
          _sourceEntityIdMeta,
        ),
      );
    }
    if (data.containsKey('importance_score')) {
      context.handle(
        _importanceScoreMeta,
        importanceScore.isAcceptableOrUnknown(
          data['importance_score']!,
          _importanceScoreMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    if (data.containsKey('last_accessed_at_epoch_ms')) {
      context.handle(
        _lastAccessedAtEpochMsMeta,
        lastAccessedAtEpochMs.isAcceptableOrUnknown(
          data['last_accessed_at_epoch_ms']!,
          _lastAccessedAtEpochMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      contentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_json'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      sourceEntityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_entity_type'],
      ),
      sourceEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_entity_id'],
      ),
      importanceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}importance_score'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
      lastAccessedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed_at_epoch_ms'],
      ),
    );
  }

  @override
  $MemoryEntriesTable createAlias(String alias) {
    return $MemoryEntriesTable(attachedDatabase, alias);
  }
}

class MemoryEntry extends DataClass implements Insertable<MemoryEntry> {
  final String id;
  final String kind;
  final String scope;
  final String title;
  final String contentJson;
  final String? summary;
  final String tagsJson;
  final String? conversationId;
  final String? taskId;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final double importanceScore;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final int? lastAccessedAtEpochMs;
  const MemoryEntry({
    required this.id,
    required this.kind,
    required this.scope,
    required this.title,
    required this.contentJson,
    this.summary,
    required this.tagsJson,
    this.conversationId,
    this.taskId,
    this.sourceEntityType,
    this.sourceEntityId,
    required this.importanceScore,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.lastAccessedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['scope'] = Variable<String>(scope);
    map['title'] = Variable<String>(title);
    map['content_json'] = Variable<String>(contentJson);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['tags_json'] = Variable<String>(tagsJson);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || sourceEntityType != null) {
      map['source_entity_type'] = Variable<String>(sourceEntityType);
    }
    if (!nullToAbsent || sourceEntityId != null) {
      map['source_entity_id'] = Variable<String>(sourceEntityId);
    }
    map['importance_score'] = Variable<double>(importanceScore);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    if (!nullToAbsent || lastAccessedAtEpochMs != null) {
      map['last_accessed_at_epoch_ms'] = Variable<int>(lastAccessedAtEpochMs);
    }
    return map;
  }

  MemoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      scope: Value(scope),
      title: Value(title),
      contentJson: Value(contentJson),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      tagsJson: Value(tagsJson),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      sourceEntityType: sourceEntityType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceEntityType),
      sourceEntityId: sourceEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceEntityId),
      importanceScore: Value(importanceScore),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
      lastAccessedAtEpochMs: lastAccessedAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAccessedAtEpochMs),
    );
  }

  factory MemoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEntry(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      scope: serializer.fromJson<String>(json['scope']),
      title: serializer.fromJson<String>(json['title']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
      summary: serializer.fromJson<String?>(json['summary']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      sourceEntityType: serializer.fromJson<String?>(json['sourceEntityType']),
      sourceEntityId: serializer.fromJson<String?>(json['sourceEntityId']),
      importanceScore: serializer.fromJson<double>(json['importanceScore']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
      lastAccessedAtEpochMs: serializer.fromJson<int?>(
        json['lastAccessedAtEpochMs'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'scope': serializer.toJson<String>(scope),
      'title': serializer.toJson<String>(title),
      'contentJson': serializer.toJson<String>(contentJson),
      'summary': serializer.toJson<String?>(summary),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'conversationId': serializer.toJson<String?>(conversationId),
      'taskId': serializer.toJson<String?>(taskId),
      'sourceEntityType': serializer.toJson<String?>(sourceEntityType),
      'sourceEntityId': serializer.toJson<String?>(sourceEntityId),
      'importanceScore': serializer.toJson<double>(importanceScore),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
      'lastAccessedAtEpochMs': serializer.toJson<int?>(lastAccessedAtEpochMs),
    };
  }

  MemoryEntry copyWith({
    String? id,
    String? kind,
    String? scope,
    String? title,
    String? contentJson,
    Value<String?> summary = const Value.absent(),
    String? tagsJson,
    Value<String?> conversationId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> sourceEntityType = const Value.absent(),
    Value<String?> sourceEntityId = const Value.absent(),
    double? importanceScore,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    Value<int?> lastAccessedAtEpochMs = const Value.absent(),
  }) => MemoryEntry(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    scope: scope ?? this.scope,
    title: title ?? this.title,
    contentJson: contentJson ?? this.contentJson,
    summary: summary.present ? summary.value : this.summary,
    tagsJson: tagsJson ?? this.tagsJson,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    taskId: taskId.present ? taskId.value : this.taskId,
    sourceEntityType: sourceEntityType.present
        ? sourceEntityType.value
        : this.sourceEntityType,
    sourceEntityId: sourceEntityId.present
        ? sourceEntityId.value
        : this.sourceEntityId,
    importanceScore: importanceScore ?? this.importanceScore,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    lastAccessedAtEpochMs: lastAccessedAtEpochMs.present
        ? lastAccessedAtEpochMs.value
        : this.lastAccessedAtEpochMs,
  );
  MemoryEntry copyWithCompanion(MemoryEntriesCompanion data) {
    return MemoryEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      scope: data.scope.present ? data.scope.value : this.scope,
      title: data.title.present ? data.title.value : this.title,
      contentJson: data.contentJson.present
          ? data.contentJson.value
          : this.contentJson,
      summary: data.summary.present ? data.summary.value : this.summary,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      sourceEntityType: data.sourceEntityType.present
          ? data.sourceEntityType.value
          : this.sourceEntityType,
      sourceEntityId: data.sourceEntityId.present
          ? data.sourceEntityId.value
          : this.sourceEntityId,
      importanceScore: data.importanceScore.present
          ? data.importanceScore.value
          : this.importanceScore,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
      lastAccessedAtEpochMs: data.lastAccessedAtEpochMs.present
          ? data.lastAccessedAtEpochMs.value
          : this.lastAccessedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('title: $title, ')
          ..write('contentJson: $contentJson, ')
          ..write('summary: $summary, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('conversationId: $conversationId, ')
          ..write('taskId: $taskId, ')
          ..write('sourceEntityType: $sourceEntityType, ')
          ..write('sourceEntityId: $sourceEntityId, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('lastAccessedAtEpochMs: $lastAccessedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    scope,
    title,
    contentJson,
    summary,
    tagsJson,
    conversationId,
    taskId,
    sourceEntityType,
    sourceEntityId,
    importanceScore,
    createdAtEpochMs,
    updatedAtEpochMs,
    lastAccessedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.scope == this.scope &&
          other.title == this.title &&
          other.contentJson == this.contentJson &&
          other.summary == this.summary &&
          other.tagsJson == this.tagsJson &&
          other.conversationId == this.conversationId &&
          other.taskId == this.taskId &&
          other.sourceEntityType == this.sourceEntityType &&
          other.sourceEntityId == this.sourceEntityId &&
          other.importanceScore == this.importanceScore &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs &&
          other.lastAccessedAtEpochMs == this.lastAccessedAtEpochMs);
}

class MemoryEntriesCompanion extends UpdateCompanion<MemoryEntry> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> scope;
  final Value<String> title;
  final Value<String> contentJson;
  final Value<String?> summary;
  final Value<String> tagsJson;
  final Value<String?> conversationId;
  final Value<String?> taskId;
  final Value<String?> sourceEntityType;
  final Value<String?> sourceEntityId;
  final Value<double> importanceScore;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int?> lastAccessedAtEpochMs;
  final Value<int> rowid;
  const MemoryEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.scope = const Value.absent(),
    this.title = const Value.absent(),
    this.contentJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.sourceEntityType = const Value.absent(),
    this.sourceEntityId = const Value.absent(),
    this.importanceScore = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.lastAccessedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryEntriesCompanion.insert({
    required String id,
    required String kind,
    required String scope,
    required String title,
    this.contentJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.sourceEntityType = const Value.absent(),
    this.sourceEntityId = const Value.absent(),
    this.importanceScore = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.lastAccessedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       scope = Value(scope),
       title = Value(title),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<MemoryEntry> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? scope,
    Expression<String>? title,
    Expression<String>? contentJson,
    Expression<String>? summary,
    Expression<String>? tagsJson,
    Expression<String>? conversationId,
    Expression<String>? taskId,
    Expression<String>? sourceEntityType,
    Expression<String>? sourceEntityId,
    Expression<double>? importanceScore,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? lastAccessedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (scope != null) 'scope': scope,
      if (title != null) 'title': title,
      if (contentJson != null) 'content_json': contentJson,
      if (summary != null) 'summary': summary,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (conversationId != null) 'conversation_id': conversationId,
      if (taskId != null) 'task_id': taskId,
      if (sourceEntityType != null) 'source_entity_type': sourceEntityType,
      if (sourceEntityId != null) 'source_entity_id': sourceEntityId,
      if (importanceScore != null) 'importance_score': importanceScore,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (lastAccessedAtEpochMs != null)
        'last_accessed_at_epoch_ms': lastAccessedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? scope,
    Value<String>? title,
    Value<String>? contentJson,
    Value<String?>? summary,
    Value<String>? tagsJson,
    Value<String?>? conversationId,
    Value<String?>? taskId,
    Value<String?>? sourceEntityType,
    Value<String?>? sourceEntityId,
    Value<double>? importanceScore,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int?>? lastAccessedAtEpochMs,
    Value<int>? rowid,
  }) {
    return MemoryEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      scope: scope ?? this.scope,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      summary: summary ?? this.summary,
      tagsJson: tagsJson ?? this.tagsJson,
      conversationId: conversationId ?? this.conversationId,
      taskId: taskId ?? this.taskId,
      sourceEntityType: sourceEntityType ?? this.sourceEntityType,
      sourceEntityId: sourceEntityId ?? this.sourceEntityId,
      importanceScore: importanceScore ?? this.importanceScore,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      lastAccessedAtEpochMs:
          lastAccessedAtEpochMs ?? this.lastAccessedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (sourceEntityType.present) {
      map['source_entity_type'] = Variable<String>(sourceEntityType.value);
    }
    if (sourceEntityId.present) {
      map['source_entity_id'] = Variable<String>(sourceEntityId.value);
    }
    if (importanceScore.present) {
      map['importance_score'] = Variable<double>(importanceScore.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (lastAccessedAtEpochMs.present) {
      map['last_accessed_at_epoch_ms'] = Variable<int>(
        lastAccessedAtEpochMs.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('title: $title, ')
          ..write('contentJson: $contentJson, ')
          ..write('summary: $summary, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('conversationId: $conversationId, ')
          ..write('taskId: $taskId, ')
          ..write('sourceEntityType: $sourceEntityType, ')
          ..write('sourceEntityId: $sourceEntityId, ')
          ..write('importanceScore: $importanceScore, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('lastAccessedAtEpochMs: $lastAccessedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SemanticFactEntriesTable extends SemanticFactEntries
    with TableInfo<$SemanticFactEntriesTable, SemanticFactEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SemanticFactEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scope,
    scopeId,
    key,
    valueJson,
    confidence,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'semantic_fact_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SemanticFactEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SemanticFactEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SemanticFactEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      ),
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $SemanticFactEntriesTable createAlias(String alias) {
    return $SemanticFactEntriesTable(attachedDatabase, alias);
  }
}

class SemanticFactEntry extends DataClass
    implements Insertable<SemanticFactEntry> {
  final String id;
  final String scope;
  final String? scopeId;
  final String key;
  final String valueJson;
  final double confidence;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const SemanticFactEntry({
    required this.id,
    required this.scope,
    this.scopeId,
    required this.key,
    required this.valueJson,
    required this.confidence,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || scopeId != null) {
      map['scope_id'] = Variable<String>(scopeId);
    }
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['confidence'] = Variable<double>(confidence);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  SemanticFactEntriesCompanion toCompanion(bool nullToAbsent) {
    return SemanticFactEntriesCompanion(
      id: Value(id),
      scope: Value(scope),
      scopeId: scopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(scopeId),
      key: Value(key),
      valueJson: Value(valueJson),
      confidence: Value(confidence),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory SemanticFactEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SemanticFactEntry(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      scopeId: serializer.fromJson<String?>(json['scopeId']),
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      confidence: serializer.fromJson<double>(json['confidence']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'scopeId': serializer.toJson<String?>(scopeId),
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'confidence': serializer.toJson<double>(confidence),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  SemanticFactEntry copyWith({
    String? id,
    String? scope,
    Value<String?> scopeId = const Value.absent(),
    String? key,
    String? valueJson,
    double? confidence,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => SemanticFactEntry(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    scopeId: scopeId.present ? scopeId.value : this.scopeId,
    key: key ?? this.key,
    valueJson: valueJson ?? this.valueJson,
    confidence: confidence ?? this.confidence,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  SemanticFactEntry copyWithCompanion(SemanticFactEntriesCompanion data) {
    return SemanticFactEntry(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SemanticFactEntry(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('scopeId: $scopeId, ')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('confidence: $confidence, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    scopeId,
    key,
    valueJson,
    confidence,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SemanticFactEntry &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.scopeId == this.scopeId &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.confidence == this.confidence &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class SemanticFactEntriesCompanion extends UpdateCompanion<SemanticFactEntry> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String?> scopeId;
  final Value<String> key;
  final Value<String> valueJson;
  final Value<double> confidence;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const SemanticFactEntriesCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.confidence = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SemanticFactEntriesCompanion.insert({
    required String id,
    required String scope,
    this.scopeId = const Value.absent(),
    required String key,
    required String valueJson,
    this.confidence = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scope = Value(scope),
       key = Value(key),
       valueJson = Value(valueJson),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<SemanticFactEntry> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? scopeId,
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<double>? confidence,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (scopeId != null) 'scope_id': scopeId,
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (confidence != null) 'confidence': confidence,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SemanticFactEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String?>? scopeId,
    Value<String>? key,
    Value<String>? valueJson,
    Value<double>? confidence,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return SemanticFactEntriesCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      scopeId: scopeId ?? this.scopeId,
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      confidence: confidence ?? this.confidence,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SemanticFactEntriesCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('scopeId: $scopeId, ')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('confidence: $confidence, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkingMemorySnapshotEntriesTable extends WorkingMemorySnapshotEntries
    with
        TableInfo<
          $WorkingMemorySnapshotEntriesTable,
          WorkingMemorySnapshotEntry
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkingMemorySnapshotEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assumptionsJsonMeta = const VerificationMeta(
    'assumptionsJson',
  );
  @override
  late final GeneratedColumn<String> assumptionsJson = GeneratedColumn<String>(
    'assumptions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _focusFilePathsJsonMeta =
      const VerificationMeta('focusFilePathsJson');
  @override
  late final GeneratedColumn<String> focusFilePathsJson =
      GeneratedColumn<String>(
        'focus_file_paths_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    taskId,
    summary,
    assumptionsJson,
    focusFilePathsJson,
    metadataJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'working_memory_snapshot_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkingMemorySnapshotEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('assumptions_json')) {
      context.handle(
        _assumptionsJsonMeta,
        assumptionsJson.isAcceptableOrUnknown(
          data['assumptions_json']!,
          _assumptionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('focus_file_paths_json')) {
      context.handle(
        _focusFilePathsJsonMeta,
        focusFilePathsJson.isAcceptableOrUnknown(
          data['focus_file_paths_json']!,
          _focusFilePathsJsonMeta,
        ),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkingMemorySnapshotEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkingMemorySnapshotEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      assumptionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assumptions_json'],
      )!,
      focusFilePathsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}focus_file_paths_json'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $WorkingMemorySnapshotEntriesTable createAlias(String alias) {
    return $WorkingMemorySnapshotEntriesTable(attachedDatabase, alias);
  }
}

class WorkingMemorySnapshotEntry extends DataClass
    implements Insertable<WorkingMemorySnapshotEntry> {
  final String id;
  final String? conversationId;
  final String taskId;
  final String summary;
  final String assumptionsJson;
  final String focusFilePathsJson;
  final String? metadataJson;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const WorkingMemorySnapshotEntry({
    required this.id,
    this.conversationId,
    required this.taskId,
    required this.summary,
    required this.assumptionsJson,
    required this.focusFilePathsJson,
    this.metadataJson,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    map['task_id'] = Variable<String>(taskId);
    map['summary'] = Variable<String>(summary);
    map['assumptions_json'] = Variable<String>(assumptionsJson);
    map['focus_file_paths_json'] = Variable<String>(focusFilePathsJson);
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  WorkingMemorySnapshotEntriesCompanion toCompanion(bool nullToAbsent) {
    return WorkingMemorySnapshotEntriesCompanion(
      id: Value(id),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      taskId: Value(taskId),
      summary: Value(summary),
      assumptionsJson: Value(assumptionsJson),
      focusFilePathsJson: Value(focusFilePathsJson),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory WorkingMemorySnapshotEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkingMemorySnapshotEntry(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      summary: serializer.fromJson<String>(json['summary']),
      assumptionsJson: serializer.fromJson<String>(json['assumptionsJson']),
      focusFilePathsJson: serializer.fromJson<String>(
        json['focusFilePathsJson'],
      ),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String?>(conversationId),
      'taskId': serializer.toJson<String>(taskId),
      'summary': serializer.toJson<String>(summary),
      'assumptionsJson': serializer.toJson<String>(assumptionsJson),
      'focusFilePathsJson': serializer.toJson<String>(focusFilePathsJson),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  WorkingMemorySnapshotEntry copyWith({
    String? id,
    Value<String?> conversationId = const Value.absent(),
    String? taskId,
    String? summary,
    String? assumptionsJson,
    String? focusFilePathsJson,
    Value<String?> metadataJson = const Value.absent(),
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => WorkingMemorySnapshotEntry(
    id: id ?? this.id,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    taskId: taskId ?? this.taskId,
    summary: summary ?? this.summary,
    assumptionsJson: assumptionsJson ?? this.assumptionsJson,
    focusFilePathsJson: focusFilePathsJson ?? this.focusFilePathsJson,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  WorkingMemorySnapshotEntry copyWithCompanion(
    WorkingMemorySnapshotEntriesCompanion data,
  ) {
    return WorkingMemorySnapshotEntry(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      summary: data.summary.present ? data.summary.value : this.summary,
      assumptionsJson: data.assumptionsJson.present
          ? data.assumptionsJson.value
          : this.assumptionsJson,
      focusFilePathsJson: data.focusFilePathsJson.present
          ? data.focusFilePathsJson.value
          : this.focusFilePathsJson,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkingMemorySnapshotEntry(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('taskId: $taskId, ')
          ..write('summary: $summary, ')
          ..write('assumptionsJson: $assumptionsJson, ')
          ..write('focusFilePathsJson: $focusFilePathsJson, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    taskId,
    summary,
    assumptionsJson,
    focusFilePathsJson,
    metadataJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkingMemorySnapshotEntry &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.taskId == this.taskId &&
          other.summary == this.summary &&
          other.assumptionsJson == this.assumptionsJson &&
          other.focusFilePathsJson == this.focusFilePathsJson &&
          other.metadataJson == this.metadataJson &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class WorkingMemorySnapshotEntriesCompanion
    extends UpdateCompanion<WorkingMemorySnapshotEntry> {
  final Value<String> id;
  final Value<String?> conversationId;
  final Value<String> taskId;
  final Value<String> summary;
  final Value<String> assumptionsJson;
  final Value<String> focusFilePathsJson;
  final Value<String?> metadataJson;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const WorkingMemorySnapshotEntriesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.summary = const Value.absent(),
    this.assumptionsJson = const Value.absent(),
    this.focusFilePathsJson = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkingMemorySnapshotEntriesCompanion.insert({
    required String id,
    this.conversationId = const Value.absent(),
    required String taskId,
    required String summary,
    this.assumptionsJson = const Value.absent(),
    this.focusFilePathsJson = const Value.absent(),
    this.metadataJson = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       summary = Value(summary),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<WorkingMemorySnapshotEntry> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? taskId,
    Expression<String>? summary,
    Expression<String>? assumptionsJson,
    Expression<String>? focusFilePathsJson,
    Expression<String>? metadataJson,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (taskId != null) 'task_id': taskId,
      if (summary != null) 'summary': summary,
      if (assumptionsJson != null) 'assumptions_json': assumptionsJson,
      if (focusFilePathsJson != null)
        'focus_file_paths_json': focusFilePathsJson,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkingMemorySnapshotEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? conversationId,
    Value<String>? taskId,
    Value<String>? summary,
    Value<String>? assumptionsJson,
    Value<String>? focusFilePathsJson,
    Value<String?>? metadataJson,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return WorkingMemorySnapshotEntriesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      taskId: taskId ?? this.taskId,
      summary: summary ?? this.summary,
      assumptionsJson: assumptionsJson ?? this.assumptionsJson,
      focusFilePathsJson: focusFilePathsJson ?? this.focusFilePathsJson,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (assumptionsJson.present) {
      map['assumptions_json'] = Variable<String>(assumptionsJson.value);
    }
    if (focusFilePathsJson.present) {
      map['focus_file_paths_json'] = Variable<String>(focusFilePathsJson.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkingMemorySnapshotEntriesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('taskId: $taskId, ')
          ..write('summary: $summary, ')
          ..write('assumptionsJson: $assumptionsJson, ')
          ..write('focusFilePathsJson: $focusFilePathsJson, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuntimeRunEntriesTable extends RuntimeRunEntries
    with TableInfo<$RuntimeRunEntriesTable, RuntimeRunEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuntimeRunEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentRunIdMeta = const VerificationMeta(
    'parentRunId',
  );
  @override
  late final GeneratedColumn<String> parentRunId = GeneratedColumn<String>(
    'parent_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilityKeyMeta = const VerificationMeta(
    'capabilityKey',
  );
  @override
  late final GeneratedColumn<String> capabilityKey = GeneratedColumn<String>(
    'capability_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestJsonMeta = const VerificationMeta(
    'requestJson',
  );
  @override
  late final GeneratedColumn<String> requestJson = GeneratedColumn<String>(
    'request_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtEpochMsMeta =
      const VerificationMeta('completedAtEpochMs');
  @override
  late final GeneratedColumn<int> completedAtEpochMs = GeneratedColumn<int>(
    'completed_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    status,
    title,
    conversationId,
    taskId,
    parentRunId,
    capabilityKey,
    requestJson,
    resultJson,
    error,
    metadataJson,
    createdAtEpochMs,
    updatedAtEpochMs,
    completedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runtime_run_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuntimeRunEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('parent_run_id')) {
      context.handle(
        _parentRunIdMeta,
        parentRunId.isAcceptableOrUnknown(
          data['parent_run_id']!,
          _parentRunIdMeta,
        ),
      );
    }
    if (data.containsKey('capability_key')) {
      context.handle(
        _capabilityKeyMeta,
        capabilityKey.isAcceptableOrUnknown(
          data['capability_key']!,
          _capabilityKeyMeta,
        ),
      );
    }
    if (data.containsKey('request_json')) {
      context.handle(
        _requestJsonMeta,
        requestJson.isAcceptableOrUnknown(
          data['request_json']!,
          _requestJsonMeta,
        ),
      );
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    if (data.containsKey('completed_at_epoch_ms')) {
      context.handle(
        _completedAtEpochMsMeta,
        completedAtEpochMs.isAcceptableOrUnknown(
          data['completed_at_epoch_ms']!,
          _completedAtEpochMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuntimeRunEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuntimeRunEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      parentRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_run_id'],
      ),
      capabilityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capability_key'],
      ),
      requestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_json'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
      completedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_epoch_ms'],
      ),
    );
  }

  @override
  $RuntimeRunEntriesTable createAlias(String alias) {
    return $RuntimeRunEntriesTable(attachedDatabase, alias);
  }
}

class RuntimeRunEntry extends DataClass implements Insertable<RuntimeRunEntry> {
  final String id;
  final String kind;
  final String status;
  final String title;
  final String? conversationId;
  final String? taskId;
  final String? parentRunId;
  final String? capabilityKey;
  final String requestJson;
  final String? resultJson;
  final String? error;
  final String metadataJson;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final int? completedAtEpochMs;
  const RuntimeRunEntry({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    this.conversationId,
    this.taskId,
    this.parentRunId,
    this.capabilityKey,
    required this.requestJson,
    this.resultJson,
    this.error,
    required this.metadataJson,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.completedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || parentRunId != null) {
      map['parent_run_id'] = Variable<String>(parentRunId);
    }
    if (!nullToAbsent || capabilityKey != null) {
      map['capability_key'] = Variable<String>(capabilityKey);
    }
    map['request_json'] = Variable<String>(requestJson);
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['metadata_json'] = Variable<String>(metadataJson);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    if (!nullToAbsent || completedAtEpochMs != null) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs);
    }
    return map;
  }

  RuntimeRunEntriesCompanion toCompanion(bool nullToAbsent) {
    return RuntimeRunEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      status: Value(status),
      title: Value(title),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      parentRunId: parentRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentRunId),
      capabilityKey: capabilityKey == null && nullToAbsent
          ? const Value.absent()
          : Value(capabilityKey),
      requestJson: Value(requestJson),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      metadataJson: Value(metadataJson),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
      completedAtEpochMs: completedAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtEpochMs),
    );
  }

  factory RuntimeRunEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuntimeRunEntry(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      title: serializer.fromJson<String>(json['title']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      parentRunId: serializer.fromJson<String?>(json['parentRunId']),
      capabilityKey: serializer.fromJson<String?>(json['capabilityKey']),
      requestJson: serializer.fromJson<String>(json['requestJson']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      error: serializer.fromJson<String?>(json['error']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
      completedAtEpochMs: serializer.fromJson<int?>(json['completedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'title': serializer.toJson<String>(title),
      'conversationId': serializer.toJson<String?>(conversationId),
      'taskId': serializer.toJson<String?>(taskId),
      'parentRunId': serializer.toJson<String?>(parentRunId),
      'capabilityKey': serializer.toJson<String?>(capabilityKey),
      'requestJson': serializer.toJson<String>(requestJson),
      'resultJson': serializer.toJson<String?>(resultJson),
      'error': serializer.toJson<String?>(error),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
      'completedAtEpochMs': serializer.toJson<int?>(completedAtEpochMs),
    };
  }

  RuntimeRunEntry copyWith({
    String? id,
    String? kind,
    String? status,
    String? title,
    Value<String?> conversationId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> parentRunId = const Value.absent(),
    Value<String?> capabilityKey = const Value.absent(),
    String? requestJson,
    Value<String?> resultJson = const Value.absent(),
    Value<String?> error = const Value.absent(),
    String? metadataJson,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    Value<int?> completedAtEpochMs = const Value.absent(),
  }) => RuntimeRunEntry(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    title: title ?? this.title,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    taskId: taskId.present ? taskId.value : this.taskId,
    parentRunId: parentRunId.present ? parentRunId.value : this.parentRunId,
    capabilityKey: capabilityKey.present
        ? capabilityKey.value
        : this.capabilityKey,
    requestJson: requestJson ?? this.requestJson,
    resultJson: resultJson.present ? resultJson.value : this.resultJson,
    error: error.present ? error.value : this.error,
    metadataJson: metadataJson ?? this.metadataJson,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    completedAtEpochMs: completedAtEpochMs.present
        ? completedAtEpochMs.value
        : this.completedAtEpochMs,
  );
  RuntimeRunEntry copyWithCompanion(RuntimeRunEntriesCompanion data) {
    return RuntimeRunEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      title: data.title.present ? data.title.value : this.title,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      parentRunId: data.parentRunId.present
          ? data.parentRunId.value
          : this.parentRunId,
      capabilityKey: data.capabilityKey.present
          ? data.capabilityKey.value
          : this.capabilityKey,
      requestJson: data.requestJson.present
          ? data.requestJson.value
          : this.requestJson,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      error: data.error.present ? data.error.value : this.error,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
      completedAtEpochMs: data.completedAtEpochMs.present
          ? data.completedAtEpochMs.value
          : this.completedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeRunEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('title: $title, ')
          ..write('conversationId: $conversationId, ')
          ..write('taskId: $taskId, ')
          ..write('parentRunId: $parentRunId, ')
          ..write('capabilityKey: $capabilityKey, ')
          ..write('requestJson: $requestJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('completedAtEpochMs: $completedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    status,
    title,
    conversationId,
    taskId,
    parentRunId,
    capabilityKey,
    requestJson,
    resultJson,
    error,
    metadataJson,
    createdAtEpochMs,
    updatedAtEpochMs,
    completedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuntimeRunEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.title == this.title &&
          other.conversationId == this.conversationId &&
          other.taskId == this.taskId &&
          other.parentRunId == this.parentRunId &&
          other.capabilityKey == this.capabilityKey &&
          other.requestJson == this.requestJson &&
          other.resultJson == this.resultJson &&
          other.error == this.error &&
          other.metadataJson == this.metadataJson &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs &&
          other.completedAtEpochMs == this.completedAtEpochMs);
}

class RuntimeRunEntriesCompanion extends UpdateCompanion<RuntimeRunEntry> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> status;
  final Value<String> title;
  final Value<String?> conversationId;
  final Value<String?> taskId;
  final Value<String?> parentRunId;
  final Value<String?> capabilityKey;
  final Value<String> requestJson;
  final Value<String?> resultJson;
  final Value<String?> error;
  final Value<String> metadataJson;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int?> completedAtEpochMs;
  final Value<int> rowid;
  const RuntimeRunEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.title = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.parentRunId = const Value.absent(),
    this.capabilityKey = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.completedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuntimeRunEntriesCompanion.insert({
    required String id,
    required String kind,
    required String status,
    required String title,
    this.conversationId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.parentRunId = const Value.absent(),
    this.capabilityKey = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    this.metadataJson = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.completedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       status = Value(status),
       title = Value(title),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<RuntimeRunEntry> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? title,
    Expression<String>? conversationId,
    Expression<String>? taskId,
    Expression<String>? parentRunId,
    Expression<String>? capabilityKey,
    Expression<String>? requestJson,
    Expression<String>? resultJson,
    Expression<String>? error,
    Expression<String>? metadataJson,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? completedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (title != null) 'title': title,
      if (conversationId != null) 'conversation_id': conversationId,
      if (taskId != null) 'task_id': taskId,
      if (parentRunId != null) 'parent_run_id': parentRunId,
      if (capabilityKey != null) 'capability_key': capabilityKey,
      if (requestJson != null) 'request_json': requestJson,
      if (resultJson != null) 'result_json': resultJson,
      if (error != null) 'error': error,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (completedAtEpochMs != null)
        'completed_at_epoch_ms': completedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuntimeRunEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? status,
    Value<String>? title,
    Value<String?>? conversationId,
    Value<String?>? taskId,
    Value<String?>? parentRunId,
    Value<String?>? capabilityKey,
    Value<String>? requestJson,
    Value<String?>? resultJson,
    Value<String?>? error,
    Value<String>? metadataJson,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int?>? completedAtEpochMs,
    Value<int>? rowid,
  }) {
    return RuntimeRunEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      title: title ?? this.title,
      conversationId: conversationId ?? this.conversationId,
      taskId: taskId ?? this.taskId,
      parentRunId: parentRunId ?? this.parentRunId,
      capabilityKey: capabilityKey ?? this.capabilityKey,
      requestJson: requestJson ?? this.requestJson,
      resultJson: resultJson ?? this.resultJson,
      error: error ?? this.error,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      completedAtEpochMs: completedAtEpochMs ?? this.completedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (parentRunId.present) {
      map['parent_run_id'] = Variable<String>(parentRunId.value);
    }
    if (capabilityKey.present) {
      map['capability_key'] = Variable<String>(capabilityKey.value);
    }
    if (requestJson.present) {
      map['request_json'] = Variable<String>(requestJson.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (completedAtEpochMs.present) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeRunEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('title: $title, ')
          ..write('conversationId: $conversationId, ')
          ..write('taskId: $taskId, ')
          ..write('parentRunId: $parentRunId, ')
          ..write('capabilityKey: $capabilityKey, ')
          ..write('requestJson: $requestJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('completedAtEpochMs: $completedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuntimeRunEventEntriesTable extends RuntimeRunEventEntries
    with TableInfo<$RuntimeRunEventEntriesTable, RuntimeRunEventEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuntimeRunEventEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    kind,
    title,
    detail,
    payloadJson,
    createdAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runtime_run_event_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuntimeRunEventEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuntimeRunEventEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuntimeRunEventEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
    );
  }

  @override
  $RuntimeRunEventEntriesTable createAlias(String alias) {
    return $RuntimeRunEventEntriesTable(attachedDatabase, alias);
  }
}

class RuntimeRunEventEntry extends DataClass
    implements Insertable<RuntimeRunEventEntry> {
  final String id;
  final String runId;
  final String kind;
  final String title;
  final String? detail;
  final String payloadJson;
  final int createdAtEpochMs;
  const RuntimeRunEventEntry({
    required this.id,
    required this.runId,
    required this.kind,
    required this.title,
    this.detail,
    required this.payloadJson,
    required this.createdAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    return map;
  }

  RuntimeRunEventEntriesCompanion toCompanion(bool nullToAbsent) {
    return RuntimeRunEventEntriesCompanion(
      id: Value(id),
      runId: Value(runId),
      kind: Value(kind),
      title: Value(title),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      payloadJson: Value(payloadJson),
      createdAtEpochMs: Value(createdAtEpochMs),
    );
  }

  factory RuntimeRunEventEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuntimeRunEventEntry(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      detail: serializer.fromJson<String?>(json['detail']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'detail': serializer.toJson<String?>(detail),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
    };
  }

  RuntimeRunEventEntry copyWith({
    String? id,
    String? runId,
    String? kind,
    String? title,
    Value<String?> detail = const Value.absent(),
    String? payloadJson,
    int? createdAtEpochMs,
  }) => RuntimeRunEventEntry(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    detail: detail.present ? detail.value : this.detail,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
  );
  RuntimeRunEventEntry copyWithCompanion(RuntimeRunEventEntriesCompanion data) {
    return RuntimeRunEventEntry(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      detail: data.detail.present ? data.detail.value : this.detail,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeRunEventEntry(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    kind,
    title,
    detail,
    payloadJson,
    createdAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuntimeRunEventEntry &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.detail == this.detail &&
          other.payloadJson == this.payloadJson &&
          other.createdAtEpochMs == this.createdAtEpochMs);
}

class RuntimeRunEventEntriesCompanion
    extends UpdateCompanion<RuntimeRunEventEntry> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> kind;
  final Value<String> title;
  final Value<String?> detail;
  final Value<String> payloadJson;
  final Value<int> createdAtEpochMs;
  final Value<int> rowid;
  const RuntimeRunEventEntriesCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.detail = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuntimeRunEventEntriesCompanion.insert({
    required String id,
    required String runId,
    required String kind,
    required String title,
    this.detail = const Value.absent(),
    this.payloadJson = const Value.absent(),
    required int createdAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       kind = Value(kind),
       title = Value(title),
       createdAtEpochMs = Value(createdAtEpochMs);
  static Insertable<RuntimeRunEventEntry> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? detail,
    Expression<String>? payloadJson,
    Expression<int>? createdAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (detail != null) 'detail': detail,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuntimeRunEventEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? kind,
    Value<String>? title,
    Value<String?>? detail,
    Value<String>? payloadJson,
    Value<int>? createdAtEpochMs,
    Value<int>? rowid,
  }) {
    return RuntimeRunEventEntriesCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeRunEventEntriesCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuntimeOperationLedgerEntriesTable extends RuntimeOperationLedgerEntries
    with
        TableInfo<
          $RuntimeOperationLedgerEntriesTable,
          RuntimeOperationLedgerEntry
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuntimeOperationLedgerEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationKeyMeta = const VerificationMeta(
    'operationKey',
  );
  @override
  late final GeneratedColumn<String> operationKey = GeneratedColumn<String>(
    'operation_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestJsonMeta = const VerificationMeta(
    'requestJson',
  );
  @override
  late final GeneratedColumn<String> requestJson = GeneratedColumn<String>(
    'request_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtEpochMsMeta =
      const VerificationMeta('completedAtEpochMs');
  @override
  late final GeneratedColumn<int> completedAtEpochMs = GeneratedColumn<int>(
    'completed_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    operationKey,
    kind,
    status,
    requestJson,
    resultJson,
    error,
    createdAtEpochMs,
    updatedAtEpochMs,
    completedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runtime_operation_ledger_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuntimeOperationLedgerEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('operation_key')) {
      context.handle(
        _operationKeyMeta,
        operationKey.isAcceptableOrUnknown(
          data['operation_key']!,
          _operationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationKeyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('request_json')) {
      context.handle(
        _requestJsonMeta,
        requestJson.isAcceptableOrUnknown(
          data['request_json']!,
          _requestJsonMeta,
        ),
      );
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    if (data.containsKey('completed_at_epoch_ms')) {
      context.handle(
        _completedAtEpochMsMeta,
        completedAtEpochMs.isAcceptableOrUnknown(
          data['completed_at_epoch_ms']!,
          _completedAtEpochMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuntimeOperationLedgerEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuntimeOperationLedgerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      operationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_key'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      requestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_json'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
      completedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_epoch_ms'],
      ),
    );
  }

  @override
  $RuntimeOperationLedgerEntriesTable createAlias(String alias) {
    return $RuntimeOperationLedgerEntriesTable(attachedDatabase, alias);
  }
}

class RuntimeOperationLedgerEntry extends DataClass
    implements Insertable<RuntimeOperationLedgerEntry> {
  final String id;
  final String runId;
  final String operationKey;
  final String kind;
  final String status;
  final String requestJson;
  final String? resultJson;
  final String? error;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  final int? completedAtEpochMs;
  const RuntimeOperationLedgerEntry({
    required this.id,
    required this.runId,
    required this.operationKey,
    required this.kind,
    required this.status,
    required this.requestJson,
    this.resultJson,
    this.error,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.completedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['operation_key'] = Variable<String>(operationKey);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    map['request_json'] = Variable<String>(requestJson);
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    if (!nullToAbsent || completedAtEpochMs != null) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs);
    }
    return map;
  }

  RuntimeOperationLedgerEntriesCompanion toCompanion(bool nullToAbsent) {
    return RuntimeOperationLedgerEntriesCompanion(
      id: Value(id),
      runId: Value(runId),
      operationKey: Value(operationKey),
      kind: Value(kind),
      status: Value(status),
      requestJson: Value(requestJson),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
      completedAtEpochMs: completedAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtEpochMs),
    );
  }

  factory RuntimeOperationLedgerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuntimeOperationLedgerEntry(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      operationKey: serializer.fromJson<String>(json['operationKey']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      requestJson: serializer.fromJson<String>(json['requestJson']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      error: serializer.fromJson<String?>(json['error']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
      completedAtEpochMs: serializer.fromJson<int?>(json['completedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'operationKey': serializer.toJson<String>(operationKey),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'requestJson': serializer.toJson<String>(requestJson),
      'resultJson': serializer.toJson<String?>(resultJson),
      'error': serializer.toJson<String?>(error),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
      'completedAtEpochMs': serializer.toJson<int?>(completedAtEpochMs),
    };
  }

  RuntimeOperationLedgerEntry copyWith({
    String? id,
    String? runId,
    String? operationKey,
    String? kind,
    String? status,
    String? requestJson,
    Value<String?> resultJson = const Value.absent(),
    Value<String?> error = const Value.absent(),
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
    Value<int?> completedAtEpochMs = const Value.absent(),
  }) => RuntimeOperationLedgerEntry(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    operationKey: operationKey ?? this.operationKey,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    requestJson: requestJson ?? this.requestJson,
    resultJson: resultJson.present ? resultJson.value : this.resultJson,
    error: error.present ? error.value : this.error,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    completedAtEpochMs: completedAtEpochMs.present
        ? completedAtEpochMs.value
        : this.completedAtEpochMs,
  );
  RuntimeOperationLedgerEntry copyWithCompanion(
    RuntimeOperationLedgerEntriesCompanion data,
  ) {
    return RuntimeOperationLedgerEntry(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      operationKey: data.operationKey.present
          ? data.operationKey.value
          : this.operationKey,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      requestJson: data.requestJson.present
          ? data.requestJson.value
          : this.requestJson,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      error: data.error.present ? data.error.value : this.error,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
      completedAtEpochMs: data.completedAtEpochMs.present
          ? data.completedAtEpochMs.value
          : this.completedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeOperationLedgerEntry(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('operationKey: $operationKey, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('requestJson: $requestJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('completedAtEpochMs: $completedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    operationKey,
    kind,
    status,
    requestJson,
    resultJson,
    error,
    createdAtEpochMs,
    updatedAtEpochMs,
    completedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuntimeOperationLedgerEntry &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.operationKey == this.operationKey &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.requestJson == this.requestJson &&
          other.resultJson == this.resultJson &&
          other.error == this.error &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs &&
          other.completedAtEpochMs == this.completedAtEpochMs);
}

class RuntimeOperationLedgerEntriesCompanion
    extends UpdateCompanion<RuntimeOperationLedgerEntry> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> operationKey;
  final Value<String> kind;
  final Value<String> status;
  final Value<String> requestJson;
  final Value<String?> resultJson;
  final Value<String?> error;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int?> completedAtEpochMs;
  final Value<int> rowid;
  const RuntimeOperationLedgerEntriesCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.operationKey = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.completedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuntimeOperationLedgerEntriesCompanion.insert({
    required String id,
    required String runId,
    required String operationKey,
    required String kind,
    required String status,
    this.requestJson = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.completedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       operationKey = Value(operationKey),
       kind = Value(kind),
       status = Value(status),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<RuntimeOperationLedgerEntry> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? operationKey,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? requestJson,
    Expression<String>? resultJson,
    Expression<String>? error,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? completedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (operationKey != null) 'operation_key': operationKey,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (requestJson != null) 'request_json': requestJson,
      if (resultJson != null) 'result_json': resultJson,
      if (error != null) 'error': error,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (completedAtEpochMs != null)
        'completed_at_epoch_ms': completedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuntimeOperationLedgerEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? operationKey,
    Value<String>? kind,
    Value<String>? status,
    Value<String>? requestJson,
    Value<String?>? resultJson,
    Value<String?>? error,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int?>? completedAtEpochMs,
    Value<int>? rowid,
  }) {
    return RuntimeOperationLedgerEntriesCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      operationKey: operationKey ?? this.operationKey,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      requestJson: requestJson ?? this.requestJson,
      resultJson: resultJson ?? this.resultJson,
      error: error ?? this.error,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      completedAtEpochMs: completedAtEpochMs ?? this.completedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (operationKey.present) {
      map['operation_key'] = Variable<String>(operationKey.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (requestJson.present) {
      map['request_json'] = Variable<String>(requestJson.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (completedAtEpochMs.present) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeOperationLedgerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('operationKey: $operationKey, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('requestJson: $requestJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('completedAtEpochMs: $completedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuntimeRunNodeEntriesTable extends RuntimeRunNodeEntries
    with TableInfo<$RuntimeRunNodeEntriesTable, RuntimeRunNodeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuntimeRunNodeEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentNodeIdMeta = const VerificationMeta(
    'parentNodeId',
  );
  @override
  late final GeneratedColumn<String> parentNodeId = GeneratedColumn<String>(
    'parent_node_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phaseKeyMeta = const VerificationMeta(
    'phaseKey',
  );
  @override
  late final GeneratedColumn<String> phaseKey = GeneratedColumn<String>(
    'phase_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _capabilityKeyMeta = const VerificationMeta(
    'capabilityKey',
  );
  @override
  late final GeneratedColumn<String> capabilityKey = GeneratedColumn<String>(
    'capability_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toolNameMeta = const VerificationMeta(
    'toolName',
  );
  @override
  late final GeneratedColumn<String> toolName = GeneratedColumn<String>(
    'tool_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toolCallIdMeta = const VerificationMeta(
    'toolCallId',
  );
  @override
  late final GeneratedColumn<String> toolCallId = GeneratedColumn<String>(
    'tool_call_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operationKeyMeta = const VerificationMeta(
    'operationKey',
  );
  @override
  late final GeneratedColumn<String> operationKey = GeneratedColumn<String>(
    'operation_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestJsonMeta = const VerificationMeta(
    'requestJson',
  );
  @override
  late final GeneratedColumn<String> requestJson = GeneratedColumn<String>(
    'request_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtEpochMsMeta = const VerificationMeta(
    'startedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> startedAtEpochMs = GeneratedColumn<int>(
    'started_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtEpochMsMeta =
      const VerificationMeta('completedAtEpochMs');
  @override
  late final GeneratedColumn<int> completedAtEpochMs = GeneratedColumn<int>(
    'completed_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    parentNodeId,
    phaseKey,
    title,
    status,
    ordinal,
    attempt,
    capabilityKey,
    toolName,
    toolCallId,
    operationKey,
    requestJson,
    resultJson,
    metadataJson,
    error,
    startedAtEpochMs,
    updatedAtEpochMs,
    completedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runtime_run_node_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuntimeRunNodeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('parent_node_id')) {
      context.handle(
        _parentNodeIdMeta,
        parentNodeId.isAcceptableOrUnknown(
          data['parent_node_id']!,
          _parentNodeIdMeta,
        ),
      );
    }
    if (data.containsKey('phase_key')) {
      context.handle(
        _phaseKeyMeta,
        phaseKey.isAcceptableOrUnknown(data['phase_key']!, _phaseKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('capability_key')) {
      context.handle(
        _capabilityKeyMeta,
        capabilityKey.isAcceptableOrUnknown(
          data['capability_key']!,
          _capabilityKeyMeta,
        ),
      );
    }
    if (data.containsKey('tool_name')) {
      context.handle(
        _toolNameMeta,
        toolName.isAcceptableOrUnknown(data['tool_name']!, _toolNameMeta),
      );
    }
    if (data.containsKey('tool_call_id')) {
      context.handle(
        _toolCallIdMeta,
        toolCallId.isAcceptableOrUnknown(
          data['tool_call_id']!,
          _toolCallIdMeta,
        ),
      );
    }
    if (data.containsKey('operation_key')) {
      context.handle(
        _operationKeyMeta,
        operationKey.isAcceptableOrUnknown(
          data['operation_key']!,
          _operationKeyMeta,
        ),
      );
    }
    if (data.containsKey('request_json')) {
      context.handle(
        _requestJsonMeta,
        requestJson.isAcceptableOrUnknown(
          data['request_json']!,
          _requestJsonMeta,
        ),
      );
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('started_at_epoch_ms')) {
      context.handle(
        _startedAtEpochMsMeta,
        startedAtEpochMs.isAcceptableOrUnknown(
          data['started_at_epoch_ms']!,
          _startedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    if (data.containsKey('completed_at_epoch_ms')) {
      context.handle(
        _completedAtEpochMsMeta,
        completedAtEpochMs.isAcceptableOrUnknown(
          data['completed_at_epoch_ms']!,
          _completedAtEpochMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuntimeRunNodeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuntimeRunNodeEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      parentNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_node_id'],
      ),
      phaseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      )!,
      capabilityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capability_key'],
      ),
      toolName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_name'],
      ),
      toolCallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_call_id'],
      ),
      operationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_key'],
      ),
      requestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_json'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      startedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
      completedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_epoch_ms'],
      ),
    );
  }

  @override
  $RuntimeRunNodeEntriesTable createAlias(String alias) {
    return $RuntimeRunNodeEntriesTable(attachedDatabase, alias);
  }
}

class RuntimeRunNodeEntry extends DataClass
    implements Insertable<RuntimeRunNodeEntry> {
  final String id;
  final String runId;
  final String? parentNodeId;
  final String phaseKey;
  final String title;
  final String status;
  final int ordinal;
  final int attempt;
  final String? capabilityKey;
  final String? toolName;
  final String? toolCallId;
  final String? operationKey;
  final String requestJson;
  final String? resultJson;
  final String metadataJson;
  final String? error;
  final int startedAtEpochMs;
  final int updatedAtEpochMs;
  final int? completedAtEpochMs;
  const RuntimeRunNodeEntry({
    required this.id,
    required this.runId,
    this.parentNodeId,
    required this.phaseKey,
    required this.title,
    required this.status,
    required this.ordinal,
    required this.attempt,
    this.capabilityKey,
    this.toolName,
    this.toolCallId,
    this.operationKey,
    required this.requestJson,
    this.resultJson,
    required this.metadataJson,
    this.error,
    required this.startedAtEpochMs,
    required this.updatedAtEpochMs,
    this.completedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    if (!nullToAbsent || parentNodeId != null) {
      map['parent_node_id'] = Variable<String>(parentNodeId);
    }
    map['phase_key'] = Variable<String>(phaseKey);
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['ordinal'] = Variable<int>(ordinal);
    map['attempt'] = Variable<int>(attempt);
    if (!nullToAbsent || capabilityKey != null) {
      map['capability_key'] = Variable<String>(capabilityKey);
    }
    if (!nullToAbsent || toolName != null) {
      map['tool_name'] = Variable<String>(toolName);
    }
    if (!nullToAbsent || toolCallId != null) {
      map['tool_call_id'] = Variable<String>(toolCallId);
    }
    if (!nullToAbsent || operationKey != null) {
      map['operation_key'] = Variable<String>(operationKey);
    }
    map['request_json'] = Variable<String>(requestJson);
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    map['metadata_json'] = Variable<String>(metadataJson);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['started_at_epoch_ms'] = Variable<int>(startedAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    if (!nullToAbsent || completedAtEpochMs != null) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs);
    }
    return map;
  }

  RuntimeRunNodeEntriesCompanion toCompanion(bool nullToAbsent) {
    return RuntimeRunNodeEntriesCompanion(
      id: Value(id),
      runId: Value(runId),
      parentNodeId: parentNodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentNodeId),
      phaseKey: Value(phaseKey),
      title: Value(title),
      status: Value(status),
      ordinal: Value(ordinal),
      attempt: Value(attempt),
      capabilityKey: capabilityKey == null && nullToAbsent
          ? const Value.absent()
          : Value(capabilityKey),
      toolName: toolName == null && nullToAbsent
          ? const Value.absent()
          : Value(toolName),
      toolCallId: toolCallId == null && nullToAbsent
          ? const Value.absent()
          : Value(toolCallId),
      operationKey: operationKey == null && nullToAbsent
          ? const Value.absent()
          : Value(operationKey),
      requestJson: Value(requestJson),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      metadataJson: Value(metadataJson),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      startedAtEpochMs: Value(startedAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
      completedAtEpochMs: completedAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtEpochMs),
    );
  }

  factory RuntimeRunNodeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuntimeRunNodeEntry(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      parentNodeId: serializer.fromJson<String?>(json['parentNodeId']),
      phaseKey: serializer.fromJson<String>(json['phaseKey']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      attempt: serializer.fromJson<int>(json['attempt']),
      capabilityKey: serializer.fromJson<String?>(json['capabilityKey']),
      toolName: serializer.fromJson<String?>(json['toolName']),
      toolCallId: serializer.fromJson<String?>(json['toolCallId']),
      operationKey: serializer.fromJson<String?>(json['operationKey']),
      requestJson: serializer.fromJson<String>(json['requestJson']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      error: serializer.fromJson<String?>(json['error']),
      startedAtEpochMs: serializer.fromJson<int>(json['startedAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
      completedAtEpochMs: serializer.fromJson<int?>(json['completedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'parentNodeId': serializer.toJson<String?>(parentNodeId),
      'phaseKey': serializer.toJson<String>(phaseKey),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'ordinal': serializer.toJson<int>(ordinal),
      'attempt': serializer.toJson<int>(attempt),
      'capabilityKey': serializer.toJson<String?>(capabilityKey),
      'toolName': serializer.toJson<String?>(toolName),
      'toolCallId': serializer.toJson<String?>(toolCallId),
      'operationKey': serializer.toJson<String?>(operationKey),
      'requestJson': serializer.toJson<String>(requestJson),
      'resultJson': serializer.toJson<String?>(resultJson),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'error': serializer.toJson<String?>(error),
      'startedAtEpochMs': serializer.toJson<int>(startedAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
      'completedAtEpochMs': serializer.toJson<int?>(completedAtEpochMs),
    };
  }

  RuntimeRunNodeEntry copyWith({
    String? id,
    String? runId,
    Value<String?> parentNodeId = const Value.absent(),
    String? phaseKey,
    String? title,
    String? status,
    int? ordinal,
    int? attempt,
    Value<String?> capabilityKey = const Value.absent(),
    Value<String?> toolName = const Value.absent(),
    Value<String?> toolCallId = const Value.absent(),
    Value<String?> operationKey = const Value.absent(),
    String? requestJson,
    Value<String?> resultJson = const Value.absent(),
    String? metadataJson,
    Value<String?> error = const Value.absent(),
    int? startedAtEpochMs,
    int? updatedAtEpochMs,
    Value<int?> completedAtEpochMs = const Value.absent(),
  }) => RuntimeRunNodeEntry(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    parentNodeId: parentNodeId.present ? parentNodeId.value : this.parentNodeId,
    phaseKey: phaseKey ?? this.phaseKey,
    title: title ?? this.title,
    status: status ?? this.status,
    ordinal: ordinal ?? this.ordinal,
    attempt: attempt ?? this.attempt,
    capabilityKey: capabilityKey.present
        ? capabilityKey.value
        : this.capabilityKey,
    toolName: toolName.present ? toolName.value : this.toolName,
    toolCallId: toolCallId.present ? toolCallId.value : this.toolCallId,
    operationKey: operationKey.present ? operationKey.value : this.operationKey,
    requestJson: requestJson ?? this.requestJson,
    resultJson: resultJson.present ? resultJson.value : this.resultJson,
    metadataJson: metadataJson ?? this.metadataJson,
    error: error.present ? error.value : this.error,
    startedAtEpochMs: startedAtEpochMs ?? this.startedAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    completedAtEpochMs: completedAtEpochMs.present
        ? completedAtEpochMs.value
        : this.completedAtEpochMs,
  );
  RuntimeRunNodeEntry copyWithCompanion(RuntimeRunNodeEntriesCompanion data) {
    return RuntimeRunNodeEntry(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      parentNodeId: data.parentNodeId.present
          ? data.parentNodeId.value
          : this.parentNodeId,
      phaseKey: data.phaseKey.present ? data.phaseKey.value : this.phaseKey,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      capabilityKey: data.capabilityKey.present
          ? data.capabilityKey.value
          : this.capabilityKey,
      toolName: data.toolName.present ? data.toolName.value : this.toolName,
      toolCallId: data.toolCallId.present
          ? data.toolCallId.value
          : this.toolCallId,
      operationKey: data.operationKey.present
          ? data.operationKey.value
          : this.operationKey,
      requestJson: data.requestJson.present
          ? data.requestJson.value
          : this.requestJson,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      error: data.error.present ? data.error.value : this.error,
      startedAtEpochMs: data.startedAtEpochMs.present
          ? data.startedAtEpochMs.value
          : this.startedAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
      completedAtEpochMs: data.completedAtEpochMs.present
          ? data.completedAtEpochMs.value
          : this.completedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeRunNodeEntry(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('parentNodeId: $parentNodeId, ')
          ..write('phaseKey: $phaseKey, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('ordinal: $ordinal, ')
          ..write('attempt: $attempt, ')
          ..write('capabilityKey: $capabilityKey, ')
          ..write('toolName: $toolName, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('operationKey: $operationKey, ')
          ..write('requestJson: $requestJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('error: $error, ')
          ..write('startedAtEpochMs: $startedAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('completedAtEpochMs: $completedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    parentNodeId,
    phaseKey,
    title,
    status,
    ordinal,
    attempt,
    capabilityKey,
    toolName,
    toolCallId,
    operationKey,
    requestJson,
    resultJson,
    metadataJson,
    error,
    startedAtEpochMs,
    updatedAtEpochMs,
    completedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuntimeRunNodeEntry &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.parentNodeId == this.parentNodeId &&
          other.phaseKey == this.phaseKey &&
          other.title == this.title &&
          other.status == this.status &&
          other.ordinal == this.ordinal &&
          other.attempt == this.attempt &&
          other.capabilityKey == this.capabilityKey &&
          other.toolName == this.toolName &&
          other.toolCallId == this.toolCallId &&
          other.operationKey == this.operationKey &&
          other.requestJson == this.requestJson &&
          other.resultJson == this.resultJson &&
          other.metadataJson == this.metadataJson &&
          other.error == this.error &&
          other.startedAtEpochMs == this.startedAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs &&
          other.completedAtEpochMs == this.completedAtEpochMs);
}

class RuntimeRunNodeEntriesCompanion
    extends UpdateCompanion<RuntimeRunNodeEntry> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String?> parentNodeId;
  final Value<String> phaseKey;
  final Value<String> title;
  final Value<String> status;
  final Value<int> ordinal;
  final Value<int> attempt;
  final Value<String?> capabilityKey;
  final Value<String?> toolName;
  final Value<String?> toolCallId;
  final Value<String?> operationKey;
  final Value<String> requestJson;
  final Value<String?> resultJson;
  final Value<String> metadataJson;
  final Value<String?> error;
  final Value<int> startedAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int?> completedAtEpochMs;
  final Value<int> rowid;
  const RuntimeRunNodeEntriesCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.parentNodeId = const Value.absent(),
    this.phaseKey = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.attempt = const Value.absent(),
    this.capabilityKey = const Value.absent(),
    this.toolName = const Value.absent(),
    this.toolCallId = const Value.absent(),
    this.operationKey = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.error = const Value.absent(),
    this.startedAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.completedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuntimeRunNodeEntriesCompanion.insert({
    required String id,
    required String runId,
    this.parentNodeId = const Value.absent(),
    required String phaseKey,
    required String title,
    required String status,
    required int ordinal,
    this.attempt = const Value.absent(),
    this.capabilityKey = const Value.absent(),
    this.toolName = const Value.absent(),
    this.toolCallId = const Value.absent(),
    this.operationKey = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.error = const Value.absent(),
    required int startedAtEpochMs,
    required int updatedAtEpochMs,
    this.completedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       phaseKey = Value(phaseKey),
       title = Value(title),
       status = Value(status),
       ordinal = Value(ordinal),
       startedAtEpochMs = Value(startedAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<RuntimeRunNodeEntry> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? parentNodeId,
    Expression<String>? phaseKey,
    Expression<String>? title,
    Expression<String>? status,
    Expression<int>? ordinal,
    Expression<int>? attempt,
    Expression<String>? capabilityKey,
    Expression<String>? toolName,
    Expression<String>? toolCallId,
    Expression<String>? operationKey,
    Expression<String>? requestJson,
    Expression<String>? resultJson,
    Expression<String>? metadataJson,
    Expression<String>? error,
    Expression<int>? startedAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? completedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (parentNodeId != null) 'parent_node_id': parentNodeId,
      if (phaseKey != null) 'phase_key': phaseKey,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (ordinal != null) 'ordinal': ordinal,
      if (attempt != null) 'attempt': attempt,
      if (capabilityKey != null) 'capability_key': capabilityKey,
      if (toolName != null) 'tool_name': toolName,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      if (operationKey != null) 'operation_key': operationKey,
      if (requestJson != null) 'request_json': requestJson,
      if (resultJson != null) 'result_json': resultJson,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (error != null) 'error': error,
      if (startedAtEpochMs != null) 'started_at_epoch_ms': startedAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (completedAtEpochMs != null)
        'completed_at_epoch_ms': completedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuntimeRunNodeEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String?>? parentNodeId,
    Value<String>? phaseKey,
    Value<String>? title,
    Value<String>? status,
    Value<int>? ordinal,
    Value<int>? attempt,
    Value<String?>? capabilityKey,
    Value<String?>? toolName,
    Value<String?>? toolCallId,
    Value<String?>? operationKey,
    Value<String>? requestJson,
    Value<String?>? resultJson,
    Value<String>? metadataJson,
    Value<String?>? error,
    Value<int>? startedAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int?>? completedAtEpochMs,
    Value<int>? rowid,
  }) {
    return RuntimeRunNodeEntriesCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      parentNodeId: parentNodeId ?? this.parentNodeId,
      phaseKey: phaseKey ?? this.phaseKey,
      title: title ?? this.title,
      status: status ?? this.status,
      ordinal: ordinal ?? this.ordinal,
      attempt: attempt ?? this.attempt,
      capabilityKey: capabilityKey ?? this.capabilityKey,
      toolName: toolName ?? this.toolName,
      toolCallId: toolCallId ?? this.toolCallId,
      operationKey: operationKey ?? this.operationKey,
      requestJson: requestJson ?? this.requestJson,
      resultJson: resultJson ?? this.resultJson,
      metadataJson: metadataJson ?? this.metadataJson,
      error: error ?? this.error,
      startedAtEpochMs: startedAtEpochMs ?? this.startedAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      completedAtEpochMs: completedAtEpochMs ?? this.completedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (parentNodeId.present) {
      map['parent_node_id'] = Variable<String>(parentNodeId.value);
    }
    if (phaseKey.present) {
      map['phase_key'] = Variable<String>(phaseKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (capabilityKey.present) {
      map['capability_key'] = Variable<String>(capabilityKey.value);
    }
    if (toolName.present) {
      map['tool_name'] = Variable<String>(toolName.value);
    }
    if (toolCallId.present) {
      map['tool_call_id'] = Variable<String>(toolCallId.value);
    }
    if (operationKey.present) {
      map['operation_key'] = Variable<String>(operationKey.value);
    }
    if (requestJson.present) {
      map['request_json'] = Variable<String>(requestJson.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (startedAtEpochMs.present) {
      map['started_at_epoch_ms'] = Variable<int>(startedAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (completedAtEpochMs.present) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuntimeRunNodeEntriesCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('parentNodeId: $parentNodeId, ')
          ..write('phaseKey: $phaseKey, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('ordinal: $ordinal, ')
          ..write('attempt: $attempt, ')
          ..write('capabilityKey: $capabilityKey, ')
          ..write('toolName: $toolName, ')
          ..write('toolCallId: $toolCallId, ')
          ..write('operationKey: $operationKey, ')
          ..write('requestJson: $requestJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('error: $error, ')
          ..write('startedAtEpochMs: $startedAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('completedAtEpochMs: $completedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChatConversationEntriesTable chatConversationEntries =
      $ChatConversationEntriesTable(this);
  late final $AgentTaskEntriesTable agentTaskEntries = $AgentTaskEntriesTable(
    this,
  );
  late final $AppSettingsEntriesTable appSettingsEntries =
      $AppSettingsEntriesTable(this);
  late final $AppMetadataEntriesTable appMetadataEntries =
      $AppMetadataEntriesTable(this);
  late final $AuditLogEntriesTable auditLogEntries = $AuditLogEntriesTable(
    this,
  );
  late final $WorkspaceItemEntriesTable workspaceItemEntries =
      $WorkspaceItemEntriesTable(this);
  late final $MemoryEntriesTable memoryEntries = $MemoryEntriesTable(this);
  late final $SemanticFactEntriesTable semanticFactEntries =
      $SemanticFactEntriesTable(this);
  late final $WorkingMemorySnapshotEntriesTable workingMemorySnapshotEntries =
      $WorkingMemorySnapshotEntriesTable(this);
  late final $RuntimeRunEntriesTable runtimeRunEntries =
      $RuntimeRunEntriesTable(this);
  late final $RuntimeRunEventEntriesTable runtimeRunEventEntries =
      $RuntimeRunEventEntriesTable(this);
  late final $RuntimeOperationLedgerEntriesTable runtimeOperationLedgerEntries =
      $RuntimeOperationLedgerEntriesTable(this);
  late final $RuntimeRunNodeEntriesTable runtimeRunNodeEntries =
      $RuntimeRunNodeEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatConversationEntries,
    agentTaskEntries,
    appSettingsEntries,
    appMetadataEntries,
    auditLogEntries,
    workspaceItemEntries,
    memoryEntries,
    semanticFactEntries,
    workingMemorySnapshotEntries,
    runtimeRunEntries,
    runtimeRunEventEntries,
    runtimeOperationLedgerEntries,
    runtimeRunNodeEntries,
  ];
}

typedef $$ChatConversationEntriesTableCreateCompanionBuilder =
    ChatConversationEntriesCompanion Function({
      required String id,
      required String title,
      Value<String> messagesJson,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$ChatConversationEntriesTableUpdateCompanionBuilder =
    ChatConversationEntriesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> messagesJson,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$ChatConversationEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatConversationEntriesTable> {
  $$ChatConversationEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messagesJson => $composableBuilder(
    column: $table.messagesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatConversationEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatConversationEntriesTable> {
  $$ChatConversationEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messagesJson => $composableBuilder(
    column: $table.messagesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatConversationEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatConversationEntriesTable> {
  $$ChatConversationEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get messagesJson => $composableBuilder(
    column: $table.messagesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$ChatConversationEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatConversationEntriesTable,
          ChatConversationEntry,
          $$ChatConversationEntriesTableFilterComposer,
          $$ChatConversationEntriesTableOrderingComposer,
          $$ChatConversationEntriesTableAnnotationComposer,
          $$ChatConversationEntriesTableCreateCompanionBuilder,
          $$ChatConversationEntriesTableUpdateCompanionBuilder,
          (
            ChatConversationEntry,
            BaseReferences<
              _$AppDatabase,
              $ChatConversationEntriesTable,
              ChatConversationEntry
            >,
          ),
          ChatConversationEntry,
          PrefetchHooks Function()
        > {
  $$ChatConversationEntriesTableTableManager(
    _$AppDatabase db,
    $ChatConversationEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatConversationEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ChatConversationEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ChatConversationEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> messagesJson = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatConversationEntriesCompanion(
                id: id,
                title: title,
                messagesJson: messagesJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> messagesJson = const Value.absent(),
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => ChatConversationEntriesCompanion.insert(
                id: id,
                title: title,
                messagesJson: messagesJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatConversationEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatConversationEntriesTable,
      ChatConversationEntry,
      $$ChatConversationEntriesTableFilterComposer,
      $$ChatConversationEntriesTableOrderingComposer,
      $$ChatConversationEntriesTableAnnotationComposer,
      $$ChatConversationEntriesTableCreateCompanionBuilder,
      $$ChatConversationEntriesTableUpdateCompanionBuilder,
      (
        ChatConversationEntry,
        BaseReferences<
          _$AppDatabase,
          $ChatConversationEntriesTable,
          ChatConversationEntry
        >,
      ),
      ChatConversationEntry,
      PrefetchHooks Function()
    >;
typedef $$AgentTaskEntriesTableCreateCompanionBuilder =
    AgentTaskEntriesCompanion Function({
      required String id,
      required String conversationId,
      required String prompt,
      required String status,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<String> stepsJson,
      Value<String?> error,
      Value<int> rowid,
    });
typedef $$AgentTaskEntriesTableUpdateCompanionBuilder =
    AgentTaskEntriesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> prompt,
      Value<String> status,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<String> stepsJson,
      Value<String?> error,
      Value<int> rowid,
    });

class $$AgentTaskEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AgentTaskEntriesTable> {
  $$AgentTaskEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentTaskEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentTaskEntriesTable> {
  $$AgentTaskEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentTaskEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentTaskEntriesTable> {
  $$AgentTaskEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$AgentTaskEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentTaskEntriesTable,
          AgentTaskEntry,
          $$AgentTaskEntriesTableFilterComposer,
          $$AgentTaskEntriesTableOrderingComposer,
          $$AgentTaskEntriesTableAnnotationComposer,
          $$AgentTaskEntriesTableCreateCompanionBuilder,
          $$AgentTaskEntriesTableUpdateCompanionBuilder,
          (
            AgentTaskEntry,
            BaseReferences<
              _$AppDatabase,
              $AgentTaskEntriesTable,
              AgentTaskEntry
            >,
          ),
          AgentTaskEntry,
          PrefetchHooks Function()
        > {
  $$AgentTaskEntriesTableTableManager(
    _$AppDatabase db,
    $AgentTaskEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentTaskEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentTaskEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentTaskEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentTaskEntriesCompanion(
                id: id,
                conversationId: conversationId,
                prompt: prompt,
                status: status,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                stepsJson: stepsJson,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String prompt,
                required String status,
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<String> stepsJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentTaskEntriesCompanion.insert(
                id: id,
                conversationId: conversationId,
                prompt: prompt,
                status: status,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                stepsJson: stepsJson,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AgentTaskEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentTaskEntriesTable,
      AgentTaskEntry,
      $$AgentTaskEntriesTableFilterComposer,
      $$AgentTaskEntriesTableOrderingComposer,
      $$AgentTaskEntriesTableAnnotationComposer,
      $$AgentTaskEntriesTableCreateCompanionBuilder,
      $$AgentTaskEntriesTableUpdateCompanionBuilder,
      (
        AgentTaskEntry,
        BaseReferences<_$AppDatabase, $AgentTaskEntriesTable, AgentTaskEntry>,
      ),
      AgentTaskEntry,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsEntriesTableCreateCompanionBuilder =
    AppSettingsEntriesCompanion Function({
      Value<int> id,
      required String azureApiKey,
      required String selectedModelId,
    });
typedef $$AppSettingsEntriesTableUpdateCompanionBuilder =
    AppSettingsEntriesCompanion Function({
      Value<int> id,
      Value<String> azureApiKey,
      Value<String> selectedModelId,
    });

class $$AppSettingsEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsEntriesTable> {
  $$AppSettingsEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get azureApiKey => $composableBuilder(
    column: $table.azureApiKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedModelId => $composableBuilder(
    column: $table.selectedModelId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsEntriesTable> {
  $$AppSettingsEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get azureApiKey => $composableBuilder(
    column: $table.azureApiKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedModelId => $composableBuilder(
    column: $table.selectedModelId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsEntriesTable> {
  $$AppSettingsEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get azureApiKey => $composableBuilder(
    column: $table.azureApiKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedModelId => $composableBuilder(
    column: $table.selectedModelId,
    builder: (column) => column,
  );
}

class $$AppSettingsEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsEntriesTable,
          AppSettingsEntry,
          $$AppSettingsEntriesTableFilterComposer,
          $$AppSettingsEntriesTableOrderingComposer,
          $$AppSettingsEntriesTableAnnotationComposer,
          $$AppSettingsEntriesTableCreateCompanionBuilder,
          $$AppSettingsEntriesTableUpdateCompanionBuilder,
          (
            AppSettingsEntry,
            BaseReferences<
              _$AppDatabase,
              $AppSettingsEntriesTable,
              AppSettingsEntry
            >,
          ),
          AppSettingsEntry,
          PrefetchHooks Function()
        > {
  $$AppSettingsEntriesTableTableManager(
    _$AppDatabase db,
    $AppSettingsEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> azureApiKey = const Value.absent(),
                Value<String> selectedModelId = const Value.absent(),
              }) => AppSettingsEntriesCompanion(
                id: id,
                azureApiKey: azureApiKey,
                selectedModelId: selectedModelId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String azureApiKey,
                required String selectedModelId,
              }) => AppSettingsEntriesCompanion.insert(
                id: id,
                azureApiKey: azureApiKey,
                selectedModelId: selectedModelId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsEntriesTable,
      AppSettingsEntry,
      $$AppSettingsEntriesTableFilterComposer,
      $$AppSettingsEntriesTableOrderingComposer,
      $$AppSettingsEntriesTableAnnotationComposer,
      $$AppSettingsEntriesTableCreateCompanionBuilder,
      $$AppSettingsEntriesTableUpdateCompanionBuilder,
      (
        AppSettingsEntry,
        BaseReferences<
          _$AppDatabase,
          $AppSettingsEntriesTable,
          AppSettingsEntry
        >,
      ),
      AppSettingsEntry,
      PrefetchHooks Function()
    >;
typedef $$AppMetadataEntriesTableCreateCompanionBuilder =
    AppMetadataEntriesCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$AppMetadataEntriesTableUpdateCompanionBuilder =
    AppMetadataEntriesCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$AppMetadataEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetadataEntriesTable> {
  $$AppMetadataEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetadataEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetadataEntriesTable> {
  $$AppMetadataEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetadataEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetadataEntriesTable> {
  $$AppMetadataEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetadataEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetadataEntriesTable,
          AppMetadataEntry,
          $$AppMetadataEntriesTableFilterComposer,
          $$AppMetadataEntriesTableOrderingComposer,
          $$AppMetadataEntriesTableAnnotationComposer,
          $$AppMetadataEntriesTableCreateCompanionBuilder,
          $$AppMetadataEntriesTableUpdateCompanionBuilder,
          (
            AppMetadataEntry,
            BaseReferences<
              _$AppDatabase,
              $AppMetadataEntriesTable,
              AppMetadataEntry
            >,
          ),
          AppMetadataEntry,
          PrefetchHooks Function()
        > {
  $$AppMetadataEntriesTableTableManager(
    _$AppDatabase db,
    $AppMetadataEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetadataEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetadataEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetadataEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataEntriesCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetadataEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetadataEntriesTable,
      AppMetadataEntry,
      $$AppMetadataEntriesTableFilterComposer,
      $$AppMetadataEntriesTableOrderingComposer,
      $$AppMetadataEntriesTableAnnotationComposer,
      $$AppMetadataEntriesTableCreateCompanionBuilder,
      $$AppMetadataEntriesTableUpdateCompanionBuilder,
      (
        AppMetadataEntry,
        BaseReferences<
          _$AppDatabase,
          $AppMetadataEntriesTable,
          AppMetadataEntry
        >,
      ),
      AppMetadataEntry,
      PrefetchHooks Function()
    >;
typedef $$AuditLogEntriesTableCreateCompanionBuilder =
    AuditLogEntriesCompanion Function({
      required String id,
      required int createdAtEpochMs,
      required String capabilityKey,
      required String title,
      Value<String?> detail,
      required String status,
      Value<String?> conversationId,
      Value<int> rowid,
    });
typedef $$AuditLogEntriesTableUpdateCompanionBuilder =
    AuditLogEntriesCompanion Function({
      Value<String> id,
      Value<int> createdAtEpochMs,
      Value<String> capabilityKey,
      Value<String> title,
      Value<String?> detail,
      Value<String> status,
      Value<String?> conversationId,
      Value<int> rowid,
    });

class $$AuditLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogEntriesTable> {
  $$AuditLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogEntriesTable> {
  $$AuditLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogEntriesTable> {
  $$AuditLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );
}

class $$AuditLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogEntriesTable,
          AuditLogEntry,
          $$AuditLogEntriesTableFilterComposer,
          $$AuditLogEntriesTableOrderingComposer,
          $$AuditLogEntriesTableAnnotationComposer,
          $$AuditLogEntriesTableCreateCompanionBuilder,
          $$AuditLogEntriesTableUpdateCompanionBuilder,
          (
            AuditLogEntry,
            BaseReferences<_$AppDatabase, $AuditLogEntriesTable, AuditLogEntry>,
          ),
          AuditLogEntry,
          PrefetchHooks Function()
        > {
  $$AuditLogEntriesTableTableManager(
    _$AppDatabase db,
    $AuditLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<String> capabilityKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogEntriesCompanion(
                id: id,
                createdAtEpochMs: createdAtEpochMs,
                capabilityKey: capabilityKey,
                title: title,
                detail: detail,
                status: status,
                conversationId: conversationId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAtEpochMs,
                required String capabilityKey,
                required String title,
                Value<String?> detail = const Value.absent(),
                required String status,
                Value<String?> conversationId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogEntriesCompanion.insert(
                id: id,
                createdAtEpochMs: createdAtEpochMs,
                capabilityKey: capabilityKey,
                title: title,
                detail: detail,
                status: status,
                conversationId: conversationId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogEntriesTable,
      AuditLogEntry,
      $$AuditLogEntriesTableFilterComposer,
      $$AuditLogEntriesTableOrderingComposer,
      $$AuditLogEntriesTableAnnotationComposer,
      $$AuditLogEntriesTableCreateCompanionBuilder,
      $$AuditLogEntriesTableUpdateCompanionBuilder,
      (
        AuditLogEntry,
        BaseReferences<_$AppDatabase, $AuditLogEntriesTable, AuditLogEntry>,
      ),
      AuditLogEntry,
      PrefetchHooks Function()
    >;
typedef $$WorkspaceItemEntriesTableCreateCompanionBuilder =
    WorkspaceItemEntriesCompanion Function({
      required String id,
      required String conversationId,
      required String type,
      required String title,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<String?> sourceUri,
      Value<String?> localPath,
      Value<String?> mimeType,
      Value<String?> extension,
      Value<int?> sizeBytes,
      Value<String?> metadataJson,
      Value<int> rowid,
    });
typedef $$WorkspaceItemEntriesTableUpdateCompanionBuilder =
    WorkspaceItemEntriesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> type,
      Value<String> title,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<String?> sourceUri,
      Value<String?> localPath,
      Value<String?> mimeType,
      Value<String?> extension,
      Value<int?> sizeBytes,
      Value<String?> metadataJson,
      Value<int> rowid,
    });

class $$WorkspaceItemEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspaceItemEntriesTable> {
  $$WorkspaceItemEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extension => $composableBuilder(
    column: $table.extension,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkspaceItemEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspaceItemEntriesTable> {
  $$WorkspaceItemEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extension => $composableBuilder(
    column: $table.extension,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkspaceItemEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspaceItemEntriesTable> {
  $$WorkspaceItemEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUri =>
      $composableBuilder(column: $table.sourceUri, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get extension =>
      $composableBuilder(column: $table.extension, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );
}

class $$WorkspaceItemEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkspaceItemEntriesTable,
          WorkspaceItemEntry,
          $$WorkspaceItemEntriesTableFilterComposer,
          $$WorkspaceItemEntriesTableOrderingComposer,
          $$WorkspaceItemEntriesTableAnnotationComposer,
          $$WorkspaceItemEntriesTableCreateCompanionBuilder,
          $$WorkspaceItemEntriesTableUpdateCompanionBuilder,
          (
            WorkspaceItemEntry,
            BaseReferences<
              _$AppDatabase,
              $WorkspaceItemEntriesTable,
              WorkspaceItemEntry
            >,
          ),
          WorkspaceItemEntry,
          PrefetchHooks Function()
        > {
  $$WorkspaceItemEntriesTableTableManager(
    _$AppDatabase db,
    $WorkspaceItemEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspaceItemEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspaceItemEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkspaceItemEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<String?> sourceUri = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> extension = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspaceItemEntriesCompanion(
                id: id,
                conversationId: conversationId,
                type: type,
                title: title,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                sourceUri: sourceUri,
                localPath: localPath,
                mimeType: mimeType,
                extension: extension,
                sizeBytes: sizeBytes,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String type,
                required String title,
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<String?> sourceUri = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> extension = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspaceItemEntriesCompanion.insert(
                id: id,
                conversationId: conversationId,
                type: type,
                title: title,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                sourceUri: sourceUri,
                localPath: localPath,
                mimeType: mimeType,
                extension: extension,
                sizeBytes: sizeBytes,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkspaceItemEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkspaceItemEntriesTable,
      WorkspaceItemEntry,
      $$WorkspaceItemEntriesTableFilterComposer,
      $$WorkspaceItemEntriesTableOrderingComposer,
      $$WorkspaceItemEntriesTableAnnotationComposer,
      $$WorkspaceItemEntriesTableCreateCompanionBuilder,
      $$WorkspaceItemEntriesTableUpdateCompanionBuilder,
      (
        WorkspaceItemEntry,
        BaseReferences<
          _$AppDatabase,
          $WorkspaceItemEntriesTable,
          WorkspaceItemEntry
        >,
      ),
      WorkspaceItemEntry,
      PrefetchHooks Function()
    >;
typedef $$MemoryEntriesTableCreateCompanionBuilder =
    MemoryEntriesCompanion Function({
      required String id,
      required String kind,
      required String scope,
      required String title,
      Value<String> contentJson,
      Value<String?> summary,
      Value<String> tagsJson,
      Value<String?> conversationId,
      Value<String?> taskId,
      Value<String?> sourceEntityType,
      Value<String?> sourceEntityId,
      Value<double> importanceScore,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int?> lastAccessedAtEpochMs,
      Value<int> rowid,
    });
typedef $$MemoryEntriesTableUpdateCompanionBuilder =
    MemoryEntriesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> scope,
      Value<String> title,
      Value<String> contentJson,
      Value<String?> summary,
      Value<String> tagsJson,
      Value<String?> conversationId,
      Value<String?> taskId,
      Value<String?> sourceEntityType,
      Value<String?> sourceEntityId,
      Value<double> importanceScore,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int?> lastAccessedAtEpochMs,
      Value<int> rowid,
    });

class $$MemoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryEntriesTable> {
  $$MemoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceEntityType => $composableBuilder(
    column: $table.sourceEntityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAtEpochMs => $composableBuilder(
    column: $table.lastAccessedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryEntriesTable> {
  $$MemoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceEntityType => $composableBuilder(
    column: $table.sourceEntityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAtEpochMs => $composableBuilder(
    column: $table.lastAccessedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryEntriesTable> {
  $$MemoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get sourceEntityType => $composableBuilder(
    column: $table.sourceEntityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get importanceScore => $composableBuilder(
    column: $table.importanceScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAccessedAtEpochMs => $composableBuilder(
    column: $table.lastAccessedAtEpochMs,
    builder: (column) => column,
  );
}

class $$MemoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryEntriesTable,
          MemoryEntry,
          $$MemoryEntriesTableFilterComposer,
          $$MemoryEntriesTableOrderingComposer,
          $$MemoryEntriesTableAnnotationComposer,
          $$MemoryEntriesTableCreateCompanionBuilder,
          $$MemoryEntriesTableUpdateCompanionBuilder,
          (
            MemoryEntry,
            BaseReferences<_$AppDatabase, $MemoryEntriesTable, MemoryEntry>,
          ),
          MemoryEntry,
          PrefetchHooks Function()
        > {
  $$MemoryEntriesTableTableManager(_$AppDatabase db, $MemoryEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> contentJson = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> sourceEntityType = const Value.absent(),
                Value<String?> sourceEntityId = const Value.absent(),
                Value<double> importanceScore = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int?> lastAccessedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntriesCompanion(
                id: id,
                kind: kind,
                scope: scope,
                title: title,
                contentJson: contentJson,
                summary: summary,
                tagsJson: tagsJson,
                conversationId: conversationId,
                taskId: taskId,
                sourceEntityType: sourceEntityType,
                sourceEntityId: sourceEntityId,
                importanceScore: importanceScore,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                lastAccessedAtEpochMs: lastAccessedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String scope,
                required String title,
                Value<String> contentJson = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> sourceEntityType = const Value.absent(),
                Value<String?> sourceEntityId = const Value.absent(),
                Value<double> importanceScore = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int?> lastAccessedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEntriesCompanion.insert(
                id: id,
                kind: kind,
                scope: scope,
                title: title,
                contentJson: contentJson,
                summary: summary,
                tagsJson: tagsJson,
                conversationId: conversationId,
                taskId: taskId,
                sourceEntityType: sourceEntityType,
                sourceEntityId: sourceEntityId,
                importanceScore: importanceScore,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                lastAccessedAtEpochMs: lastAccessedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryEntriesTable,
      MemoryEntry,
      $$MemoryEntriesTableFilterComposer,
      $$MemoryEntriesTableOrderingComposer,
      $$MemoryEntriesTableAnnotationComposer,
      $$MemoryEntriesTableCreateCompanionBuilder,
      $$MemoryEntriesTableUpdateCompanionBuilder,
      (
        MemoryEntry,
        BaseReferences<_$AppDatabase, $MemoryEntriesTable, MemoryEntry>,
      ),
      MemoryEntry,
      PrefetchHooks Function()
    >;
typedef $$SemanticFactEntriesTableCreateCompanionBuilder =
    SemanticFactEntriesCompanion Function({
      required String id,
      required String scope,
      Value<String?> scopeId,
      required String key,
      required String valueJson,
      Value<double> confidence,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$SemanticFactEntriesTableUpdateCompanionBuilder =
    SemanticFactEntriesCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String?> scopeId,
      Value<String> key,
      Value<String> valueJson,
      Value<double> confidence,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$SemanticFactEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SemanticFactEntriesTable> {
  $$SemanticFactEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SemanticFactEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SemanticFactEntriesTable> {
  $$SemanticFactEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SemanticFactEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SemanticFactEntriesTable> {
  $$SemanticFactEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$SemanticFactEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SemanticFactEntriesTable,
          SemanticFactEntry,
          $$SemanticFactEntriesTableFilterComposer,
          $$SemanticFactEntriesTableOrderingComposer,
          $$SemanticFactEntriesTableAnnotationComposer,
          $$SemanticFactEntriesTableCreateCompanionBuilder,
          $$SemanticFactEntriesTableUpdateCompanionBuilder,
          (
            SemanticFactEntry,
            BaseReferences<
              _$AppDatabase,
              $SemanticFactEntriesTable,
              SemanticFactEntry
            >,
          ),
          SemanticFactEntry,
          PrefetchHooks Function()
        > {
  $$SemanticFactEntriesTableTableManager(
    _$AppDatabase db,
    $SemanticFactEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SemanticFactEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SemanticFactEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SemanticFactEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String?> scopeId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SemanticFactEntriesCompanion(
                id: id,
                scope: scope,
                scopeId: scopeId,
                key: key,
                valueJson: valueJson,
                confidence: confidence,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scope,
                Value<String?> scopeId = const Value.absent(),
                required String key,
                required String valueJson,
                Value<double> confidence = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => SemanticFactEntriesCompanion.insert(
                id: id,
                scope: scope,
                scopeId: scopeId,
                key: key,
                valueJson: valueJson,
                confidence: confidence,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SemanticFactEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SemanticFactEntriesTable,
      SemanticFactEntry,
      $$SemanticFactEntriesTableFilterComposer,
      $$SemanticFactEntriesTableOrderingComposer,
      $$SemanticFactEntriesTableAnnotationComposer,
      $$SemanticFactEntriesTableCreateCompanionBuilder,
      $$SemanticFactEntriesTableUpdateCompanionBuilder,
      (
        SemanticFactEntry,
        BaseReferences<
          _$AppDatabase,
          $SemanticFactEntriesTable,
          SemanticFactEntry
        >,
      ),
      SemanticFactEntry,
      PrefetchHooks Function()
    >;
typedef $$WorkingMemorySnapshotEntriesTableCreateCompanionBuilder =
    WorkingMemorySnapshotEntriesCompanion Function({
      required String id,
      Value<String?> conversationId,
      required String taskId,
      required String summary,
      Value<String> assumptionsJson,
      Value<String> focusFilePathsJson,
      Value<String?> metadataJson,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$WorkingMemorySnapshotEntriesTableUpdateCompanionBuilder =
    WorkingMemorySnapshotEntriesCompanion Function({
      Value<String> id,
      Value<String?> conversationId,
      Value<String> taskId,
      Value<String> summary,
      Value<String> assumptionsJson,
      Value<String> focusFilePathsJson,
      Value<String?> metadataJson,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$WorkingMemorySnapshotEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkingMemorySnapshotEntriesTable> {
  $$WorkingMemorySnapshotEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assumptionsJson => $composableBuilder(
    column: $table.assumptionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get focusFilePathsJson => $composableBuilder(
    column: $table.focusFilePathsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkingMemorySnapshotEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkingMemorySnapshotEntriesTable> {
  $$WorkingMemorySnapshotEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assumptionsJson => $composableBuilder(
    column: $table.assumptionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get focusFilePathsJson => $composableBuilder(
    column: $table.focusFilePathsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkingMemorySnapshotEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkingMemorySnapshotEntriesTable> {
  $$WorkingMemorySnapshotEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get assumptionsJson => $composableBuilder(
    column: $table.assumptionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get focusFilePathsJson => $composableBuilder(
    column: $table.focusFilePathsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$WorkingMemorySnapshotEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkingMemorySnapshotEntriesTable,
          WorkingMemorySnapshotEntry,
          $$WorkingMemorySnapshotEntriesTableFilterComposer,
          $$WorkingMemorySnapshotEntriesTableOrderingComposer,
          $$WorkingMemorySnapshotEntriesTableAnnotationComposer,
          $$WorkingMemorySnapshotEntriesTableCreateCompanionBuilder,
          $$WorkingMemorySnapshotEntriesTableUpdateCompanionBuilder,
          (
            WorkingMemorySnapshotEntry,
            BaseReferences<
              _$AppDatabase,
              $WorkingMemorySnapshotEntriesTable,
              WorkingMemorySnapshotEntry
            >,
          ),
          WorkingMemorySnapshotEntry,
          PrefetchHooks Function()
        > {
  $$WorkingMemorySnapshotEntriesTableTableManager(
    _$AppDatabase db,
    $WorkingMemorySnapshotEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkingMemorySnapshotEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkingMemorySnapshotEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkingMemorySnapshotEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> assumptionsJson = const Value.absent(),
                Value<String> focusFilePathsJson = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkingMemorySnapshotEntriesCompanion(
                id: id,
                conversationId: conversationId,
                taskId: taskId,
                summary: summary,
                assumptionsJson: assumptionsJson,
                focusFilePathsJson: focusFilePathsJson,
                metadataJson: metadataJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> conversationId = const Value.absent(),
                required String taskId,
                required String summary,
                Value<String> assumptionsJson = const Value.absent(),
                Value<String> focusFilePathsJson = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => WorkingMemorySnapshotEntriesCompanion.insert(
                id: id,
                conversationId: conversationId,
                taskId: taskId,
                summary: summary,
                assumptionsJson: assumptionsJson,
                focusFilePathsJson: focusFilePathsJson,
                metadataJson: metadataJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkingMemorySnapshotEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkingMemorySnapshotEntriesTable,
      WorkingMemorySnapshotEntry,
      $$WorkingMemorySnapshotEntriesTableFilterComposer,
      $$WorkingMemorySnapshotEntriesTableOrderingComposer,
      $$WorkingMemorySnapshotEntriesTableAnnotationComposer,
      $$WorkingMemorySnapshotEntriesTableCreateCompanionBuilder,
      $$WorkingMemorySnapshotEntriesTableUpdateCompanionBuilder,
      (
        WorkingMemorySnapshotEntry,
        BaseReferences<
          _$AppDatabase,
          $WorkingMemorySnapshotEntriesTable,
          WorkingMemorySnapshotEntry
        >,
      ),
      WorkingMemorySnapshotEntry,
      PrefetchHooks Function()
    >;
typedef $$RuntimeRunEntriesTableCreateCompanionBuilder =
    RuntimeRunEntriesCompanion Function({
      required String id,
      required String kind,
      required String status,
      required String title,
      Value<String?> conversationId,
      Value<String?> taskId,
      Value<String?> parentRunId,
      Value<String?> capabilityKey,
      Value<String> requestJson,
      Value<String?> resultJson,
      Value<String?> error,
      Value<String> metadataJson,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int?> completedAtEpochMs,
      Value<int> rowid,
    });
typedef $$RuntimeRunEntriesTableUpdateCompanionBuilder =
    RuntimeRunEntriesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> status,
      Value<String> title,
      Value<String?> conversationId,
      Value<String?> taskId,
      Value<String?> parentRunId,
      Value<String?> capabilityKey,
      Value<String> requestJson,
      Value<String?> resultJson,
      Value<String?> error,
      Value<String> metadataJson,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int?> completedAtEpochMs,
      Value<int> rowid,
    });

class $$RuntimeRunEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $RuntimeRunEntriesTable> {
  $$RuntimeRunEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentRunId => $composableBuilder(
    column: $table.parentRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuntimeRunEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RuntimeRunEntriesTable> {
  $$RuntimeRunEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentRunId => $composableBuilder(
    column: $table.parentRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuntimeRunEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuntimeRunEntriesTable> {
  $$RuntimeRunEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get parentRunId => $composableBuilder(
    column: $table.parentRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => column,
  );
}

class $$RuntimeRunEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuntimeRunEntriesTable,
          RuntimeRunEntry,
          $$RuntimeRunEntriesTableFilterComposer,
          $$RuntimeRunEntriesTableOrderingComposer,
          $$RuntimeRunEntriesTableAnnotationComposer,
          $$RuntimeRunEntriesTableCreateCompanionBuilder,
          $$RuntimeRunEntriesTableUpdateCompanionBuilder,
          (
            RuntimeRunEntry,
            BaseReferences<
              _$AppDatabase,
              $RuntimeRunEntriesTable,
              RuntimeRunEntry
            >,
          ),
          RuntimeRunEntry,
          PrefetchHooks Function()
        > {
  $$RuntimeRunEntriesTableTableManager(
    _$AppDatabase db,
    $RuntimeRunEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuntimeRunEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuntimeRunEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuntimeRunEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> parentRunId = const Value.absent(),
                Value<String?> capabilityKey = const Value.absent(),
                Value<String> requestJson = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeRunEntriesCompanion(
                id: id,
                kind: kind,
                status: status,
                title: title,
                conversationId: conversationId,
                taskId: taskId,
                parentRunId: parentRunId,
                capabilityKey: capabilityKey,
                requestJson: requestJson,
                resultJson: resultJson,
                error: error,
                metadataJson: metadataJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                completedAtEpochMs: completedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String status,
                required String title,
                Value<String?> conversationId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> parentRunId = const Value.absent(),
                Value<String?> capabilityKey = const Value.absent(),
                Value<String> requestJson = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeRunEntriesCompanion.insert(
                id: id,
                kind: kind,
                status: status,
                title: title,
                conversationId: conversationId,
                taskId: taskId,
                parentRunId: parentRunId,
                capabilityKey: capabilityKey,
                requestJson: requestJson,
                resultJson: resultJson,
                error: error,
                metadataJson: metadataJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                completedAtEpochMs: completedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuntimeRunEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuntimeRunEntriesTable,
      RuntimeRunEntry,
      $$RuntimeRunEntriesTableFilterComposer,
      $$RuntimeRunEntriesTableOrderingComposer,
      $$RuntimeRunEntriesTableAnnotationComposer,
      $$RuntimeRunEntriesTableCreateCompanionBuilder,
      $$RuntimeRunEntriesTableUpdateCompanionBuilder,
      (
        RuntimeRunEntry,
        BaseReferences<_$AppDatabase, $RuntimeRunEntriesTable, RuntimeRunEntry>,
      ),
      RuntimeRunEntry,
      PrefetchHooks Function()
    >;
typedef $$RuntimeRunEventEntriesTableCreateCompanionBuilder =
    RuntimeRunEventEntriesCompanion Function({
      required String id,
      required String runId,
      required String kind,
      required String title,
      Value<String?> detail,
      Value<String> payloadJson,
      required int createdAtEpochMs,
      Value<int> rowid,
    });
typedef $$RuntimeRunEventEntriesTableUpdateCompanionBuilder =
    RuntimeRunEventEntriesCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String> kind,
      Value<String> title,
      Value<String?> detail,
      Value<String> payloadJson,
      Value<int> createdAtEpochMs,
      Value<int> rowid,
    });

class $$RuntimeRunEventEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $RuntimeRunEventEntriesTable> {
  $$RuntimeRunEventEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuntimeRunEventEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RuntimeRunEventEntriesTable> {
  $$RuntimeRunEventEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuntimeRunEventEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuntimeRunEventEntriesTable> {
  $$RuntimeRunEventEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );
}

class $$RuntimeRunEventEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuntimeRunEventEntriesTable,
          RuntimeRunEventEntry,
          $$RuntimeRunEventEntriesTableFilterComposer,
          $$RuntimeRunEventEntriesTableOrderingComposer,
          $$RuntimeRunEventEntriesTableAnnotationComposer,
          $$RuntimeRunEventEntriesTableCreateCompanionBuilder,
          $$RuntimeRunEventEntriesTableUpdateCompanionBuilder,
          (
            RuntimeRunEventEntry,
            BaseReferences<
              _$AppDatabase,
              $RuntimeRunEventEntriesTable,
              RuntimeRunEventEntry
            >,
          ),
          RuntimeRunEventEntry,
          PrefetchHooks Function()
        > {
  $$RuntimeRunEventEntriesTableTableManager(
    _$AppDatabase db,
    $RuntimeRunEventEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuntimeRunEventEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RuntimeRunEventEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RuntimeRunEventEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeRunEventEntriesCompanion(
                id: id,
                runId: runId,
                kind: kind,
                title: title,
                detail: detail,
                payloadJson: payloadJson,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String kind,
                required String title,
                Value<String?> detail = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                required int createdAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => RuntimeRunEventEntriesCompanion.insert(
                id: id,
                runId: runId,
                kind: kind,
                title: title,
                detail: detail,
                payloadJson: payloadJson,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuntimeRunEventEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuntimeRunEventEntriesTable,
      RuntimeRunEventEntry,
      $$RuntimeRunEventEntriesTableFilterComposer,
      $$RuntimeRunEventEntriesTableOrderingComposer,
      $$RuntimeRunEventEntriesTableAnnotationComposer,
      $$RuntimeRunEventEntriesTableCreateCompanionBuilder,
      $$RuntimeRunEventEntriesTableUpdateCompanionBuilder,
      (
        RuntimeRunEventEntry,
        BaseReferences<
          _$AppDatabase,
          $RuntimeRunEventEntriesTable,
          RuntimeRunEventEntry
        >,
      ),
      RuntimeRunEventEntry,
      PrefetchHooks Function()
    >;
typedef $$RuntimeOperationLedgerEntriesTableCreateCompanionBuilder =
    RuntimeOperationLedgerEntriesCompanion Function({
      required String id,
      required String runId,
      required String operationKey,
      required String kind,
      required String status,
      Value<String> requestJson,
      Value<String?> resultJson,
      Value<String?> error,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int?> completedAtEpochMs,
      Value<int> rowid,
    });
typedef $$RuntimeOperationLedgerEntriesTableUpdateCompanionBuilder =
    RuntimeOperationLedgerEntriesCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String> operationKey,
      Value<String> kind,
      Value<String> status,
      Value<String> requestJson,
      Value<String?> resultJson,
      Value<String?> error,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int?> completedAtEpochMs,
      Value<int> rowid,
    });

class $$RuntimeOperationLedgerEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $RuntimeOperationLedgerEntriesTable> {
  $$RuntimeOperationLedgerEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuntimeOperationLedgerEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RuntimeOperationLedgerEntriesTable> {
  $$RuntimeOperationLedgerEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuntimeOperationLedgerEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuntimeOperationLedgerEntriesTable> {
  $$RuntimeOperationLedgerEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => column,
  );
}

class $$RuntimeOperationLedgerEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuntimeOperationLedgerEntriesTable,
          RuntimeOperationLedgerEntry,
          $$RuntimeOperationLedgerEntriesTableFilterComposer,
          $$RuntimeOperationLedgerEntriesTableOrderingComposer,
          $$RuntimeOperationLedgerEntriesTableAnnotationComposer,
          $$RuntimeOperationLedgerEntriesTableCreateCompanionBuilder,
          $$RuntimeOperationLedgerEntriesTableUpdateCompanionBuilder,
          (
            RuntimeOperationLedgerEntry,
            BaseReferences<
              _$AppDatabase,
              $RuntimeOperationLedgerEntriesTable,
              RuntimeOperationLedgerEntry
            >,
          ),
          RuntimeOperationLedgerEntry,
          PrefetchHooks Function()
        > {
  $$RuntimeOperationLedgerEntriesTableTableManager(
    _$AppDatabase db,
    $RuntimeOperationLedgerEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuntimeOperationLedgerEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RuntimeOperationLedgerEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RuntimeOperationLedgerEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> operationKey = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> requestJson = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeOperationLedgerEntriesCompanion(
                id: id,
                runId: runId,
                operationKey: operationKey,
                kind: kind,
                status: status,
                requestJson: requestJson,
                resultJson: resultJson,
                error: error,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                completedAtEpochMs: completedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String operationKey,
                required String kind,
                required String status,
                Value<String> requestJson = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeOperationLedgerEntriesCompanion.insert(
                id: id,
                runId: runId,
                operationKey: operationKey,
                kind: kind,
                status: status,
                requestJson: requestJson,
                resultJson: resultJson,
                error: error,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                completedAtEpochMs: completedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuntimeOperationLedgerEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuntimeOperationLedgerEntriesTable,
      RuntimeOperationLedgerEntry,
      $$RuntimeOperationLedgerEntriesTableFilterComposer,
      $$RuntimeOperationLedgerEntriesTableOrderingComposer,
      $$RuntimeOperationLedgerEntriesTableAnnotationComposer,
      $$RuntimeOperationLedgerEntriesTableCreateCompanionBuilder,
      $$RuntimeOperationLedgerEntriesTableUpdateCompanionBuilder,
      (
        RuntimeOperationLedgerEntry,
        BaseReferences<
          _$AppDatabase,
          $RuntimeOperationLedgerEntriesTable,
          RuntimeOperationLedgerEntry
        >,
      ),
      RuntimeOperationLedgerEntry,
      PrefetchHooks Function()
    >;
typedef $$RuntimeRunNodeEntriesTableCreateCompanionBuilder =
    RuntimeRunNodeEntriesCompanion Function({
      required String id,
      required String runId,
      Value<String?> parentNodeId,
      required String phaseKey,
      required String title,
      required String status,
      required int ordinal,
      Value<int> attempt,
      Value<String?> capabilityKey,
      Value<String?> toolName,
      Value<String?> toolCallId,
      Value<String?> operationKey,
      Value<String> requestJson,
      Value<String?> resultJson,
      Value<String> metadataJson,
      Value<String?> error,
      required int startedAtEpochMs,
      required int updatedAtEpochMs,
      Value<int?> completedAtEpochMs,
      Value<int> rowid,
    });
typedef $$RuntimeRunNodeEntriesTableUpdateCompanionBuilder =
    RuntimeRunNodeEntriesCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String?> parentNodeId,
      Value<String> phaseKey,
      Value<String> title,
      Value<String> status,
      Value<int> ordinal,
      Value<int> attempt,
      Value<String?> capabilityKey,
      Value<String?> toolName,
      Value<String?> toolCallId,
      Value<String?> operationKey,
      Value<String> requestJson,
      Value<String?> resultJson,
      Value<String> metadataJson,
      Value<String?> error,
      Value<int> startedAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int?> completedAtEpochMs,
      Value<int> rowid,
    });

class $$RuntimeRunNodeEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $RuntimeRunNodeEntriesTable> {
  $$RuntimeRunNodeEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentNodeId => $composableBuilder(
    column: $table.parentNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phaseKey => $composableBuilder(
    column: $table.phaseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtEpochMs => $composableBuilder(
    column: $table.startedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuntimeRunNodeEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RuntimeRunNodeEntriesTable> {
  $$RuntimeRunNodeEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentNodeId => $composableBuilder(
    column: $table.parentNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phaseKey => $composableBuilder(
    column: $table.phaseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolName => $composableBuilder(
    column: $table.toolName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtEpochMs => $composableBuilder(
    column: $table.startedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuntimeRunNodeEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuntimeRunNodeEntriesTable> {
  $$RuntimeRunNodeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get parentNodeId => $composableBuilder(
    column: $table.parentNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phaseKey =>
      $composableBuilder(column: $table.phaseKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<String> get capabilityKey => $composableBuilder(
    column: $table.capabilityKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolName =>
      $composableBuilder(column: $table.toolName, builder: (column) => column);

  GeneratedColumn<String> get toolCallId => $composableBuilder(
    column: $table.toolCallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get startedAtEpochMs => $composableBuilder(
    column: $table.startedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => column,
  );
}

class $$RuntimeRunNodeEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuntimeRunNodeEntriesTable,
          RuntimeRunNodeEntry,
          $$RuntimeRunNodeEntriesTableFilterComposer,
          $$RuntimeRunNodeEntriesTableOrderingComposer,
          $$RuntimeRunNodeEntriesTableAnnotationComposer,
          $$RuntimeRunNodeEntriesTableCreateCompanionBuilder,
          $$RuntimeRunNodeEntriesTableUpdateCompanionBuilder,
          (
            RuntimeRunNodeEntry,
            BaseReferences<
              _$AppDatabase,
              $RuntimeRunNodeEntriesTable,
              RuntimeRunNodeEntry
            >,
          ),
          RuntimeRunNodeEntry,
          PrefetchHooks Function()
        > {
  $$RuntimeRunNodeEntriesTableTableManager(
    _$AppDatabase db,
    $RuntimeRunNodeEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuntimeRunNodeEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RuntimeRunNodeEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RuntimeRunNodeEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String?> parentNodeId = const Value.absent(),
                Value<String> phaseKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<String?> capabilityKey = const Value.absent(),
                Value<String?> toolName = const Value.absent(),
                Value<String?> toolCallId = const Value.absent(),
                Value<String?> operationKey = const Value.absent(),
                Value<String> requestJson = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> startedAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeRunNodeEntriesCompanion(
                id: id,
                runId: runId,
                parentNodeId: parentNodeId,
                phaseKey: phaseKey,
                title: title,
                status: status,
                ordinal: ordinal,
                attempt: attempt,
                capabilityKey: capabilityKey,
                toolName: toolName,
                toolCallId: toolCallId,
                operationKey: operationKey,
                requestJson: requestJson,
                resultJson: resultJson,
                metadataJson: metadataJson,
                error: error,
                startedAtEpochMs: startedAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                completedAtEpochMs: completedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                Value<String?> parentNodeId = const Value.absent(),
                required String phaseKey,
                required String title,
                required String status,
                required int ordinal,
                Value<int> attempt = const Value.absent(),
                Value<String?> capabilityKey = const Value.absent(),
                Value<String?> toolName = const Value.absent(),
                Value<String?> toolCallId = const Value.absent(),
                Value<String?> operationKey = const Value.absent(),
                Value<String> requestJson = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required int startedAtEpochMs,
                required int updatedAtEpochMs,
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuntimeRunNodeEntriesCompanion.insert(
                id: id,
                runId: runId,
                parentNodeId: parentNodeId,
                phaseKey: phaseKey,
                title: title,
                status: status,
                ordinal: ordinal,
                attempt: attempt,
                capabilityKey: capabilityKey,
                toolName: toolName,
                toolCallId: toolCallId,
                operationKey: operationKey,
                requestJson: requestJson,
                resultJson: resultJson,
                metadataJson: metadataJson,
                error: error,
                startedAtEpochMs: startedAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                completedAtEpochMs: completedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuntimeRunNodeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuntimeRunNodeEntriesTable,
      RuntimeRunNodeEntry,
      $$RuntimeRunNodeEntriesTableFilterComposer,
      $$RuntimeRunNodeEntriesTableOrderingComposer,
      $$RuntimeRunNodeEntriesTableAnnotationComposer,
      $$RuntimeRunNodeEntriesTableCreateCompanionBuilder,
      $$RuntimeRunNodeEntriesTableUpdateCompanionBuilder,
      (
        RuntimeRunNodeEntry,
        BaseReferences<
          _$AppDatabase,
          $RuntimeRunNodeEntriesTable,
          RuntimeRunNodeEntry
        >,
      ),
      RuntimeRunNodeEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatConversationEntriesTableTableManager get chatConversationEntries =>
      $$ChatConversationEntriesTableTableManager(
        _db,
        _db.chatConversationEntries,
      );
  $$AgentTaskEntriesTableTableManager get agentTaskEntries =>
      $$AgentTaskEntriesTableTableManager(_db, _db.agentTaskEntries);
  $$AppSettingsEntriesTableTableManager get appSettingsEntries =>
      $$AppSettingsEntriesTableTableManager(_db, _db.appSettingsEntries);
  $$AppMetadataEntriesTableTableManager get appMetadataEntries =>
      $$AppMetadataEntriesTableTableManager(_db, _db.appMetadataEntries);
  $$AuditLogEntriesTableTableManager get auditLogEntries =>
      $$AuditLogEntriesTableTableManager(_db, _db.auditLogEntries);
  $$WorkspaceItemEntriesTableTableManager get workspaceItemEntries =>
      $$WorkspaceItemEntriesTableTableManager(_db, _db.workspaceItemEntries);
  $$MemoryEntriesTableTableManager get memoryEntries =>
      $$MemoryEntriesTableTableManager(_db, _db.memoryEntries);
  $$SemanticFactEntriesTableTableManager get semanticFactEntries =>
      $$SemanticFactEntriesTableTableManager(_db, _db.semanticFactEntries);
  $$WorkingMemorySnapshotEntriesTableTableManager
  get workingMemorySnapshotEntries =>
      $$WorkingMemorySnapshotEntriesTableTableManager(
        _db,
        _db.workingMemorySnapshotEntries,
      );
  $$RuntimeRunEntriesTableTableManager get runtimeRunEntries =>
      $$RuntimeRunEntriesTableTableManager(_db, _db.runtimeRunEntries);
  $$RuntimeRunEventEntriesTableTableManager get runtimeRunEventEntries =>
      $$RuntimeRunEventEntriesTableTableManager(
        _db,
        _db.runtimeRunEventEntries,
      );
  $$RuntimeOperationLedgerEntriesTableTableManager
  get runtimeOperationLedgerEntries =>
      $$RuntimeOperationLedgerEntriesTableTableManager(
        _db,
        _db.runtimeOperationLedgerEntries,
      );
  $$RuntimeRunNodeEntriesTableTableManager get runtimeRunNodeEntries =>
      $$RuntimeRunNodeEntriesTableTableManager(_db, _db.runtimeRunNodeEntries);
}
