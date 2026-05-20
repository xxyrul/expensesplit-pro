import 'package:flutter/material.dart';

class RecentGovernanceActions extends StatelessWidget {
  final List<GovernanceAction> actions;

  const RecentGovernanceActions({
    Key? key,
    this.actions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = actions.isEmpty
        ? [
            GovernanceAction(
              keyText: 'UPDATE_PRIVACY_POLICY',
              description: 'Updated policy: Mask PII = true, Data R...',
              metadata: 'norazrul7@gmail.com @ 17:36',
            ),
          ]
        : actions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.history, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Recent Governance Actions',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: items.map((a) => _buildRow(context, a)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, GovernanceAction a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Left badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C2D12), // dark brownish-orange
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              a.keyText,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Middle description
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                a.description,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right metadata
          Text(
            a.metadata,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class GovernanceAction {
  final String keyText;
  final String description;
  final String metadata;

  GovernanceAction({
    required this.keyText,
    required this.description,
    required this.metadata,
  });
}
