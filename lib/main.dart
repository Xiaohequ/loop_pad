import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models/audio_button.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'services/database_service.dart';
import 'services/file_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soundboard App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SoundboardPage(),
    );
  }
}

class SoundboardPage extends StatefulWidget {
  const SoundboardPage({super.key});

  @override
  State<SoundboardPage> createState() => _SoundboardPageState();
}

class _SoundboardPageState extends State<SoundboardPage> {
  final List<AudioButton> audioButtons = [];
  final audioPlayer = AudioPlayer();
  final recorder = AudioRecorder();
  String? currentlyPlayingId;
  bool editingMode = false;

  @override
  void initState() {
    super.initState();
    _loadButtons();
  }

  Future<void> _loadButtons() async {
    final buttons = await DatabaseService.getButtons();
    setState(() {
      audioButtons.clear();
      audioButtons.addAll(buttons);
    });
  }

  Future<void> _addAudioFromFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      final String savedPath = await FileService.copyAudioToAppDirectory(result.files.single.path!);
      _showAddButtonDialog(savedPath);
    }
  }

  Future<void> _startRecording() async {
    if (await recorder.hasPermission()) {
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = '${tempDir.path}/recorded_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await recorder.start(const RecordConfig(), path: tempPath);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enregistrement en cours'),
            content: ElevatedButton(
              onPressed: () async {
                String? recordedPath = await recorder.stop();
                Navigator.pop(context);
                if (recordedPath != null) {
                  final String savedPath = await FileService.copyAudioToAppDirectory(recordedPath);
                  _showAddButtonDialog(savedPath);
                  // Supprimer le fichier temporaire
                  await FileService.deleteAudioFile(recordedPath);
                }
              },
              child: const Text('Arrêter l\'enregistrement'),
            ),
          ),
        );
      }
    }
  }

  void _showAddButtonDialog(String audioPath) {
    String buttonName = '';
    Color selectedColor = Colors.blue;
    bool holdToPlay = false;

    void changeColor(Color color) {
      selectedColor = color;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un nouveau son'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nom du bouton'),
                onChanged: (value) => buttonName = value,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Choisir une couleur'),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: selectedColor,
                                  onColorChanged: (Color color) {
                                    setState(() {
                                      selectedColor = color;
                                    });
                                  },
                                  pickerAreaHeightPercent: 0.8,
                                  enableAlpha: false,
                                  displayThumbColor: true,
                                  showLabel: false,
                                  paletteType: PaletteType.hsvWithHue,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Choisir une couleur'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Mode de lecture'),
                subtitle: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('Jouer jusqu\'à la fin'),
                      value: false,
                      groupValue: holdToPlay,
                      onChanged: (value) => setState(() => holdToPlay = value!),
                    ),
                    RadioListTile<bool>(
                      title: const Text('Maintenir appuyé pour jouer'),
                      value: true,
                      groupValue: holdToPlay,
                      onChanged: (value) => setState(() => holdToPlay = value!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (buttonName.isNotEmpty) {
                final newButton = AudioButton(
                  id: DateTime.now().toString(),
                  name: buttonName,
                  audioPath: audioPath,
                  color: selectedColor.value,
                  holdToPlay: holdToPlay,
                );
                
                DatabaseService.insertButton(newButton);
                setState(() {
                  audioButtons.add(newButton);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEditButtonDialog(AudioButton button) {
    String buttonName = button.name;
    Color selectedColor = Color(button.color);
    bool holdToPlay = button.holdToPlay;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le bouton'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nom du bouton'),
                controller: TextEditingController(text: buttonName),
                onChanged: (value) => buttonName = value,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Choisir une couleur'),
                              content: SingleChildScrollView(
                                child: ColorPicker(
                                  pickerColor: selectedColor,
                                  onColorChanged: (Color color) {
                                    setState(() {
                                      selectedColor = color;
                                    });
                                  },
                                  pickerAreaHeightPercent: 0.8,
                                  enableAlpha: false,
                                  displayThumbColor: true,
                                  showLabel: false,
                                  paletteType: PaletteType.hsvWithHue,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Choisir une couleur'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Mode de lecture'),
                subtitle: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('Jouer jusqu\'à la fin'),
                      value: false,
                      groupValue: holdToPlay,
                      onChanged: (value) => setState(() => holdToPlay = value!),
                    ),
                    RadioListTile<bool>(
                      title: const Text('Maintenir appuyé pour jouer'),
                      value: true,
                      groupValue: holdToPlay,
                      onChanged: (value) => setState(() => holdToPlay = value!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (buttonName.isNotEmpty) {
                final updatedButton = AudioButton(
                  id: button.id,
                  name: buttonName,
                  audioPath: button.audioPath,
                  color: selectedColor.value,
                  holdToPlay: holdToPlay,
                );
                
                await DatabaseService.updateButton(updatedButton);
                setState(() {
                  final index = audioButtons.indexWhere((b) => b.id == button.id);
                  if (index != -1) {
                    audioButtons[index] = updatedButton;
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteButton(AudioButton button) async {
    // Afficher le dialogue de confirmation
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer le bouton "${button.name}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    // Si l'utilisateur confirme la suppression
    if (confirmDelete == true) {
      // Supprimer le fichier audio
      await FileService.deleteAudioFile(button.audioPath);
      // Supprimer le bouton de la base de données
      await DatabaseService.deleteButton(button.id);
      setState(() {
        audioButtons.removeWhere((b) => b.id == button.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Soundboard'),
        actions: [
          IconButton(
              onPressed: () {
                setState(() {
                  editingMode = !editingMode;
                });
              },
              icon: editingMode ? const Icon(Icons.check) : const Icon(Icons.edit)
          )
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: audioButtons.length,
        itemBuilder: (context, index) {
          final button = audioButtons[index];
          return StreamBuilder<PlayerState>(
            stream: audioPlayer.onPlayerStateChanged,
            builder: (context, snapshot) {
              final isPlaying = currentlyPlayingId == button.id && 
                              snapshot.data == PlayerState.playing;

              return GestureDetector(
                onTapDown: button.holdToPlay ? (_) async {
                  setState(() => currentlyPlayingId = button.id);
                  await audioPlayer.play(DeviceFileSource(button.audioPath));
                } : null,
                onTapUp: button.holdToPlay ? (_) async {
                  await audioPlayer.stop();
                  setState(() => currentlyPlayingId = null);
                } : null,
                onTapCancel: button.holdToPlay ? () async {
                  await audioPlayer.stop();
                  setState(() => currentlyPlayingId = null);
                } : null,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(button.color),
                          padding: const EdgeInsets.all(8),
                        ),
                        onPressed: () async {
                          if(button.holdToPlay){
                            return;
                          }

                          if (isPlaying) {
                            await audioPlayer.stop();
                            setState(() => currentlyPlayingId = null);
                          } else {
                            setState(() => currentlyPlayingId = button.id);
                            await audioPlayer.play(DeviceFileSource(button.audioPath));
                            audioPlayer.onPlayerComplete.listen((_) {
                              setState(() {
                                if (currentlyPlayingId == button.id) {
                                  currentlyPlayingId = null;
                                }
                              });
                            });
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isPlaying ? Icons.stop_circle : Icons.play_circle,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              button.name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (button.holdToPlay)
                              const Text(
                                '(Maintenir)',
                                style: TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if(editingMode) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditButtonDialog(button),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(0.7),
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _deleteButton(button),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.7),
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _addAudioFromFile,
            tooltip: 'Ajouter un fichier audio',
            child: const Icon(Icons.audio_file),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _startRecording,
            tooltip: 'Enregistrer un son',
            child: const Icon(Icons.mic),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    recorder.dispose();
    super.dispose();
  }
}
