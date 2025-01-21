class AudioButton {
  final String id;
  final String name;
  final String audioPath;
  final int color;
  final bool holdToPlay; // true = maintenir appuyé, false = jouer jusqu'à la fin
  final bool loopMode; // Nouvelle propriété
  final int orderIndex; // Nouvel attribut

  AudioButton({
    required this.id,
    required this.name,
    required this.audioPath,
    required this.color,
    required this.holdToPlay,
    required this.loopMode,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'audioPath': audioPath,
      'color': color,
      'holdToPlay': holdToPlay ? 1 : 0,
      'loopMode': loopMode ? 1 : 0,
      'orderIndex': orderIndex,
    };
  }

  factory AudioButton.fromMap(Map<String, dynamic> map) {
    return AudioButton(
      id: map['id'],
      name: map['name'],
      audioPath: map['audioPath'],
      color: map['color'],
      holdToPlay: map['holdToPlay'] == 1,
      loopMode: map['loopMode'] == 1,
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
} 