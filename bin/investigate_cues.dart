#!/usr/bin/env dart
// ignore_for_file: lines_longer_than_80_chars

import 'package:rekorddart/logger.dart';
import 'package:rekorddart/rekorddart.dart';

/// Investigates cues for a specific track to understand the difference
/// between memory cues and hot cues.
Future<void> main(List<String> arguments) async {
  final trackId = arguments.isNotEmpty ? arguments[0] : '202265496';

  log('Investigating cues for track ID: $trackId');
  log('==========================================\n');

  try {
    // Connect to the database
    final db = await RekordboxDatabase.connect(
      allowConnectionWhenRunning: true,
    );

    // Get the track
    final track = await db.getSongById(trackId);
    if (track == null) {
      log('Track with ID $trackId not found!');
      return;
    }

    log('Track Information:');
    log('  ID: ${track.id}');
    log('  Title: ${track.title ?? 'N/A'}');
    log('  Artist ID: ${track.artistID ?? 'N/A'}');
    log('  Content UUID: ${track.uuid ?? 'N/A'}');
    log('');

    // Get all cues for this track
    final cues =
        await (db.select(db.djmdCue)
              ..where((c) => c.contentID.equals(trackId))
              ..orderBy([(c) => OrderingTerm.asc(c.inMsec)]))
            .get();

    log('Found ${cues.length} cue(s) for this track\n');

    if (cues.isEmpty) {
      log('No cues found for this track.');
      return;
    }

    // Group cues by Kind value
    final cuesByKind = <int, List<DjmdCueData>>{};
    for (final cue in cues) {
      final kind = cue.kind ?? -1;
      cuesByKind.putIfAbsent(kind, () => []).add(cue);
    }

    log('Cues grouped by Kind value:');
    for (final entry in cuesByKind.entries) {
      final kind = entry.key;
      final kindCues = entry.value;
      log('  Kind $kind: ${kindCues.length} cue(s)');
    }
    log('');

    // Display detailed information for each cue
    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      log('Cue ${i + 1}:');
      log('  ID: ${cue.id}');
      log('  Kind: ${cue.kind ?? 'NULL'}');
      log('  InMsec: ${cue.inMsec ?? 'NULL'}');
      log('  OutMsec: ${cue.outMsec ?? 'NULL'}');
      log('  CueMicrosec: ${cue.cueMicrosec ?? 'NULL'}');
      log('  Color: ${cue.color ?? 'NULL'}');
      log('  ColorTableIndex: ${cue.colorTableIndex ?? 'NULL'}');
      log('  ActiveLoop: ${cue.activeLoop ?? 'NULL'}');
      log('  BeatLoopSize: ${cue.beatLoopSize ?? 'NULL'}');
      log('  Comment: ${cue.comment ?? 'NULL'}');
      log('  ContentUUID: ${cue.contentUUID ?? 'NULL'}');
      log('  UUID: ${cue.uuid ?? 'NULL'}');
      log('');
    }

    // Analyze differences
    log('Analysis:');
    log('=========');

    // Check if there are cues with different Kind values
    if (cuesByKind.length > 1) {
      log('Found cues with different Kind values:');
      for (final entry in cuesByKind.entries) {
        final kind = entry.key;
        final kindCues = entry.value;
        log('  Kind $kind (${kindCues.length} cue(s)):');
        for (final cue in kindCues) {
          log(
            '    - InMsec: ${cue.inMsec ?? 'NULL'}, '
            'Color: ${cue.color ?? 'NULL'}, '
            'Comment: ${cue.comment ?? 'NULL'}',
          );
        }
      }
    } else {
      log('All cues have the same Kind value: ${cuesByKind.keys.first}');
    }

    // Check for hot cues in djmdSongHotCueBanklist
    final hotCueBanklistEntries = await (db.select(
      db.djmdSongHotCueBanklist,
    )..where((h) => h.contentID.equals(trackId))).get();

    if (hotCueBanklistEntries.isNotEmpty) {
      log('\nHot Cue Banklist Analysis:');
      log('  Found ${hotCueBanklistEntries.length} entries');
      for (final entry in hotCueBanklistEntries) {
        log('    Entry ID: ${entry.id}');
        log('    HotCueBanklistID: ${entry.hotCueBanklistID}');
        log('    CueID: ${entry.cueID ?? 'NULL'}');
        log('    InMsec: ${entry.inMsec ?? 'NULL'}');
        log('');
      }
      log('\nHot Cue Banklist entries:');
      log(
        '  Found ${hotCueBanklistEntries.length} hot cue banklist entry/entries',
      );
      for (final entry in hotCueBanklistEntries) {
        log('    HotCueBanklistID: ${entry.hotCueBanklistID}');
        log('    CueID: ${entry.cueID ?? 'NULL'}');
        log('    InMsec: ${entry.inMsec ?? 'NULL'}');
        log('    Color: ${entry.color ?? 'NULL'}');
        log('');
      }

      // Try to match hot cue banklist entries with djmdCue entries
      log('Matching hot cue banklist entries with djmdCue entries:');
      for (final banklistEntry in hotCueBanklistEntries) {
        if (banklistEntry.cueID != null) {
          final matchingCues = cues
              .where(
                (c) => c.id == banklistEntry.cueID,
              )
              .toList();
          if (matchingCues.isNotEmpty) {
            final matchingCue = matchingCues.first;
            log('  Hot Cue Banklist CueID ${banklistEntry.cueID} matches:');
            log('    djmdCue Kind: ${matchingCue.kind ?? 'NULL'}');
            log('    djmdCue InMsec: ${matchingCue.inMsec ?? 'NULL'}');
            log('    djmdCue Color: ${matchingCue.color ?? 'NULL'}');
          } else {
            log(
              '  Hot Cue Banklist CueID ${banklistEntry.cueID} '
              'not found in djmdCue',
            );
          }
        }
      }
    } else {
      log('\nNo hot cue banklist entries found for this track.');
    }

    // Enhanced analysis: Identify memory cues vs hot cues
    log('\nEnhanced Analysis:');
    log('==================');

    // Research suggests:
    // - Kind 0 = Memory cue
    // - Kind 1-3 = Hot cue slots A-C (slots 1-3)
    // - Kind 5-9 = Hot cue slots D-H (slots 4-8)
    // - Kind 4 is skipped
    // - Other Kind values might be loops, etc.

    final memoryCues = cues.where((c) => c.kind == 0).toList();
    final hotCues = cues.where((c) {
      final kind = c.kind;
      if (kind == null) return false;
      return (kind >= 1 && kind <= 3) || (kind >= 5 && kind <= 9);
    }).toList();
    final otherCues = cues.where((c) {
      final kind = c.kind;
      if (kind == null) return true;
      return kind != 0 &&
          !((kind >= 1 && kind <= 3) || (kind >= 5 && kind <= 9));
    }).toList();

    log('Memory Cues (Kind = 0): ${memoryCues.length}');
    for (final cue in memoryCues) {
      log('  - ID: ${cue.id}, InMsec: ${cue.inMsec ?? 'NULL'}');
    }

    log('\nHot Cues (Kind 1-3 for A-C, Kind 5-9 for D-H): ${hotCues.length}');
    for (final cue in hotCues) {
      log(
        '  - ID: ${cue.id}, Kind: ${cue.kind}, InMsec: ${cue.inMsec ?? 'NULL'}',
      );
    }

    if (otherCues.isNotEmpty) {
      log('\nOther Cues (Kind < 0 or > 8): ${otherCues.length}');
      for (final cue in otherCues) {
        log(
          '  - ID: ${cue.id}, Kind: ${cue.kind}, '
          'InMsec: ${cue.inMsec ?? 'NULL'}',
        );
      }
    }

    // Check for patterns
    log('\nPattern Analysis:');
    log(
      '  Memory cues at start (0ms): ${memoryCues.where((c) => c.inMsec == 0).length}',
    );
    log(
      '  Memory cues elsewhere: ${memoryCues.where((c) => c.inMsec != 0 && c.inMsec != null).length}',
    );
    log(
      '  Hot cues at start (0ms): ${hotCues.where((c) => c.inMsec == 0).length}',
    );
    log(
      '  Hot cues elsewhere: ${hotCues.where((c) => c.inMsec != 0 && c.inMsec != null).length}',
    );

    // Check which hot cue slots are used (1-8 = A-H)
    log('\nHot Cue Slot Analysis:');
    final usedSlots = hotCues.map((c) => c.kind).whereType<int>().toSet();
    final allSlots = {1, 2, 3, 4, 5, 6, 7, 8};
    final missingSlots = allSlots.difference(usedSlots);
    final usedSlotsList = usedSlots.toList()..sort();
    final missingSlotsList = missingSlots.toList()..sort();
    log('  Used slots (Kind values): $usedSlotsList');
    log('  Missing slots: ${missingSlots.isEmpty ? 'None' : missingSlotsList}');

    // Check if missing slots have memory cues at expected positions
    if (missingSlots.isNotEmpty) {
      log('\n  Checking missing slots for memory cues at expected positions:');
      for (final slot in missingSlots) {
        final slotLetter = String.fromCharCode(64 + slot); // A=65, B=66, etc.
        log('    Slot $slotLetter (Kind $slot): No hot cue entry');

        // Find hot cues before and after this slot to estimate expected position
        final hotCuesBeforeSlot =
            hotCues.where((hc) => hc.kind != null && hc.kind! < slot).toList()
              ..sort((a, b) => (a.inMsec ?? 0).compareTo(b.inMsec ?? 0));
        final hotCuesAfterSlot =
            hotCues.where((hc) => hc.kind != null && hc.kind! > slot).toList()
              ..sort((a, b) => (a.inMsec ?? 0).compareTo(b.inMsec ?? 0));

        if (hotCuesBeforeSlot.isNotEmpty && hotCuesAfterSlot.isNotEmpty) {
          final beforeTime = hotCuesBeforeSlot.last.inMsec;
          final afterTime = hotCuesAfterSlot.first.inMsec;
          if (beforeTime != null && afterTime != null) {
            final expectedTime = beforeTime + ((afterTime - beforeTime) ~/ 2);
            log(
              '      Expected position: ~${expectedTime}ms (between ${beforeTime}ms and ${afterTime}ms)',
            );

            // Check if there's a memory cue near this expected position
            final memoryCuesNearSlot = memoryCues.where((mc) {
              final mcTime = mc.inMsec;
              if (mcTime == null) return false;
              // Allow some tolerance (within 5 seconds)
              return (mcTime - expectedTime).abs() < 5000;
            }).toList();

            if (memoryCuesNearSlot.isNotEmpty) {
              log('      Found memory cue(s) near expected position:');
              for (final mc in memoryCuesNearSlot) {
                log(
                  '        Memory cue at ${mc.inMsec}ms (ID: ${mc.id}) - ${((mc.inMsec ?? 0) - expectedTime).abs()}ms difference',
                );
              }
            } else {
              log('      No memory cue found near expected position');
            }
          }
        }
      }
    }

    // Summary
    log('\nSummary:');
    log('========');
    log('Total cues in djmdCue: ${cues.length}');
    log('  - Memory cues (Kind=0): ${memoryCues.length}');
    log('  - Hot cues (Kind 1-3, 5-9): ${hotCues.length}');
    log('  - Other cues: ${otherCues.length}');
    log('Unique Kind values: ${cuesByKind.keys.toList()}');
    log('Hot cue banklist entries: ${hotCueBanklistEntries.length}');
    log('');
    log('Findings:');
    log('  - All cues are stored in the djmdCue table');
    log('  - Kind = 0 indicates Memory Cues');
    log('  - Kind 1-3 = Hot cue slots A-C (slots 1-3)');
    log('  - Kind 5-9 = Hot cue slots D-H (slots 4-8)');
    log('  - Kind 4 is skipped (not used)');
    log('  - Hot cues may also have entries in djmdSongHotCueBanklist');
    log('  - Memory cues only exist in djmdCue (Kind=0)');
  } catch (e, stackTrace) {
    log('Error: $e');
    log('Stack trace: $stackTrace');
  }
}
