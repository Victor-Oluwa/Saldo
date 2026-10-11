import 'package:saldo/core/errors/failures.dart';

/// Pure domain entity — no Flutter, no Drift.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.openingBalanceMinor,
    this.description,
    this.iconKey,
    this.colorKey,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String currencyCode;
  final int openingBalanceMinor;
  final String? description;
  final String? iconKey;
  final String? colorKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  static void validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Account name is required');
    }
    if (trimmed.length > 100) {
      throw const ValidationFailure('Account name is too long (max 100)');
    }
  }

  static String normalizeCurrency(String code) {
    final upper = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(upper)) {
      throw const ValidationFailure(
        'Currency code must be 3 letters (ISO 4217)',
      );
    }
    return upper;
  }

  Account copyWith({
    String? name,
    String? description,
    String? iconKey,
    String? colorKey,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      currencyCode: currencyCode,
      openingBalanceMinor: openingBalanceMinor,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      colorKey: colorKey ?? this.colorKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
