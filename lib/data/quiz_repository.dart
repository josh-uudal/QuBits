import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz.dart';

class QuizRepository {
  final _quizzesRef =
  FirebaseFirestore.instance.collection('quizzes');

  // Listen to all quizzes (shared)
  Stream<List<Quiz>> listenToQuizzes() {
    return _quizzesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // ensure id field matches document ID
        data['id'] = doc.id;
        return Quiz.fromJson(data);
      }).toList();
    });
  }

  // Create or update a quiz
  Future<void> saveQuiz(Quiz quiz) async {
    final docRef = _quizzesRef.doc(quiz.id);

    final data = quiz.toJson()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));
  }

  // Delete a quiz
  Future<void> deleteQuiz(String quizId) async {
    await _quizzesRef.doc(quizId).delete();
  }
}
