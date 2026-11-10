import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/features/auth/terms_content.dart';

void main() {
  test('los Términos tienen las 9 secciones, en orden y con contenido (RF-03)', () {
    expect(termsSections, hasLength(9));
    for (final (index, section) in termsSections.indexed) {
      expect(section.title, startsWith('${index + 1}. '));
      expect(section.blocks, isNotEmpty);
    }
  });
}
