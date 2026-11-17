import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/data/models/fault_category.dart';
import 'package:tyckops/data/models/ticket.dart';

void main() {
  group('Reporte de falla (RF-04)', () {
    test('las 4 categorías viajan con el código que espera el servidor', () {
      expect(
        FaultCategory.values.map((c) => c.apiValue),
        ['ELECTRICA', 'BANOS', 'AIRE_ACONDICIONADO', 'INMOBILIARIO'],
      );
    });

    test('la foto se reconoce por su firma, no por el nombre', () {
      final jpg = PickedPhoto(bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]), name: 'a.png');
      final png = PickedPhoto(bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]), name: 'b.jpg');
      final exe = PickedPhoto(bytes: Uint8List.fromList('MZ falso'.codeUnits), name: 'foto.jpg');
      expect(jpg.mimeType, 'image/jpeg');
      expect(png.mimeType, 'image/png');
      expect(exe.mimeType, isNull);
    });

    test('un ticket recién creado no tiene prioridad (por asignar)', () {
      final ticket = Ticket.fromJson({
        'id': '15',
        'code': 'REP-0015',
        'category': 'Eléctrica',
        'title': 'El enchufe echa chispas',
        'status': 'RECIBIDO',
        'priority': null,
        'location': 'Piso 2',
        'createdAt': '2026-11-16T13:30:00.000Z',
      });
      expect(ticket.priority, isNull);
      expect(ticket.isActive, isTrue);
    });
  });
}
