import 'dart:io';

import 'package:jsi/jsi.dart';

extension on JSObject {
  void bindFunc1(String name, JSValue? Function(JSValue) func) {
    set(name, JSFunction(name, 1, (r, a, c) => func(a.at(0)) ?? JSValue.UNDEFINED));
  }

  void bindFunc2(String name, JSValue? Function(JSValue, JSValue) func) {
    set(name, JSFunction(name, 2, (r, a, c) => func(a.at(0), a.at(1)) ?? JSValue.UNDEFINED));
  }
}

void main() {
  var ast = parse(File('js/jsi.js').readAsStringSync());
  // File('parsed.js').writeAsStringSync(ast.toString());

  var env = global()
    ..bindFunc2('RegExp', (pattern, flags) {
      final re = RegExp(
        pattern.stringValue(),
        multiLine: flags.stringValue().contains('m'),
      );
      return JSObject({})
        ..set('pattern', pattern)
        ..set('flags', flags)
        ..set('lastindex', JSNumber(0))
        ..set(
            'exec',
            JSFunction('exec', 1, (r, a, c) {
              final input = a.at(0).stringValue();
              final start = r.get('lastindex')!.numValue().toInt();
              final match = re.firstMatch(input.substring(start));
              if (match == null) return JSValue.NULL;
              if (r.get('flags')!.stringValue().contains('g')) {
                r.set('lastindex', JSNumber(start + match.end));
              }
              final result = JSObject({});
              result.set('input', a.at(0));
              result.set('index', JSNumber(start + match.start));
              for (var i = 0; i <= match.groupCount; i++) {
                final m = match[i];
                result.set('$i', m != null ? JSString(m) : JSValue.NULL);
              }
              return result;
            }))
        ..set(
            'test',
            JSFunction('test', 1, (r, a, c) {
              final input = a.at(0).stringValue();
              final match = re.firstMatch(input);
              return JSBoolean(match != null);
            }));
    })
    ..bindFunc2('_readFileSync', (a, b) {
      return JSString(File(a.stringValue()).readAsStringSync());
    })
    ..bindFunc1('_log', (a) {
      print(a.stringValue());
      return JSValue.UNDEFINED;
    })
    ..bindFunc1('parseFloat', (a) {
      return JSNumber(num.tryParse(a.stringValue()) ?? double.nan);
    });

  parse('''
function require(path) {
  return {
    readFileSync: _readFileSync
  };
}
var console = {
  log: _log
};
var Object = {
  create: function create(obj) { return {__proto__: obj}; }
};
''').run(env);

  ast.run(env);
}
