import 'package:flutter_test/flutter_test.dart';
import 'package:tyckops/core/validators.dart';
import 'package:tyckops/data/models/ticket_status.dart';

void main() {
  group('Correo corporativo (RF-01)', () {
    test('acepta @gamaitaly.cl, sin importar mayúsculas ni espacios', () {
      expect(Validators.corporateEmail('camila@gamaitaly.cl'), isNull);
      expect(Validators.corporateEmail('  Camila.H@GAMAITALY.CL '), isNull);
    });

    test('rechaza otros dominios y textos vacíos', () {
      expect(Validators.corporateEmail('camila@gmail.com'), isNotNull);
      expect(Validators.corporateEmail('camila@gamaitaly.cl.falso.com'), isNotNull);
      expect(Validators.corporateEmail(''), isNotNull);
    });
  });

  group('Nueva contraseña opcional (RF-02)', () {
    test('vacía significa mantener la actual', () {
      expect(Validators.optionalNewPassword(''), isNull);
    });

    test('exige 8 caracteres con letras y números', () {
      expect(Validators.optionalNewPassword('abc12'), isNotNull);
      expect(Validators.optionalNewPassword('solamenteletras'), isNotNull);
      expect(Validators.optionalNewPassword('12345678'), isNotNull);
      expect(Validators.optionalNewPassword('gama2026'), isNull);
    });

    test('la confirmación debe coincidir', () {
      expect(Validators.confirmPassword('gama2026', 'gama2026'), isNull);
      expect(Validators.confirmPassword('gama2025', 'gama2026'), isNotNull);
    });
  });

  group('Estados del ticket', () {
    test('solo Recibido se puede cancelar (RF-09)', () {
      final cancelables = TicketStatus.values.where((s) => s.canBeCancelled);
      expect(cancelables, [TicketStatus.received]);
    });

    test('se lee el estado que manda la API', () {
      expect(TicketStatus.fromApi('en_revision'), TicketStatus.inReview);
      expect(() => TicketStatus.fromApi('INVENTADO'), throwsFormatException);
    });
  });
}
