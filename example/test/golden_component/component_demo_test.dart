import 'package:flutter/material.dart';
import 'package:golden_matrix/golden_matrix.dart';
import 'package:golden_matrix_example/widgets/notification_badge.dart';
import 'package:golden_matrix_example/widgets/sample_button.dart';
import 'package:golden_matrix_example/widgets/user_avatar.dart';

void main() {
  // Demo of `componentMatrixGolden` — captures widgets at their intrinsic
  // size, light + dark themes. PNGs end up exactly button/badge-sized
  // rather than 375×667 with a tiny widget centered in whitespace.
  //
  // `tolerance: 0.005` (0.5%) absorbs sub-pixel anti-aliasing differences
  // between dev machines and CI macOS runners. Without it, 1-pixel diffs
  // would fail the regression check on a fresh CI image even though the
  // widget renders identically by eye.
  const kDemoTolerance = 0.005;

  componentMatrixGolden(
    'NotificationBadge',
    scenarios: const [
      MatrixScenario('info', builder: _badgeInfo),
      MatrixScenario('warning', builder: _badgeWarning),
      MatrixScenario('error', builder: _badgeError),
    ],
    axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
    tolerance: kDemoTolerance,
  );

  componentMatrixGolden(
    'SampleButton',
    scenarios: const [
      MatrixScenario('default', builder: _btnDefault),
      MatrixScenario('disabled', builder: _btnDisabled),
      MatrixScenario('loading', builder: _btnLoading),
    ],
    axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
    freezeAnimations: true, // loading uses CircularProgressIndicator
    tolerance: kDemoTolerance,
  );

  componentMatrixGolden(
    'UserAvatar',
    scenarios: const [
      MatrixScenario('small_offline', builder: _avatarSmallOffline),
      MatrixScenario('medium_online', builder: _avatarMediumOnline),
      MatrixScenario('large_online', builder: _avatarLargeOnline),
    ],
    axes: const MatrixAxes(themes: [MatrixTheme.light, MatrixTheme.dark]),
    tolerance: kDemoTolerance,
  );
}

// Top-level builders keep MatrixScenario const-able.

Widget _badgeInfo() =>
    const NotificationBadge(count: 3, label: 'Messages', severity: BadgeSeverity.info);
Widget _badgeWarning() =>
    const NotificationBadge(count: 12, label: 'Alerts', severity: BadgeSeverity.warning);
Widget _badgeError() =>
    const NotificationBadge(count: 99, label: 'Errors', severity: BadgeSeverity.error);

Widget _btnDefault() => const SampleButton(label: 'Click me');
Widget _btnDisabled() => const SampleButton(label: 'Disabled', enabled: false);
Widget _btnLoading() => const SampleButton(label: 'Loading', loading: true);

Widget _avatarSmallOffline() => const UserAvatar(name: 'Maya Patel', size: AvatarSize.small);
Widget _avatarMediumOnline() => const UserAvatar(name: 'Alex Rivera', isOnline: true);
Widget _avatarLargeOnline() =>
    const UserAvatar(name: 'Sam Lee', size: AvatarSize.large, isOnline: true);
