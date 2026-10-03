import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../theme.dart';
import 'documents_screen.dart';
import 'history_screen.dart';
import 'loans_screen.dart';
import 'lock_screen.dart';
import 'more_screen.dart';
import 'order_loan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _relockAfter = Duration(seconds: 30);

  int _tab = 0; // 0 home, 1 history, 2 documents, 3 more
  DateTime? _pausedAt;
  bool _locking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: refresh() notifies listeners right away.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => LoanRepository.instance.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ask for biometrics again if the app was in background for 30 s or more.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          !_locking &&
          DateTime.now().difference(pausedAt) >= _relockAfter) {
        _relock();
      }
      LoanRepository.instance.refresh();
    }
  }

  Future<void> _relock() async {
    _locking = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LockScreen(isRelock: true),
      ),
    );
    _locking = false;
  }

  void _openOrder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderLoanScreen(
          onSubmitted: () => setState(() => _tab = 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          LoansScreen(
            onOrderLoan: _openOrder,
            onOpenTab: (i) => setState(() => _tab = i),
          ),
          const HistoryScreen(),
          const DocumentsScreen(),
          const MoreScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openOrder,
        shape: const CircleBorder(),
        backgroundColor: AppColors.primary,
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        height: 68,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          children: [
            _item(0, Icons.home_outlined, Icons.home, 'nav.home'),
            _item(1, Icons.history, Icons.history, 'nav.history'),
            const SizedBox(width: 72),
            _item(2, Icons.description_outlined, Icons.description, 'nav.docs'),
            _item(3, Icons.apps, Icons.apps, 'nav.more'),
          ],
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData activeIcon, String key) {
    final selected = _tab == index;
    final color = selected ? AppColors.ink : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color),
            const SizedBox(height: 2),
            Text(
              context.tr(key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
