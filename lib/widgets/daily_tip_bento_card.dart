import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyTipBentoCard extends StatefulWidget {
  /// Incremented by the dashboard's pull-to-refresh — triggers a new AI tip.
  final int refreshCount;

  const DailyTipBentoCard({super.key, this.refreshCount = 0});

  @override
  State<DailyTipBentoCard> createState() => _DailyTipBentoCardState();
}

class _DailyTipBentoCardState extends State<DailyTipBentoCard>
    with SingleTickerProviderStateMixin {
  int _lastRefreshCount = 0;
  bool _isGenerating = false;
  Map<String, dynamic>? _displayedTip;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DailyTipBentoCard old) {
    super.didUpdateWidget(old);
    if (widget.refreshCount != _lastRefreshCount) {
      _lastRefreshCount = widget.refreshCount;
      _generateNewTip();
    }
  }

  Future<void> _generateNewTip() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(
        Uri.parse(
            'https://us-central1-expensesplit-pro-9e1c8.cloudfunctions.net/generateNewDailyTip'),
      );
      final res = await req.close();
      debugPrint('generateNewDailyTip → ${res.statusCode}');
      // Firestore stream will auto-update with the new tip
    } catch (e) {
      debugPrint('Error generating tip: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _animateIn() {
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_tips')
          .orderBy('generatedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting &&
            _displayedTip == null) {
          return const _BentoSkeleton(message: 'Loading your daily nudge…');
        }

        // While generating — show skeleton with message
        if (_isGenerating) {
          return const _BentoSkeleton(
              message: '✨ Generating a fresh tip with AI…');
        }

        final docs = snapshot.data?.docs ?? [];
        final tips = docs
            .map((d) => d.data() as Map<String, dynamic>)
            .where((d) => d['isActive'] == true)
            .toList();

        if (tips.isEmpty) return const SizedBox.shrink();

        // When stream updates and we have a new tip, pick the latest one
        final latestTip = tips.first;
        if (_displayedTip == null ||
            _displayedTip!['message'] != latestTip['message']) {
          // Schedule animation after build
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _animateIn());
          _displayedTip = latestTip;
        }

        final tip = _displayedTip ?? latestTip;
        final message =
            tip['message'] as String? ?? 'Stay on top of your finances!';
        final category = tip['category'] as String? ?? 'wisdom';

        return _TipCard(
          message: message,
          category: category,
          fadeAnim: _fadeAnim,
          slideAnim: _slideAnim,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card UI
// ─────────────────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final String message;
  final String category;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _TipCard({
    required this.message,
    required this.category,
    required this.fadeAnim,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    IconData catIcon;
    Color catColor;
    String catLabel;

    switch (category) {
      case 'saving':
        catIcon = Icons.savings_rounded;
        catColor = const Color(0xFF10B981);
        catLabel = 'Saving Tip';
        break;
      case 'security':
        catIcon = Icons.security_rounded;
        catColor = const Color(0xFF3B82F6);
        catLabel = 'Security';
        break;
      case 'positive_reinforcement':
        catIcon = Icons.emoji_events_rounded;
        catColor = const Color(0xFFEC4899);
        catLabel = 'Keep it up! 🎉';
        break;
      case 'wisdom':
      default:
        catIcon = Icons.lightbulb_outline_rounded;
        catColor = const Color(0xFFF59E0B);
        catLabel = 'Financial Wisdom';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            catColor.withValues(alpha: 0.1),
            cs.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: catColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Financial Nudge',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    catLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: catColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // AI badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: catColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 11, color: catColor),
                    const SizedBox(width: 3),
                    Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Animated message ─────────────────────────────────────────
          FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Footer hint ──────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.swipe_down_alt_rounded,
                  size: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
              const SizedBox(width: 5),
              Text(
                'Pull down to get a new AI tip',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton / Loading state
// ─────────────────────────────────────────────────────────────────────────────

class _BentoSkeleton extends StatelessWidget {
  final String message;
  const _BentoSkeleton({this.message = ''});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message.isEmpty ? 'Loading…' : message,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
