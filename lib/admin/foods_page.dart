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
            final crossAxisCount = width > 1280 ? 3 : (width > 860 ? 2 : 1);

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
                              childAspectRatio: crossAxisCount == 1 ? 1.5 : 1.7,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
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
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Food';
    final category = data['category']?.toString() ?? '';
    final price = data['price']?.toString() ?? '';

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
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(category),
                  const Spacer(),
                  Text(
                    '\$$price',
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

  Future<void> _save() async {
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
      'time': _timeController.text.trim(),
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
        Navigator.pop(context);
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
        constraints: const BoxConstraints(maxWidth: 720),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: _requiredField,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _subtitleController,
                          decoration:
                              const InputDecoration(labelText: 'Subtitle'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          validator: _requiredField,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _timeController,
                          decoration: const InputDecoration(
                            labelText: 'Time (e.g., 18-22 min)',
                          ),
                          validator: _timeValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: _requiredField,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Price'),
                          keyboardType: TextInputType.number,
                          validator: _numberRequired,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _caloriesController,
                          decoration:
                              const InputDecoration(labelText: 'Calories'),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rating: ${value.toStringAsFixed(1)}'),
                          Slider(
                            min: 1,
                            max: 5,
                            divisions: 8,
                            label: value.toStringAsFixed(1),
                            value: value,
                            onChanged: (v) => _ratingController.value = v,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ingredientsController,
                    decoration: const InputDecoration(
                      labelText: 'Ingredients (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration:
                        const InputDecoration(labelText: 'Image URL'),
                    validator: _requiredField,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Popular Food'),
                        selected: _foodType.contains('Popular Food'),
                        onSelected: (value) => setState(() {
                          value
                              ? _foodType.add('Popular Food')
                              : _foodType.remove('Popular Food');
                        }),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Delicious Foods'),
                        selected: _foodType.contains('Delicious Foods'),
                        onSelected: (value) => setState(() {
                          value
                              ? _foodType.add('Delicious Foods')
                              : _foodType.remove('Delicious Foods');
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _imageUrlController.text.trim().isEmpty
                              ? const Center(
                                  child: Text('Image preview'),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _imageUrlController.text.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Center(
                                      child: Text('Invalid image URL'),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            FilledButton(
                              onPressed: _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.primary,
                              ),
                              child:
                                  Text(isEditing ? 'Update' : 'Create'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  String? _timeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final cleaned = value.trim();
    final regex = RegExp(r'^\d{1,2}-\d{1,2}\s*min$');
    if (!regex.hasMatch(cleaned)) {
      return 'Format like 18-22 min';
    }
    return null;
  }
}
