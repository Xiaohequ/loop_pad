import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
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
      title: 'Sound Pad',
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
  final Map<String, AudioPlayer> audioPlayers = {};
  final Map<String, Completer> audioButtonPromise = {};
  final recorder = AudioRecorder();
  final Set<String> playingButtonIds = {};
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
    bool loopMode = false;

    void changeColor(Color color) {
      selectedColor = color;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
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
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Lecture en boucle'),
                subtitle: const Text('Le son se répète automatiquement'),
                value: loopMode,
                onChanged: (bool value) {
                  setState(() {
                    loopMode = value;
                  });
                },
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
                  loopMode: loopMode,
                  orderIndex: audioButtons.length
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
    bool loopMode = button.loopMode;

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
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Lecture en boucle'),
                subtitle: const Text('Le son se répète automatiquement'),
                value: loopMode,
                onChanged: (bool value) {
                  setState(() {
                    loopMode = value;
                  });
                },
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
                  loopMode: loopMode,
                  orderIndex: audioButtons.length
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

  AudioPlayer _getAudioPlayer(String buttonId) {
    if (!audioPlayers.containsKey(buttonId)) {
      audioPlayers[buttonId] = AudioPlayer();
    }
    return audioPlayers[buttonId]!;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final AudioButton item = audioButtons.removeAt(oldIndex);
      audioButtons.insert(newIndex, item);
    });
    
    // Mettre à jour l'ordre dans la base de données
    await DatabaseService.updateButtonsOrder(audioButtons);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Pad'),
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
      body: editingMode
          ? ReorderableGridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: audioButtons.length,
              itemBuilder: (context, index) {
                final button = audioButtons[index];
                return _buildButtonWidget(button, key: Key(button.id));
              },
              onReorder: _onReorder,
              padding: const EdgeInsets.all(8),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: audioButtons.length,
              itemBuilder: (context, index) {
                final button = audioButtons[index];
                return _buildButtonWidget(button, key: Key(button.id));
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

  Widget _buildButtonWidget(AudioButton button, {Key? key}) {
    return StreamBuilder<PlayerState>(
      key: key,
      stream: _getAudioPlayer(button.id).onPlayerStateChanged,
      builder: (context, snapshot) {
        final isPlaying = playingButtonIds.contains(button.id) && 
                        snapshot.data == PlayerState.playing;

        Completer? stopSonCompleter;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: button.holdToPlay ? (_) async {
            await _playSound(button);
          } : null,
          onTapCancel: button.holdToPlay ? () async {
            stopSonCompleter = Completer();
            stopSonCompleter!.future.then((value) async{
              await _stopSound(button);
            }, onError: (e) => print(e));

            await Future.delayed(const Duration(milliseconds: 50));
            if(!stopSonCompleter!.isCompleted){
              stopSonCompleter!.complete();
            }
          } : null,
          onHorizontalDragStart: button.holdToPlay ? (details) async{
            if(stopSonCompleter != null){
              stopSonCompleter!.completeError("stop sound ignored");
            }
          }: null,
          onVerticalDragStart: button.holdToPlay ? (details) async{
            if(stopSonCompleter != null){
              stopSonCompleter!.completeError("stop sound ignored");
            }
          }: null,
          onHorizontalDragEnd: button.holdToPlay ? (details) async{
            await _stopSound(button);
          }: null,
          onVerticalDragEnd: button.holdToPlay ? (details) async{
            await _stopSound(button);
          }: null,
          child: Stack(
            children: [
              Column(
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
                          await _stopSound(button);
                        } else {
                          await _playSound(button);
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if(!editingMode) ... [
                            Icon(
                              isPlaying ? Icons.stop_circle : Icons.play_circle,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                          ],
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
              if(button.loopMode) ...[
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.loop,
                    color: Colors.white,
                    size: 16,
                  )
                )
              ]
            ]
          ),
        );
      },
    );
  }

  _stopSound(AudioButton button) async {
    print("_stopSound");
    final player = _getAudioPlayer(button.id);
    await player.stop();
    setState(() => playingButtonIds.remove(button.id));
  }

  _playSound(AudioButton button) async {
    final player = _getAudioPlayer(button.id);
    setState(() => playingButtonIds.add(button.id));
    if (button.loopMode) {
      await player.setReleaseMode(ReleaseMode.loop);
    } else {
      await player.setReleaseMode(ReleaseMode.release);
    }
    await player.play(DeviceFileSource(button.audioPath));

    //auto stop
    if (!button.loopMode) {
      player.onPlayerComplete.listen((_) {
        setState(() {
          playingButtonIds.remove(button.id);
        });
      });
    }
  }

  @override
  void dispose() {
    for (var player in audioPlayers.values) {
      player.dispose();
    }
    recorder.dispose();
    super.dispose();
  }
}
