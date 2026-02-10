import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key, required this.searchQuery});

  final ValueListenable<String> searchQuery;

  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('foods')
          .orderBy('title')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        return ValueListenableBuilder<String>(
          valueListenable: widget.searchQuery,
          builder: (context, query, _) {
            final filtered = docs.where((doc) {
              if (query.trim().isEmpty) {
                return true;
              }
              final lower = query.toLowerCase();
              final data = doc.data();
              final title = data['title']?.toString() ?? '';
              final category = data['category']?.toString() ?? '';
              return ('$title $category').toLowerCase().contains(lower);
            }).toList();

            final width = MediaQuery.of(context).size.width;
            final crossAxisCount = width > 1700
                ? 5
                : (width > 1400
                    ? 4
                    : (width > 1100 ? 3 : (width > 820 ? 2 : 1)));

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Foods',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 12),
                      _CountPill(count: filtered.length),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => const FoodFormDialog(),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Food'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FoodHintBar(total: filtered.length),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No foods found.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio:
                                  crossAxisCount >= 4 ? 1.35 : 1.55,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              return _FoodCard(doc: doc);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final imageUrl = (data['imageUrl']?.toString() ?? '').trim();
    final title = data['title']?.toString() ?? 'Food';
    final category = data['category']?.toString() ?? '';
    final price = data['price']?.toString() ?? '';
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final calories = data['calories']?.toString() ?? '';
    final time = data['time']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 120,
                color: Colors.grey.shade100,
                child: imageUrl.isEmpty
                    ? const Icon(Icons.image_not_supported)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CategoryChip(label: category),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        icon: Icons.star,
                        label: rating == 0 ? 'Unrated' : rating.toStringAsFixed(1),
                      ),
                      if (calories.isNotEmpty)
                        _MetaChip(
                          icon: Icons.local_fire_department,
                          label: '$calories kcal',
                        ),
                      if (time.isNotEmpty)
                        _MetaChip(
                          icon: Icons.schedule,
                          label: time,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'GHS $price',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => FoodFormDialog(
                        docId: doc.id,
                        existing: data,
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete food?'),
                        content:
                            const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await doc.reference.delete();
                      Fluttertoast.showToast(
                        msg: 'Food deleted',
                        gravity: ToastGravity.BOTTOM,
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count items',
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _FoodHintBar extends StatelessWidget {
  const _FoodHintBar({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: Use "Create & Add Another" to add multiple foods quickly.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            'Total: $total',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.isEmpty ? 'Uncategorized' : label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class FoodFormDialog extends StatefulWidget {
  const FoodFormDialog({super.key, this.docId, this.existing});

  final String? docId;
  final Map<String, dynamic>? existing;

  @override
  State<FoodFormDialog> createState() => _FoodFormDialogState();
}

class _FoodFormDialogState extends State<FoodFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _ratingController = ValueNotifier<double>(4);
  final _caloriesController = TextEditingController();
  final _timeController = TextEditingController();
  Duration _duration = const Duration(minutes: 20);
  final List<String> _categories = [
    'Heavy Meal',
    'Rice & Bean Meal',
    'Side Dishes & Snacks',
  ];
  final _ingredientsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _foodType = <String>{};

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data != null) {
      _titleController.text = data['title']?.toString() ?? '';
      _subtitleController.text = data['subtitle']?.toString() ?? '';
      _categoryController.text = data['category']?.toString() ?? '';
      _descriptionController.text = data['description']?.toString() ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _ratingController.value = (data['rating'] as num?)?.toDouble() ?? 4;
      _caloriesController.text = data['calories']?.toString() ?? '';
      _timeController.text = data['time']?.toString() ?? '';
      _duration = _parseDuration(_timeController.text) ?? _duration;
      _ingredientsController.text =
          (data['ingredients'] as List?)?.join(', ') ?? '';
      _imageUrlController.text = data['imageUrl']?.toString() ?? '';
      final types = (data['foodType'] as List?)?.cast<String>() ?? [];
      _foodType.addAll(types);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _ratingController.dispose();
    _caloriesController.dispose();
    _timeController.dispose();
    _ingredientsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool stayOpen}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final ingredients = _ingredientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = {
      'title': _titleController.text.trim(),
      'subtitle': _subtitleController.text.trim(),
      'category': _categoryController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'rating': _ratingController.value,
      'calories': double.parse(_caloriesController.text.trim()),
      'time': _formatDuration(_duration),
      'ingredients': ingredients,
      'foodType': _foodType.toList(),
      'imageUrl': _imageUrlController.text.trim(),
    };

    try {
      final foods = FirebaseFirestore.instance.collection('foods');
      if (widget.docId == null) {
        await foods.add(payload);
      } else {
        await foods.doc(widget.docId).update(payload);
      }
      if (mounted) {
        Navigator.pop(context);
        if (stayOpen && widget.docId == null) {
          _resetForm();
        } else {
          Navigator.pop(context);
        }
        Fluttertoast.showToast(
          msg: widget.docId == null ? 'Food created' : 'Food updated',
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        Fluttertoast.showToast(
          msg: 'Failed to save food',
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.docId != null;
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Food' : 'Add Food',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEditing
                        ? 'Update this food item.'
                        : 'Create a new food item for the menu.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth > 720;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: twoColumns ? 3 : 1,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _titleController,
                                        decoration: const InputDecoration(
                                          labelText: 'Title',
                                        ),
                                        validator: _requiredField,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _subtitleController,
                                        decoration: const InputDecoration(
                                          labelText: 'Subtitle',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _categoryController.text.isEmpty
                                            ? null
                                            : _categoryController.text,
                                        decoration: const InputDecoration(
                                          labelText: 'Category',
                                        ),
                                        items: _categories
                                            .map(
                                              (cat) => DropdownMenuItem(
                                                value: cat,
                                                child: Text(cat),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _categoryController.text =
                                                value ?? '';
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _timeController,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Prep time',
                                          suffixIcon: Icon(Icons.schedule),
                                        ),
                                        onTap: _pickDuration,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                  ),
                                  maxLines: 3,
                                  validator: _requiredField,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceController,
                                        decoration: const InputDecoration(
                                          labelText: 'Price (GHS)',
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: _numberRequired,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _caloriesController,
                                        decoration: const InputDecoration(
                                          labelText: 'Calories',
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: _numberRequired,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ValueListenableBuilder<double>(
                                  valueListenable: _ratingController,
                                  builder: (context, value, _) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rating: ${value.toStringAsFixed(1)}',
                                        ),
                                        Slider(
                                          min: 1,
                                          max: 5,
                                          divisions: 8,
                                          label: value.toStringAsFixed(1),
                                          value: value,
                                          onChanged: (v) =>
                                              _ratingController.value = v,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _ingredientsController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Ingredients (comma separated)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _imageUrlController,
                                  decoration: const InputDecoration(
                                    labelText: 'Image URL',
                                  ),
                                  validator: _requiredField,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    FilterChip(
                                      label: const Text('Popular Food'),
                                      selected:
                                          _foodType.contains('Popular Food'),
                                      onSelected: (value) => setState(() {
                                        value
                                            ? _foodType.add('Popular Food')
                                            : _foodType.remove('Popular Food');
                                      }),
                                    ),
                                    const SizedBox(width: 8),
                                    FilterChip(
                                      label: const Text('Delicious Foods'),
                                      selected: _foodType
                                          .contains('Delicious Foods'),
                                      onSelected: (value) => setState(() {
                                        value
                                            ? _foodType
                                                .add('Delicious Foods')
                                            : _foodType
                                                .remove('Delicious Foods');
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (twoColumns) const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child:
                                  _imageUrlController.text.trim().isEmpty
                                      ? const Center(
                                          child: Text('Image preview'),
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                                _imageUrlController.text.trim(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Center(
                                                  child: Text(
                                                    'Invalid image URL',
                                                  ),
                                                ),
                                              ),
                                            ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => _save(stayOpen: false),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                  ),
                                  child: Text(isEditing ? 'Update' : 'Create'),
                                ),
                                if (!isEditing) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _save(stayOpen: true),
                                    icon: Icon(
                                      Icons.add_task,
                                      color: scheme.secondary,
                                    ),
                                    label: Text(
                                      'Create & Add Another',
                                      style: TextStyle(color: scheme.secondary),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: scheme.secondary),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      backgroundColor: scheme.secondary
                                          .withValues(alpha: 0.06),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _numberRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a number';
    }
    return null;
  }

  Future<void> _pickDuration() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        const options = [
          5,
          10,
          15,
          20,
          25,
          30,
          35,
          40,
          45,
          50,
          55,
          60,
          75,
          90,
          105,
          120
        ];
        final current = _duration.inMinutes.clamp(5, 120);
        int tempValue = current;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select prep time (minutes)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: tempValue,
                    items: options
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text('$m min'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() => tempValue = value);
                    },
                    decoration:
                        const InputDecoration(labelText: 'Minutes'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, tempValue),
                        child: const Text('Use time'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected == null) {
      return;
    }
    _duration = Duration(minutes: selected);
    _timeController.text = _formatDuration(_duration);
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    return '${totalMinutes} min';
  }

  Duration? _parseDuration(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    final hoursMatch = RegExp(r'(\d+)h').firstMatch(cleaned);
    final minutesMatch = RegExp(r'(\d+)\s*m').firstMatch(cleaned);
    if (hoursMatch == null && minutesMatch == null) {
      final onlyMinutes = int.tryParse(cleaned.replaceAll(RegExp(r'\D'), ''));
      if (onlyMinutes != null) {
        return Duration(minutes: onlyMinutes);
      }
      return null;
    }
    final hours = int.tryParse(hoursMatch?.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(minutesMatch?.group(1) ?? '0') ?? 0;
    return Duration(hours: hours, minutes: minutes);
  }

  void _resetForm() {
    _titleController.clear();
    _subtitleController.clear();
    _categoryController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _caloriesController.clear();
    _timeController.clear();
    _duration = const Duration(minutes: 20);
    _ingredientsController.clear();
    _imageUrlController.clear();
    _ratingController.value = 4;
    _foodType.clear();
    setState(() {});
  }
}
