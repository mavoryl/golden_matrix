import 'package:flutter/widgets.dart';

import '../models/matrix_result.dart';

/// Renders a self-contained HTML report from a [MatrixResult].
class HtmlTemplate {
  /// Renders the complete HTML document.
  static String render(MatrixResult result) {
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="en">');
    _writeHead(buf, result.name);
    buf.writeln('<body>');
    _writeSummary(buf, result);
    _writeStaleSection(buf, result);
    _writeFilters(buf, result);
    _writeScenarios(buf, result);
    _writeScript(buf);
    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }

  static void _writeHead(StringBuffer buf, String title) {
    buf.writeln('<head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buf.writeln('<title>${_esc(title)} — Golden Matrix Report</title>');
    buf.writeln('<style>');
    buf.writeln(_css);
    buf.writeln('</style>');
    buf.writeln('</head>');
  }

  static void _writeSummary(StringBuffer buf, MatrixResult result) {
    final duration = result.duration.inSeconds > 0
        ? '${result.duration.inSeconds}s'
        : '${result.duration.inMilliseconds}ms';
    final time =
        '${result.timestamp.year}'
        '-${_pad(result.timestamp.month)}'
        '-${_pad(result.timestamp.day)}'
        ' ${_pad(result.timestamp.hour)}'
        ':${_pad(result.timestamp.minute)}'
        ':${_pad(result.timestamp.second)}';

    buf.writeln('<header>');
    buf.writeln('<h1>${_esc(result.name)}</h1>');
    buf.writeln('<p class="meta">$time &middot; $duration</p>');
    buf.writeln('<div class="summary">');
    buf.writeln(
      '<div class="stat"><span class="stat-value">${result.total}</span>'
      '<span class="stat-label">Total</span></div>',
    );
    buf.writeln(
      '<div class="stat stat-passed"><span class="stat-value">${result.passed}</span>'
      '<span class="stat-label">Passed</span></div>',
    );
    if (result.failed > 0) {
      buf.writeln(
        '<div class="stat stat-failed"><span class="stat-value">${result.failed}</span>'
        '<span class="stat-label">Failed</span></div>',
      );
    }
    if (result.skipped > 0) {
      buf.writeln(
        '<div class="stat stat-skipped"><span class="stat-value">${result.skipped}</span>'
        '<span class="stat-label">Skipped</span></div>',
      );
    }
    if (result.warningCount > 0) {
      buf.writeln(
        '<div class="stat stat-warning"><span class="stat-value">${result.warningCount}</span><span class="stat-label">Warnings</span></div>',
      );
    }
    if (result.staleGoldens.isNotEmpty) {
      buf.writeln(
        '<div class="stat stat-warning"><span class="stat-value">${result.staleGoldens.length}</span><span class="stat-label">Stale</span></div>',
      );
    }
    buf.writeln('</div>');
    buf.writeln('</header>');
  }

  static void _writeStaleSection(StringBuffer buf, MatrixResult result) {
    if (result.staleGoldens.isEmpty) return;
    buf.writeln('<details class="stale-section" open>');
    buf.writeln(
      '<summary>'
      '${result.staleGoldens.length} stale golden file'
      '${result.staleGoldens.length == 1 ? '' : 's'} '
      '(not produced by any combination in this run)'
      '</summary>',
    );
    buf.writeln('<ul class="stale-list">');
    for (final path in result.staleGoldens) {
      buf.writeln('<li><code>${_esc(path)}</code></li>');
    }
    buf.writeln('</ul>');
    buf.writeln('</details>');
  }

  static void _writeFilters(StringBuffer buf, MatrixResult result) {
    final scenarios = result.results.map((r) => r.combination.scenario.name).toSet().toList()
      ..sort();
    final themes = result.results.map((r) => r.combination.theme.name).toSet().toList()..sort();
    final statuses = result.results.map((r) => r.status.name).toSet().toList()..sort();

    buf.writeln('<div class="filters">');
    // Scenario filter
    buf.writeln('<label>Scenario <select id="filter-scenario" onchange="filterCards()">');
    buf.writeln('<option value="all">All</option>');
    for (final s in scenarios) {
      buf.writeln('<option value="${_esc(s)}">${_esc(s)}</option>');
    }
    buf.writeln('</select></label>');
    // Theme filter
    buf.writeln('<label>Theme <select id="filter-theme" onchange="filterCards()">');
    buf.writeln('<option value="all">All</option>');
    for (final t in themes) {
      buf.writeln('<option value="${_esc(t)}">${_esc(t)}</option>');
    }
    buf.writeln('</select></label>');
    // Status filter
    buf.writeln('<label>Status <select id="filter-status" onchange="filterCards()">');
    buf.writeln('<option value="all">All</option>');
    for (final s in statuses) {
      buf.writeln('<option value="${_esc(s)}">${_esc(s)}</option>');
    }
    buf.writeln('</select></label>');
    buf.writeln('</div>');
  }

  static void _writeScenarios(StringBuffer buf, MatrixResult result) {
    final grouped = <String, List<MatrixCombinationResult>>{};
    for (final r in result.results) {
      (grouped[r.combination.scenario.name] ??= []).add(r);
    }

    for (final entry in grouped.entries) {
      final scenarioName = entry.key;
      final results = entry.value;
      final passCount = results.where((r) => r.status == MatrixResultStatus.passed).length;
      final failCount = results.where((r) => r.status == MatrixResultStatus.failed).length;

      buf.writeln('<details open class="scenario-section" data-scenario="${_esc(scenarioName)}">');
      buf.writeln('<summary>');
      buf.writeln('<span class="scenario-name">${_esc(scenarioName)}</span>');
      buf.writeln('<span class="scenario-count">${results.length} tests');
      if (failCount > 0) {
        buf.writeln(' &middot; <span class="text-fail">$failCount failed</span>');
      }
      if (passCount == results.length) {
        buf.writeln(' &middot; <span class="text-pass">all passed</span>');
      }
      buf.writeln('</span>');
      buf.writeln('</summary>');
      buf.writeln('<div class="grid">');

      for (final r in results) {
        _writeCard(buf, r);
      }

      buf.writeln('</div>');
      buf.writeln('</details>');
    }
  }

  static void _writeCard(StringBuffer buf, MatrixCombinationResult r) {
    final c = r.combination;
    final dir = c.direction == TextDirection.ltr ? 'ltr' : 'rtl';
    final locale = c.locale.toLanguageTag();
    final scale = c.textScale % 1 == 0 ? '${c.textScale.toInt()}x' : '${c.textScale}x';
    final imgSrc = r.goldenPath.replaceFirst('goldens/', '');
    final statusClass = switch (r.status) {
      MatrixResultStatus.passed => 'badge-passed',
      MatrixResultStatus.failed => 'badge-failed',
      MatrixResultStatus.skipped => 'badge-skipped',
    };

    buf.writeln(
      '<div class="card" data-scenario="${_esc(c.scenario.name)}" '
      'data-theme="${_esc(c.theme.name)}" data-status="${r.status.name}">',
    );
    buf.writeln('<a href="${_esc(imgSrc)}" target="_blank">');
    buf.writeln(
      '<img src="${_esc(imgSrc)}" loading="lazy" '
      'alt="${_esc(c.scenario.name)}" '
      'onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\'">',
    );
    buf.writeln('<div class="img-placeholder" style="display:none">No image</div>');
    buf.writeln('</a>');
    buf.writeln('<div class="card-meta">');
    buf.writeln('<span class="$statusClass">${r.status.name}</span>');
    buf.writeln('<span class="tag">${_esc(c.theme.name)}</span>');
    buf.writeln('<span class="tag">${_esc(locale)}</span>');
    buf.writeln('<span class="tag">$dir</span>');
    buf.writeln('<span class="tag">$scale</span>');
    buf.writeln('<span class="tag">${_esc(c.device.name)}</span>');
    buf.writeln('</div>');
    if (r.errorMessage != null) {
      buf.writeln('<div class="error">${_esc(r.errorMessage!)}</div>');
    }
    if (r.warnings.isNotEmpty) {
      buf.writeln('<div class="warning">${r.warnings.map((w) => _esc(w)).join('<br>')}</div>');
    }
    if (r.status == MatrixResultStatus.failed) {
      _writeDiffThumbs(buf, r.goldenPath);
    }
    buf.writeln('</div>');
  }

  /// Renders a 4-tile grid pointing at Flutter's auto-generated
  /// `failures/<base>_{masterImage,testImage,isolatedDiff,maskedDiff}.png`.
  ///
  /// `LocalFileComparator.generateFailureOutput()` writes these files to a
  /// **single `failures/` directory at the comparator's basedir level**
  /// (i.e. one level up from `goldens/`), NOT inside the per-scenario
  /// subdirectory. Their filename is `<golden-basename>_<diffKey>.png`,
  /// without any test/scenario prefix. Since the HTML report lives inside
  /// `goldens/`, the relative reference is `../failures/<base>_<suffix>.png`.
  ///
  /// Tiles `onerror`-hide themselves when the file doesn't exist (some
  /// failure modes — timeouts, pre-compare exceptions — never create
  /// `failures/`). Multiple matrixGolden calls with overlapping
  /// `<theme>_<locale>_<dir>_<scale>_<device>` basenames will collide in
  /// `failures/` (Flutter limitation, not ours): the last failing combo
  /// wins. Acceptable trade-off for click-through diff thumbnails.
  static void _writeDiffThumbs(StringBuffer buf, String goldenPath) {
    final imgRelative = goldenPath.replaceFirst('goldens/', '');
    final lastSlash = imgRelative.lastIndexOf('/');
    if (lastSlash < 0) return;
    final base = imgRelative.substring(lastSlash + 1).replaceFirst(RegExp(r'\.png$'), '');
    final tiles = <({String label, String suffix})>[
      (label: 'expected', suffix: '_masterImage'),
      (label: 'actual', suffix: '_testImage'),
      (label: 'diff', suffix: '_isolatedDiff'),
      (label: 'masked', suffix: '_maskedDiff'),
    ];
    buf.writeln('<div class="diff-thumbs">');
    for (final t in tiles) {
      final src = '../failures/$base${t.suffix}.png';
      buf.writeln('<figure class="diff-tile">');
      buf.writeln('<a href="${_esc(src)}" target="_blank">');
      buf.writeln(
        '<img src="${_esc(src)}" loading="lazy" alt="${t.label}" '
        'onerror="this.closest(\'figure\').style.display=\'none\'">',
      );
      buf.writeln('</a>');
      buf.writeln('<figcaption>${t.label}</figcaption>');
      buf.writeln('</figure>');
    }
    buf.writeln('</div>');
  }

  static void _writeScript(StringBuffer buf) {
    buf.writeln('<script>');
    buf.writeln('''
function filterCards() {
  var scenario = document.getElementById('filter-scenario').value;
  var status = document.getElementById('filter-status').value;
  var theme = document.getElementById('filter-theme').value;
  var sections = document.querySelectorAll('.scenario-section');
  for (var i = 0; i < sections.length; i++) {
    var section = sections[i];
    var cards = section.querySelectorAll('.card');
    var visibleCount = 0;
    for (var j = 0; j < cards.length; j++) {
      var card = cards[j];
      var show = (scenario === 'all' || card.dataset.scenario === scenario) &&
                 (status === 'all' || card.dataset.status === status) &&
                 (theme === 'all' || card.dataset.theme === theme);
      card.style.display = show ? '' : 'none';
      if (show) visibleCount++;
    }
    section.style.display = (scenario === 'all' || section.dataset.scenario === scenario) && visibleCount > 0 ? '' : 'none';
  }
}
''');
    buf.writeln('</script>');
  }

  static String _esc(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static const _css = '''
:root {
  --bg: #f8f9fa;
  --text: #1a1a2e;
  --card-bg: #ffffff;
  --border: #e0e0e0;
  --meta: #6c757d;
  --badge-pass: #d4edda;
  --badge-pass-text: #155724;
  --badge-fail: #f8d7da;
  --badge-fail-text: #721c24;
  --badge-skip: #e2e3e5;
  --badge-skip-text: #383d41;
  --tag-bg: #e9ecef;
  --tag-text: #495057;
  --accent: #6c5ce7;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1a1a2e;
    --text: #e0e0e0;
    --card-bg: #16213e;
    --border: #2a2a4a;
    --meta: #8a8a9a;
    --badge-pass: #1b4332;
    --badge-pass-text: #95d5b2;
    --badge-fail: #5c1a1a;
    --badge-fail-text: #f4a0a0;
    --badge-skip: #2a2a3a;
    --badge-skip-text: #a0a0b0;
    --tag-bg: #2a2a4a;
    --tag-text: #b0b0c0;
    --accent: #a29bfe;
  }
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: var(--bg); color: var(--text); padding: 24px; max-width: 1400px; margin: 0 auto; }
header { margin-bottom: 24px; }
h1 { font-size: 1.8rem; margin-bottom: 4px; }
.meta { color: var(--meta); font-size: 0.9rem; margin-bottom: 16px; }
.summary { display: flex; gap: 12px; flex-wrap: wrap; }
.stat { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 12px 20px; text-align: center; min-width: 80px; }
.stat-value { display: block; font-size: 1.5rem; font-weight: 700; }
.stat-label { font-size: 0.8rem; color: var(--meta); }
.stat-passed { border-color: var(--badge-pass-text); }
.stat-passed .stat-value { color: var(--badge-pass-text); }
.stat-failed { border-color: var(--badge-fail-text); }
.stat-failed .stat-value { color: var(--badge-fail-text); }
.stat-skipped .stat-value { color: var(--badge-skip-text); }
.filters { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 24px; align-items: center; }
.filters label { font-size: 0.85rem; color: var(--meta); }
.filters select { margin-left: 4px; padding: 4px 8px; border-radius: 6px; border: 1px solid var(--border); background: var(--card-bg); color: var(--text); font-size: 0.85rem; }
.scenario-section { margin-bottom: 16px; }
summary { cursor: pointer; font-size: 1.1rem; font-weight: 600; padding: 8px 0; user-select: none; }
.scenario-name { color: var(--accent); }
.scenario-count { font-size: 0.85rem; font-weight: 400; color: var(--meta); margin-left: 8px; }
.text-pass { color: var(--badge-pass-text); }
.text-fail { color: var(--badge-fail-text); }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 12px; padding: 8px 0; }
.card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; transition: box-shadow 0.15s; }
.card:hover { box-shadow: 0 2px 12px rgba(0,0,0,0.1); }
.card a { display: block; }
.card img { width: 100%; height: auto; display: block; border-bottom: 1px solid var(--border); }
.img-placeholder { width: 100%; height: 120px; display: flex; align-items: center; justify-content: center; color: var(--meta); font-size: 0.85rem; background: var(--tag-bg); border-bottom: 1px solid var(--border); }
.card-meta { padding: 8px; display: flex; flex-wrap: wrap; gap: 4px; align-items: center; }
.badge-passed, .badge-failed, .badge-skipped { font-size: 0.7rem; font-weight: 600; padding: 2px 8px; border-radius: 10px; text-transform: uppercase; }
.badge-passed { background: var(--badge-pass); color: var(--badge-pass-text); }
.badge-failed { background: var(--badge-fail); color: var(--badge-fail-text); }
.badge-skipped { background: var(--badge-skip); color: var(--badge-skip-text); }
.tag { font-size: 0.7rem; padding: 2px 6px; border-radius: 4px; background: var(--tag-bg); color: var(--tag-text); }
.error { padding: 8px; font-size: 0.75rem; color: var(--badge-fail-text); background: var(--badge-fail); border-top: 1px solid var(--border); word-break: break-all; max-height: 60px; overflow: auto; }
.stat-warning { border-color: #e0a800; }
.stale-section { background: #fff8e1; border: 1px solid #e0a800; border-radius: 4px; padding: 0.75rem 1rem; margin: 0 0 1rem; }
.stale-section summary { font-weight: 600; cursor: pointer; color: #b45309; }
.stale-list { margin: 0.5rem 0 0; padding-left: 1.25rem; }
.stale-list li { margin: 0.15rem 0; }
.stale-list code { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 0.85rem; background: rgba(0, 0, 0, 0.05); padding: 0.05rem 0.3rem; border-radius: 3px; }
@media (prefers-color-scheme: dark) {
  .stale-section { background: rgba(224, 168, 0, 0.1); }
  .stale-list code { background: rgba(255, 255, 255, 0.1); }
}
.stat-warning .stat-value { color: #e0a800; }
.warning { padding: 8px; font-size: 0.75rem; color: #856404; background: #fff3cd; border-top: 1px solid var(--border); word-break: break-all; max-height: 60px; overflow: auto; }
.diff-thumbs { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.4rem; padding: 8px; border-top: 1px solid var(--border); background: rgba(0, 0, 0, 0.02); }
.diff-tile { margin: 0; text-align: center; }
.diff-tile img { width: 100%; height: auto; display: block; border: 1px solid var(--border); border-radius: 3px; background: #fff; }
.diff-tile figcaption { font-size: 0.65rem; color: var(--meta); margin-top: 0.2rem; text-transform: uppercase; letter-spacing: 0.05em; }
@media (prefers-color-scheme: dark) {
  .diff-thumbs { background: rgba(255, 255, 255, 0.03); }
  .diff-tile img { background: #1a1a1a; }
}
''';
}
