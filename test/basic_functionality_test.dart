import 'package:flutter_test/flutter_test.dart';
import 'package:northern_star/core/services/markdown_converter.dart';

void main() {
  group('Basic Functionality Tests', () {
    group('Markdown Detection', () {
      test('should detect markdown headers', () {
        const markdown = '# Header 1\n## Header 2';
        expect(MarkdownConverter.isMarkdown(markdown), isTrue);
      });

      test('should detect markdown formatting', () {
        const markdown = 'This is **bold** and *italic* text.';
        expect(MarkdownConverter.isMarkdown(markdown), isTrue);
      });

      test('should detect markdown lists', () {
        const markdown = '- Item 1\n- Item 2';
        expect(MarkdownConverter.isMarkdown(markdown), isTrue);
      });

      test('should not detect plain text as markdown', () {
        const plainText = 'This is just plain text.';
        expect(MarkdownConverter.isMarkdown(plainText), isFalse);
      });
    });

    group('Markdown Conversion', () {
      test('should convert simple markdown to delta', () {
        const markdown = '# Header\nSome text.';
        final delta = MarkdownConverter.markdownToDelta(markdown);
        expect(delta, isNotNull);
      });

      test('should convert delta back to markdown', () {
        const markdown = '# Header\nSome text.';
        final delta = MarkdownConverter.markdownToDelta(markdown);
        final convertedMarkdown = MarkdownConverter.deltaToMarkdown(delta);
        expect(convertedMarkdown, contains('Header'));
        expect(convertedMarkdown, contains('Some text'));
      });
    });
  });
}
