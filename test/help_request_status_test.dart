import 'package:flutter_test/flutter_test.dart';
import 'package:floodguard_ai/utils/help_request_status.dart';

void main() {
  test('legacy statuses display as Submitted', () {
    expect(HelpRequestStatus.normalize(null), HelpRequestStatus.submitted);
    expect(HelpRequestStatus.normalize('pending'), HelpRequestStatus.submitted);
    expect(
        HelpRequestStatus.normalize('verified'), HelpRequestStatus.submitted);
    expect(HelpRequestStatus.label('pending', isTaglish: false), 'Submitted');
  });

  test('citizen-facing labels are text, not color-only', () {
    expect(HelpRequestStatus.label('help_on_the_way', isTaglish: false),
        'Help is on the way');
    expect(HelpRequestStatus.label('resolved', isTaglish: false), 'Resolved');
    expect(HelpRequestStatus.label('rejected', isTaglish: false), 'Rejected');
  });
}
