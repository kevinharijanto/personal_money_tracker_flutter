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

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return CategoryModel.fromJson(data);
  }

  /// DELETE /api/categories/YOUR_CATEGORY_ID
  Future<void> deleteCategory(String categoryId) async {
    await ApiClient.delete('/api/categories/$categoryId');
  }
}
