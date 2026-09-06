import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

// Helper for WCAG 2.1 relative luminance
double computeWCAGLuminance(Color color) {
  double channel(int value) {
    final v = value / 255.0;
    return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  }
  final argb = color.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return 0.2126 * channel(r) +
         0.7152 * channel(g) +
         0.0722 * channel(b);
}

double computeContrastRatio(Color c1, Color c2) {
  final l1 = computeWCAGLuminance(c1);
  final l2 = computeWCAGLuminance(c2);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

// Baseline contrast formula based on ThemeData brightness estimation
Color proposedComputeOnPrimary(Color primaryAccent) {
  final brightness = ThemeData.estimateBrightnessForColor(primaryAccent);
  return brightness == Brightness.light
      ? const Color(0xFF0B0F14) // Deep obsidian dark ink
      : Colors.white;            // Pure white
}

// Production contrast formula using relative luminance threshold (0.1833)
Color remediatedComputeOnPrimary(Color primaryAccent) {
  final lum = primaryAccent.computeLuminance();
  return lum > 0.1833 ? const Color(0xFF0B0F14) : Colors.white;
}

void main() {
  group('1. Contrast Calculations & ThemeData.estimateBrightnessForColor Mathematical Stress Test', () {
    final themeAccents = <String, Color>{
      'Obsidian': const Color(0xFF3FB950),
      'Catppuccin Mocha': const Color(0xFFA6E3A1),
      'Dracula': const Color(0xFF50FA7B),
      'Nord': const Color(0xFFA3BE8C),
      'Tokyo Night': const Color(0xFF9ECE6A),
      'Solarized Dark': const Color(0xFF859900),
    };

    test('Audit ThemeData.estimateBrightnessForColor behavior across all 6 presets', () {
      for (final entry in themeAccents.entries) {
        final name = entry.key;
        final color = entry.value;
        final brightness = ThemeData.estimateBrightnessForColor(color);
        final onPrimary = proposedComputeOnPrimary(color);
        final contrast = computeContrastRatio(onPrimary, color);
        final darkContrast = computeContrastRatio(const Color(0xFF0B0F14), color);
        final whiteContrast = computeContrastRatio(Colors.white, color);
        final relLum = color.computeLuminance();

        // Print empirical table for analysis
        // ignore: avoid_print
        print('Theme: $name | Accent: #${color.toARGB32().toRadixString(16).toUpperCase()} '
              '| Lum: ${relLum.toStringAsFixed(4)} '
              '| Brightness: $brightness '
              '| Selected onPrimary: ${onPrimary == Colors.white ? "WHITE" : "DARK"} '
              '| Actual Contrast: ${contrast.toStringAsFixed(2)}:1 '
              '| (Dark: ${darkContrast.toStringAsFixed(2)}:1, White: ${whiteContrast.toStringAsFixed(2)}:1)');

        if (name == 'Solarized Dark') {
          // Solarized Dark check: Does ThemeData.estimateBrightnessForColor return light or dark?
          // Proposal claim at line 830:
          // "Solarized Dark | #859900 | White: 3.20:1 | Dark: 6.55:1 | PASS (AA)"
          // But if estimateBrightnessForColor returns dark, it selects WHITE, yielding 3.20:1 (FAIL)!
          // ignore: avoid_print
          print('>>> SOLARIZED DARK EMPIRICAL VERIFICATION:');
          // ignore: avoid_print
          print('    ThemeData.estimateBrightnessForColor(#859900) = $brightness');
          // ignore: avoid_print
          print('    Selected foreground = $onPrimary');
          // ignore: avoid_print
          print('    Resulting contrast = ${contrast.toStringAsFixed(2)}:1');
          // ignore: avoid_print
          print('    WCAG AA requires >= 4.5:1. Did it pass? ${contrast >= 4.5}');
        }
      }
    });

    test('Mathematical flaw verification: ThemeData.estimateBrightnessForColor threshold vs WCAG AA', () {
      // In Flutter, estimateBrightnessForColor uses threshold: (lum + 0.05)^2 > 0.15
      // which means lum > sqrt(0.15) - 0.05 = ~0.3373.
      // But WCAG AA requires contrast >= 4.5:1.
      // White fails WCAG AA whenever (1.0 + 0.05) / (lum + 0.05) < 4.5 => lum > 0.1833!
      // Therefore, any color with luminance between 0.1833 and 0.3373 will be classified
      // as "dark" by Flutter, picking white text, which FAILS WCAG AA!
      const testColor = Color(0xFF859900); // Solarized Dark olive green
      final lum = testColor.computeLuminance();
      expect(lum > 0.1833, isTrue, reason: 'Luminance exceeds white WCAG AA threshold');
      expect((lum + 0.05) * (lum + 0.05) > 0.15, isFalse, reason: 'Flutter formula treats it as DARK');
      expect(ThemeData.estimateBrightnessForColor(testColor), equals(Brightness.dark));
      expect(proposedComputeOnPrimary(testColor), equals(Colors.white));
      expect(computeContrastRatio(Colors.white, testColor) < 4.5, isTrue,
          reason: 'Empirically FAILS WCAG AA (3.20:1 < 4.5:1)');
    });

    test('Remediation verification: computeOnPrimary threshold passes WCAG AA across ALL 6 presets', () {
      for (final entry in themeAccents.entries) {
        final name = entry.key;
        final color = entry.value;
        final onPrimary = remediatedComputeOnPrimary(color);
        final contrast = computeContrastRatio(onPrimary, color);

        expect(contrast >= 4.5, isTrue,
            reason: '$name ($color) with onPrimary $onPrimary must achieve WCAG AA (>= 4.5:1), got ${contrast.toStringAsFixed(2)}:1');

        if (name == 'Solarized Dark') {
          expect(onPrimary, equals(const Color(0xFF0B0F14)),
              reason: 'Solarized Dark correctly selects dark text (#0B0F14)');
          expect(contrast.toStringAsFixed(2), equals('6.00'),
              reason: 'Solarized Dark yields ~6.00:1 contrast (PASS AA)');
        }
      }
    });
  });

  group('2. Viewport Constraints (320px) & RenderFlex Stress Tests', () {
    testWidgets('Stress test ContextualSelectionBar on 320px screen at 1.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 52.0,
                decoration: const BoxDecoration(
                  color: Color(0xFF161B22),
                  border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.0)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3FB950),
                          foregroundColor: const Color(0xFF0B0F14),
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
                      child: const Text('Word'),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Clear Selection',
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // ignore: avoid_print
      print('ContextualSelectionBar 320px (1.0x scale) error count: ${errors.length}');
      for (final e in errors) {
        // ignore: avoid_print
        print('  Error: ${e.exceptionAsString()}');
      }
    });

    testWidgets('Stress test ContextualSelectionBar on 320px screen at 1.5x and 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final scale in [1.5, 2.0]) {
        final errors = <FlutterErrorDetails>[];
        FlutterError.onError = (details) => errors.add(details);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 52.0, // Fixed 52dp height per line 596
                    decoration: const BoxDecoration(
                      color: Color(0xFF161B22),
                      border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.0)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3FB950),
                              foregroundColor: const Color(0xFF0B0F14),
                              minimumSize: const Size(0, 44),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
                          child: const Text('Word'),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Clear Selection',
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

        await tester.pump();
        // ignore: avoid_print
        print('ContextualSelectionBar 320px (${scale}x scale) error count: ${errors.length}');
        for (final e in errors) {
          // ignore: avoid_print
          print('  Error at ${scale}x: ${e.exceptionAsString()}');
        }
      }
    });

    testWidgets('Remediation verification: Responsive ContextualSelectionBar on 320px screen has ZERO errors at 1.5x and 2.0x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final scale in [1.0, 1.5, 2.0]) {
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);

        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Builder(
                    builder: (context) {
                      final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                      final dynamicHeight = 52.0 * textScale.clamp(1.0, 1.35);
                      final copyLabel = textScale > 1.2 ? 'Copy' : 'Copy Selection';

                      return Container(
                        height: dynamicHeight,
                        decoration: const BoxDecoration(
                          color: Color(0xFF161B22),
                          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1.0)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3FB950),
                                  foregroundColor: const Color(0xFF0B0F14),
                                  minimumSize: const Size(0, 44),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: Text(
                                  copyLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
                                child: const Text('Word'),
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                icon: const Icon(Icons.close_rounded, size: 20),
                                tooltip: 'Clear Selection',
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              // Pinned emergency keys
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(minimumSize: const Size(44, 44)),
                                child: const Text('Esc'),
                                onPressed: () {},
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(minimumSize: const Size(44, 44)),
                                child: const Text('^C'),
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          expect(errors, isEmpty,
              reason: 'Remediated ContextualSelectionBar with horizontal scroll, responsive label, and flexible text must have ZERO errors at ${scale}x scale');
        } finally {
          FlutterError.onError = originalOnError;
        }
      }
    });

    testWidgets('Stress test ServerFormHostPortRow on 320px screen at 1.0x and 1.5x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final scale in [1.0, 1.5, 2.0]) {
        final errors = <FlutterErrorDetails>[];
        FlutterError.onError = (details) => errors.add(details);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '192.168.1.100',
                          decoration: const InputDecoration(
                            labelText: 'Host / IP Address',
                            hintText: 'e.g. 192.168.1.10',
                            prefixIcon: Icon(Icons.dns_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      SizedBox(
                        width: 96.0,
                        child: TextFormField(
                          initialValue: '65535',
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '22',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

        await tester.pumpAndSettle();
        // ignore: avoid_print
        print('ServerFormHostPortRow 320px (${scale}x scale) errors: ${errors.length}');
        for (final e in errors) {
          // ignore: avoid_print
          print('  Error: ${e.exceptionAsString()}');
        }
      }
    });

    testWidgets('Stress test ServerCard Tier 2 Wrap with long telemetry and badges on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final scale in [1.0, 1.5, 2.0]) {
        final errors = <FlutterErrorDetails>[];
        FlutterError.onError = (details) => errors.add(details);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(
                body: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 40, height: 40, color: Colors.blue),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'production-database-replica-01',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'ubuntu@192.168.1.100:2222',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48, height: 48),
                          ],
                        ),
                        const Divider(height: 1),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: const Text('Key', style: TextStyle(fontSize: 10)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: const Text('tmux', style: TextStyle(fontSize: 10)),
                            ),
                            const Text(
                              'CPU 98.5% · RAM 15.8GB · Disk 89%',
                              style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

        await tester.pumpAndSettle();
        // ignore: avoid_print
        print('ServerCard 320px (${scale}x scale) errors: ${errors.length}');
        for (final e in errors) {
          // ignore: avoid_print
          print('  Error: ${e.exceptionAsString()}');
        }
      }
    });
  });

  group('3. Dynamic TextScaler Clamping Logic Stress Test', () {
    test('Verify behavior of (baseHeight * textScale).clamp(minHeight, maxHeight)', () {
      const baseHeight = 52.0;
      const minHeight = 44.0;
      const maxHeight = 72.0; // clamp(1.0, ~1.4)

      for (final scale in [1.0, 1.2, 1.5, 1.8, 2.0]) {
        final dynamicHeight = (baseHeight * scale).clamp(minHeight, maxHeight);
        // ignore: avoid_print
        print('Scale: ${scale}x -> dynamicHeight: $dynamicHeight (unclamped: ${baseHeight * scale})');
      }
    });

    testWidgets('Stress test container height clamping when child text scales unconstrained to 2.0x', (tester) async {
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  const baseHeight = 52.0;
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  // Proposal formula: (baseHeight * textScale).clamp(minHeight, maxHeight)
                  // where clamp is 1.0 to 1.4:
                  final clampedHeight = (baseHeight * textScale).clamp(44.0, baseHeight * 1.4);

                  return SizedBox(
                    height: clampedHeight,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Line 1 of Key Description', style: TextStyle(fontSize: 14)),
                        Text('Line 2 of Key Description', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // ignore: avoid_print
      print('Clamped container with 2.0x textScaler error count: ${errors.length}');
      for (final e in errors) {
        // ignore: avoid_print
        print('  Error: ${e.exceptionAsString()}');
      }
    });

    testWidgets('Remediation verification: Subtree textScaler clamping produces ZERO RenderFlex overflow at 2.0x text scale', (tester) async {
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Remediated: Subtree textScaler clamping instead of rigid container height clamping
                  final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Line 1 of Key Description', style: TextStyle(fontSize: 14)),
                          Text('Line 2 of Key Description', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(errors, isEmpty,
          reason: 'Subtree textScaler clamping must produce ZERO RenderFlex overflow at 2.0x scale');
    });
  });

  group('4. Touch Ergonomics & In-Place Morphing Stress Tests', () {
    testWidgets('Verify key lockout when selection is active in accessory bar', (tester) async {
      bool hasSelection = false;
      bool escTapped = false;

      Widget buildBar(StateSetter setState) {
        return SizedBox(
          height: 52,
          child: hasSelection
              ? Row(
                  children: [
                    ElevatedButton(
                      child: const Text('Copy'),
                      onPressed: () {},
                    ),
                    ElevatedButton(
                      child: const Text('Word'),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => hasSelection = false),
                    ),
                  ],
                )
              : Row(
                  children: [
                    ElevatedButton(
                      child: const Text('Esc'),
                      onPressed: () => escTapped = true,
                    ),
                    ElevatedButton(
                      child: const Text('Ctrl'),
                      onPressed: () {},
                    ),
                  ],
                ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    const Expanded(child: Text('Terminal Buffer')),
                    buildBar(setState),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Normal state: Esc is available
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      await tester.tap(find.text('Esc'));
      expect(escTapped, isTrue);

      // Text is selected -> bar morphs into Selection Bar
      final dynamic state = tester.state(find.byType(StatefulBuilder));
      state.setState(() => hasSelection = true);
      await tester.pump();

      // In selection state: Esc is completely REMOVED from the tree!
      expect(find.text('Esc'), findsNothing);
      expect(find.text('Copy'), findsOneWidget);
      // User cannot send Esc, Ctrl, Tab, or arrow keys while text is selected
      // ignore: avoid_print
      print('Ergonomic finding: Active text selection completely hides all terminal accessory keys (Esc, Ctrl, Tab, arrows)');
    });

    testWidgets('Occlusion stress test: Bottom-line teardrop handle vs accessory bar', (tester) async {
      // Simulating terminal view with selection on the very last visible line
      // Terminal canvas height: 300dp, cellHeight: 20dp. Row 14 is at y = 280..300.
      // A 22dp downward stem puts the handle knob at y = 300 + 22 = 322dp!
      // But the bottom accessory bar starts at y = 300dp!
      // If the handle is inside TerminalView (clipped), it is invisible/truncated.
      // If unclipped, it overlays the accessory bar, intercepting touch events for the bar!
      bool accessoryButtonTapped = false;
      bool handleTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Terminal canvas area
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 300,
                  child: Container(
                    color: Colors.black,
                    child: const Text('Terminal Row 14: bottom text'),
                  ),
                ),
                // Bottom accessory bar
                Positioned(
                  top: 300,
                  left: 0,
                  right: 0,
                  height: 52,
                  child: Container(
                    color: Colors.grey[900],
                    child: ElevatedButton(
                      key: const ValueKey('copy_btn'),
                      onPressed: () => accessoryButtonTapped = true,
                      child: const Text('Copy Selection'),
                    ),
                  ),
                ),
                // Selection handle extending 22dp downward from terminal bottom line (y = 295)
                Positioned(
                  top: 295,
                  left: 50,
                  width: 44,
                  height: 44, // 22dp stem + 22dp touch target
                  child: GestureDetector(
                    key: const ValueKey('handle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => handleTapped = true,
                    child: Container(
                      color: Colors.blue.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Tap in the overlap zone (y = 310, x = 60)
      await tester.tapAt(const Offset(60, 310));
      await tester.pump();

      // ignore: avoid_print
      print('Overlap test: handleTapped=$handleTapped, accessoryButtonTapped=$accessoryButtonTapped');
      expect(handleTapped, isTrue, reason: 'Handle intercepts tap intended for accessory bar');
      expect(accessoryButtonTapped, isFalse, reason: 'Accessory bar button tap was swallowed by overlapping handle');
    });

    testWidgets('Remediation verification: Pinned emergency keys Esc and ^C remain accessible during active selection', (tester) async {
      bool hasSelection = false;
      bool escTapped = false;
      bool sigintTapped = false;

      Widget buildBar(StateSetter setState) {
        return SizedBox(
          height: 52,
          child: hasSelection
              ? Row(
                  children: [
                    ElevatedButton(
                      child: const Text('Copy'),
                      onPressed: () {},
                    ),
                    ElevatedButton(
                      child: const Text('Word'),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => hasSelection = false),
                    ),
                    const Spacer(),
                    // Remediated: Pinned emergency keys on far right prevent CLI lockout
                    ElevatedButton(
                      child: const Text('Esc'),
                      onPressed: () => escTapped = true,
                    ),
                    ElevatedButton(
                      child: const Text('^C'),
                      onPressed: () => sigintTapped = true,
                    ),
                  ],
                )
              : Row(
                  children: [
                    ElevatedButton(
                      child: const Text('Esc'),
                      onPressed: () => escTapped = true,
                    ),
                    ElevatedButton(
                      child: const Text('Ctrl'),
                      onPressed: () {},
                    ),
                  ],
                ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    const Expanded(child: Text('Terminal Buffer')),
                    buildBar(setState),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Normal state: Esc is available
      expect(find.text('Esc'), findsOneWidget);
      await tester.tap(find.text('Esc'));
      expect(escTapped, isTrue);

      // Text is selected -> bar morphs into Selection Bar
      final dynamic state = tester.state(find.byType(StatefulBuilder));
      state.setState(() => hasSelection = true);
      await tester.pump();

      // Remediated: In selection state, Esc AND ^C are STILL available!
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('^C'), findsOneWidget);
      escTapped = false;
      await tester.tap(find.text('Esc'));
      expect(escTapped, isTrue);
      await tester.tap(find.text('^C'));
      expect(sigintTapped, isTrue);
    });

    testWidgets('Remediation verification: Bottom-line teardrop handle stem inverts upward, avoiding accessory bar collision', (tester) async {
      bool accessoryButtonTapped = false;
      bool handleTapped = false;

      // Selection row at y = 295 (within 32dp of bottom canvas height 300)
      const canvasHeight = 300.0;
      const selectionY = 295.0;
      const isNearBottom = (canvasHeight - selectionY) < 32.0; // true!
      // Inverted upward stem offset: -22dp
      const stemOffset = isNearBottom ? -22.0 : 22.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: canvasHeight,
                  child: Container(
                    color: Colors.black,
                    child: const Text('Terminal Row 14: bottom text'),
                  ),
                ),
                Positioned(
                  top: canvasHeight,
                  left: 0,
                  right: 0,
                  height: 52,
                  child: Container(
                    color: Colors.grey[900],
                    child: ElevatedButton(
                      key: const ValueKey('copy_btn'),
                      onPressed: () => accessoryButtonTapped = true,
                      child: const Text('Copy Selection'),
                    ),
                  ),
                ),
                // Remediated: Stem inverts upward to y = 295 - 22 = 273 (touch target at 251..295)
                Positioned(
                  top: selectionY + stemOffset - 22.0,
                  left: 50,
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    key: const ValueKey('handle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => handleTapped = true,
                    child: Container(
                      color: Colors.blue.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Tap in accessory bar button zone (y = 310, x = 60)
      await tester.tapAt(const Offset(60, 310));
      await tester.pump();

      expect(handleTapped, isFalse, reason: 'Inverted handle does not collide with accessory bar');
      expect(accessoryButtonTapped, isTrue, reason: 'Accessory bar button receives tap cleanly');
    });
  });

  group('5. State Management & Terminal Resilience Stress Tests', () {
    testWidgets('600ms hold-to-disconnect race conditions and timing', (tester) async {
      bool disconnected = false;
      Timer? holdTimer;

      Widget buildHoldButton() {
        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTapDown: (_) {
                holdTimer = Timer(const Duration(milliseconds: 600), () {
                  disconnected = true;
                });
              },
              onTapUp: (_) {
                holdTimer?.cancel();
              },
              onTapCancel: () {
                holdTimer?.cancel();
              },
              child: Container(
                width: 48,
                height: 48,
                color: Colors.red,
                child: const Icon(Icons.power_settings_new),
              ),
            );
          },
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: buildHoldButton()),
          ),
        ),
      );

      // Scenario A: User releases at 300ms (should NOT disconnect)
      final center = tester.getCenter(find.byType(GestureDetector));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(disconnected, isFalse, reason: 'Released at 300ms should cancel disconnect');

      // Scenario B: User holds for full 600ms (SHOULD disconnect)
      final gesture2 = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 650));
      expect(disconnected, isTrue, reason: 'Holding >=600ms triggers disconnect');
      await gesture2.up();
      await tester.pump();

      // Scenario C: Rapid tap (touch and immediately release)
      disconnected = false;
      await tester.tap(find.byType(GestureDetector));
      await tester.pump(const Duration(milliseconds: 700));
      expect(disconnected, isFalse, reason: 'Normal tap should not trigger disconnect');
    });

    testWidgets('Reconnect banner layout: Column vs Stack impact on TerminalView resize / SIGWINCH', (tester) async {
      final terminal = Terminal(maxLines: 1000);
      int resizeCount = 0;
      terminal.addListener(() {});
      terminal.onResize = (w, h, pw, ph) {
        resizeCount++;
      };

      bool showBanner = false;

      // Layout 1: Column layout (Banner inserted above terminal)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Container(height: 56, color: Colors.blue), // AppBar
                    if (showBanner)
                      Container(height: 48, color: Colors.amber), // Reconnect Banner
                    Expanded(
                      child: TerminalView(terminal),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialResizes = resizeCount;
      // ignore: avoid_print
      print('Column Layout initial terminal resizes: $initialResizes');

      // Now connection drops and banner is shown:
      final dynamic state = tester.state(find.byType(StatefulBuilder));
      state.setState(() => showBanner = true);
      await tester.pumpAndSettle();

      final afterBannerResizes = resizeCount;
      // ignore: avoid_print
      print('Column Layout resizes after showing banner: $afterBannerResizes (delta: ${afterBannerResizes - initialResizes})');
      expect(afterBannerResizes > initialResizes, isTrue,
          reason: 'Inserting banner in a Column forces TerminalView to change height, triggering terminal.resize and SIGWINCH!');

      // Layout 2: Floating Stack layout (Banner overlaid on terminal)
      int stackResizeCount = 0;
      final terminalStack = Terminal(maxLines: 1000);
      terminalStack.onResize = (w, h, pw, ph) {
        stackResizeCount++;
      };
      bool showStackBanner = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Container(height: 56, color: Colors.blue), // AppBar
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: TerminalView(terminalStack),
                          ),
                          if (showStackBanner)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 48,
                              child: Container(color: Colors.amber),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialStackResizes = stackResizeCount;

      final dynamic stackState = tester.state(find.byType(StatefulBuilder));
      stackState.setState(() => showStackBanner = true);
      await tester.pumpAndSettle();

      final afterStackBannerResizes = stackResizeCount;
      // ignore: avoid_print
      print('Stack Layout resizes after showing banner: $afterStackBannerResizes (delta: ${afterStackBannerResizes - initialStackResizes})');
      expect(afterStackBannerResizes == initialStackResizes, isTrue,
          reason: 'Floating banner in Stack preserves exact TerminalView dimensions with ZERO resize and ZERO SIGWINCH!');
    });
  });
}
