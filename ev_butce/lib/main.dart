import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ANDROID • LOCAL ONLY (No Firebase)
/// Persistence: SharedPreferences JSON blob.
/// Required:
///   flutter pub add shared_preferences

void main() {
  runApp(const EvButceApp());
}

class EvButceApp extends StatelessWidget {
  const EvButceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0EA5E9),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'EV Bütçe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F3F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 74,
          indicatorColor: scheme.primary.withOpacity(0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

enum PaymentMethod { cash, debit, creditCard, multinet }
enum IncomeType { salary, rent, multinet, extra }
enum AccountKind { cash, bankCard }

String paymentLabel(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Nakit';
    case PaymentMethod.debit:
      return 'Hesap Kartı';
    case PaymentMethod.creditCard:
      return 'Kredi Kartı';
    case PaymentMethod.multinet:
      return 'Multinet';
  }
}

String incomeTypeLabel(IncomeType t) {
  switch (t) {
    case IncomeType.salary:
      return 'Maaş';
    case IncomeType.rent:
      return 'Kira';
    case IncomeType.multinet:
      return 'Multinet';
    case IncomeType.extra:
      return 'Ek Ödeme';
  }
}

String accountKindLabel(AccountKind k) => k == AccountKind.cash ? 'Nakit' : 'Hesap Kartı';

String fmtMoney(double v) => '${v.toStringAsFixed(2)} ₺';
String fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String monthKey(int y, int m) => '${y.toString().padLeft(4, '0')}${m.toString().padLeft(2, '0')}';
String genId() => DateTime.now().microsecondsSinceEpoch.toString();

String monthNameTR(int m) {
  const names = [
    'OCAK',
    'ŞUBAT',
    'MART',
    'NİSAN',
    'MAYIS',
    'HAZİRAN',
    'TEMMUZ',
    'AĞUSTOS',
    'EYLÜL',
    'EKİM',
    'KASIM',
    'ARALIK'
  ];
  return names[(m - 1).clamp(0, 11)];
}

const List<String> kCategories = [
  'SAĞLIK',
  'MULTINET',
  'ÖZEL OKUL',
  'OKUL İHTİYAÇ',
  'MARKET',
  'GEZME',
  'EV',
  'FIRIN',
  'FATURA',
  'AİDAT',
  'TEKEL',
  'GİYİM',
  'SİGARA',
  'DEFNE',
  'OKUL',
  'PAZAR',
  'KİŞİSEL',
  'YATIRIM',
  'TATİL',
  'TEMİZLİK',
  'Z.KREDİ',
  'Z.KREDİ KARTI',
  'Z.EKSİ HESAP',
  'V.KREDİ KARTI',
  'V.KREDİ',
  'V.EKSİ HESAP',
  'GIDA',
];

class CreditCardDef {
  final String id;
  final String name;
  final int cutDay; // 1..28
  final int dueDay; // 1..28
  final String paymentCategory; // card payment expense category
  const CreditCardDef({
    required this.id,
    required this.name,
    required this.cutDay,
    required this.dueDay,
    required this.paymentCategory,
  });
}

class AccountDef {
  final String id;
  final String name;
  final AccountKind kind;
  const AccountDef({required this.id, required this.name, required this.kind});
}

class ExpenseEntry {
  final String id;
  DateTime date;
  double amount;
  String category;
  String description;

  PaymentMethod method;
  String? accountId; // for cash/debit/multinet
  String? cardId; // for credit card
  int? installments;

  bool isAutoCcPayment;
  String? sourcePurchaseId;
  int? installmentIndex;
  int? installmentCount;

  ExpenseEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.description,
    required this.method,
    this.accountId,
    this.cardId,
    this.installments,
    this.isAutoCcPayment = false,
    this.sourcePurchaseId,
    this.installmentIndex,
    this.installmentCount,
  });
}

class BudgetEntry {
  final String id;
  DateTime month; // y,m,1
  String category;
  double amount;
  String? groupId;

  BudgetEntry({
    required this.id,
    required this.month,
    required this.category,
    required this.amount,
    this.groupId,
  });
}

class PlannedIncomeEntry {
  final String id;
  DateTime month;
  IncomeType type;
  double amount;
  String? groupId;

  PlannedIncomeEntry({
    required this.id,
    required this.month,
    required this.type,
    required this.amount,
    this.groupId,
  });
}

class IncomeEntry {
  final String id;
  DateTime date;
  double amount;
  IncomeType type;
  String description;

  IncomeEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.description,
  });
}

class MonthLedger {
  final int year;
  final int month;
  double carryInCash;
  bool isClosed;

  final List<ExpenseEntry> actualExpenses = [];
  final List<BudgetEntry> budgets = [];
  final List<PlannedIncomeEntry> plannedIncomes = [];
  final List<IncomeEntry> incomes = [];

  MonthLedger({
    required this.year,
    required this.month,
    this.carryInCash = 0.0,
    this.isClosed = false,
  });

  String get key => monthKey(year, month);
  String get labelShort => '${month.toString().padLeft(2, '0')}.${year.toString().padLeft(4, '0')}';
  String get labelLong => '${monthNameTR(month)} $year';

  double get actualCashOut =>
      actualExpenses.where((e) => e.method == PaymentMethod.cash || e.method == PaymentMethod.debit).fold(0.0, (s, e) => s + e.amount);

  double get actualCashIn => incomes.where((i) => i.type != IncomeType.multinet).fold(0.0, (s, i) => s + i.amount);

  double get actualMultinetIn => incomes.where((i) => i.type == IncomeType.multinet).fold(0.0, (s, i) => s + i.amount);

  double get actualMultinetOut => actualExpenses.where((e) => e.method == PaymentMethod.multinet).fold(0.0, (s, e) => s + e.amount);

  double get multinetBalance => actualMultinetIn - actualMultinetOut;

  double cashEndOnClose() => carryInCash + actualCashIn - actualCashOut;
}

class _CloseSnapshot {
  final String prevCurrentKey;
  final String closedMonthKey;
  final String nextKey;
  final bool nextLedgerWasNew;
  final double prevNextCarryIn;
  _CloseSnapshot({
    required this.prevCurrentKey,
    required this.closedMonthKey,
    required this.nextKey,
    required this.nextLedgerWasNew,
    required this.prevNextCarryIn,
  });
}

class _InstallmentAlloc {
  final DateTime payMonth;
  final DateTime dueDate;
  final double amount;
  final int index;
  final int count;
  _InstallmentAlloc({
    required this.payMonth,
    required this.dueDate,
    required this.amount,
    required this.index,
    required this.count,
  });
}

class _LocalStore {
  static const _key = 'ev_butce_local_v4';

  Future<void> save(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}

class AppState extends ChangeNotifier {
  final _LocalStore _store = _LocalStore();
  Timer? _saveDebounce;

  final Map<String, MonthLedger> _ledgers = {};
  String _currentKey;
  String _budgetViewKey;
  _CloseSnapshot? _lastClose;

  // Cards + Accounts
  final List<CreditCardDef> cards = [
    const CreditCardDef(id: 'max', name: 'Maksimum', cutDay: 15, dueDay: 1, paymentCategory: 'Z.KREDİ KARTI'),
    const CreditCardDef(id: 'bonus', name: 'Bonus', cutDay: 15, dueDay: 1, paymentCategory: 'V.KREDİ KARTI'),
  ];

  final List<AccountDef> accounts = [
    const AccountDef(id: 'vk_debit', name: 'Volkan Hesap Kartı', kind: AccountKind.bankCard),
    const AccountDef(id: 'zk_debit', name: 'Zeynep Hesap Kartı', kind: AccountKind.bankCard),
    const AccountDef(id: 'vk_cash', name: 'Volkan Nakit', kind: AccountKind.cash),
    const AccountDef(id: 'zk_cash', name: 'Zeynep Nakit', kind: AccountKind.cash),
  ];

  // Portfolio
  double portfolioVolkan = 0;
  double portfolioZeynep = 0;

  AppState()
      : _currentKey = monthKey(DateTime.now().year, DateTime.now().month),
        _budgetViewKey = monthKey(DateTime.now().year, DateTime.now().month) {
    _ensureLedger(DateTime.now().year, DateTime.now().month);
    _loadFromDisk();
  }

  DateTime get now => DateTime.now();

  void _notify() {
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _store.save(_toJson());
    });
  }

  Future<void> _loadFromDisk() async {
    final data = await _store.load();
    if (data == null) return;
    try {
      final ck = (data['currentKey'] ?? '').toString();
      if (ck.isEmpty) return;

      _currentKey = ck;
      _budgetViewKey = (data['budgetViewKey'] ?? ck).toString();

      portfolioVolkan = (data['portfolioVolkan'] is num) ? (data['portfolioVolkan'] as num).toDouble() : 0.0;
      portfolioZeynep = (data['portfolioZeynep'] is num) ? (data['portfolioZeynep'] as num).toDouble() : 0.0;

      final cardsRaw = data['cards'];
      if (cardsRaw is List) {
        cards
          ..clear()
          ..addAll(cardsRaw.whereType<Map>().map((m) {
            final mm = m.cast<String, dynamic>();
            return CreditCardDef(
              id: (mm['id'] ?? '').toString(),
              name: (mm['name'] ?? '').toString(),
              cutDay: (mm['cutDay'] is num) ? (mm['cutDay'] as num).toInt() : 15,
              dueDay: (mm['dueDay'] is num) ? (mm['dueDay'] as num).toInt() : 1,
              paymentCategory: (mm['paymentCategory'] ?? 'KİŞİSEL').toString(),
            );
          }));
      }

      final accRaw = data['accounts'];
      if (accRaw is List) {
        accounts
          ..clear()
          ..addAll(accRaw.whereType<Map>().map((m) {
            final mm = m.cast<String, dynamic>();
            final kind = (mm['kind'] is num) ? (mm['kind'] as num).toInt() : 0;
            return AccountDef(
              id: (mm['id'] ?? '').toString(),
              name: (mm['name'] ?? '').toString(),
              kind: AccountKind.values[kind.clamp(0, AccountKind.values.length - 1)],
            );
          }));
      }

      _ledgers.clear();
      final led = data['ledgers'];
      if (led is Map) {
        final map = led.cast<String, dynamic>();
        for (final entry in map.entries) {
          final mk = entry.key;
          final lm = (entry.value is Map) ? (entry.value as Map).cast<String, dynamic>() : <String, dynamic>{};

          final y = int.tryParse(mk.substring(0, 4)) ?? now.year;
          final mo = int.tryParse(mk.substring(4, 6)) ?? now.month;

          final ledger = MonthLedger(
            year: y,
            month: mo,
            carryInCash: (lm['carryInCash'] is num) ? (lm['carryInCash'] as num).toDouble() : 0.0,
            isClosed: lm['isClosed'] == true,
          );

          for (final e in (lm['expenses'] is List ? lm['expenses'] as List : const [])) {
            if (e is! Map) continue;
            final m = e.cast<String, dynamic>();
            ledger.actualExpenses.add(
              ExpenseEntry(
                id: (m['id'] ?? '').toString(),
                date: DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now(),
                amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0,
                category: (m['category'] ?? '').toString(),
                description: (m['description'] ?? '').toString(),
                method: PaymentMethod.values[((m['method'] is num) ? (m['method'] as num).toInt() : 0).clamp(0, PaymentMethod.values.length - 1)],
                accountId: m['accountId']?.toString(),
                cardId: m['cardId']?.toString(),
                installments: (m['installments'] is num) ? (m['installments'] as num).toInt() : null,
                isAutoCcPayment: m['isAutoCcPayment'] == true,
                sourcePurchaseId: m['sourcePurchaseId']?.toString(),
                installmentIndex: (m['installmentIndex'] is num) ? (m['installmentIndex'] as num).toInt() : null,
                installmentCount: (m['installmentCount'] is num) ? (m['installmentCount'] as num).toInt() : null,
              ),
            );
          }

          for (final i in (lm['incomes'] is List ? lm['incomes'] as List : const [])) {
            if (i is! Map) continue;
            final m = i.cast<String, dynamic>();
            ledger.incomes.add(
              IncomeEntry(
                id: (m['id'] ?? '').toString(),
                date: DateTime.tryParse((m['date'] ?? '').toString()) ?? DateTime.now(),
                amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0,
                type: IncomeType.values[((m['type'] is num) ? (m['type'] as num).toInt() : 0).clamp(0, IncomeType.values.length - 1)],
                description: (m['description'] ?? '').toString(),
              ),
            );
          }

          for (final b in (lm['budgets'] is List ? lm['budgets'] as List : const [])) {
            if (b is! Map) continue;
            final m = b.cast<String, dynamic>();
            ledger.budgets.add(BudgetEntry(
              id: (m['id'] ?? '').toString(),
              month: DateTime.tryParse((m['month'] ?? '').toString()) ?? DateTime(y, mo, 1),
              category: (m['category'] ?? '').toString(),
              amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0,
              groupId: m['groupId']?.toString(),
            ));
          }

          for (final p in (lm['plannedIncomes'] is List ? lm['plannedIncomes'] as List : const [])) {
            if (p is! Map) continue;
            final m = p.cast<String, dynamic>();
            ledger.plannedIncomes.add(PlannedIncomeEntry(
              id: (m['id'] ?? '').toString(),
              month: DateTime.tryParse((m['month'] ?? '').toString()) ?? DateTime(y, mo, 1),
              type: IncomeType.values[((m['type'] is num) ? (m['type'] as num).toInt() : 0).clamp(0, IncomeType.values.length - 1)],
              amount: (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0,
              groupId: m['groupId']?.toString(),
            ));
          }

          _ledgers[mk] = ledger;
        }
      }

      notifyListeners();
    } catch (_) {
      // ignore corrupted data
    }
  }

  Map<String, dynamic> _toJson() {
    final ledgers = <String, dynamic>{};
    for (final e in _ledgers.entries) {
      final l = e.value;
      ledgers[e.key] = {
        'carryInCash': l.carryInCash,
        'isClosed': l.isClosed,
        'expenses': l.actualExpenses
            .map((x) => {
                  'id': x.id,
                  'date': x.date.toIso8601String(),
                  'amount': x.amount,
                  'category': x.category,
                  'description': x.description,
                  'method': x.method.index,
                  'accountId': x.accountId,
                  'cardId': x.cardId,
                  'installments': x.installments,
                  'isAutoCcPayment': x.isAutoCcPayment,
                  'sourcePurchaseId': x.sourcePurchaseId,
                  'installmentIndex': x.installmentIndex,
                  'installmentCount': x.installmentCount,
                })
            .toList(),
        'incomes': l.incomes
            .map((x) => {
                  'id': x.id,
                  'date': x.date.toIso8601String(),
                  'amount': x.amount,
                  'type': x.type.index,
                  'description': x.description,
                })
            .toList(),
        'budgets': l.budgets
            .map((x) => {
                  'id': x.id,
                  'month': x.month.toIso8601String(),
                  'category': x.category,
                  'amount': x.amount,
                  'groupId': x.groupId,
                })
            .toList(),
        'plannedIncomes': l.plannedIncomes
            .map((x) => {
                  'id': x.id,
                  'month': x.month.toIso8601String(),
                  'type': x.type.index,
                  'amount': x.amount,
                  'groupId': x.groupId,
                })
            .toList(),
      };
    }

    return {
      'currentKey': _currentKey,
      'budgetViewKey': _budgetViewKey,
      'portfolioVolkan': portfolioVolkan,
      'portfolioZeynep': portfolioZeynep,
      'cards': cards
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'cutDay': c.cutDay,
                'dueDay': c.dueDay,
                'paymentCategory': c.paymentCategory,
              })
          .toList(),
      'accounts': accounts
          .map((a) => {
                'id': a.id,
                'name': a.name,
                'kind': a.kind.index,
              })
          .toList(),
      'ledgers': ledgers,
    };
  }

  MonthLedger _ensureLedger(int y, int m) {
    final k = monthKey(y, m);
    if (_ledgers.containsKey(k)) return _ledgers[k]!;
    final l = MonthLedger(year: y, month: m);
    _ledgers[k] = l;
    return l;
  }

  MonthLedger get currentLedger {
    final y = int.parse(_currentKey.substring(0, 4));
    final m = int.parse(_currentKey.substring(4, 6));
    return _ensureLedger(y, m);
  }

  MonthLedger get budgetViewLedger {
    final y = int.parse(_budgetViewKey.substring(0, 4));
    final m = int.parse(_budgetViewKey.substring(4, 6));
    return _ensureLedger(y, m);
  }

  void setBudgetViewMonth(int year, int month) {
    _budgetViewKey = monthKey(year, month);
    _ensureLedger(year, month);
    _notify();
  }

  bool get canUndoClose => _lastClose != null;

  String accountName(String? id) {
    if (id == null) return '-';
    final a = accounts.where((x) => x.id == id).toList();
    return a.isEmpty ? '-' : a.first.name;
  }

  // ---- Income CRUD ----
  void addIncome(IncomeEntry i) {
    currentLedger.incomes.insert(0, i);
    _notify();
  }

  void updateIncome(String id, IncomeEntry updated) {
    final list = currentLedger.incomes;
    final idx = list.indexWhere((x) => x.id == id);
    if (idx >= 0) {
      list[idx] = updated;
      _notify();
    }
  }

  void deleteIncome(String id) {
    currentLedger.incomes.removeWhere((x) => x.id == id);
    _notify();
  }

  // ---- Actual CRUD ----
  void addActual(ExpenseEntry e) {
    currentLedger.actualExpenses.insert(0, e);
    if (e.method == PaymentMethod.creditCard && !e.isAutoCcPayment) {
      _generateCcPaymentsForPurchase(e);
    }
    _notify();
  }

  void updateActual(String id, ExpenseEntry updated) {
    final list = currentLedger.actualExpenses;
    final idx = list.indexWhere((x) => x.id == id);
    if (idx < 0) return;

    final old = list[idx];
    list[idx] = updated;

    if (old.method == PaymentMethod.creditCard && !old.isAutoCcPayment) {
      _removeCcPaymentsBySource(old.id);
    }
    if (updated.method == PaymentMethod.creditCard && !updated.isAutoCcPayment) {
      _generateCcPaymentsForPurchase(updated);
    }
    _notify();
  }

  void deleteActual(String id) {
    final list = currentLedger.actualExpenses;
    final idx = list.indexWhere((x) => x.id == id);
    if (idx < 0) return;

    final old = list[idx];
    list.removeAt(idx);

    if (old.method == PaymentMethod.creditCard && !old.isAutoCcPayment) {
      _removeCcPaymentsBySource(old.id);
    }
    _notify();
  }

  void _removeCcPaymentsBySource(String sourceId) {
    for (final ledger in _ledgers.values) {
      ledger.actualExpenses.removeWhere((e) => e.isAutoCcPayment && e.sourcePurchaseId == sourceId);
    }
  }

  // ---- Budget CRUD ----
  void addBudgetMulti({required double amount, required String category, required List<DateTime> months}) {
    if (months.isEmpty) return;
    final gid = months.length > 1 ? genId() : null;

    for (final m in months) {
      final ledger = _ensureLedger(m.year, m.month);
      final existingIdx = ledger.budgets.indexWhere((b) => b.category == category);
      final entry = BudgetEntry(
        id: existingIdx >= 0 ? ledger.budgets[existingIdx].id : genId(),
        month: DateTime(m.year, m.month, 1),
        category: category,
        amount: amount,
        groupId: gid,
      );
      if (existingIdx >= 0) {
        ledger.budgets[existingIdx] = entry;
      } else {
        ledger.budgets.insert(0, entry);
      }
    }
    _notify();
  }

  void updateBudget(BudgetEntry entry, {required bool applyGroup}) {
    if (applyGroup && entry.groupId != null) {
      final gid = entry.groupId!;
      for (final ledger in _ledgers.values) {
        for (var i = 0; i < ledger.budgets.length; i++) {
          final b = ledger.budgets[i];
          if (b.groupId == gid && b.category == entry.category) {
            ledger.budgets[i] = BudgetEntry(id: b.id, month: b.month, category: entry.category, amount: entry.amount, groupId: b.groupId);
          }
        }
      }
    } else {
      final ledger = _ensureLedger(entry.month.year, entry.month.month);
      final idx = ledger.budgets.indexWhere((b) => b.id == entry.id);
      if (idx >= 0) ledger.budgets[idx] = entry;
    }
    _notify();
  }

  void deleteBudget(BudgetEntry entry, {required bool applyGroup}) {
    if (applyGroup && entry.groupId != null) {
      final gid = entry.groupId!;
      for (final ledger in _ledgers.values) {
        ledger.budgets.removeWhere((b) => b.groupId == gid && b.category == entry.category);
      }
    } else {
      final ledger = _ensureLedger(entry.month.year, entry.month.month);
      ledger.budgets.removeWhere((b) => b.id == entry.id);
    }
    _notify();
  }

  // ---- Planned income CRUD ----
  void addPlannedIncomeMulti({required double amount, required IncomeType type, required List<DateTime> months}) {
    if (months.isEmpty) return;
    final gid = months.length > 1 ? genId() : null;

    for (final m in months) {
      final ledger = _ensureLedger(m.year, m.month);
      final existingIdx = ledger.plannedIncomes.indexWhere((p) => p.type == type);
      final entry = PlannedIncomeEntry(
        id: existingIdx >= 0 ? ledger.plannedIncomes[existingIdx].id : genId(),
        month: DateTime(m.year, m.month, 1),
        type: type,
        amount: amount,
        groupId: gid,
      );
      if (existingIdx >= 0) {
        ledger.plannedIncomes[existingIdx] = entry;
      } else {
        ledger.plannedIncomes.insert(0, entry);
      }
    }
    _notify();
  }

  void updatePlannedIncome(PlannedIncomeEntry entry, {required bool applyGroup}) {
    if (applyGroup && entry.groupId != null) {
      final gid = entry.groupId!;
      for (final ledger in _ledgers.values) {
        for (var i = 0; i < ledger.plannedIncomes.length; i++) {
          final p = ledger.plannedIncomes[i];
          if (p.groupId == gid && p.type == entry.type) {
            ledger.plannedIncomes[i] = PlannedIncomeEntry(id: p.id, month: p.month, type: entry.type, amount: entry.amount, groupId: p.groupId);
          }
        }
      }
    } else {
      final ledger = _ensureLedger(entry.month.year, entry.month.month);
      final idx = ledger.plannedIncomes.indexWhere((p) => p.id == entry.id);
      if (idx >= 0) ledger.plannedIncomes[idx] = entry;
    }
    _notify();
  }

  void deletePlannedIncome(PlannedIncomeEntry entry, {required bool applyGroup}) {
    if (applyGroup && entry.groupId != null) {
      final gid = entry.groupId!;
      for (final ledger in _ledgers.values) {
        ledger.plannedIncomes.removeWhere((p) => p.groupId == gid && p.type == entry.type);
      }
    } else {
      final ledger = _ensureLedger(entry.month.year, entry.month.month);
      ledger.plannedIncomes.removeWhere((p) => p.id == entry.id);
    }
    _notify();
  }

  // ---- Cards & Accounts ----
  void addCard(String name, int cutDay, int dueDay, String paymentCategory) {
    cards.insert(0, CreditCardDef(id: genId(), name: name.trim(), cutDay: cutDay.clamp(1, 28), dueDay: dueDay.clamp(1, 28), paymentCategory: paymentCategory));
    _notify();
  }

  void deleteCard(String id) {
    cards.removeWhere((c) => c.id == id);
    _notify();
  }

  void addAccount(String name, AccountKind kind) {
    accounts.insert(0, AccountDef(id: genId(), name: name.trim(), kind: kind));
    _notify();
  }

  void deleteAccount(String id) {
    accounts.removeWhere((a) => a.id == id);
    _notify();
  }

  String cardName(String? id) {
    if (id == null) return '-';
    final c = cards.where((x) => x.id == id).toList();
    return c.isEmpty ? '-' : c.first.name;
  }

  // ---- Credit card logic ----
  void _generateCcPaymentsForPurchase(ExpenseEntry purchase) {
    final allocs = _allocateInstallments(purchase);
    final card = cards.where((c) => c.id == purchase.cardId).toList();
    final payCat = card.isEmpty ? 'KİŞİSEL' : card.first.paymentCategory;

    for (final a in allocs) {
      final ledger = _ensureLedger(a.payMonth.year, a.payMonth.month);
      ledger.actualExpenses.insert(
        0,
        ExpenseEntry(
          id: genId(),
          date: a.dueDate,
          amount: a.amount,
          category: payCat,
          description: 'KK Ödeme (${purchase.category})',
          method: PaymentMethod.debit,
          accountId: null,
          isAutoCcPayment: true,
          sourcePurchaseId: purchase.id,
          installmentIndex: a.index,
          installmentCount: a.count,
        ),
      );
    }
  }

  List<_InstallmentAlloc> _allocateInstallments(ExpenseEntry purchase) {
    final card = cards.where((c) => c.id == purchase.cardId).toList();
    final cut = card.isEmpty ? 15 : card.first.cutDay;
    final dueDay = card.isEmpty ? 1 : card.first.dueDay;

    final statementMonth = purchase.date.day <= cut
        ? DateTime(purchase.date.year, purchase.date.month, 1)
        : DateTime(purchase.date.year, purchase.date.month + 1, 1);

    final firstPayMonth = DateTime(statementMonth.year, statementMonth.month + 1, 1);

    final n = (purchase.installments ?? 1).clamp(1, 60);
    final per = purchase.amount / n;

    final out = <_InstallmentAlloc>[];
    for (int i = 0; i < n; i++) {
      final pm = DateTime(firstPayMonth.year, firstPayMonth.month + i, 1);
      final dueDate = DateTime(pm.year, pm.month, dueDay.clamp(1, 28));
      out.add(_InstallmentAlloc(payMonth: pm, dueDate: dueDate, amount: per, index: i + 1, count: n));
    }
    return out;
  }

  // ---- Aggregations (budget view month) ----
  Map<String, double> budgetByCategoryForBudgetViewMonth() {
    final m = budgetViewLedger;
    final out = <String, double>{};
    for (final b in m.budgets) {
      out[b.category] = b.amount;
    }
    return out;
  }

  Map<String, double> actualByCategoryForBudgetViewMonth() {
    final m = budgetViewLedger;
    final out = <String, double>{};
    for (final e in m.actualExpenses) {
      out[e.category] = (out[e.category] ?? 0) + e.amount;
    }
    return out;
  }

  Map<IncomeType, double> plannedIncomeByTypeForBudgetViewMonth() {
    final m = budgetViewLedger;
    final out = <IncomeType, double>{};
    for (final p in m.plannedIncomes) {
      out[p.type] = p.amount;
    }
    return out;
  }

  double plannedIncomeTotalForMonth(int year, int month) => _ensureLedger(year, month).plannedIncomes.fold(0.0, (s, p) => s + p.amount);

  Map<String, double> ccBudgetImpactForMonth(int year, int month) {
    final out = <String, double>{};
    for (final ledger in _ledgers.values) {
      for (final e in ledger.actualExpenses) {
        if (e.method != PaymentMethod.creditCard || e.isAutoCcPayment) continue;
        final allocations = _allocateInstallments(e);
        for (final a in allocations) {
          if (a.payMonth.year == year && a.payMonth.month == month) {
            out[e.category] = (out[e.category] ?? 0) + a.amount;
          }
        }
      }
    }
    return out;
  }

  Map<String, double> ccPaymentTotalByCardPaymentCategoryForMonth(int year, int month) {
    final out = <String, double>{};
    final ledger = _ensureLedger(year, month);
    for (final e in ledger.actualExpenses) {
      if (!e.isAutoCcPayment) continue;
      out[e.category] = (out[e.category] ?? 0) + e.amount;
    }
    return out;
  }

  // ---- Projections ----
  double projectedNetForMonth(int year, int month) {
    final ledger = _ensureLedger(year, month);
    final plannedIncome = plannedIncomeTotalForMonth(year, month);

    final budgetMap = <String, double>{};
    for (final b in ledger.budgets) {
      budgetMap[b.category] = b.amount;
    }

    final actualMap = <String, double>{};
    for (final e in ledger.actualExpenses) {
      actualMap[e.category] = (actualMap[e.category] ?? 0) + e.amount;
    }

    final ccImpact = ccBudgetImpactForMonth(year, month);

    final keys = <String>{...budgetMap.keys, ...actualMap.keys, ...ccImpact.keys};
    double plannedSpendUsed = 0;
    for (final k in keys) {
      final budget = budgetMap[k] ?? 0;
      final actual = (actualMap[k] ?? 0) + (ccImpact[k] ?? 0);
      final use = (year == now.year && month == now.month) ? (actual > budget ? actual : budget) : budget;
      plannedSpendUsed += use;
    }

    final cashNow = ledger.carryInCash + ledger.actualCashIn - ledger.actualCashOut;
    return (plannedIncome - plannedSpendUsed) + cashNow;
  }

  // ---- Month close + undo ----
  void closeCurrentMonth() {
    final cur = currentLedger;
    cur.isClosed = true;

    final next = DateTime(cur.year, cur.month + 1, 1);
    final nextKey = monthKey(next.year, next.month);
    final existed = _ledgers.containsKey(nextKey);
    final nextLedger = _ensureLedger(next.year, next.month);
    final prevCarry = nextLedger.carryInCash;

    _lastClose = _CloseSnapshot(
      prevCurrentKey: _currentKey,
      closedMonthKey: cur.key,
      nextKey: nextKey,
      nextLedgerWasNew: !existed,
      prevNextCarryIn: prevCarry,
    );

    nextLedger.carryInCash = cur.cashEndOnClose();
    _currentKey = nextLedger.key;
    _budgetViewKey = _currentKey;

    _notify();
  }

  void undoCloseMonth() {
    final snap = _lastClose;
    if (snap == null) return;

    final closedLedger = _ledgers[snap.closedMonthKey];
    final nextLedger = _ledgers[snap.nextKey];
    if (closedLedger == null) return;

    closedLedger.isClosed = false;

    if (nextLedger != null) {
      nextLedger.carryInCash = snap.prevNextCarryIn;
      if (snap.nextLedgerWasNew &&
          nextLedger.actualExpenses.isEmpty &&
          nextLedger.budgets.isEmpty &&
          nextLedger.plannedIncomes.isEmpty &&
          nextLedger.incomes.isEmpty) {
        _ledgers.remove(snap.nextKey);
      }
    }

    _currentKey = snap.prevCurrentKey;
    _budgetViewKey = _currentKey;
    _lastClose = null;

    _notify();
  }

  // ---- Past/Future ----
  List<MonthLedger> get pastClosed {
    final list = _ledgers.values.where((l) => l.isClosed).toList();
    list.sort((a, b) => (b.year * 100 + b.month).compareTo(a.year * 100 + a.month));
    return list;
  }

  List<MonthLedger> get futureOpen {
    final cur = currentLedger;
    final curVal = cur.year * 100 + cur.month;
    final list = _ledgers.values.where((l) => !l.isClosed && (l.year * 100 + l.month) > curVal).toList();
    list.sort((a, b) => (a.year * 100 + a.month).compareTo(b.year * 100 + b.month));
    return list;
  }

  double get currentWealthApprox => (currentLedger.carryInCash + currentLedger.actualCashIn - currentLedger.actualCashOut) + currentLedger.multinetBalance;
}

// ---------------- App Shell ----------------

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final AppState state = AppState();

  @override
  Widget build(BuildContext context) {
    final screens = [
      ActualScreen(state: state, onOpenManage: () => _openManage(context)),
      BudgetScreen(state: state),
      IncomeScreen(state: state, onEditPortfolio: () => _openPortfolio(context)),
      SummaryScreen(state: state, onJumpHome: () => setState(() => index = 0)),
      PastMonthsScreen(state: state),
      FutureMonthsScreen(state: state),
    ];

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Scaffold(
          body: screens[index],
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: index == 0
              ? Transform.translate(
                  offset: const Offset(0, -20), // lift above bottom total bar
                  child: FloatingActionButton.extended(
                    onPressed: () => _openAddActual(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Harcama Ekle'),
                  ),
                )
              : (index == 1
                  ? Transform.translate(
                      offset: const Offset(0, -8),
                      child: FloatingActionButton.extended(
                        onPressed: () => _openAddBudget(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Ekle'),
                      ),
                    )
                  : null),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Gerçekleşen'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Bütçe'),
              NavigationDestination(icon: Icon(Icons.savings), label: 'Gelir'),
              NavigationDestination(icon: Icon(Icons.dashboard), label: 'Özet'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Geçmiş'),
              NavigationDestination(icon: Icon(Icons.upcoming), label: 'Gelecek'),
            ],
          ),
        );
      },
    );
  }

  void _openManage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ManageCardsAccountsSheet(state: state),
    );
  }

  void _openPortfolio(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => PortfolioSheet(state: state),
    );
  }

  void _openAddActual(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddExpenseSheet(
          title: 'Harcama Ekle • ${state.currentLedger.labelLong}',
          cards: state.cards,
          accounts: state.accounts,
          initialDate: DateTime.now(),
          onSubmit: (e) {
            state.addActual(e);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _openAddBudget(BuildContext context) {
    final vm = state.budgetViewLedger;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: BudgetAddChooserSheet(
          monthLabel: vm.labelLong,
          onAddBudget: () => _openAddBudgetExpense(context),
          onAddIncomePlan: () => _openAddPlannedIncome(context),
        ),
      ),
    );
  }

  void _openAddBudgetExpense(BuildContext context) {
    final vm = state.budgetViewLedger;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddBudgetMultiSheet(
          title: 'Gider Bütçesi • ${vm.labelLong}',
          initialYear: vm.year,
          onSubmit: (amount, category, months) {
            state.addBudgetMulti(amount: amount, category: category, months: months);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _openAddPlannedIncome(BuildContext context) {
    final vm = state.budgetViewLedger;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddPlannedIncomeMultiSheet(
          title: 'Gelir Planı • ${vm.labelLong}',
          initialYear: vm.year,
          onSubmit: (amount, type, months) {
            state.addPlannedIncomeMulti(amount: amount, type: type, months: months);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

// ---------------- Screens ----------------

class ActualScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenManage;
  const ActualScreen({super.key, required this.state, required this.onOpenManage});

  @override
  Widget build(BuildContext context) {
    final m = state.currentLedger;

    final Map<String, List<ExpenseEntry>> groups = {};
    double total = 0;
    for (final e in m.actualExpenses) {
      groups.putIfAbsent(e.category, () => []).add(e);
      total += e.amount;
    }

    final cats = groups.keys.toList()
      ..removeWhere((c) => c == 'MARKET') // hide MARKET from list
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final c in cats) {
      groups[c]!.sort((a, b) => b.date.compareTo(a.date));
    }

    return SafeArea(
      child: Column(
        children: [
          _TopBar(
            title: 'Gerçekleşen',
            subtitle: 'Kategoriler alfabetik',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Pill(icon: Icons.calendar_month, text: m.labelLong),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Kartlar / Hesaplar',
                  icon: const Icon(Icons.tune),
                  onPressed: onOpenManage,
                ),
              ],
            ),
          ),
          Expanded(
            child: cats.isEmpty
                ? const _EmptyHint(title: 'Henüz harcama yok', desc: '“Harcama Ekle” ile başlayın.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                    children: [
                      for (final cat in cats)
                        _GlassCard(
                          child: ExpansionTile(
                            title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('Toplam: ${fmtMoney(groups[cat]!.fold(0.0, (s, e) => s + e.amount))}'),
                            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            children: [
                              for (final e in groups[cat]!)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: _EditableTile(
                                    child: _EntryTile(
                                      leading: e.isAutoCcPayment ? Icons.credit_score : Icons.payments,
                                      title: '${paymentLabel(e.method)} • ${fmtDate(e.date)}',
                                      subtitle: [
                                        if (e.description.trim().isNotEmpty) e.description.trim(),
                                        if (e.method == PaymentMethod.creditCard) 'Kart: ${state.cardName(e.cardId)} • Taksit: ${e.installments ?? 1}',
                                        if (e.method != PaymentMethod.creditCard) 'Hesap: ${state.accountName(e.accountId)}',
                                      ].join(' • '),
                                      trailing: fmtMoney(e.amount),
                                    ),
                                    onEdit: e.isAutoCcPayment ? null : () => _editActual(context, e),
                                    onDelete: e.isAutoCcPayment ? null : () => state.deleteActual(e.id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
          ),
          _BottomTotalBar(total: total),
        ],
      ),
    );
  }

  void _editActual(BuildContext context, ExpenseEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddExpenseSheet(
          title: 'Harcama Düzenle',
          cards: state.cards,
          accounts: state.accounts,
          initialAmount: e.amount,
          initialCategory: e.category,
          initialDescription: e.description,
          initialMethod: e.method,
          initialAccountId: e.accountId,
          initialCardId: e.cardId,
          initialInstallments: e.installments ?? 1,
          initialDate: e.date,
          onSubmit: (updated) {
            state.updateActual(
              e.id,
              ExpenseEntry(
                id: e.id,
                date: updated.date,
                amount: updated.amount,
                category: updated.category,
                description: updated.description,
                method: updated.method,
                accountId: updated.accountId,
                cardId: updated.cardId,
                installments: updated.installments,
              ),
            );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _BottomTotalBar extends StatelessWidget {
  final double total;
  const _BottomTotalBar({required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, -8))],
      ),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: cs.primary.withOpacity(0.7), borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          const Expanded(child: Text('Toplam Harcama', style: TextStyle(fontWeight: FontWeight.w900))),
          Text(fmtMoney(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

// --- Budget / Income / Summary / Past / Future ---
// For brevity: reuse the stable implementations from previous version without introducing new syntax risks.
// We keep them minimal but functional.

class BudgetScreen extends StatelessWidget {
  final AppState state;
  const BudgetScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final vm = state.budgetViewLedger;
    return SafeArea(
      child: Column(
        children: [
          _TopBar(
            title: 'Bütçe',
            subtitle: vm.labelLong,
            trailing: IconButton(
              tooltip: 'Ay Seç',
              icon: const Icon(Icons.date_range),
              onPressed: () async {
                final picked = await showMonthPickerDialog(context, initial: DateTime(vm.year, vm.month, 1));
                if (picked != null) state.setBudgetViewMonth(picked.year, picked.month);
              },
            ),
          ),
          Expanded(child: _ExpenseBudgetView(state: state)),
        ],
      ),
    );
  }
}

class _ExpenseBudgetView extends StatelessWidget {
  final AppState state;
  const _ExpenseBudgetView({required this.state});

  @override
  Widget build(BuildContext context) {
    final vm = state.budgetViewLedger;
    final budgetMap = state.budgetByCategoryForBudgetViewMonth();
    final actualMap = state.actualByCategoryForBudgetViewMonth();
    final ccImpact = state.ccBudgetImpactForMonth(vm.year, vm.month);

    final keys = <String>{...budgetMap.keys, ...actualMap.keys, ...ccImpact.keys}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _GlassCard(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Kalem')),
                DataColumn(label: Text('Bütçe'), numeric: true),
                DataColumn(label: Text('Gerçek'), numeric: true),
                DataColumn(label: Text('KK Etki'), numeric: true),
                DataColumn(label: Text('Kalan'), numeric: true),
              ],
              rows: [
                for (final k in keys)
                  DataRow(cells: [
                    DataCell(Text(k)),
                    DataCell(Text(fmtMoney(budgetMap[k] ?? 0))),
                    DataCell(Text(fmtMoney(actualMap[k] ?? 0))),
                    DataCell(Text(fmtMoney(ccImpact[k] ?? 0))),
                    DataCell(Text(fmtMoney((budgetMap[k] ?? 0) - (actualMap[k] ?? 0) - (ccImpact[k] ?? 0)))),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Gider Bütçesi Ekle (Çoklu Ay)'),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: AddBudgetMultiSheet(
                  title: 'Gider Bütçesi',
                  initialYear: vm.year,
                  onSubmit: (amount, category, months) {
                    state.addBudgetMulti(amount: amount, category: category, months: months);
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class IncomeScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onEditPortfolio;
  const IncomeScreen({super.key, required this.state, required this.onEditPortfolio});

  @override
  Widget build(BuildContext context) {
    final m = state.currentLedger;

    return SafeArea(
      child: Column(
        children: [
          _TopBar(
            title: 'Gelir',
            subtitle: m.labelLong,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Portföy',
                  icon: const Icon(Icons.account_balance),
                  onPressed: onEditPortfolio,
                ),
                IconButton(
                  tooltip: 'Gelir Ekle',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _openAddIncome(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Expanded(child: Text('Portföy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                      Text(fmtMoney(state.portfolioVolkan + state.portfolioZeynep), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Volkan: ${fmtMoney(state.portfolioVolkan)} • Zeynep: ${fmtMoney(state.portfolioZeynep)}', style: const TextStyle(color: Colors.black54)),
                ]),
              ),
            ),
          ),
          Expanded(
            child: m.incomes.isEmpty
                ? const _EmptyHint(title: 'Henüz gelir yok', desc: 'Sağ üstteki + ile gelir ekleyin.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemBuilder: (context, i) {
                      final inc = m.incomes[i];
                      return _EditableTile(
                        child: _EntryTile(
                          leading: Icons.savings,
                          title: '${incomeTypeLabel(inc.type)} • ${fmtDate(inc.date)}',
                          subtitle: inc.description.trim().isEmpty ? '-' : inc.description.trim(),
                          trailing: fmtMoney(inc.amount),
                        ),
                        onEdit: () => _editIncome(context, inc),
                        onDelete: () => state.deleteIncome(inc.id),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: m.incomes.length,
                  ),
          ),
        ],
      ),
    );
  }

  void _openAddIncome(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddIncomeSheet(
          onSubmit: (amount, type, date, desc) {
            state.addIncome(IncomeEntry(id: genId(), date: date, amount: amount, type: type, description: desc));
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _editIncome(BuildContext context, IncomeEntry inc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddIncomeSheet(
          title: 'Gelir Düzenle',
          initialAmount: inc.amount,
          initialType: inc.type,
          initialDate: inc.date,
          initialDescription: inc.description,
          onSubmit: (amount, type, date, desc) {
            state.updateIncome(inc.id, IncomeEntry(id: inc.id, date: date, amount: amount, type: type, description: desc));
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class SummaryScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onJumpHome;
  const SummaryScreen({super.key, required this.state, required this.onJumpHome});

  @override
  Widget build(BuildContext context) {
    final m = state.currentLedger;
    final net = state.projectedNetForMonth(m.year, m.month);
    final bgTop = net >= 0 ? Colors.green.shade100 : Colors.red.shade100;

    final rs = DateTime(m.year, m.month, 1);
    final re = DateTime(m.year, m.month + 1, 0);
    final rep = _buildReport(state, rs, re);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgTop, const Color(0xFFF6F7FB)]),
        ),
        child: Column(
          children: [
            _TopBar(
              title: 'Özet',
              subtitle: m.labelLong,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.canUndoClose)
                    IconButton(
                      tooltip: 'Ay Bitir Geri Al',
                      icon: const Icon(Icons.undo),
                      onPressed: state.undoCloseMonth,
                    ),
                  IconButton(
                    tooltip: 'Ayı Bitir',
                    icon: const Icon(Icons.done_all),
                    onPressed: () => _confirmCloseMonth(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _MetricCard(
                    title: 'Net Projeksiyon',
                    value: fmtMoney(net),
                    subtitle: 'Planlı gelir - planlı gider + (devreden + gerçekleşen nakit). Aşım olan kalemlerde gerçekleşen baz alınır.',
                    emphasize: true,
                  ),
                  const SizedBox(height: 12),
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Bu Ay Harcamalar (Tarih + Açıklama)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (rep.entries.isEmpty)
                          const Text('Kayıt yok.')
                        else
                          ...rep.entries.take(30).map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('${fmtDate(e.date)} • ${e.category}\n${e.description.isEmpty ? '-' : e.description}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                    Text(fmtMoney(e.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              )),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCloseMonth(BuildContext context) {
    final m = state.currentLedger;
    final carry = m.cashEndOnClose();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ayı Bitir'),
        content: Text('${m.labelLong} ayı “Geçmiş”e taşınacak.\nYeni ay otomatik açılacak.\n\nDevreden Nakit: ${fmtMoney(carry)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              state.closeCurrentMonth();
              Navigator.pop(context);
              onJumpHome();
            },
            child: const Text('Bitir ve Geç'),
          ),
        ],
      ),
    );
  }
}

class PastMonthsScreen extends StatelessWidget {
  final AppState state;
  const PastMonthsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final closed = state.pastClosed;
    return SafeArea(
      child: Column(
        children: [
          const _TopBar(title: 'Geçmiş Aylar', subtitle: 'Kapanan aylar'),
          Expanded(
            child: closed.isEmpty
                ? const _EmptyHint(title: 'Henüz geçmiş ay yok', desc: 'Özet ekranında “Ayı Bitir” ile ayı kapatın.')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, i) => _MonthCard(month: closed[i], state: state),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: closed.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class FutureMonthsScreen extends StatelessWidget {
  final AppState state;
  const FutureMonthsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final future = state.futureOpen;
    return SafeArea(
      child: Column(
        children: [
          const _TopBar(title: 'Gelecek Aylar', subtitle: 'Açık aylar'),
          Expanded(
            child: future.isEmpty
                ? const _EmptyHint(title: 'Henüz gelecek ay yok', desc: 'Ay kapatınca yeni ay açılır.')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, i) => _MonthCard(month: future[i], state: state),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: future.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final MonthLedger month;
  final AppState state;
  const _MonthCard({required this.month, required this.state});

  @override
  Widget build(BuildContext context) {
    final cashEnd = month.cashEndOnClose();
    final net = state.projectedNetForMonth(month.year, month.month);
    return _GlassCard(
      child: ListTile(
        leading: const Icon(Icons.calendar_month),
        title: Text(month.labelLong, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('Devreden: ${fmtMoney(month.carryInCash)} • Nakit kapanış: ${fmtMoney(cashEnd)} • Net: ${fmtMoney(net)}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ---------------- Sheets ----------------

typedef ExpenseSubmit = void Function(ExpenseEntry e);

class AddExpenseSheet extends StatefulWidget {
  final String title;
  final ExpenseSubmit onSubmit;
  final List<CreditCardDef> cards;
  final List<AccountDef> accounts;

  final double? initialAmount;
  final String? initialCategory;
  final String? initialDescription;
  final PaymentMethod? initialMethod;
  final String? initialAccountId;
  final String? initialCardId;
  final int initialInstallments;
  final DateTime initialDate;

  const AddExpenseSheet({
    super.key,
    required this.title,
    required this.onSubmit,
    required this.cards,
    required this.accounts,
    this.initialAmount,
    this.initialCategory,
    this.initialDescription,
    this.initialMethod,
    this.initialAccountId,
    this.initialCardId,
    this.initialInstallments = 1,
    required this.initialDate,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  late final TextEditingController amountCtrl;
  late final TextEditingController descCtrl;
  late String category;
  late PaymentMethod method;
  String? accountId;
  String? cardId;
  late int installments;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    amountCtrl = TextEditingController(text: widget.initialAmount?.toStringAsFixed(0) ?? '');
    descCtrl = TextEditingController(text: widget.initialDescription ?? '');
    category = widget.initialCategory ?? kCategories.first;
    method = widget.initialMethod ?? PaymentMethod.cash;
    accountId = widget.initialAccountId ?? (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
    cardId = widget.initialCardId ?? (widget.cards.isNotEmpty ? widget.cards.first.id : null);
    installments = widget.initialInstallments;
    date = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final needCard = method == PaymentMethod.creditCard;
    final needAccount = method != PaymentMethod.creditCard;
    final cards = widget.cards;
    final accounts = widget.accounts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        runSpacing: 12,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tutar', prefixIcon: Icon(Icons.currency_lira)),
          ),
          DropdownButtonFormField<String>(
            value: category,
            items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => category = v ?? category),
            decoration: const InputDecoration(labelText: 'Kalem (Kategori)'),
          ),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Açıklama', prefixIcon: Icon(Icons.notes)),
          ),
          DropdownButtonFormField<PaymentMethod>(
            value: method,
            items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(paymentLabel(m)))).toList(),
            onChanged: (v) => setState(() => method = v ?? method),
            decoration: const InputDecoration(labelText: 'Nasıl Ödendi?'),
          ),
          if (needAccount)
            DropdownButtonFormField<String>(
              value: accountId,
              items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} • ${accountKindLabel(a.kind)}'))).toList(),
              onChanged: (v) => setState(() => accountId = v),
              decoration: const InputDecoration(labelText: 'Hangi Hesap'),
            ),
          if (needCard)
            DropdownButtonFormField<String>(
              value: cardId,
              items: cards.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (Kesim: ${c.cutDay}, Son: ${c.dueDay})'))).toList(),
              onChanged: (v) => setState(() => cardId = v),
              decoration: const InputDecoration(labelText: 'Hangi Kredi Kartı'),
            ),
          if (needCard)
            TextField(
              decoration: const InputDecoration(labelText: 'Taksit Sayısı', prefixIcon: Icon(Icons.view_week)),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => installments = int.tryParse(v) ?? 1),
            ),
          _DateRow(date: date, onPick: (picked) => setState(() => date = picked)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir tutar girin.')));
                  return;
                }
                final e = ExpenseEntry(
                  id: widget.initialAmount == null ? genId() : genId(),
                  date: date,
                  amount: amount,
                  category: category,
                  description: descCtrl.text.trim(),
                  method: method,
                  accountId: needAccount ? accountId : null,
                  cardId: needCard ? cardId : null,
                  installments: needCard ? (installments < 1 ? 1 : installments) : null,
                );
                widget.onSubmit(e);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ManageCardsAccountsSheet extends StatefulWidget {
  final AppState state;
  const ManageCardsAccountsSheet({super.key, required this.state});

  @override
  State<ManageCardsAccountsSheet> createState() => _ManageCardsAccountsSheetState();
}

class _ManageCardsAccountsSheetState extends State<ManageCardsAccountsSheet> {
  final cardNameCtrl = TextEditingController();
  final cardCutCtrl = TextEditingController(text: '15');
  final cardDueCtrl = TextEditingController(text: '1');
  String cardPayCat = 'Z.KREDİ KARTI';

  final accNameCtrl = TextEditingController();
  AccountKind accKind = AccountKind.bankCard;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Kartlar & Hesaplar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kredi Kartı Ekle', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  TextField(controller: cardNameCtrl, decoration: const InputDecoration(labelText: 'Kart Adı')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: cardCutCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kesim Günü (1-28)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: cardDueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Son Ödeme (1-28)'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: cardPayCat,
                    items: ['Z.KREDİ KARTI', 'V.KREDİ KARTI', 'KİŞİSEL'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => cardPayCat = v ?? cardPayCat),
                    decoration: const InputDecoration(labelText: 'Ödeme Kalemi'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Kart Ekle'),
                    onPressed: () {
                      final name = cardNameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final cut = int.tryParse(cardCutCtrl.text) ?? 15;
                      final due = int.tryParse(cardDueCtrl.text) ?? 1;
                      state.addCard(name, cut, due, cardPayCat);
                      cardNameCtrl.clear();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kart eklendi.')));
                      setState(() {});
                    },
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hesap Ekle', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  TextField(controller: accNameCtrl, decoration: const InputDecoration(labelText: 'Hesap Adı')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<AccountKind>(
                    value: accKind,
                    items: AccountKind.values.map((k) => DropdownMenuItem(value: k, child: Text(accountKindLabel(k)))).toList(),
                    onChanged: (v) => setState(() => accKind = v ?? accKind),
                    decoration: const InputDecoration(labelText: 'Tür'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Hesap Ekle'),
                    onPressed: () {
                      final name = accNameCtrl.text.trim();
                      if (name.isEmpty) return;
                      state.addAccount(name, accKind);
                      accNameCtrl.clear();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hesap eklendi.')));
                      setState(() {});
                    },
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Mevcut Kredi Kartları', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final c in state.cards)
              _GlassCard(
                child: ListTile(
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('Kesim: ${c.cutDay} • Son: ${c.dueDay} • Kalem: ${c.paymentCategory}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => state.deleteCard(c.id))),
                ),
              ),
            const SizedBox(height: 12),
            const Text('Mevcut Hesaplar', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final a in state.accounts)
              _GlassCard(
                child: ListTile(
                  title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(accountKindLabel(a.kind)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => state.deleteAccount(a.id))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PortfolioSheet extends StatefulWidget {
  final AppState state;
  const PortfolioSheet({super.key, required this.state});

  @override
  State<PortfolioSheet> createState() => _PortfolioSheetState();
}

class _PortfolioSheetState extends State<PortfolioSheet> {
  late final TextEditingController vCtrl;
  late final TextEditingController zCtrl;

  @override
  void initState() {
    super.initState();
    vCtrl = TextEditingController(text: widget.state.portfolioVolkan.toStringAsFixed(0));
    zCtrl = TextEditingController(text: widget.state.portfolioZeynep.toStringAsFixed(0));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SafeArea(
        child: Wrap(
          runSpacing: 12,
          children: [
            Text('Portföy', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            TextField(controller: vCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Volkan Bakiye')),
            TextField(controller: zCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Zeynep Bakiye')),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                onPressed: () {
                  final v = double.tryParse(vCtrl.text.replaceAll(',', '.')) ?? 0;
                  final z = double.tryParse(zCtrl.text.replaceAll(',', '.')) ?? 0;

                  state.portfolioVolkan = v;
                  state.portfolioZeynep = z;

                  final sum = v + z;
                  final wealth = state.currentWealthApprox;

                  // Warning rule: portfolio sum should not exceed "available wealth" (cash + multinet + carry)
                  if (sum > wealth + 0.01) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Uyarı: Portföy toplamı (${fmtMoney(sum)}) mevcut gelir+devreden toplamını (${fmtMoney(wealth)}) aşıyor.')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Portföy kaydedildi.')));
                  }

                  state._notify();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetAddChooserSheet extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onAddBudget;
  final VoidCallback onAddIncomePlan;
  const BudgetAddChooserSheet({
    super.key,
    required this.monthLabel,
    required this.onAddBudget,
    required this.onAddIncomePlan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Wrap(
          runSpacing: 12,
          children: [
            Text('Ekle • $monthLabel', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            _GlassCard(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Gider Bütçesi'),
                subtitle: const Text('Kategori bazlı aylık bütçe'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onAddBudget,
              ),
            ),
            _GlassCard(
              child: ListTile(
                leading: const Icon(Icons.savings),
                title: const Text('Gelir Planı'),
                subtitle: const Text('Gelecek aylar için tahmini gelir'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onAddIncomePlan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef BudgetMultiSubmit = void Function(double amount, String category, List<DateTime> months);

class AddBudgetMultiSheet extends StatefulWidget {
  final String title;
  final BudgetMultiSubmit onSubmit;

  final double? initialAmount;
  final String? initialCategory;
  final int initialYear;

  const AddBudgetMultiSheet({
    super.key,
    required this.title,
    required this.onSubmit,
    required this.initialYear,
    this.initialAmount,
    this.initialCategory,
  });

  @override
  State<AddBudgetMultiSheet> createState() => _AddBudgetMultiSheetState();
}

class _AddBudgetMultiSheetState extends State<AddBudgetMultiSheet> {
  late final TextEditingController amountCtrl;
  late String category;
  late int year;
  Set<int> selectedMonths = {};

  @override
  void initState() {
    super.initState();
    amountCtrl = TextEditingController(text: widget.initialAmount?.toStringAsFixed(0) ?? '');
    category = widget.initialCategory ?? kCategories.first;
    year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(11, (i) => DateTime.now().year - 5 + i);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        runSpacing: 12,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bütçe Tutarı')),
          DropdownButtonFormField<String>(
            value: category,
            items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => category = v ?? category),
            decoration: const InputDecoration(labelText: 'Kategori'),
          ),
          DropdownButtonFormField<int>(
            value: year,
            items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
            onChanged: (v) => setState(() {
              year = v ?? year;
              selectedMonths = {};
            }),
            decoration: const InputDecoration(labelText: 'Yıl'),
          ),
          _MonthChips(enabled: true, selectedMonths: selectedMonths, onChanged: (s) => setState(() => selectedMonths = s)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Ekle'),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli tutar girin.')));
                  return;
                }
                if (selectedMonths.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az 1 ay seçin.')));
                  return;
                }
                final months = selectedMonths.map((m) => DateTime(year, m, 1)).toList()
                  ..sort((a, b) => (a.year * 100 + a.month).compareTo(b.year * 100 + b.month));
                widget.onSubmit(amount, category, months);
              },
            ),
          ),
        ],
      ),
    );
  }
}

typedef IncomePlanMultiSubmit = void Function(double amount, IncomeType type, List<DateTime> months);

class AddPlannedIncomeMultiSheet extends StatefulWidget {
  final String title;
  final IncomePlanMultiSubmit onSubmit;
  final int initialYear;

  const AddPlannedIncomeMultiSheet({
    super.key,
    required this.title,
    required this.onSubmit,
    required this.initialYear,
  });

  @override
  State<AddPlannedIncomeMultiSheet> createState() => _AddPlannedIncomeMultiSheetState();
}

class _AddPlannedIncomeMultiSheetState extends State<AddPlannedIncomeMultiSheet> {
  late final TextEditingController amountCtrl;
  IncomeType type = IncomeType.salary;
  late int year;
  Set<int> selectedMonths = {};

  @override
  void initState() {
    super.initState();
    amountCtrl = TextEditingController();
    year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(11, (i) => DateTime.now().year - 5 + i);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        runSpacing: 12,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Gelir Tutarı')),
          DropdownButtonFormField<IncomeType>(
            value: type,
            items: IncomeType.values.map((t) => DropdownMenuItem(value: t, child: Text(incomeTypeLabel(t)))).toList(),
            onChanged: (v) => setState(() => type = v ?? type),
            decoration: const InputDecoration(labelText: 'Tür'),
          ),
          DropdownButtonFormField<int>(
            value: year,
            items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
            onChanged: (v) => setState(() {
              year = v ?? year;
              selectedMonths = {};
            }),
            decoration: const InputDecoration(labelText: 'Yıl'),
          ),
          _MonthChips(enabled: true, selectedMonths: selectedMonths, onChanged: (s) => setState(() => selectedMonths = s)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Ekle'),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli tutar girin.')));
                  return;
                }
                if (selectedMonths.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az 1 ay seçin.')));
                  return;
                }
                final months = selectedMonths.map((m) => DateTime(year, m, 1)).toList();
                widget.onSubmit(amount, type, months);
              },
            ),
          ),
        ],
      ),
    );
  }
}

typedef IncomeSubmit = void Function(double amount, IncomeType type, DateTime date, String description);

class AddIncomeSheet extends StatefulWidget {
  final IncomeSubmit onSubmit;
  final String title;
  final double? initialAmount;
  final IncomeType? initialType;
  final DateTime? initialDate;
  final String? initialDescription;

  const AddIncomeSheet({
    super.key,
    required this.onSubmit,
    this.title = 'Gelir Ekle',
    this.initialAmount,
    this.initialType,
    this.initialDate,
    this.initialDescription,
  });

  @override
  State<AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<AddIncomeSheet> {
  late final TextEditingController amountCtrl;
  late final TextEditingController descCtrl;
  late IncomeType type;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    amountCtrl = TextEditingController(text: widget.initialAmount?.toStringAsFixed(0) ?? '');
    descCtrl = TextEditingController(text: widget.initialDescription ?? '');
    type = widget.initialType ?? IncomeType.salary;
    date = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        runSpacing: 12,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tutar')),
          DropdownButtonFormField<IncomeType>(
            value: type,
            items: IncomeType.values.map((t) => DropdownMenuItem(value: t, child: Text(incomeTypeLabel(t)))).toList(),
            onChanged: (v) => setState(() => type = v ?? type),
            decoration: const InputDecoration(labelText: 'Tür'),
          ),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama')),
          _DateRow(date: date, onPick: (d) => setState(() => date = d)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli tutar girin.')));
                  return;
                }
                widget.onSubmit(amount, type, date, descCtrl.text.trim());
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> showMonthPickerDialog(BuildContext context, {required DateTime initial}) async {
  int y = initial.year;
  int m = initial.month;

  return showDialog<DateTime>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Ay Seç'),
      content: StatefulBuilder(
        builder: (context, setState) {
          final years = List<int>.generate(11, (i) => DateTime.now().year - 5 + i);
          final months = List<int>.generate(12, (i) => i + 1);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: y,
                items: years.map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                onChanged: (v) => setState(() => y = v ?? y),
                decoration: const InputDecoration(labelText: 'Yıl'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: m,
                items: months.map((v) => DropdownMenuItem(value: v, child: Text(monthNameTR(v)))).toList(),
                onChanged: (v) => setState(() => m = v ?? m),
                decoration: const InputDecoration(labelText: 'Ay'),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.pop(context, DateTime(y, m, 1)), child: const Text('Seç')),
      ],
    ),
  );
}

// ---------------- Report ----------------

class _ReportEntry {
  final DateTime date;
  final String category;
  final String description;
  final double amount;
  const _ReportEntry({required this.date, required this.category, required this.description, required this.amount});
}

class _Report {
  final List<_ReportEntry> entries;
  const _Report({required this.entries});
}

_Report _buildReport(AppState state, DateTime start, DateTime end) {
  final items = <_ReportEntry>[];
  for (final ledger in state._ledgers.values) {
    for (final ex in ledger.actualExpenses) {
      if (ex.date.isBefore(start) || ex.date.isAfter(end)) continue;
      items.add(_ReportEntry(date: ex.date, category: ex.category, description: ex.description, amount: ex.amount));
    }
  }
  items.sort((a, b) => b.date.compareTo(a.date));
  return _Report(entries: items);
}

// ---------------- UI Components ----------------

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _TopBar({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withOpacity(0.14),
              cs.tertiary.withOpacity(0.08),
              Colors.white.withOpacity(0.92),
            ],
          ),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                ]),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.95), const Color(0xFFF9FAFF)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.primary.withOpacity(0.10),
        border: Border.all(color: cs.primary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String title;
  final String desc;
  const _EmptyHint({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(desc, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        ]),
      ),
    );
  }
}

class _EditableTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _EditableTile({required this.child, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (onEdit == null && onDelete == null) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 10,
          top: 10,
          child: Row(
            children: [
              if (onEdit != null) _IconCircle(icon: Icons.edit, onTap: onEdit!),
              if (onEdit != null && onDelete != null) const SizedBox(width: 8),
              if (onDelete != null) _IconCircle(icon: Icons.delete_outline, onTap: onDelete!),
            ],
          ),
        )
      ],
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.92),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
        ),
        child: Icon(icon, size: 18, color: cs.primary),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final String subtitle;
  final String trailing;
  const _EntryTile({required this.leading, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cs.primary.withOpacity(0.12)),
            child: Icon(leading, color: cs.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool emphasize;
  const _MetricCard({required this.title, required this.value, required this.subtitle, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: cs.primary.withOpacity(0.7), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: emphasize
                ? Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)
                : Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
        ]),
      ),
    );
  }
}

class _MonthChips extends StatelessWidget {
  final bool enabled;
  final Set<int> selectedMonths;
  final ValueChanged<Set<int>> onChanged;

  const _MonthChips({required this.enabled, required this.selectedMonths, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(12, (i) {
            final m = i + 1;
            final selected = selectedMonths.contains(m);
            return ChoiceChip(
              label: Text(monthNameTR(m)),
              selected: selected,
              onSelected: !enabled
                  ? null
                  : (v) {
                      final next = Set<int>.from(selectedMonths);
                      if (v) {
                        next.add(m);
                      } else {
                        next.remove(m);
                      }
                      onChanged(next);
                    },
            );
          }),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateRow({required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today),
      title: const Text('Tarih'),
      subtitle: Text(fmtDate(date)),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(DateTime.now().year - 5),
          lastDate: DateTime(DateTime.now().year + 5),
          initialDate: date,
        );
        if (picked != null) onPick(picked);
      },
    );
  }
}
