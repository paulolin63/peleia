import 'package:flutter_test/flutter_test.dart';
import 'package:peleia/core/services/device_security_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DeviceSecurityService.resetForTesting();
  });

  group('DeviceSecurityService - Prevenção de Fraude e Ancoragem de Dispositivo', () {
    test('1. Deve gerar um hash SHA-256 válido de 64 caracteres hexadecimais', () async {
      final fingerprint = await DeviceSecurityService.getDeviceFingerprint();

      expect(fingerprint, isNotEmpty);
      expect(fingerprint.length, equals(64));
      // Verifica se é um hex válido
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint), isTrue);
    });

    test('2. Deve manter o mesmo fingerprint em chamadas subsequentes (idempotência)', () async {
      final first = await DeviceSecurityService.getDeviceFingerprint();
      final second = await DeviceSecurityService.getDeviceFingerprint();

      expect(first, equals(second));
    });

    test('3. Deve persistir no SharedPreferences para resistir a oscilações de runtime', () async {
      final fingerprint = await DeviceSecurityService.getDeviceFingerprint();
      final prefs = await SharedPreferences.getInstance();

      final stored = prefs.getString('peleia_device_fingerprint_v1');
      expect(stored, equals(fingerprint));
    });
  });
}
