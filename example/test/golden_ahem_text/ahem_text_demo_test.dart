import 'package:flutter/material.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix_example/widgets/sample_card.dart';

void main() {
  matrixGolden(
    'AhemTextDemo',
    scenarios: [
      MatrixScenario(
        'card_with_icons',
        builder: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              SampleCard(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'You have 3 unread messages',
              ),
              SizedBox(height: 12),
              SampleCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'Theme, language, account',
              ),
              SizedBox(height: 12),
              SampleCard(icon: Icons.help_outline, title: 'Help', subtitle: 'FAQ and support'),
            ],
          ),
        ),
      ),
    ],
    axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
  );
}
