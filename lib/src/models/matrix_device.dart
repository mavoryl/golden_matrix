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
/// ### Generic phones (legacy names — pick by size class)
///
/// | Preset           | Logical size  | DPR    | Safe area (top/bottom) |
/// |------------------|---------------|--------|------------------------|
/// | `phoneSmall`     | 375 x 667     | 2.0    | 20 / 0                 |
/// | `phoneMedium`    | 390 x 844     | 3.0    | 47 / 34                |
/// | `phoneLarge`     | 414 x 896     | 3.0    | 44 / 34                |
/// | `androidSmall`   | 360 x 800     | 4.0    | 0 / 0                  |
/// | `androidMedium`  | 412 x 915     | 2.625  | 0 / 0                  |
///
/// ### Modern phones
///
/// | Preset             | Logical size  | DPR    | Safe area (top/bottom) |
/// |--------------------|---------------|--------|------------------------|
/// | `iphone15Pro`      | 393 x 852     | 3.0    | 59 / 34                |
/// | `iphone16ProMax`   | 440 x 956     | 3.0    | 62 / 34                |
/// | `pixel8`           | 412 x 915     | 2.625  | 24 / 24                |
/// | `pixel8Pro`        | 448 x 998     | 2.625  | 24 / 24                |
/// | `galaxyS24`        | 384 x 832     | 3.0    | 24 / 24                |
///
/// ### Foldables
///
/// | Preset                       | Logical size | DPR    | Safe area |
/// |------------------------------|--------------|--------|-----------|
/// | `galaxyZFoldFolded`          | 374 x 882    | 3.0    | 24 / 24   |
/// | `galaxyZFoldUnfolded`        | 716 x 882    | 2.625  | 24 / 24   |
///
/// ### Tablets
///
/// | Preset                | Logical size   | DPR  | Safe area (top/bottom) |
/// |-----------------------|----------------|------|------------------------|
/// | `tablet`              | 768 x 1024     | 2.0  | 20 / 0                 |
/// | `tabletLandscape`     | 1024 x 768     | 2.0  | 20 / 0                 |
/// | `ipadMini`            | 744 x 1133     | 2.0  | 24 / 20                |
/// | `ipadAir`             | 820 x 1180     | 2.0  | 24 / 20                |
/// | `ipadPro11`           | 834 x 1194     | 2.0  | 24 / 20                |
/// | `ipadPro11Landscape`  | 1194 x 834     | 2.0  | 24 / 20                |
/// | `ipadPro13`           | 1024 x 1366    | 2.0  | 24 / 20                |
/// | `ipadPro13Landscape`  | 1366 x 1024    | 2.0  | 24 / 20                |
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

  // Modern iPhones
  static const iphone15Pro = MatrixDevice(
    name: 'iphone15Pro',
    logicalSize: Size(393, 852),
    pixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 59, bottom: 34),
  );

  static const iphone16ProMax = MatrixDevice(
    name: 'iphone16ProMax',
    logicalSize: Size(440, 956),
    pixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 62, bottom: 34),
  );

  // Modern Android phones
  static const pixel8 = MatrixDevice(
    name: 'pixel8',
    logicalSize: Size(412, 915),
    pixelRatio: 2.625,
    safeArea: EdgeInsets.only(top: 24, bottom: 24),
  );

  static const pixel8Pro = MatrixDevice(
    name: 'pixel8Pro',
    logicalSize: Size(448, 998),
    pixelRatio: 2.625,
    safeArea: EdgeInsets.only(top: 24, bottom: 24),
  );

  static const galaxyS24 = MatrixDevice(
    name: 'galaxyS24',
    logicalSize: Size(384, 832),
    pixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 24),
  );

  // Foldables (Galaxy Z Fold 5 reference geometry)
  static const galaxyZFoldFolded = MatrixDevice(
    name: 'galaxyZFoldFolded',
    logicalSize: Size(374, 882),
    pixelRatio: 3.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 24),
  );

  static const galaxyZFoldUnfolded = MatrixDevice(
    name: 'galaxyZFoldUnfolded',
    logicalSize: Size(716, 882),
    pixelRatio: 2.625,
    safeArea: EdgeInsets.only(top: 24, bottom: 24),
  );

  // iPads
  static const ipadMini = MatrixDevice(
    name: 'ipadMini',
    logicalSize: Size(744, 1133),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  static const ipadAir = MatrixDevice(
    name: 'ipadAir',
    logicalSize: Size(820, 1180),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  static const ipadPro11 = MatrixDevice(
    name: 'ipadPro11',
    logicalSize: Size(834, 1194),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  static const ipadPro11Landscape = MatrixDevice(
    name: 'ipadPro11Landscape',
    logicalSize: Size(1194, 834),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  static const ipadPro13 = MatrixDevice(
    name: 'ipadPro13',
    logicalSize: Size(1024, 1366),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  static const ipadPro13Landscape = MatrixDevice(
    name: 'ipadPro13Landscape',
    logicalSize: Size(1366, 1024),
    pixelRatio: 2.0,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  );

  /// Returns a copy of this device with selected fields replaced.
  ///
  /// Useful for tweaking a built-in preset: rotate, override DPR, or
  /// adjust safe area without re-declaring the whole device.
  ///
  /// ```dart
  /// final landscape = MatrixDevice.ipadPro11.copyWith(
  ///   name: 'ipadPro11Landscape',
  ///   logicalSize: const Size(1194, 834),
  /// );
  /// ```
  MatrixDevice copyWith({
    String? name,
    Size? logicalSize,
    double? pixelRatio,
    EdgeInsets? safeArea,
  }) {
    return MatrixDevice(
      name: name ?? this.name,
      logicalSize: logicalSize ?? this.logicalSize,
      pixelRatio: pixelRatio ?? this.pixelRatio,
      safeArea: safeArea ?? this.safeArea,
    );
  }

  String get slug => slugify(name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MatrixDevice && other.name == name);

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'MatrixDevice($name, ${logicalSize.width}x${logicalSize.height})';
}
