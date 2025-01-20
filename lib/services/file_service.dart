import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileService {
  static Future<String> copyAudioToAppDirectory(String sourcePath) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}${path.extension(sourcePath)}';
    final String destinationPath = path.join(appDir.path, 'audio_files', fileName);

    // Créer le dossier audio_files s'il n'existe pas
    final Directory audioDir = Directory(path.dirname(destinationPath));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    // Copier le fichier
    final File sourceFile = File(sourcePath);
    await sourceFile.copy(destinationPath);

    return destinationPath;
  }

  static Future<void> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Erreur lors de la suppression du fichier: $e');
    }
  }
} 