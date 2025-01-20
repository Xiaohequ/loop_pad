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
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $tableName(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            audioPath TEXT NOT NULL,
            color INTEGER NOT NULL,
            holdToPlay INTEGER NOT NULL,
            loopMode INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $tableName ADD COLUMN loopMode INTEGER NOT NULL DEFAULT 0');
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
        'color': button.color,
        'holdToPlay': button.holdToPlay ? 1 : 0,
        'loopMode': button.loopMode ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<AudioButton>> getButtons() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    return List.generate(maps.length, (i) {
      return AudioButton(
        id: maps[i]['id'],
        name: maps[i]['name'],
        audioPath: maps[i]['audioPath'],
        color: maps[i]['color'],
        holdToPlay: maps[i]['holdToPlay'] == 1,
        loopMode: maps[i]['loopMode'] == 1,
      );
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
        'color': button.color,
        'holdToPlay': button.holdToPlay ? 1 : 0,
        'loopMode': button.loopMode ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [button.id],
    );
  }
} 