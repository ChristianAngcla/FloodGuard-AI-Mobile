import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/services/notification_service.dart';

void main() {
  test('canonical barangay topics match server formatter examples', () {
    expect(NotificationService.topicForBarangay('Santo Niño'),
        'barangay_santo_nino');
    expect(NotificationService.topicForBarangay('Tañong'), 'barangay_tanong');
    expect(NotificationService.topicForBarangay('Jesus Dela Peña'),
        'barangay_jesus_dela_pena');
    expect(NotificationService.topicForBarangay('Concepcion Uno'),
        'barangay_concepcion_uno');
    expect(
        NotificationService.topicForBarangay('Malanday'), 'barangay_malanday');
    expect(NotificationService.topicForBarangay('Nangka'), 'barangay_nangka');
  });
}
