import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../error/error_handler.dart';
import '../models/app_error.dart';

/// Professional database manager using SQLite
class DatabaseManager {
  static DatabaseManager? _instance;
  static DatabaseManager get instance =>
      _instance ??= DatabaseManager._internal();
  DatabaseManager._internal();

  Database? _database;
  final ErrorHandler _errorHandler = ErrorHandler();

  static const String _databaseName = 'boofer_app.db';
  static const int _databaseVersion = 3;

  /// Get database instance
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final databasePath = path.join(documentsDirectory.path, _databaseName);

      return await openDatabase(
        databasePath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to initialize database: $e',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // Removed problematic PRAGMA statements that cause issues on some Android versions
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Users table
    batch.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        virtual_number TEXT NOT NULL UNIQUE,
        handle TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        bio TEXT,
        is_discoverable INTEGER NOT NULL DEFAULT 1,
        profile_picture TEXT,
        status TEXT NOT NULL DEFAULT 'offline',
        last_username_change TEXT,
        last_seen TEXT,
        location TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Messages table
    batch.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        receiver_id TEXT,
        conversation_id TEXT,
        timestamp TEXT NOT NULL,
        is_offline INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        message_hash TEXT UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Conversations table
    batch.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        name TEXT,
        type TEXT NOT NULL DEFAULT 'direct',
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Conversation participants table
    batch.execute('''
      CREATE TABLE conversation_participants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        joined_at TEXT NOT NULL,
        left_at TEXT,
        role TEXT NOT NULL DEFAULT 'member',
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        UNIQUE(conversation_id, user_id)
      )
    ''');

    // Friends table
    batch.execute('''
      CREATE TABLE friends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        friend_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (friend_id) REFERENCES users (id) ON DELETE CASCADE,
        UNIQUE(user_id, friend_id)
      )
    ''');

    // Connection requests table
    batch.execute('''
      CREATE TABLE connection_requests (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        message TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        sent_at TEXT NOT NULL,
        responded_at TEXT,
        FOREIGN KEY (from_user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (to_user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // App settings table
    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'string',
        updated_at TEXT NOT NULL
      )
    ''');

    // Error logs table
    batch.execute('''
      CREATE TABLE error_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        message TEXT NOT NULL,
        severity TEXT NOT NULL,
        category TEXT NOT NULL,
        stack_trace TEXT,
        context TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    // Cached friends table (for offline-first chat list)
    batch.execute('''
      CREATE TABLE cached_friends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        friend_id TEXT NOT NULL,
        name TEXT NOT NULL,
        handle TEXT NOT NULL,
        virtual_number TEXT,
        avatar TEXT,
        last_message TEXT,
        last_message_time TEXT NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        is_online INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT NOT NULL,
        UNIQUE(user_id, friend_id)
      )
    ''');

    // Cached conversations table (for offline-first conversation metadata)
    batch.execute('''
      CREATE TABLE cached_conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        friend_id TEXT NOT NULL,
        last_message TEXT,
        last_message_time TEXT NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT NOT NULL,
        UNIQUE(user_id, friend_id)
      )
    ''');

    // Create indexes for better performance
    batch.execute(
      'CREATE INDEX idx_messages_conversation_id ON messages(conversation_id)',
    );
    batch.execute('CREATE INDEX idx_messages_sender_id ON messages(sender_id)');
    batch.execute('CREATE INDEX idx_messages_timestamp ON messages(timestamp)');
    batch.execute('CREATE INDEX idx_messages_status ON messages(status)');
    batch.execute('CREATE INDEX idx_messages_hash ON messages(message_hash)');
    batch.execute('CREATE INDEX idx_friends_user_id ON friends(user_id)');
    batch.execute('CREATE INDEX idx_friends_status ON friends(status)');
    batch.execute(
      'CREATE INDEX idx_connection_requests_to_user ON connection_requests(to_user_id)',
    );
    batch.execute(
      'CREATE INDEX idx_conversation_participants_conversation ON conversation_participants(conversation_id)',
    );
    batch.execute(
      'CREATE INDEX idx_error_logs_timestamp ON error_logs(timestamp)',
    );
    batch.execute(
      'CREATE INDEX idx_cached_friends_user_id ON cached_friends(user_id)',
    );
    batch.execute(
      'CREATE INDEX idx_cached_friends_last_message_time ON cached_friends(last_message_time)',
    );
    batch.execute(
      'CREATE INDEX idx_cached_conversations_user_id ON cached_conversations(user_id)',
    );
    batch.execute(
      'CREATE INDEX idx_cached_conversations_cached_at ON cached_conversations(cached_at)',
    );

    await batch.commit(noResult: true);
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema migrations here
    if (oldVersion < 2) {
      // Add location column to users table
      await db.execute('ALTER TABLE users ADD COLUMN location TEXT');
    }

    if (oldVersion < 3) {
      // Add cache tables for WhatsApp-style offline-first architecture
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_friends (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          friend_id TEXT NOT NULL,
          name TEXT NOT NULL,
          handle TEXT NOT NULL,
          virtual_number TEXT,
          avatar TEXT,
          last_message TEXT,
          last_message_time TEXT NOT NULL,
          unread_count INTEGER NOT NULL DEFAULT 0,
          is_online INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          cached_at TEXT NOT NULL,
          UNIQUE(user_id, friend_id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_conversations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          friend_id TEXT NOT NULL,
          last_message TEXT,
          last_message_time TEXT NOT NULL,
          unread_count INTEGER NOT NULL DEFAULT 0,
          cached_at TEXT NOT NULL,
          UNIQUE(user_id, friend_id)
        )
      ''');

      // Add indexes for cache tables
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cached_friends_user_id ON cached_friends(user_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cached_friends_last_message_time ON cached_friends(last_message_time)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cached_conversations_user_id ON cached_conversations(user_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cached_conversations_cached_at ON cached_conversations(cached_at)',
      );
    }
  }

  /// Execute a query with error handling
  Future<List<Map<String, dynamic>>> query(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    try {
      final db = await database;
      return await db.rawQuery(sql, arguments);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Query failed: $sql',
          stackTrace: stackTrace,
          context: {'sql': sql, 'arguments': arguments},
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Execute an insert with error handling
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    try {
      final db = await database;
      return await db.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Insert failed for table: $table',
          stackTrace: stackTrace,
          context: {'table': table, 'values': values},
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Execute an update with error handling
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    try {
      final db = await database;
      return await db.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Update failed for table: $table',
          stackTrace: stackTrace,
          context: {'table': table, 'values': values, 'where': where},
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Execute a delete with error handling
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Delete failed for table: $table',
          stackTrace: stackTrace,
          context: {'table': table, 'where': where},
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Execute a transaction with error handling
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      final db = await database;
      return await db.transaction(action);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Transaction failed',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
      rethrow;
    }
  }

  /// Get database file size
  Future<int> getDatabaseSize() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final databasePath = path.join(documentsDirectory.path, _databaseName);
      final file = File(databasePath);

      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Vacuum database to reclaim space
  Future<void> vacuum() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Database vacuum failed',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete database file (for testing/reset)
  Future<void> deleteDatabase() async {
    try {
      await close();
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final databasePath = path.join(documentsDirectory.path, _databaseName);
      final file = File(databasePath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        AppError.database(
          message: 'Failed to delete database',
          stackTrace: stackTrace,
          originalException: e is Exception ? e : Exception(e.toString()),
        ),
      );
    }
  }
}
