import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quiz.dart';
import '../theme_controller.dart';
import 'quiz_maker_view.dart';
import 'quiz_play_view.dart';
import '../data/quiz_repository.dart';


enum QuizViewMode { maker, play }

class QuizShellScreen extends StatefulWidget {
  const QuizShellScreen({super.key});

  @override
  State<QuizShellScreen> createState() => _QuizShellScreenState();
}

class _QuizShellScreenState extends State<QuizShellScreen> {

  final _repo = QuizRepository();

  List<Quiz> _quizzes = [];
  Quiz? _selectedQuiz;
  QuizViewMode _viewMode = QuizViewMode.play;
  StreamSubscription<List<Quiz>>? _quizSub;

  @override
  void initState() {
    super.initState();

    _quizSub = _repo.listenToQuizzes().listen((quizzes) {
      setState(() {
        _quizzes = quizzes;

        // If nothing left at all
        if (_quizzes.isEmpty) {
          _selectedQuiz = null;
          return;
        }

        // If we had a selected quiz, check if it still exists
        if (_selectedQuiz != null) {
          final stillExists = _quizzes.any((q) => q.id == _selectedQuiz!.id);

          if (!stillExists) {
            // The selected quiz was deleted → pick a new one
            _selectedQuiz = _quizzes.first;
          } else {
            // Update the reference to the latest instance from the list
            _selectedQuiz =
                _quizzes.firstWhere((q) => q.id == _selectedQuiz!.id);
          }
        } else {
          // No selected quiz yet, pick the first one
          _selectedQuiz = _quizzes.first;
        }

        // Optional: adjust view mode based on selected quiz content
        _viewMode = _selectedQuiz!.questions.isEmpty
            ? QuizViewMode.maker
            : QuizViewMode.play;
      });
    });
  }

  @override
  void dispose() {
    _quizSub?.cancel();
    super.dispose();
  }

  void _selectQuiz(Quiz quiz) {
    setState(() {
      _selectedQuiz = quiz;
      _viewMode = quiz.questions.isEmpty
          ? QuizViewMode.maker
          : QuizViewMode.play;
    });
    Navigator.of(context).maybePop(); // close drawer
  }

  void _setViewMode(QuizViewMode mode) {
    setState(() {
      _viewMode = mode;
    });
  }

  void _onQuizUpdated(Quiz updated) async {
    setState(() {
      final index = _quizzes.indexWhere((q) => q.id == updated.id);
      if (index != -1) {
        _quizzes[index] = updated;
      } else {
        _quizzes.add(updated);
      }
      _selectedQuiz = updated;
    });

    await _repo.saveQuiz(updated);
  }


  void _createNewQuiz() {
    final newId = FirebaseFirestore.instance.collection('quizzes').doc().id;

    final newQuiz = Quiz(
      id: newId,
      title: 'Untitled quiz',
      questions: const [],
    );

    _onQuizUpdated(newQuiz);
    Navigator.of(context).maybePop();
  }

  void _deleteSelectedQuiz() async {
    if (_selectedQuiz == null) return;
    final id = _selectedQuiz!.id;

    await _repo.deleteQuiz(id);
  }



  void _exportCurrentQuiz() {
    if (_selectedQuiz == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quiz selected to export.')),
      );
      return;
    }

    final jsonString = jsonEncode(_selectedQuiz!.toJson());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Text(
                    'Export Quiz JSON',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can copy this JSON and share it or paste it into another device to import the quiz.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: jsonString),
                    readOnly: true,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: jsonString),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quiz JSON copied to clipboard.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _importQuizFromJson() {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Text(
                    'Import Quiz JSON',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Paste a quiz JSON here (from the Export feature) and tap Import.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Paste quiz JSON here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _handleImportJson(textController.text.trim());
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Import'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleImportJson(String jsonText) {
    if (jsonText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No JSON provided.')),
      );
      return;
    }

    try {
      final data = jsonDecode(jsonText);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('JSON is not an object');
      }

      var importedQuiz = Quiz.fromJson(data);

      // Avoid ID collisions: if ID already exists, give a fresh Firestore ID
      final exists = _quizzes.any((q) => q.id == importedQuiz.id);
      if (exists) {
        final newId =
            FirebaseFirestore.instance.collection('quizzes').doc().id;
        importedQuiz = importedQuiz.copyWith(
          id: newId,
          title: '${importedQuiz.title} (imported)',
        );
      }

      // Reuse existing logic: updates local state + saves to Firestore
      _onQuizUpdated(importedQuiz);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported quiz: ${importedQuiz.title}'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import quiz: $e'),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final quizTitle = _selectedQuiz?.title ?? 'No quiz selected';

    return Scaffold(
      drawer: _buildQuizDrawer(),
      appBar: AppBar(
        title: Text(
          quizTitle,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          _ModeToggle(
            currentMode: _viewMode,
            onChanged: _setViewMode,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedQuiz == null) {
      return const Center(
        child: Text(
          'Create or select a quiz from the menu.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    switch (_viewMode) {
      case QuizViewMode.maker:
        return QuizMakerView(
          key: ValueKey(_selectedQuiz!.id),
          quiz: _selectedQuiz!,
          onQuizUpdated: _onQuizUpdated,
        );
      case QuizViewMode.play:
        return QuizPlayView(
          key: ValueKey(_selectedQuiz!.id),
          quiz: _selectedQuiz!,
        );
    }
  }

  Widget _buildQuizDrawer() {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top logo + app name "Qubits"
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.6),
              ),
              child: Row(
                children: [
                  // Placeholder logo
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: cs.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Qubits",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // "My Quizzes" section label
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                "My Quizzes",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            ),

            // Quiz list
            Expanded(
              child: ListView.builder(
                itemCount: _quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = _quizzes[index];
                  final selected = quiz == _selectedQuiz;

                  return ListTile(
                    title: Text(quiz.title),
                    selected: selected,
                    leading: Icon(
                      selected ? Icons.bookmark : Icons.description_outlined,
                      color:
                      selected ? cs.primary : cs.onSurface.withOpacity(0.7),
                    ),
                    onTap: () => _selectQuiz(quiz),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Actions header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Actions",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            ),

            // New quiz button
            ListTile(
              leading: Icon(Icons.add, color: cs.primary),
              title: const Text("New Quiz"),
              onTap: _createNewQuiz,
            ),

            // Delete selected quiz
            ListTile(
              leading: Icon(Icons.delete, color: cs.error),
              title: const Text("Delete selected quiz"),
              onTap: _selectedQuiz == null
                  ? null
                  : () {
                // show dialog then call _deleteSelectedQuiz()


                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete Quiz?"),
                    content: Text(
                      "Are you sure you want to delete '${_selectedQuiz!.title}'?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          _deleteSelectedQuiz();
                          Navigator.pop(context);
                          Navigator.of(context).maybePop(); // close drawer
                        },
                        child: Text(
                          "Delete",
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),


            // Export current quiz
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text("Export current quiz"),
              onTap: _exportCurrentQuiz,
            ),

            // Import quiz
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text("Import quiz"),
              onTap: _importQuizFromJson,
            ),

// Appearance / Theme toggle
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text("Appearance"),
              subtitle: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.themeMode,
                builder: (context, mode, _) {
                  String label;
                  if (mode == ThemeMode.system) {
                    label = "System";
                  } else if (mode == ThemeMode.light) {
                    label = "Light";
                  } else {
                    label = "Dark";
                  }
                  return Text("Current: $label");
                },
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _buildThemeSelector(context),
                );
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: const Text("System Default"),
            onTap: () {
              ThemeController.setTheme(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: const Text("Light Mode"),
            onTap: () {
              ThemeController.setTheme(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
            onTap: () {
              ThemeController.setTheme(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/* ---------- MODE TOGGLE IN APPBAR ---------- */

class _ModeToggle extends StatelessWidget {
  final QuizViewMode currentMode;
  final ValueChanged<QuizViewMode> onChanged;

  const _ModeToggle({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surfaceVariant.withOpacity(0.4),
      ),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Edit',
            icon: Icons.edit,
            isSelected: currentMode == QuizViewMode.maker,
            onTap: () => onChanged(QuizViewMode.maker),
          ),
          _ToggleButton(
            label: 'Quiz',
            icon: Icons.quiz,
            isSelected: currentMode == QuizViewMode.play,
            onTap: () => onChanged(QuizViewMode.play),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isSelected ? cs.primary : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? cs.onPrimary
                  : cs.onSurface.withOpacity(0.8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? cs.onPrimary
                    : cs.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
