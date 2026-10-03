import 'package:flutter/foundation.dart';

import '../models/loan.dart';
import 'api_client.dart';
import 'mock_data.dart';

/// Single source of loan data for every screen, loaded from the Loan API.
///
/// Screens read the cached lists synchronously and rebuild through
/// ListenableBuilder; [refresh] reloads everything from the server.
class LoanRepository extends ChangeNotifier {
  LoanRepository._();
  static final LoanRepository instance = LoanRepository._();

  final ApiClient _api = ApiClient.instance;

  List<Loan> _loans = [];
  List<LoanApplication> _applications = [];

  // Built-in list until GET /catalog answers (the order screen needs ids).
  List<LoanProduct> _products = MockData.products;
  List<String> _purposes = MockData.purposes;
  String _currency = MockData.currency;
  bool _catalogLoaded = false;

  final Map<String, List<LoanDocument>> _documents = {};
  final Set<String> _documentsLoading = {};

  bool _loading = false;
  ApiException? _error;
  DateTime? _loadedAt;

  bool get isLoading => _loading;

  /// Last error of [refresh] (null when the last load worked).
  ApiException? get error => _error;

  /// True after the first successful load.
  bool get hasData => _loadedAt != null;

  List<LoanProduct> get products => _products;
  List<String> get purposes => _purposes;
  String get currency => _currency;
  bool get catalogLoaded => _catalogLoaded;

  List<Loan> get loans {
    final sorted = [..._loans];
    sorted.sort((a, b) => a.state.index.compareTo(b.state.index));
    return sorted;
  }

  /// Applications still under review or rejected (approved ones are loans).
  List<LoanApplication> get applications => List.unmodifiable(_applications);

  Loan? byId(String id) {
    for (final l in _loans) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Most urgent open loan: overdue first, otherwise the nearest due date.
  Loan? get urgentLoan {
    final open = _loans.where((l) => l.state != LoanState.closed).toList();
    if (open.isEmpty) return null;
    for (final l in open) {
      if (l.state == LoanState.overdue) return l;
    }
    open.sort((a, b) => a.firstUnpaid!.dueDate.compareTo(b.firstUnpaid!.dueDate));
    return open.first;
  }

  /// All paid installments of all loans, newest first.
  List<(Loan, Installment)> get paymentHistory {
    final list = <(Loan, Installment)>[
      for (final l in _loans)
        for (final i in l.schedule)
          if (i.isPaid) (l, i),
    ];
    list.sort((a, b) => b.$2.paidDate!.compareTo(a.$2.paidDate!));
    return list;
  }

  // ------------------------------------------------------------- loading

  /// Loads loans (with schedules), applications and the product catalog.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (!_catalogLoaded) await _loadCatalogQuietly();

      final list = await _api.get('/api/v1/loans') as Map<String, dynamic>;
      final items = (list['items'] as List).cast<Map<String, dynamic>>();
      final details = await Future.wait([
        for (final item in items) _api.get('/api/v1/loans/${item['id']}'),
      ]);
      _loans = [
        for (final d in details) Loan.fromJson(d as Map<String, dynamic>),
      ];

      final apps = await _api.get('/api/v1/applications') as List;
      _applications = [
        for (final a in apps) LoanApplication.fromJson(a as Map<String, dynamic>),
      ]
          .where((a) => a.status == 'submitted' || a.status == 'rejected')
          .toList();

      _documents.clear();
      _loadedAt = DateTime.now();
    } on ApiException catch (e) {
      _error = e;
    } catch (e) {
      debugPrint('LoanRepository.refresh: $e');
      _error = ApiException(0, 'bad_response', '$e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// GET /catalog (public). Throws on failure.
  Future<void> loadCatalog() async {
    final j = await _api.getPublic('/api/v1/catalog') as Map<String, dynamic>;
    final products = [
      for (final p in (j['products'] as List))
        LoanProduct.fromJson(p as Map<String, dynamic>),
    ];
    if (products.isNotEmpty) _products = products;
    _purposes = (j['purposes'] as List).cast<String>().toList();
    _currency = (j['currency'] as String?) ?? _currency;
    _catalogLoaded = true;
    notifyListeners();
  }

  Future<void> _loadCatalogQuietly() async {
    try {
      await loadCatalog();
    } catch (e) {
      debugPrint('LoanRepository.loadCatalog: $e');
    }
  }

  Future<void> _reloadLoan(String loanId) async {
    final j = await _api.get('/api/v1/loans/$loanId') as Map<String, dynamic>;
    final loan = Loan.fromJson(j);
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index < 0) {
      _loans.add(loan);
    } else {
      _loans[index] = loan;
    }
    notifyListeners();
  }

  /// Forget everything (sign out).
  void clear() {
    _loans = [];
    _applications = [];
    _documents.clear();
    _documentsLoading.clear();
    _error = null;
    _loadedAt = null;
    notifyListeners();
  }

  // ----------------------------------------------------------- documents

  /// Cached documents of a loan, or null while not loaded yet.
  List<LoanDocument>? documentsFor(String loanId) => _documents[loanId];

  /// Starts loading the documents of a loan once. Safe to call from build().
  void ensureDocuments(String loanId) {
    if (_documents.containsKey(loanId) || _documentsLoading.contains(loanId)) {
      return;
    }
    _documentsLoading.add(loanId);
    _loadDocuments(loanId);
  }

  Future<void> _loadDocuments(String loanId) async {
    try {
      final list = await _api.get('/api/v1/loans/$loanId/documents') as List;
      _documents[loanId] = [
        for (final d in list) LoanDocument.fromJson(d as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('LoanRepository.documents: $e');
      _documents[loanId] = const [];
    } finally {
      _documentsLoading.remove(loanId);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- actions

  /// Pays the earliest unpaid installment (overdue first).
  /// The same Idempotency-Key is reused when the network drops, so a retry
  /// never pays twice.
  Future<Installment?> payNext(String loanId) async {
    final key = _api.newKey();
    Map<String, dynamic>? res;
    try {
      res = await _pay(loanId, key);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
    }
    res ??= await _pay(loanId, key);
    final payment = res['payment'] as Map<String, dynamic>;
    final number = (payment['installmentNumber'] as num).toInt();
    await _reloadLoan(loanId);
    final loan = byId(loanId);
    if (loan == null) return null;
    for (final i in loan.schedule) {
      if (i.number == number) return i;
    }
    return null;
  }

  Future<Map<String, dynamic>> _pay(String loanId, String key) async {
    final res = await _api.post(
      '/api/v1/loans/$loanId/payments',
      headers: {'Idempotency-Key': key},
    );
    return res as Map<String, dynamic>;
  }

  /// POST /applications. Rate and monthly payment come from the server.
  Future<LoanApplication> submitApplication({
    required LoanProduct product,
    required double amount,
    required int termMonths,
    required String purpose,
  }) async {
    final j = await _api.post('/api/v1/applications', body: {
      'productId': product.id,
      'amount': amount,
      'termMonths': termMonths,
      'purpose': purpose,
    }) as Map<String, dynamic>;
    final app = LoanApplication.fromJson(j);
    _applications.insert(0, app);
    notifyListeners();
    return app;
  }
}
