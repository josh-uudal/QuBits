// lib/models/quiz.dart
import 'question.dart';

class Quiz {
  final String id;
  final String title;
  final List<Question> questions;

  Quiz({
    required this.id,
    required this.title,
    required this.questions,
  });

  Quiz copyWith({
    String? id,
    String? title,
    List<Question>? questions,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      questions: questions ?? this.questions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: (json['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled quiz',
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
