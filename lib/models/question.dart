// lib/models/question.dart
enum QuestionType {
  trueFalse,
  multipleChoice,
}

class Question {
  final String id;
  final QuestionType type;
  final String text;
  final List<String> choices;
  final int correctIndex;

  /// NEW: URL to an image stored in Firebase Storage (or elsewhere)
  final String? imageUrl;

  Question({
    required this.id,
    required this.type,
    required this.text,
    required this.choices,
    required this.correctIndex,
    this.imageUrl,
  });

  Question copyWith({
    String? id,
    QuestionType? type,
    String? text,
    List<String>? choices,
    int? correctIndex,
    String? imageUrl,
  }) {
    return Question(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      choices: choices ?? this.choices,
      correctIndex: correctIndex ?? this.correctIndex,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name, // 'trueFalse' or 'multipleChoice'
      'text': text,
      'choices': choices,
      'correctIndex': correctIndex,
      'imageUrl': imageUrl, // <--- stored as URL string in Firestore
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    // Backwards compatibility: support old 'imagePath' field if present
    final dynamic rawType = json['type'];
    QuestionType parsedType;

    if (rawType is String) {
      parsedType = rawType == 'trueFalse'
          ? QuestionType.trueFalse
          : QuestionType.multipleChoice;
    } else {
      // Fallback in weird cases
      parsedType = QuestionType.multipleChoice;
    }

    return Question(
      id: json['id'] as String,
      type: parsedType,
      text: json['text'] as String,
      choices: List<String>.from(json['choices'] as List),
      correctIndex: json['correctIndex'] as int,
      imageUrl: (json['imageUrl'] ?? json['imagePath']) as String?, // 👈 compat
    );
  }
}

