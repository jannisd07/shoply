import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/supabase_service.dart';

void main() {
  test('the Apple nonce is 32 safe characters and its SHA-256 in hex', () {
    final nonce = SupabaseService.appleNonce(Random(7));

    expect(nonce.raw, hasLength(32));
    expect(nonce.raw, matches(RegExp(r'^[0-9A-Za-z\-._]+$')));
    expect(nonce.hashed, sha256.convert(utf8.encode(nonce.raw)).toString());
    expect(nonce.hashed, hasLength(64));
  });

  test('every call makes a new nonce', () {
    final a = SupabaseService.appleNonce();
    final b = SupabaseService.appleNonce();

    expect(a.raw, isNot(b.raw));
  });
}
