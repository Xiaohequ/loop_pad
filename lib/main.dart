import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
  MobileAds.instance.initialize();
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
  bool fadeOutEnabled = false;
  int fadeOutDuration = 500;
  final Map<String, Timer?> fadeTimers = {};
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadButtons();

    //load ads
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // ID de test
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
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
      allowMultiple: true,
    );

    if (result != null) {
      if(result.files.length == 1) {
        PlatformFile file = result.files.single;
        final String savedPath = await FileService.copyAudioToAppDirectory(file.path!);
        final String buttonName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        _showButtonDialog(audioPath: savedPath, buttonName: buttonName, fileName: file.name);
      }
      else {
        for (PlatformFile file in result.files) {
          if (file.path != null) {
            final String savedPath = await FileService.copyAudioToAppDirectory(file.path!);
            final String buttonName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

            final newButton = AudioButton(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: buttonName,
              audioPath: savedPath,
              fileName: file.name,
              color: Colors.blue.value,
              holdToPlay: false,
              loopMode: false,
              orderIndex: audioButtons.length,
            );

            await DatabaseService.insertButton(newButton);
            setState(() {
              audioButtons.add(newButton);
            });
          }
        }
      }
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
                  _showButtonDialog(audioPath: savedPath);
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

  void _showButtonDialog({
    required String audioPath,
    String? buttonName,
    String? fileName,
    AudioButton? existingButton,  // null pour l'ajout, non-null pour l'édition
  }) {
    final bool isEditing = existingButton != null;
    buttonName = isEditing ? existingButton.name : buttonName ?? '';
    Color selectedColor = isEditing ? Color(existingButton.color) : Colors.blue;
    bool holdToPlay = isEditing ? existingButton.holdToPlay : false;
    bool loopMode = isEditing ? existingButton.loopMode : false;
    bool fadeOutEnabled = isEditing ? existingButton.fadeOutEnabled : false;
    int fadeOutDuration = isEditing ? existingButton.fadeOutDuration : 500;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(isEditing ? 'Modifier le bouton' : 'Ajouter un nouveau son'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nom du bouton'),
                controller: TextEditingController(text: buttonName),
                onChanged: (value) => buttonName = value,
              ),
              if (fileName != null) ... [
                const SizedBox(height: 8),
                Text(
                  'Fichier : $fileName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              _buildColorPicker(selectedColor, (color) => setState(() => selectedColor = color)),
              _buildPlayModeSelector(holdToPlay, (value) => setState(() => holdToPlay = value!)),
              _buildLoopModeSwitch(loopMode, (value) => setState(() => loopMode = value)),
              _buildFadeOutControls(
                fadeOutEnabled,
                fadeOutDuration,
                (enabled) => setState(() => fadeOutEnabled = enabled),
                (duration) => setState(() => fadeOutDuration = duration),
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
              if (buttonName!.isNotEmpty) {
                final button = AudioButton(
                  id: isEditing ? existingButton.id : DateTime.now().millisecondsSinceEpoch.toString(),
                  name: buttonName!,
                  audioPath: isEditing ? existingButton.audioPath : audioPath,
                  fileName: isEditing ? existingButton.fileName : fileName ?? '',
                  color: selectedColor.value,
                  holdToPlay: holdToPlay,
                  loopMode: loopMode,
                  fadeOutEnabled: fadeOutEnabled,
                  fadeOutDuration: fadeOutDuration,
                  orderIndex: isEditing ? existingButton.orderIndex : audioButtons.length,
                );

                if (isEditing) {
                  await DatabaseService.updateButton(button);
                  setState(() {
                    final index = audioButtons.indexWhere((b) => b.id == button.id);
                    if (index != -1) {
                      audioButtons[index] = button;
                    }
                  });
                } else {
                  await DatabaseService.insertButton(button);
                  setState(() {
                    audioButtons.add(button);
                  });
                }
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? 'Modifier' : 'Ajouter'),
          ),
        ],
      ),
    );
  }

  // Widgets d'interface utilisateur extraits
  Widget _buildColorPicker(Color selectedColor, void Function(Color) onColorChanged) {
    return Column(
      children: [
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
                onPressed: () => _showColorPickerDialog(selectedColor, onColorChanged),
                child: const Text('Choisir une couleur'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  _showColorPickerDialog(Color selectedColor, void Function(Color) onColorChanged){
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choisir une couleur'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: onColorChanged,
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
  }

  Widget _buildPlayModeSelector(bool holdToPlay, void Function(bool?) onChanged) {
    return ListTile(
      title: const Text('Mode de lecture'),
      subtitle: Column(
        children: [
          RadioListTile<bool>(
            title: const Text('Jouer jusqu\'à la fin'),
            value: false,
            groupValue: holdToPlay,
            onChanged: onChanged,
          ),
          RadioListTile<bool>(
            title: const Text('Maintenir appuyé pour jouer'),
            value: true,
            groupValue: holdToPlay,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLoopModeSwitch(bool loopMode, void Function(bool) onChanged) {
    return SwitchListTile(
      title: const Text('Lecture en boucle'),
      subtitle: const Text('Le son se répète automatiquement'),
      value: loopMode,
      onChanged: onChanged,
    );
  }

  Widget _buildFadeOutControls(
    bool fadeOutEnabled,
    int fadeOutDuration,
    void Function(bool) onEnabledChanged,
    void Function(int) onDurationChanged,
  ) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Fondu de sortie'),
          subtitle: const Text('Le son s\'arrête progressivement'),
          value: fadeOutEnabled,
          onChanged: onEnabledChanged,
        ),
        if (fadeOutEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Durée du fondu : '),
                Expanded(
                  child: Slider(
                    value: fadeOutDuration.toDouble(),
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    label: '${(fadeOutDuration / 1000).toStringAsFixed(1)}s',
                    onChanged: (value) => onDurationChanged(value.round()),
                  ),
                ),
              ],
            ),
          ),
      ],
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
      await DatabaseService.deleteButton(button.id!);
      setState(() {
        audioButtons.removeWhere((b) => b.id == button.id);
      });
    }
  }

  AudioPlayer _getAudioPlayer(String buttonId) {
    if (!audioPlayers.containsKey(buttonId)) {
      final player = AudioPlayer();

      // Gérer la fin de la lecture
      player.onPlayerComplete.listen((_) {
        print("onPlayerComplete");
        fadeTimers[buttonId]?.cancel();

        setState(() {
          playingButtonIds.remove(buttonId);
        });
      });

      audioPlayers[buttonId] = player;
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
          if(audioButtons.isNotEmpty)
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
      body: Column(
        children: [
          if (_isAdLoaded)
            SizedBox(
              height: 40,
              child: AdWidget(ad: _bannerAd!),
            ),
            Expanded(
              child: _buildMainPage(context)
            )
        ],
      ),
      floatingActionButton: audioButtons.isEmpty ? null : Row(
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

  _buildMainPage(BuildContext context) {
    // Calculer la hauteur nécessaire pour les boutons flottants plus une marge
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0; // 80.0 pour la hauteur des FAB + marge

    if(audioButtons.isEmpty){
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Aucun son disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addAudioFromFile,
              icon: const Icon(Icons.audio_file),
              label: const Text('Choisir un fichier audio'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
              label: const Text('Enregistrer un son'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if(editingMode){
      return ReorderableGridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: audioButtons.length,
        itemBuilder: (context, index) {
          final button = audioButtons[index];
          return _buildButtonWidget(button, key: Key(button.id!));
        },
        onReorder: _onReorder,
        padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: audioButtons.length,
      itemBuilder: (context, index) {
        final button = audioButtons[index];
        return _buildButtonWidget(button, key: Key(button.id!));
      },
    );
  }

  Widget _buildButtonWidget(AudioButton button, {Key? key}) {
    return StreamBuilder<PlayerState>(
      key: key,
      stream: _getAudioPlayer(button.id!).onPlayerStateChanged,
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
            // print("onTapCancel");
            stopSonCompleter = Completer();
            stopSonCompleter!.future.then((value) async{
              await _stopSound(button);
            }, onError: (e) => print(e));

            await Future.delayed(const Duration(milliseconds: 100));
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
                        shape: BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(3))),
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
                              color: Colors.white,
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            button.name,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(color: Colors.white),
                          ),
                          if (button.holdToPlay)
                            const Text(
                              '(Maintenir)',
                              style: TextStyle(fontSize: 10, color: Colors.white),
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
                          onPressed: () => _showButtonDialog(audioPath: button.audioPath, existingButton: button),
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

  Future<void> _stopSound(AudioButton button) async {
    print("_stopSound");
    final player = _getAudioPlayer(button.id!);
    
    if (button.fadeOutEnabled && player.state == PlayerState.playing) {
      await _fadeOut(player, button);
    }
    
    await player.stop();
    setState(() => playingButtonIds.remove(button.id));
  }

  _playSound(AudioButton button) async {
    print("_playSound");
    final player = _getAudioPlayer(button.id!);
    setState(() => playingButtonIds.add(button.id!));
    if (button.loopMode) {
      await player.setReleaseMode(ReleaseMode.loop);
    } else {
      await player.setReleaseMode(ReleaseMode.release);
    }
    // Remettre le volume à sa valeur initiale pour la prochaine lecture
    await player.setVolume(1.0);
    await player.play(DeviceFileSource(button.audioPath));

    if (!button.loopMode) {
      // Obtenir la durée totale du son
      Duration? duration = await player.getDuration();
      if (duration != null && button.fadeOutEnabled) {
        // Démarrer le fondu un peu avant la fin
        int fadeStartTime = duration.inMilliseconds - button.fadeOutDuration;

        await _fadeOut(player, button, fadeStartTime);
      }
    }
  }

  _fadeOut(AudioPlayer player, AudioButton button, [int? fadeStartTime]) async {
    // Annuler le timer précédent s'il existe
    fadeTimers[button.id]?.cancel();

    // Attendre jusqu'au moment de démarrer le fondu
    if(fadeStartTime != null){
      fadeTimers[button.id!] = Timer(Duration(milliseconds: fadeStartTime), () async {
        if(!playingButtonIds.contains(button.id)) return;
        
        await _executeFadeOut(player, button);
      });
      return;
    }

    if(!playingButtonIds.contains(button.id)) return;
    await _executeFadeOut(player, button);
  }

  Future<void> _executeFadeOut(AudioPlayer player, AudioButton button) async {
    print("_fadeOut start");

    // Calculer le pas de diminution
    int steps = 10;
    double currentVolume = await player.volume;
    double volumeStep = currentVolume / steps;
    int stepDuration = (button.fadeOutDuration / steps).ceil();

    // Effectuer le fondu
    for (int i = steps - 1; i >= 0; i--) {
      if (!playingButtonIds.contains(button.id)) break;
      await player.setVolume(volumeStep * i);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  @override
  void dispose() {
    // Annuler tous les timers en cours
    for (var timer in fadeTimers.values) {
      timer?.cancel();
    }
    fadeTimers.clear();
    
    for (var player in audioPlayers.values) {
      player.dispose();
    }
    recorder.dispose();

    _bannerAd?.dispose();
    super.dispose();
  }
}
