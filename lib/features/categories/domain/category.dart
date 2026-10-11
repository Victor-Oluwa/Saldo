import 'package:saldo/core/errors/failures.dart';

enum CategoryType { income, expense }

CategoryType categoryTypeFromString(String s) {
  return switch (s) {
    'income' => CategoryType.income,
    'expense' => CategoryType.expense,
    _ => throw ValidationFailure('Unknown category type: $s'),
  };
}

String categoryTypeToString(CategoryType t) => switch (t) {
  CategoryType.income => 'income',
  CategoryType.expense => 'expense',
};

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    this.iconKey,
    this.colorKey,
    this.isSystem = false,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final CategoryType type;
  final String? iconKey;
  final String? colorKey;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  static void validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Category name is required');
    }
    if (trimmed.length > 60) {
      throw const ValidationFailure('Category name is too long (max 60)');
    }
  }
}
