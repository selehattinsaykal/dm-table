import 'package:dm_table/data/music_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyMusicLink', () {
    test('YouTube domain names are recognized', () {
      for (final url in [
        'https://www.youtube.com/watch?v=abc123',
        'https://youtube.com/watch?v=abc123',
        'http://youtu.be/abc123',
        'https://music.youtube.com/watch?v=abc123',
        // Schemaless paste should also work.
        'youtube.com/watch?v=abc123',
      ]) {
        expect(classifyMusicLink(url), MusicLinkKind.youtube, reason: url);
      }
    });

    test('other http links go to generic resolver', () {
      expect(
        classifyMusicLink('https://example.com/ambience/tavern.mp3'),
        MusicLinkKind.other,
      );
    });

    test('non-url input is rejected', () {
      for (final text in ['', '   ', 'merhaba dunya', 'file:///C:/a.mp3']) {
        expect(classifyMusicLink(text), MusicLinkKind.unknown, reason: text);
      }
    });

    test('domain-like but non-YouTube URL is not classified as YouTube', () {
      // `endsWith('.youtube.com')` check should prevent `youtube.com.evil.site`
      // from being classified as YouTube.
      expect(
        classifyMusicLink('https://youtube.com.example.org/watch?v=1'),
        MusicLinkKind.other,
      );
    });
  });

  group('classifyDownloadFailure', () {
    test('403 forbidden is classified', () {
      expect(
        classifyDownloadFailure(
          'ERROR: unable to download video data: HTTP Error 403: Forbidden',
        ),
        MusicDownloadError.forbidden,
      );
    });

    test('unrecognized error stays as failed', () {
      for (final text in [
        null,
        '',
        'ERROR: [youtube] abc: Video unavailable',
      ]) {
        expect(
          classifyDownloadFailure(text),
          MusicDownloadError.failed,
          reason: '$text',
        );
      }
    });
  });

  group('MusicDownloader.download', () {
    test('non-url input gives badLink', () async {
      await expectLater(
        MusicDownloader().download('merhaba dunya'),
        throwsA(
          isA<MusicDownloadException>().having(
            (e) => e.reason,
            'reason',
            MusicDownloadError.badLink,
          ),
        ),
      );
    });
  });
}
