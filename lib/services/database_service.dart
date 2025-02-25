import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/audio_button.dart';

class DatabaseService {
  static const String tableName = 'audio_buttons';
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'soundboard.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $tableName(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            audioPath TEXT NOT NULL,
            fileName TEXT NOT NULL,
            color INTEGER NOT NULL,
            holdToPlay INTEGER NOT NULL,
            loopMode INTEGER NOT NULL DEFAULT 0,
            fadeOutEnabled INTEGER NOT NULL DEFAULT 0,
            fadeOutDuration INTEGER NOT NULL DEFAULT 500,
            orderIndex INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $tableName ADD COLUMN loopMode INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $tableName ADD COLUMN orderIndex INTEGER NOT NULL DEFAULT 0');
          var buttons = await db.query(tableName, orderBy: 'rowid');
          for (var i = 0; i < buttons.length; i++) {
            await db.update(
              tableName,
              {'orderIndex': i},
              where: 'id = ?',
              whereArgs: [buttons[i]['id']],
            );
          }
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE $tableName ADD COLUMN fileName TEXT NOT NULL DEFAULT ""');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE $tableName ADD COLUMN fadeOutEnabled INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE $tableName ADD COLUMN fadeOutDuration INTEGER NOT NULL DEFAULT 500');
        }
      },
    );
  }

  static Future<void> insertButton(AudioButton button) async {
    final Database db = await database;
    await db.insert(
      tableName,
      {
        'id': button.id,
        'name': button.name,
        'audioPath': button.audioPath,
        'fileName': button.fileName,
        'color': button.color,
        'holdToPlay': button.holdToPlay ? 1 : 0,
        'loopMode': button.loopMode ? 1 : 0,
        'orderIndex': button.orderIndex,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AudioButton>> getButtons() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'orderIndex ASC',
    );

    return List.generate(maps.length, (i) {
      return AudioButton.fromMap(maps[i]);
    });
  }

  static Future<void> deleteButton(String id) async {
    final Database db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteAllButtons() async {
    final Database db = await database;
    await db.delete(tableName);
  }

  static Future<void> updateButton(AudioButton button) async {
    final Database db = await database;
    await db.update(
      tableName,
      {
        'name': button.name,
        'audioPath': button.audioPath,
        'fileName': button.fileName,
        'color': button.color,
        'holdToPlay': button.holdToPlay ? 1 : 0,
        'loopMode': button.loopMode ? 1 : 0,
        'fadeOutEnabled': button.fadeOutEnabled ? 1 : 0,
        'fadeOutDuration': button.fadeOutDuration,
        'orderIndex': button.orderIndex,
      },
      where: 'id = ?',
      whereArgs: [button.id],
    );
  }

  static Future<void> updateButtonsOrder(List<AudioButton> buttons) async {
    final Database db = await database;
    final batch = db.batch();
    
    for (var i = 0; i < buttons.length; i++) {
      batch.update(
        tableName,
        {'orderIndex': i},
        where: 'id = ?',
        whereArgs: [buttons[i].id],
      );
    }
    
    await batch.commit();
  }
} 