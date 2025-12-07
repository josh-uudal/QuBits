// screensuiz_maker_view.dart
import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/expandable_image.dart';




class QuizMakerView extends StatelessWidget {
  final Quiz quiz;
  final ValueChanged<Quiz> onQuizUpdated;

  const QuizMakerView({
    super.key,
    required this.quiz,
    required this.onQuizUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Quiz title field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextFormField(
              initialValue: quiz.title,
              decoration: const InputDecoration(
                labelText: 'Quiz title',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                onQuizUpdated(quiz.copyWith(title: value));
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  'Questions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${quiz.questions.length})',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Questions list as review cards
          Expanded(
            child: quiz.questions.isEmpty
                ? Center(
              child: Text(
                'No questions yet.\nTap "Add question" to start.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: quiz.questions.length,
              itemBuilder: (context, index) {
                final q = quiz.questions[index];
                return _QuestionCard(
                  question: q,
                  index: index,
                  onTap: () {
                    _openQuestionEditor(
                      context: context,
                      existingQuestion: q,
                      existingIndex: index,
                    );
                  },
                  onDelete: () {
                    final updatedQuestions =
                    List<Question>.from(quiz.questions)
                      ..removeAt(index);
                    onQuizUpdated(
                      quiz.copyWith(questions: updatedQuestions),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openQuestionEditor(context: context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
      ),
    );
  }

  void _openQuestionEditor({
    required BuildContext context,
    Question? existingQuestion,
    int? existingIndex,
  }) async {
    final result = await showModalBottomSheet<Question>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _QuestionEditorSheet(
          initialQuestion: existingQuestion,
        );
      },
    );

    if (result == null) return;

    final updatedQuestions = List<Question>.from(quiz.questions);

    if (existingIndex != null) {
      updatedQuestions[existingIndex] = result;
    } else {
      updatedQuestions.add(result);
    }

    onQuizUpdated(quiz.copyWith(questions: updatedQuestions));
  }
}

/* ---------- REVIEW CARD FOR EACH QUESTION ---------- */

class _QuestionCard extends StatelessWidget {
  final Question question;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isTF = question.type == QuestionType.trueFalse;
    final typeLabel = isTF ? 'True / False' : 'Multiple Choice';

    String correctAnswer = '';
    if (question.correctIndex >= 0 &&
        question.correctIndex < question.choices.length) {
      correctAnswer = question.choices[question.correctIndex].trim();
    }
    if (correctAnswer.isEmpty && isTF) {
      correctAnswer = question.correctIndex == 0 ? 'True' : 'False';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW: number + type chip + delete aligned together
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Question number circle
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Type chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTF ? Icons.toggle_on : Icons.list_alt,
                          size: 14,
                          color: cs.onSurface.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Delete icon
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: cs.error.withOpacity(0.9),
                    ),
                    onPressed: () async {
                      // Delete image from storage if exists
                      if (question.imageUrl != null) {
                        try {
                          final ref = FirebaseStorage.instance.refFromURL(question.imageUrl!);
                          await ref.delete();
                        } catch (e) {
                          print("Failed to delete image: $e");
                        }
                      }
                      onDelete();
                    },
                    tooltip: 'Delete question',
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Question text
              Text(
                question.text.isEmpty ? '(Untitled question)' : question.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),

              const SizedBox(height: 6),

              // Image preview (if question has an image)
              if (question.imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ExpandableImage(
                    imageUrl: question.imageUrl!,
                    height: 120,
                    borderRadius: 8,
                  ),
                ),

              // Correct answer row
              if (correctAnswer.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Correct answer: $correctAnswer',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/* ---------- BOTTOM SHEET QUESTION EDITOR (unchanged logic) ---------- */

class _QuestionEditorSheet extends StatefulWidget {
  final Question? initialQuestion;

  const _QuestionEditorSheet({this.initialQuestion});

  @override
  State<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<_QuestionEditorSheet> {
  late QuestionType _type;
  late TextEditingController _textController;
  late List<TextEditingController> _choiceControllers;
  int _correctIndex = 0;

  String? _imageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();

    _imageUrl = widget.initialQuestion?.imageUrl;

    final initial = widget.initialQuestion;
    _type = initial?.type ?? QuestionType.trueFalse;

    _textController = TextEditingController(text: initial?.text ?? '');

    _choiceControllers = List.generate(4, (i) {
      String text = '';
      if (initial != null && i < initial.choices.length) {
        text = initial.choices[i];
      } else if (initial == null && _type == QuestionType.trueFalse) {
        if (i == 0) text = 'True';
        if (i == 1) text = 'False';
      }
      return TextEditingController(text: text);
    });

    _correctIndex = initial?.correctIndex ?? 0;

    _imageUrl = initial?.imageUrl; // <-- keep image on edit
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final c in _choiceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTypeChanged(QuestionType? value) {
    if (value == null) return;
    setState(() {
      _type = value;

      if (_type == QuestionType.trueFalse) {
        _choiceControllers[0].text = 'True';
        _choiceControllers[1].text = 'False';
        _choiceControllers[2].text = '';
        _choiceControllers[3].text = '';
        _correctIndex = 0;
      }
    });
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showError('Question text cannot be empty.');
      return;
    }

    List<String> choices =
    _choiceControllers.map((c) => c.text.trim()).toList();

    if (_type == QuestionType.multipleChoice) {
      if (choices.any((c) => c.isEmpty)) {
        _showError('All 4 choices must be filled for multiple choice.');
        return;
      }
    } else {
      // True/False: enforce first two and ignore last two
      choices[0] = choices[0].isEmpty ? 'True' : choices[0];
      choices[1] = choices[1].isEmpty ? 'False' : choices[1];
      choices[2] = '';
      choices[3] = '';
      if (_correctIndex > 1) _correctIndex = 0;
    }

    final newQuestion = Question(
      id: widget.initialQuestion?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      text: text,
      choices: choices,
      correctIndex: _correctIndex,
      imageUrl: _imageUrl, // <-- SAVE IMAGE HERE
    );

    Navigator.of(context).pop(newQuestion);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final file = File(picked.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('quiz_images')
          .child(fileName);

      final snapshot = await storageRef.putFile(file);

      if (snapshot.state == TaskState.success) {
        final url = await storageRef.getDownloadURL();
        setState(() {
          _imageUrl = url;
          _isUploadingImage = false;
        });
      } else {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed.')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initialQuestion == null
                        ? 'New Question'
                        : 'Edit Question',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  )
                ],
              ),

              const SizedBox(height: 12),

              // Type selector
              Row(
                children: [
                  const Text('Type:'),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('True / False'),
                    selected: _type == QuestionType.trueFalse,
                    onSelected: (selected) {
                      if (selected) _onTypeChanged(QuestionType.trueFalse);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Multiple Choice'),
                    selected: _type == QuestionType.multipleChoice,
                    onSelected: (selected) {
                      if (selected) _onTypeChanged(QuestionType.multipleChoice);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
              ),

              const SizedBox(height: 16),


              TextButton.icon(
                onPressed: _isUploadingImage ? null : _pickImage,
                icon: const Icon(Icons.image),
                label: Text(_isUploadingImage ? 'Uploading...' : 'Add Image'),
              ),

              if (_imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              if (_type == QuestionType.trueFalse)
                _buildTrueFalseOptions()
              else
                _buildMultipleChoiceOptions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrueFalseOptions() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Correct answer',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<int>(
                value: 0,
                groupValue: _correctIndex,
                title: const Text('True'),
                onChanged: (val) {
                  setState(() => _correctIndex = val ?? 0);
                },
              ),
            ),
            Expanded(
              child: RadioListTile<int>(
                value: 1,
                groupValue: _correctIndex,
                title: const Text('False'),
                onChanged: (val) {
                  setState(() => _correctIndex = val ?? 1);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceOptions() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choices (select the correct one)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),

        // ---- choices + correct selector ----
        for (int i = 0; i < 4; i++)
          RadioListTile<int>(
            value: i,
            groupValue: _correctIndex,
            onChanged: (val) {
              setState(() => _correctIndex = val ?? 0);
            },
            title: TextField(
              controller: _choiceControllers[i],
              decoration: InputDecoration(
                labelText: 'Choice ${i + 1}',
                border: const OutlineInputBorder(),
              ),
              maxLines: null,
            ),
          ),

        const SizedBox(height: 16),

        // ---- D: Upload button OR spinner ----
        if (_isUploadingImage)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: const Text("Add Image"),
          ),

        // ---- E: Preview + remove/replace ----
        if (_imageUrl != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _imageUrl = null;
                  });
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text("Remove Image"),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _isUploadingImage ? null : _pickImage,
                icon: const Icon(Icons.refresh),
                label: const Text("Replace"),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

