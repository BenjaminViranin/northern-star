import 'package:dart_quill_delta/dart_quill_delta.dart';

/// Service for converting between Markdown and Quill Delta formats
class MarkdownConverter {
  /// Converts Markdown text to Quill Delta format
  static Delta markdownToDelta(String markdown) {
    final lines = markdown.split('\n');
    final operations = <Operation>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.isEmpty) {
        operations.add(Operation.insert('\n'));
        continue;
      }

      // Handle headers
      if (line.startsWith('#')) {
        final headerMatch = RegExp(r'^(#{1,6})\s+(.*)').firstMatch(line);
        if (headerMatch != null) {
          final level = headerMatch.group(1)!.length;
          final text = headerMatch.group(2)!;

          operations.add(Operation.insert(text));
          operations.add(Operation.insert('\n', {
            'header': level,
          }));
          continue;
        }
      }

      // Handle code blocks
      if (line.startsWith('```')) {
        // Find the end of the code block
        final codeLines = <String>[];
        i++; // Skip the opening ```

        while (i < lines.length && !lines[i].startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }

        final codeText = codeLines.join('\n');
        operations.add(Operation.insert(codeText));
        operations.add(Operation.insert('\n', {
          'code-block': true,
        }));
        continue;
      }

      // Handle lists
      if (line.startsWith('- ') || line.startsWith('* ') || RegExp(r'^\d+\.\s').hasMatch(line)) {
        final isBullet = line.startsWith('- ') || line.startsWith('* ');
        final text = isBullet ? line.substring(2) : line.replaceFirst(RegExp(r'^\d+\.\s'), '');

        operations.add(Operation.insert(text));
        operations.add(Operation.insert('\n', {
          'list': isBullet ? 'bullet' : 'ordered',
        }));
        continue;
      }

      // Handle checkboxes
      if (line.startsWith('- [ ]') || line.startsWith('- [x]')) {
        final isChecked = line.startsWith('- [x]');
        final text = line.substring(5).trim();

        operations.add(Operation.insert(text));
        operations.add(Operation.insert('\n', {
          'list': 'checked',
          'checked': isChecked,
        }));
        continue;
      }

      // Handle inline formatting
      final processedLine = _processInlineFormatting(line);
      operations.addAll(processedLine);
      operations.add(Operation.insert('\n'));
    }

    final delta = Delta();
    for (final operation in operations) {
      delta.insert(operation.data, operation.attributes);
    }
    return delta;
  }

  /// Processes inline formatting like bold, italic, code, etc.
  static List<Operation> _processInlineFormatting(String text) {
    final operations = <Operation>[];
    var currentIndex = 0;

    // Patterns for inline formatting
    final patterns = [
      // Bold: **text** or __text__
      RegExp(r'\*\*(.*?)\*\*'),
      RegExp(r'__(.*?)__'),
      // Italic: *text* or _text_
      RegExp(r'\*(.*?)\*'),
      RegExp(r'_(.*?)_'),
      // Inline code: `text`
      RegExp(r'`(.*?)`'),
      // Strikethrough: ~~text~~
      RegExp(r'~~(.*?)~~'),
    ];

    final formatTypes = [
      {'bold': true}, // **text**
      {'bold': true}, // __text__
      {'italic': true}, // *text*
      {'italic': true}, // _text_
      {'code': true}, // `text`
      {'strike': true}, // ~~text~~
    ];

    while (currentIndex < text.length) {
      RegExpMatch? nearestMatch;
      var nearestIndex = text.length;
      var nearestPatternIndex = -1;

      // Find the nearest formatting pattern
      for (int i = 0; i < patterns.length; i++) {
        final match = patterns[i].firstMatch(text.substring(currentIndex));
        if (match != null) {
          final matchIndex = currentIndex + match.start;
          if (matchIndex < nearestIndex) {
            nearestMatch = match;
            nearestIndex = matchIndex;
            nearestPatternIndex = i;
          }
        }
      }

      if (nearestMatch != null) {
        // Add text before the match
        if (nearestIndex > currentIndex) {
          operations.add(Operation.insert(text.substring(currentIndex, nearestIndex)));
        }

        // Add the formatted text
        final formattedText = nearestMatch.group(1);
        operations.add(Operation.insert(formattedText, formatTypes[nearestPatternIndex]));

        currentIndex = nearestIndex + nearestMatch.group(0)!.length;
      } else {
        // No more formatting, add the rest of the text
        operations.add(Operation.insert(text.substring(currentIndex)));
        break;
      }
    }

    return operations;
  }

  /// Converts Quill Delta to Markdown format
  static String deltaToMarkdown(Delta delta) {
    final buffer = StringBuffer();

    for (final operation in delta.toList()) {
      if (operation.isInsert) {
        final text = operation.data as String;
        final attributes = operation.attributes ?? <String, dynamic>{};

        if (text == '\n') {
          // Handle block-level formatting
          if (attributes.containsKey('header')) {
            final level = attributes['header'] as int;
            buffer.write('${'#' * level} ');
          } else if (attributes.containsKey('code-block')) {
            buffer.write('```\n');
          } else if (attributes.containsKey('list')) {
            final listType = attributes['list'] as String;
            if (listType == 'bullet') {
              buffer.write('- ');
            } else if (listType == 'ordered') {
              buffer.write('1. ');
            } else if (listType == 'checked') {
              final isChecked = attributes['checked'] == true;
              buffer.write(isChecked ? '- [x] ' : '- [ ] ');
            }
          }
          buffer.write('\n');
        } else {
          // Handle inline formatting
          var formattedText = text;

          if (attributes.containsKey('bold') && attributes['bold'] == true) {
            formattedText = '**$formattedText**';
          }
          if (attributes.containsKey('italic') && attributes['italic'] == true) {
            formattedText = '*$formattedText*';
          }
          if (attributes.containsKey('code') && attributes['code'] == true) {
            formattedText = '`$formattedText`';
          }
          if (attributes.containsKey('strike') && attributes['strike'] == true) {
            formattedText = '~~$formattedText~~';
          }

          buffer.write(formattedText);
        }

        // Track attributes for future use if needed
      }
    }

    return buffer.toString();
  }

  /// Detects if the given text is likely Markdown
  static bool isMarkdown(String text) {
    // Simple heuristics to detect Markdown
    final markdownPatterns = [
      RegExp(r'^#{1,6}\s'), // Headers
      RegExp(r'\*\*(.*?)\*\*'), // Bold
      RegExp(r'\*(.*?)\*'), // Italic
      RegExp(r'`(.*?)`'), // Inline code
      RegExp(r'^```'), // Code blocks
      RegExp(r'^[-*]\s'), // Lists
      RegExp(r'^\d+\.\s'), // Numbered lists
      RegExp(r'^- \[[x ]\]'), // Checkboxes
      RegExp(r'~~(.*?)~~'), // Strikethrough
    ];

    final lines = text.split('\n');
    var markdownScore = 0;

    for (final line in lines) {
      for (final pattern in markdownPatterns) {
        if (pattern.hasMatch(line)) {
          markdownScore++;
          break;
        }
      }
    }

    // Consider it Markdown if more than 20% of lines have Markdown syntax
    return markdownScore > 0 && (markdownScore / lines.length) > 0.2;
  }
}
