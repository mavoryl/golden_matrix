import 'package:flutter/widgets.dart';

import '../core/slug.dart';

/// Represents a device configuration for matrix golden testing.
///
/// A device captures the logical viewport size, pixel ratio, and safe
/// area insets used to render goldens. Several presets are provided as
/// static constants, and named aliases match real devices.
///
/// ## Built-in presets
///
/// | Preset           | Logical size  | DPR    | Safe area (top/bottom) |
/// |------------------|---------------|--------|------------------------|
/// | `phoneSmall`     | 375 x 667     | 2.0    | 20 / 0                 |
/// | `phoneMedium`    | 390 x 844     | 3.0    | 47 / 34                |
/// | `phoneLarge`     | 414 x 896     | 3.0    | 44 / 34                |
/// | `androidSmall`   | 360 x 800     | 4.0    | 0 / 0                  |
/// | `androidMedium`  | 412 x 915     | 2.625  | 0 / 0                  |
/// | `tablet`         | 768 x 1024    | 2.0    | 20 / 0                 |
/// | `tabletLandscape`| 1024 x 768    | 2.0    | 20 / 0                 |
///
/// ## Named aliases
///
/// Use these for self-documenting tests when targeting a specific real
/// device:
///   * `iphoneSE` → [phoneSmall]
///   * `iphone15` → [phoneMedium]
///   * `iphone15ProMax` → [phoneLarge]
///   * `galaxyS20` → [androidSmall]
///   * `galaxyA51` → [androidMedium]
///   * `ipadPortrait` → [tablet]
class MatrixDevice {
  final String name;
  final Size logicalSize;
  final double pixelRatio;
  final EdgeInsets safeArea;

  const MatrixDevice({
    required this.name,
    required this.logicalSize,
    this.pixelRatio = 1.0,
    this.safeArea = EdgeInsets.zero,
  }) : assert(name != '', 'MatrixDevice name must not be empty'),
       assert(pixelRatio > 0, 'MatrixDevice pixelRatio must be > 0');

  // iOS devices
  static const phoneSmall = MatrixDevice(
    name: 'phoneSmall',
    logicalSize: Size(375, 667),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 20),
  );

  static const phoneMedium = MatrixDevice(
    name: 'phoneMedium',
    logicalSize: Size(390, 844),
    pixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 47, bottom: 34),
  );

  static const phoneLarge = MatrixDevice(
    name: 'phoneLarge',
    logicalSize: Size(414, 896),
    pixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 44, bottom: 34),
  );

  // Android devices
  static const androidSmall = MatrixDevice(
    name: 'androidSmall',
    logicalSize: Size(360, 800),
    pixelRatio: 4.0,
  );

  static const androidMedium = MatrixDevice(
    name: 'androidMedium',
    logicalSize: Size(412, 915),
    pixelRatio: 2.625,
  );

  // Tablet
  static const tablet = MatrixDevice(
    name: 'tablet',
    logicalSize: Size(768, 1024),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 20),
  );

  // Named aliases for real devices
  static const iphoneSE = phoneSmall;
  static const iphone15 = phoneMedium;
  static const iphone15ProMax = phoneLarge;
  static const galaxyS20 = androidSmall;
  static const galaxyA51 = androidMedium;
  static const ipadPortrait = tablet;

  // Tablet landscape
  static const tabletLandscape = MatrixDevice(
    name: 'tabletLandscape',
    logicalSize: Size(1024, 768),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 20),
  );

  String get slug => slugify(name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MatrixDevice && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MatrixDevice($name, ${logicalSize.width}x${logicalSize.height})';
}
