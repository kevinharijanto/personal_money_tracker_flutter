import 'dart:convert';
import '../services/api_client.dart';

class CategoryModel {
  final String id;
  final String name;
  final String type; // 'INCOME' | 'EXPENSE'

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}

class CategoryService {
  /// GET /api/categories?type=INCOME or EXPENSE
  Future<List<CategoryModel>> fetchCategories(String type, {bool useCache = true}) async {
    final res = await ApiClient.get('/api/categories?type=$type', useCache: useCache);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to load categories: ${res.body}');
    }

    final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/categories
  /// body: { "name": "...", "type": "INCOME" | "EXPENSE" }
  Future<CategoryModel> createCategory({
    required String name,
    required String type, // 'INCOME' or 'EXPENSE'
  }) async {
    final body = {
      'name': name,
      'type': type,
    };

    final res = await ApiClient.post('/api/categories', body);

    // Your API may return 201 Created or 200 OK
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Failed to add category: ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return CategoryModel.fromJson(data);
  }

  /// PUT /api/categories/YOUR_CATEGORY_ID
  /// body: { "name": "...", "type": "INCOME" | "EXPENSE" }
  Future<CategoryModel> updateCategory({
    required String categoryId,
    required String name,
    required String type, // 'INCOME' or 'EXPENSE'
  }) async {
    final body = {
      'name': name,
      'type': type,
    };

    final res = await ApiClient.put('/api/categories/$categoryId', body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to update category: ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return CategoryModel.fromJson(data);
  }

  /// DELETE /api/categories/YOUR_CATEGORY_ID
  Future<void> deleteCategory(String categoryId) async {
    final res = await ApiClient.delete('/api/categories/$categoryId');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to delete category: ${res.body}');
    }
  }
}
