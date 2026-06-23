import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/golden_matrix.dart';

void main() {
  group('MatrixScenario (default constructor)', () {
    test('stores name, builder, tags; payload is null', () {
      final s = MatrixScenario('default', builder: () => const SizedBox(), tags: ['smoke']);
      expect(s.name, 'default');
      expect(s.tags, ['smoke']);
      expect(s.payload, isNull);
      expect(s.builder(), isA<SizedBox>());
    });

    test('slug is the slugified name', () {
      expect(
        MatrixScenario('Loading State', builder: () => const SizedBox()).slug,
        'loading_state',
      );
    });

    test('equality and hashCode are name-based', () {
      final a = MatrixScenario('x', builder: () => const SizedBox());
      final b = MatrixScenario('x', builder: () => const Placeholder(), tags: ['t']);
      final c = MatrixScenario('y', builder: () => const SizedBox());
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('empty name throws in asserts', () {
      expect(
        () => MatrixScenario('', builder: () => const SizedBox()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('is const-constructible', () {
      const s = MatrixScenario('c', builder: _constBuilder);
      expect(s.name, 'c');
    });
  });

  group('MatrixScenario.typed', () {
    test('captures the typed payload and feeds it to the builder', () {
      final s = MatrixScenario.typed<String>(
        'loaded',
        payload: 'hello',
        builder: (p) => Text(p, textDirection: TextDirection.ltr),
      );
      expect(s.name, 'loaded');
      expect(s.payload, 'hello');
      // The typed builder is wrapped into the zero-arg builder, closing over
      // the payload — invoking it yields the widget built from that payload.
      expect((s.builder() as Text).data, 'hello');
    });

    test('works with a complex payload type and a reused builder', () {
      Widget build(_State s) => Text('${s.label}:${s.count}', textDirection: TextDirection.ltr);
      final scenarios = [
        MatrixScenario.typed<_State>('a', payload: const _State('a', 1), builder: build),
        MatrixScenario.typed<_State>('b', payload: const _State('b', 2), builder: build),
      ];
      expect((scenarios[0].builder() as Text).data, 'a:1');
      expect((scenarios[1].builder() as Text).data, 'b:2');
      expect(scenarios[0].payload, isA<_State>());
    });

    test('forwards tags and stays name-based for identity', () {
      final s =
          MatrixScenario.typed<int>('n', payload: 7, builder: (p) => const SizedBox(), tags: ['x']);
      expect(s.tags, ['x']);
      expect(s, equals(MatrixScenario('n', builder: () => const Placeholder())));
    });
  });
}

Widget _constBuilder() => const SizedBox();

class _State {
  const _State(this.label, this.count);
  final String label;
  final int count;
}
