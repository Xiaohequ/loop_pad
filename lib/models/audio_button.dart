class AudioButton {
  final String id;
  final String name;
  final String audioPath;
  final int color;
  final bool holdToPlay; // true = maintenir appuyé, false = jouer jusqu'à la fin

  AudioButton({
    required this.id,
    required this.name,
    required this.audioPath,
    required this.color,
    required this.holdToPlay,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'audioPath': audioPath,
      'color': color,
      'holdToPlay': holdToPlay,
    };
  }

  factory AudioButton.fromMap(Map<String, dynamic> map) {
    return AudioButton(
      id: map['id'],
      name: map['name'],
      audioPath: map['audioPath'],
      color: map['color'],
      holdToPlay: map['holdToPlay'],
    );
  }
} 