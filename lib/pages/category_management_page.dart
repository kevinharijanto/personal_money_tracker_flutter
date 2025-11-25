import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../widgets/app_loading.dart';
import '../widgets/app_error.dart';

class CategoryManagementPage extends StatefulWidget {
  final String categoryType; // 'INCOME' or 'EXPENSE'
  final String title;

  const CategoryManagementPage({
    super.key,
    required this.categoryType,
    required this.title,
  });

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final CategoryService _categoryService = CategoryService();
  late Future<List<CategoryModel>> _future;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshCategories();
  }

  Future<void> _refreshCategories() async {
    setState(() {
      _future = _categoryService.fetchCategories(widget.categoryType);
    });
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>(debugLabel: 'category_add_form_key');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Add ${widget.categoryType == 'INCOME' ? 'Income' : 'Expense'} Category', style: Theme.of(context).textTheme.headlineLarge),
          backgroundColor: Theme.of(context).colorScheme.surface,
          titleTextStyle: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Category name',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a category name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await _categoryService.createCategory(
          name: controller.text.trim(),
          type: widget.categoryType,
        );
        // Force a refresh of the categories list
        setState(() {
          _future = _categoryService.fetchCategories(widget.categoryType);
        });
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _showEditCategoryDialog(CategoryModel category) async {
    final controller = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>(debugLabel: 'category_edit_form_key');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit ${widget.categoryType == 'INCOME' ? 'Income' : 'Expense'} Category', style: Theme.of(context).textTheme.headlineLarge),
          backgroundColor: Theme.of(context).colorScheme.surface,
          titleTextStyle: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Category name',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a category name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await _categoryService.updateCategory(
          categoryId: category.id,
          name: controller.text.trim(),
          type: widget.categoryType,
        );
        // Force a refresh of the categories list
        setState(() {
          _future = _categoryService.fetchCategories(widget.categoryType);
        });
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _showDeleteConfirmation(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete Category', style: Theme.of(context).textTheme.headlineLarge),
          backgroundColor: Theme.of(context).colorScheme.surface,
          titleTextStyle: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          content: Text(
            'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _categoryService.deleteCategory(category.id);
        // Force a refresh of the categories list
        setState(() {
          _future = _categoryService.fetchCategories(widget.categoryType);
        });
      } catch (e) {
        // Handle error silently
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: Theme.of(context).textTheme.headlineLarge),
      ),
      body: FutureBuilder<List<CategoryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return AppError(
              message: 'Error: ${snapshot.error}',
              onRetry: _refreshCategories,
            );
          }

          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No ${widget.categoryType == 'INCOME' ? 'income' : 'expense'} categories yet.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showAddCategoryDialog,
                    child: const Text('Add Category'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshCategories,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      category.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () => _showEditCategoryDialog(category),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _showDeleteConfirmation(category),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
