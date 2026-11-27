import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  test('FilePicker API signature', () {
    expect(FilePicker.pickFiles, isNotNull);
  });
}
