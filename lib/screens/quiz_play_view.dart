import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../widgets/expandable_image.dart';

class QuizPlayView extends StatefulWidget {
  final Quiz quiz;

  const QuizPlayView({
    super.key,
    required this.quiz,
  });

  @override
  State<QuizPlayView> createState() => _QuizPlayViewState();
}

class _QuizPlayViewState extends State<QuizPlayView> {
  int _currentIndex = 0;
  int _score = 0;
  bool _finished = false;

  int? _selectedChoiceIndex;
  bool _showFeedback = false;

  void _answerQuestion(int choiceIndex) {
    final questions = widget.quiz.questions;
    if (_finished || _showFeedback || _currentIndex >= questions.length) return;

    final question = questions[_currentIndex];
    final isCorrect = choiceIndex == question.correctIndex;

    setState(() {
      _selectedChoiceIndex = choiceIndex;
      _showFeedback = true;
      if (isCorrect) {
        _score++;
        playSound("answer_correct");
      } else {
        playSound("answer_wrong");
      }
    });

    // Delay to show animation and highlights, then go next / finish
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;

      if (_currentIndex == questions.length - 1) {
        setState(() {
          _finished = true;
          _showFeedback = false;
          playSound("quiz_finish");
        });
      } else {
        setState(() {
          _currentIndex++;
          _selectedChoiceIndex = null;
          _showFeedback = false;
        });
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _finished = false;
      _selectedChoiceIndex = null;
      _showFeedback = false;
    });
  }

  // Method for playing the sound if right or wrong
  final AudioPlayer _player = AudioPlayer();
  Future<void> playSound(String answer) async {
    await _player.play(UrlSource('assets/$answer.wav'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final questions = widget.quiz.questions;

    if (questions.isEmpty) {
      return Center(
        child: Text(
          'This quiz has no questions yet.\nSwitch to Edit mode to add some.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface.withOpacity(0.7),
          ),
        ),
      );
    }

    if (_finished) {
      final total = questions.length;
      final percent = (total == 0) ? 0 : ((_score / total) * 100).round();

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Quiz Finished!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Score: $_score / $total  ($percent%)',
                style: TextStyle(
                  fontSize: 18,
                  color: cs.onSurface.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _restartQuiz,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart'),
              ),
            ],
          ),
        ),
      );
    }

    final question = questions[_currentIndex];
    final visibleChoiceIndices = List<int>.generate(
      question.choices.length,
          (i) => i,
    ).where((i) => question.choices[i].trim().isNotEmpty).toList();

    final isCorrectSelection = _selectedChoiceIndex != null &&
        _selectedChoiceIndex == question.correctIndex;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Question ${_currentIndex + 1} of ${questions.length}',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / questions.length,
          ),
          const SizedBox(height: 24),

          // Optional image above the question
          if (question.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ExpandableImage(
                imageUrl: question.imageUrl!,
                height: 200,
              ),
            ),


          // Question
          Text(
            question.text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Animated feedback icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showFeedback && _selectedChoiceIndex != null
                ? Icon(
              isCorrectSelection ? Icons.check_circle : Icons.cancel,
              key: ValueKey('feedback_${_currentIndex}_$_selectedChoiceIndex'),
              size: 40,
              color: isCorrectSelection ? Colors.green : cs.error,
            )
                : const SizedBox(height: 40),
          ),

          const SizedBox(height: 16),

          // Choices
          Expanded(
            child: ListView.separated(
              itemCount: visibleChoiceIndices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final choiceIdx = visibleChoiceIndices[idx];
                final label = question.choices[choiceIdx];

                final bool isSelected = _selectedChoiceIndex == choiceIdx;
                final bool isCorrectChoice =
                    choiceIdx == question.correctIndex;

                // Color logic when showing feedback
                Color? background;
                Color? foreground;

                if (_showFeedback && _selectedChoiceIndex != null) {
                  if (isCorrectChoice) {
                    // highlight correct answer
                    background = Colors.green.withOpacity(0.18);
                    foreground = Colors.green.shade800;
                  } else if (isSelected && !isCorrectChoice) {
                    // selected but wrong
                    background = cs.error.withOpacity(0.18);
                    foreground = cs.error;
                  } else {
                    // other choices – dim them
                    background = cs.surfaceVariant.withOpacity(0.3);
                    foreground = cs.onSurface.withOpacity(0.7);
                  }
                }

                return ElevatedButton(
                  onPressed: (_showFeedback || _finished)
                      ? null
                      : () => _answerQuestion(choiceIdx),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    alignment: Alignment.centerLeft,
                    backgroundColor: background,
                    foregroundColor: foreground,
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
