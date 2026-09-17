import 'dart:io';
import 'package:crypto/crypto.dart';

class VerifyFileChecksumUseCase {
  const VerifyFileChecksumUseCase();

  Future<bool> call(String filePath, String expectedSha256) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    final trimmedExpected = expectedSha256.trim().toLowerCase();
    if (trimmedExpected.isEmpty) {
      final length = await file.length();
      return length > 0;
    }

    try {
      final digest = await sha256.bind(file.openRead()).first;
      final computed = digest.toString().toLowerCase();
      return computed == trimmedExpected;
    } catch (_) {
      return false;
    }
  }
}
