import 'account.dart';

/// Repository contract — implemented in `data/`, backed by Drift.
/// All methods throw [Failure] subclasses on error, never return null
/// silently for required entities (use Nullable getters where noted).
abstract class AccountRepository {
  Future<Account> createAccount({
    required String name,
    required String currencyCode,
    required int openingBalanceMinor,
    String? description,
    String? iconKey,
    String? colorKey,
  });

  /// Edit metadata only — currency is immutable once transactions exist.
  Future<Account> updateMetadata({
    required String id,
    String? name,
    String? description,
    String? iconKey,
    String? colorKey,
  });

  Future<Account> setArchived({required String id, required bool archived});

  /// Throws [ValidationFailure] if transactions reference this account.
  /// Prefer [setArchived] for historical accounts.
  Future<void> deleteAccount(String id);

  Future<Account?> getById(String id);
  Future<List<Account>> getAll({bool includeArchived = false});
  Stream<List<Account>> watchAll({bool includeArchived = false});

  /// Current balance = opening + income + transfersIn - expenses - transfersOut.
  Future<int> getBalance(String accountId);

  /// Totals separately by currency — never sums unlike currencies.
  Future<Map<String, int>> getTotalBalancesByCurrency({
    bool includeArchived = true,
  });
}
