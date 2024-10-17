import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Organizer App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const FolderListScreen(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('card_organizer.db');
    return _database!;
  }

  Future<Database> _initDB(String dbName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, dbName);
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Folders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_name TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE Cards(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_name TEXT NOT NULL,
        suit TEXT NOT NULL,
        image_url TEXT NOT NULL,
        folder_id INTEGER,
        FOREIGN KEY (folder_id) REFERENCES Folders (id)
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    final db = await instance.database;
    return await db.query('Folders');
  }

  Future<int> addFolder(String folderName) async {
    final db = await instance.database;
    return await db.insert('Folders', {
      'folder_name': folderName,
      'timestamp': DateTime.now().toString(),
    });
  }

  Future<int> deleteFolder(int folderId) async {
    final db = await instance.database;
    return await db.delete('Folders', where: 'id = ?', whereArgs: [folderId]);
  }

  Future<int> deleteCardsInFolder(int folderId) async {
    final db = await instance.database;
    return await db.delete('Cards', where: 'folder_id = ?', whereArgs: [folderId]);
  }
}

class FolderListScreen extends StatefulWidget {
  const FolderListScreen({super.key});

  @override
  _FolderListScreenState createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  List<Map<String, dynamic>> _folders = [];
  late Database _db;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _fetchFolders();
  }

  Future<void> _initializeDatabase() async {
    _db = await DatabaseHelper.instance.database;
  }

  Future<void> _fetchFolders() async {
    final List<Map<String, dynamic>> folders = await _db.query('Folders');
    setState(() {
      _folders = folders;
    });
  }

  Future<void> _deleteFolder(int folderId) async {
    await _db.transaction((txn) async {
      await DatabaseHelper.instance.deleteCardsInFolder(folderId);
      await DatabaseHelper.instance.deleteFolder(folderId);
    });
    _fetchFolders(); // Refresh the folder list
  }

  Future<void> _showDeleteConfirmationDialog(int folderId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('Are you sure you want to delete this folder and all its cards?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await _deleteFolder(folderId);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddFolderDialog() async {
    String folderName = '';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add Folder'),
          content: TextField(
            onChanged: (value) {
              folderName = value;
            },
            decoration: const InputDecoration(hintText: 'Folder Name'),
          ),

          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),

            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                if (folderName.isNotEmpty) {
                  await DatabaseHelper.instance.addFolder(folderName);
                  _fetchFolders(); // Refresh the folder list
                  Navigator.of(dialogContext).pop();
                }
              },

            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddFolderDialog,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _folders.length,
        itemBuilder: (context, index) {
          final folder = _folders[index];
          return ListTile(
            title: Text(folder['folder_name']),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmationDialog(folder['id']),
            ),
          );
        },
      ),
    );
  }
}