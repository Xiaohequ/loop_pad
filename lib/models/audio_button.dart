import 'dart:ui';

class AudioButton {
  final String? id;
  final String name;
  final String audioPath;
  final String fileName;
  final int color;
  final bool holdToPlay; // true = maintenir appuyé, false = jouer jusqu'à la fin
  final bool loopMode; // Nouvelle propriété
  final bool fadeOutEnabled;  // Nouveau champ
  final int fadeOutDuration; // Durée en millisecondes
  final int orderIndex; // Nouvel attribut

  AudioButton({
    this.id,
    required this.name,
    required this.audioPath,
    required this.fileName,
    this.color = 0,
    this.holdToPlay = false,
    this.loopMode = false,
    this.fadeOutEnabled = false,  // Par défaut désactivé
    this.fadeOutDuration = 500,   // 500ms par défaut
    this.orderIndex = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'audioPath': audioPath,
      'fileName': fileName,
      'color': color,
      'holdToPlay': holdToPlay ? 1 : 0,
      'loopMode': loopMode ? 1 : 0,
      'fadeOutEnabled': fadeOutEnabled ? 1 : 0,
      'fadeOutDuration': fadeOutDuration,
      'orderIndex': orderIndex,
    };
  }

  factory AudioButton.fromMap(Map<String, dynamic> map) {
    return AudioButton(
      id: map['id'],
      name: map['name'],
      audioPath: map['audioPath'],
      fileName: map['fileName'] ?? '',
      color: map['color'],
      holdToPlay: map['holdToPlay'] == 1,
      loopMode: map['loopMode'] == 1,
      fadeOutEnabled: map['fadeOutEnabled'] == 1,
      fadeOutDuration: map['fadeOutDuration'] ?? 500,
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
} 