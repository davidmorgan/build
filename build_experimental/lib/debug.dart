import 'dart:io';

Map<String, int> _eventCounts = {};
Map<String, int> _eventMessageCounts = {};
Map<String, int> _eventStackCounts = {};
Map<String, int> _eventMessageStackCounts = {};

void log(String event, [String? message]) {
  final eventCount = _eventCounts[event] = (_eventCounts[event] ?? 0) + 1;

  final eventMessage = '$event $message';
  final eventMessageCount =
      _eventMessageCounts[eventMessage] =
          (_eventMessageCounts[eventMessage] ?? 0) + 1;

  final stackTrace = StackTrace.current
      .toString()
      .split('\n')
      // Skip the stack frames for this file and for the immediate caller.
      .skip(2)
      // Skip SDK stack frames.
      .where((m) => m.contains('package:'))
      .map((f) => f.sanitizeStackFrame())
      .take(2)
      .join(' ');

  final eventStack = '$event $stackTrace';
  _eventStackCounts[eventStack] = (_eventStackCounts[eventStack] ?? 0) + 1;

  final eventMessageStack = '$event $message $stackTrace';
  final eventMessageStackCount =
      _eventMessageStackCounts[eventMessageStack] =
          (_eventMessageStackCounts[eventMessageStack] ?? 0) + 1;

  if (eventCount % 1000 == 0) {
    File('/tmp/build_debug_log.txt').writeAsStringSync(
      '($eventCount) $event '
      '($eventMessageCount) $message '
      '($eventMessageStackCount) $stackTrace\n',
      mode: FileMode.append,
    );
  }
}

String summarize() {
  final result = StringBuffer('\n');
  result.write(_summarize(_eventCounts.keys.toList(), _eventMessageCounts));
  result.write('\n');
  result.write(
    _summarize(_eventCounts.keys.toList(), _eventMessageStackCounts),
  );
  result.write('\n');
  result.write(_summarize(_eventCounts.keys.toList(), _eventStackCounts));
  return result.toString();
}

String _summarize(List<String> events, Map<String, int> counts) {
  final result = StringBuffer();
  for (final event in events) {
    result.write('=== ${_eventCounts[event]} $event\n');
    final messages =
        counts.entries
            .where((e) => e.key == event || e.key.startsWith('$event '))
            .toList();

    messages.sort((a, b) {
      final result = -a.value.compareTo(b.value);
      if (result != 0) return result;
      return a.key.compareTo(b.key);
    });
    result.write(
      messages.map((e) => '${e.value} ${e.key}').take(10).join('\n'),
    );
    result.write('\n');
  }
  return result.toString();
}

extension StringExtensions on String {
  /// Removes the frame number, brackets and whitespace.
  String sanitizeStackFrame() {
    var result = trim();
    final index = result.indexOf(' ');
    result = index == -1 ? result : result.substring(index).trim();
    if (result.startsWith('(') && result.endsWith(')')) {
      result = result.substring(1, result.length - 1);
    }
    return result;
  }
}
