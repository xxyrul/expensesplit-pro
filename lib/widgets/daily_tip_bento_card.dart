import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyTipBentoCard extends StatefulWidget {
  /// External refresh trigger — increment this from the pull-to-refresh
  /// callback to cycle to a new tip and (every 3rd time) fetch a fresh AI tip.
  final int refreshCount;

  const DailyTipBentoCard({super.key, this.refreshCount = 0});

  @override
  State<DailyTipBentoCard> createState() => _DailyTipBentoCardState();
}

class _DailyTipBentoCardState extends State<DailyTipBentoCard>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  int _currentIndex = 0;
  int _lastRefreshCount = 0;
  bool _isGenerating = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Cache the full tips list so we can cycle locally without re-fetching
  List<Map<String, dynamic>> _cachedTips = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
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
      _cycleToNextTip();
    }
  }

  void _cycleToNextTip() {
    if (_cachedTips.isEmpty) return;

    // Pick a different random tip
    int next = _currentIndex;
    if (_cachedTips.length > 1) {
      while (next == _currentIndex) {
        next = _rng.nextInt(_cachedTips.length);
      }
    }
    setState(() => _currentIndex = next);
    _animCtrl.forward(from: 0);

    // Every 3rd refresh → call Gemini to generate a brand-new tip
    if (_lastRefreshCount > 0 && _lastRefreshCount % 3 == 0) {
      _generateNewTip();
    }
  }

  Future<void> _generateNewTip() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(
        Uri.parse(
            'https://us-central1-expensesplit-pro-9e1c8.cloudfunctions.net/generateNewDailyTip'),
      );
      final res = await req.close();
      debugPrint('generateNewDailyTip status: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error generating new tip: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_tips')
          .orderBy('generatedAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedTips.isEmpty) {
          return const _BentoSkeleton();
        }

        // Update cache when new data arrives
        if (snapshot.hasData) {
          final active = snapshot.data!.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .where((d) => d['isActive'] == true)
              .toList();
          if (active.isNotEmpty) {
            _cachedTips = active;
            // Clamp index in case list shrank
            if (_currentIndex >= _cachedTips.length) {
              _currentIndex = 0;
            }
          }
        }

        if (_cachedTips.isEmpty) return const SizedBox.shrink();

        final tipData = _cachedTips[_currentIndex];
        final message =
            tipData['message'] as String? ?? 'Stay on top of your finances!';
        final category = tipData['category'] as String? ?? 'wisdom';

        return _TipCard(
          message: message,
          category: category,
          isGenerating: _isGenerating,
          fadeAnim: _fadeAnim,
          slideAnim: _slideAnim,
          tipCount: _cachedTips.length,
          currentIndex: _currentIndex,
          onTapRefresh: () {
            setState(() {
              _lastRefreshCount++;
            });
            _cycleToNextTip();
          },
        );
      },
    );
  }
}

class _TipCard extends StatelessWidget {
  final String message;
  final String category;
  final bool isGenerating;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final int tipCount;
  final int currentIndex;
  final VoidCallback onTapRefresh;

  const _TipCard({
    required this.message,
    required this.category,
    required this.isGenerating,
    required this.fadeAnim,
    required this.slideAnim,
    required this.tipCount,
    required this.currentIndex,
    required this.onTapRefresh,
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
        catLabel = 'Saving';
        break;
      case 'security':
        catIcon = Icons.security_rounded;
        catColor = const Color(0xFF3B82F6);
        catLabel = 'Security';
        break;
      case 'positive_reinforcement':
        catIcon = Icons.emoji_events_rounded;
        catColor = const Color(0xFFEC4899);
        catLabel = 'Keep it up';
        break;
      case 'wisdom':
      default:
        catIcon = Icons.lightbulb_outline_rounded;
        catColor = const Color(0xFFF59E0B);
        catLabel = 'Wisdom';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            catColor.withOpacity(0.08),
            cs.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: catColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: catColor.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              const SizedBox(width: 10),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: catColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Tap-to-cycle button
              GestureDetector(
                onTap: onTapRefresh,
                child: AnimatedRotation(
                  turns: isGenerating ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isGenerating
                          ? Icons.auto_awesome_rounded
                          : Icons.refresh_rounded,
                      color: catColor,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Animated message ────────────────────────────────────────
          FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Footer hint ─────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.swipe_down_rounded,
                  size: 13, color: cs.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text(
                isGenerating
                    ? '✨ Generating a fresh tip with AI…'
                    : 'Pull down or tap ↻ for a new nudge',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withOpacity(0.55),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              // Dot indicators
              if (tipCount > 1)
                Row(
                  children: List.generate(
                    tipCount.clamp(0, 5),
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(left: 3),
                      width: i == currentIndex % 5 ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == currentIndex % 5
                            ? catColor
                            : catColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BentoSkeleton extends StatelessWidget {
  const _BentoSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHigh
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
