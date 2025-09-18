#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:rekorddart/logger.dart';
import 'package:rekorddart/rekorddart.dart';

/// Key sources for downloading the encryption key
final List<({String url, RegExp regex})> keySources = [
  (
    url:
        'https://raw.githubusercontent.com/mganss/CueGen/19878e6eb3f586dee0eb3eb4f2ce3ef18309de9d/CueGen/Generator.cs',
    regex: RegExp(
      r'((.|\n)*)Config\.UseSqlCipher.*\?.*"(?<dp>.*)".*:.*null',
      caseSensitive: false,
      multiLine: true,
    ),
  ),
  (
    url:
        'https://raw.githubusercontent.com/dvcrn/go-rekordbox/8be6191ba198ed7abd4ad6406d177ed7b4f749b5/cmd/getencryptionkey/main.go',
    regex: RegExp(
      r'((.|\n)*)fmt\.Print\("(?<dp>.*)"\)',
      caseSensitive: false,
      multiLine: true,
    ),
  ),
];

/// Downloads the Rekordbox database encryption key from online sources
Future<String?> downloadDb6Key() async {
  final httpClient = HttpClient();

  try {
    for (final source in keySources) {
      final url = source.url;
      final regex = source.regex;

      log('Looking for key: $url');

      try {
        final uri = Uri.parse(url);
        final request = await httpClient.getUrl(uri);
        final response = await request.close();

        if (response.statusCode == 200) {
          final data = await response.transform(utf8.decoder).join();
          final match = regex.firstMatch(data);

          if (match != null) {
            final key = match.namedGroup('dp');
            if (key != null && key.isNotEmpty) {
              log('Found key from online source: $url');
              return key;
            }
          }
        } else {
          log('Failed to fetch from $url (status: ${response.statusCode})');
        }
      } catch (e) {
        log('Error fetching from $url: $e');
      }
    }

    log('No key found in online sources.');
    return null;
  } finally {
    httpClient.close();
  }
}

/// Gets the Rekordbox database encryption key
///
/// Priority order:
/// 1. REKORDBOX_DB_KEY environment variable
/// 2. Downloaded key from online sources
/// 3. Default hardcoded key
Future<String> getRekordboxKey() async {
  // Check environment variable first
  final envKey = Platform.environment['REKORDBOX_DB_KEY'];
  if (envKey != null && envKey.isNotEmpty) {
    log('Using encryption key from REKORDBOX_DB_KEY environment variable');
    return envKey;
  }

  // Try to download key from online sources
  final downloadedKey = await downloadDb6Key();
  if (downloadedKey != null) {
    return downloadedKey;
  }

  // Fall back to default key
  log('Using default encryption key');
  return defaultRekordboxKey;
}

void main(List<String> arguments) async {
  log('Rekordbox Database Key Downloader');
  log('==================================');

  try {
    final key = await getRekordboxKey();
    log('\nEncryption Key: $key');

    // Also show how to set the environment variable
    log('\nTo set this key as an environment variable:');
    if (Platform.isWindows) {
      log('set REKORDBOX_DB_KEY=$key');
    } else {
      log('export REKORDBOX_DB_KEY=$key');
    }
  } catch (e) {
    log('Error: $e');
    exit(1);
  }
}
