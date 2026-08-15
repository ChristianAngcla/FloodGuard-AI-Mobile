import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('📱 PROFILE PHONE NUMBER VALIDATION & FORMATTING UNIT TESTS', () {
    final phoneRegex = RegExp(r'^09\d{9}$');

    test('1. Valid Philippine local numbers starting with 09 match ^09\\d{9}\$', () {
      expect(phoneRegex.hasMatch('09171234567'), isTrue);
      expect(phoneRegex.hasMatch('09991234567'), isTrue);
      expect(phoneRegex.hasMatch('09201234567'), isTrue);
      expect(phoneRegex.hasMatch('09561234567'), isTrue);
    });

    test('2. Invalid numbers (wrong prefix, wrong length, letters) fail ^09\\d{9}\$', () {
      expect(phoneRegex.hasMatch('9171234567'), isFalse); // 10 digits
      expect(phoneRegex.hasMatch('091712345678'), isFalse); // 12 digits
      expect(phoneRegex.hasMatch('08171234567'), isFalse); // Starts with 08
      expect(phoneRegex.hasMatch('0917ABC4567'), isFalse); // Contains letters
      expect(phoneRegex.hasMatch(''), isFalse); // Empty
      expect(phoneRegex.hasMatch('0917 123 4567'), isFalse); // Contains spaces
      expect(phoneRegex.hasMatch('+639171234567'), isFalse); // Needs normalization before local format
    });

    test('3. Normalization of E.164 (+63) and 63 prefixes to local 09 format', () {
      String normalizeToLocal(String raw) {
        String clean = raw.trim();
        if (clean.startsWith('+63')) {
          clean = '0${clean.substring(3)}';
        } else if (clean.startsWith('63') && clean.length == 12) {
          clean = '0${clean.substring(2)}';
        }
        return clean;
      }

      expect(normalizeToLocal('+639171234567'), equals('09171234567'));
      expect(normalizeToLocal('639171234567'), equals('09171234567'));
      expect(normalizeToLocal('09171234567'), equals('09171234567'));
      expect(phoneRegex.hasMatch(normalizeToLocal('+639171234567')), isTrue);
    });

    test('4. Normalization of local 09 format to E.164 (+63) for Firebase / API', () {
      String normalizeToE164(String local) {
        String clean = local.trim();
        if (clean.startsWith('0')) {
          clean = clean.substring(1);
        }
        return '+63$clean';
      }

      expect(normalizeToE164('09171234567'), equals('+639171234567'));
      expect(normalizeToE164('09991234567'), equals('+639991234567'));
    });

    testWidgets('5. Profile phone field enforces 11-digit maximum and digits-only formatters', (WidgetTester tester) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Required";
                  final clean = val.trim();
                  if (!RegExp(r'^09\d{9}$').hasMatch(clean)) {
                    return "Enter a valid 11-digit mobile number starting with 09.";
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      final inputFinder = find.byType(TextFormField);

      // Typing letters should be rejected by digitsOnly formatter
      await tester.enterText(inputFinder, '0917ABC4567');
      await tester.pump();
      expect(controller.text, equals('09174567')); // Only digits kept

      // Typing > 11 digits should be truncated at 11 by LengthLimitingTextInputFormatter
      await tester.enterText(inputFinder, '091712345678999');
      await tester.pump();
      expect(controller.text.length, equals(11));
      expect(controller.text, equals('09171234567'));

      // Validate valid number passes
      expect(formKey.currentState!.validate(), isTrue);

      // Validate 10-digit number fails
      await tester.enterText(inputFinder, '0917123456');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text("Enter a valid 11-digit mobile number starting with 09."), findsOneWidget);

      // Validate non-09 number fails (e.g. 08171234567)
      await tester.enterText(inputFinder, '08171234567');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text("Enter a valid 11-digit mobile number starting with 09."), findsOneWidget);
    });
  });
}
