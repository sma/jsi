// Copyright 2013, 2021 by Stefan Matthias Aust
part of '../jsi.dart';

/**
 * Returns an initialized global object.
 */
JSObject global() {
  JSValue isFinite(JSValue rcvr, JSArray args, JSObject env) => JSBoolean(args.at(0).numValue().isFinite);
  JSValue isNaN(JSValue rcvr, JSArray args, JSObject env) => JSBoolean(args.at(0).numValue().isNaN);

  final env = JSObject({})
    ..set('Infinity', JSValue.INFINITY)
    ..set('NaN', JSValue.NAN)
    ..set('undefined', JSValue.UNDEFINED)
    ..set('isFinite', JSFunction('isFinite', 1, isFinite))
    ..set('isNaN', JSFunction('isNaN', 1, isNaN));
  env.set('this', env);
  env.set('global', env);
  return env;
}

/**
 * Base class of all ECMAscript values.
 */
sealed class JSValue {
  const JSValue();

  static const JSUndefined UNDEFINED = JSUndefined._();
  static const JSNull NULL = JSNull._();
  static const JSBoolean TRUE = JSBoolean._(true);
  static const JSBoolean FALSE = JSBoolean._(false);
  static const JSNumber NAN = JSNumber(double.nan);
  static const JSNumber ZERO = JSNumber(0.0);
  static const JSNumber ONE = JSNumber(1.0);
  static const JSNumber INFINITY = JSNumber(double.infinity);
  static const JSNumber NEGATIVE_INFINITY = JSNumber(double.negativeInfinity);

  /// Returns the receiver converted to a number.
  num numValue();

  /// Returns the receiver converted to a boolean.
  bool boolValue();

  /// Returns the receiver converted to a string.
  String stringValue();

  /// Returns the value of property [name] or `null` if there is no such
  /// property. In the latter case, somebody else has to decide what to do.
  JSValue? get(String name) => null;

  /// Tries to set property [name] to [value] and returns whether that was
  /// sucessful or not. In the latter case, somebody else has to decided
  /// what to do.
  bool set(String name, JSValue value) => false;

  /// Tries to delete property [name] and returns whether that was
  /// sucessful or not. In the latter case, somebody else has to decided
  /// what to do.
  bool delete(String name) => false;

  /// Returns a string for debug purposes only.
  @override
  String toString() => stringValue();

  /// Returns whether the receiver is [UNDEFINED], using polymorphism.
  bool get isUndefined => this is JSUndefined;
}

/**
 * Class of the singleton `undefined` value.
 */
final class JSUndefined extends JSValue {
  const JSUndefined._();

  @override
  num numValue() => double.nan;

  @override
  bool boolValue() => false;

  @override
  String stringValue() => 'undefined';
}

/**
 * Class of the singleton `null` value.
 */
final class JSNull extends JSValue {
  const JSNull._();

  @override
  num numValue() => 0;

  @override
  bool boolValue() => false;

  @override
  String stringValue() => 'null';
}

/**
 * Class of the Boolean values `true` and `false`.
 */
final class JSBoolean extends JSValue {
  factory JSBoolean(bool value) => value ? JSValue.TRUE : JSValue.FALSE;

  const JSBoolean._(this.value);

  final bool value;

  @override
  bool operator ==(dynamic other) => other is JSBoolean && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  num numValue() => value ? 1 : 0;

  @override
  bool boolValue() => value;

  @override
  String stringValue() => value.toString();
}

/**
 * Class of numbers (including `NaN` and `Infinity`).
 */
final class JSNumber extends JSValue {
  const JSNumber(this.value);

  final num value;

  @override
  bool operator ==(dynamic other) => other is JSNumber && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  bool boolValue() => value != 0 && !value.isNaN;

  @override
  num numValue() => value;

  @override
  String stringValue() {
    if (value.isNaN) return 'NaN';
    if (value == double.infinity) return 'Infinity';
    if (value == double.negativeInfinity) return '-Infinity';
    if (value == value.truncate()) return value.truncate().toString();
    return value.toString();
  }
}

/**
 * Class of strings.
 */
final class JSString extends JSValue {
  const JSString(this.value);

  final String value;

  @override
  bool operator ==(dynamic other) => other is JSString && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  bool boolValue() => value.isNotEmpty;

  @override
  num numValue() {
    var s = value.trim();
    if (s.isEmpty) return 0;
    return num.tryParse(s) ?? double.nan;
  }

  @override
  String stringValue() => value;

  @override
  JSValue? get(String name) {
    if (name == 'length') return JSNumber(value.length);
    if (name == 'slice') {
      // TODO belongs to a prototype
      return JSFunction('slice', 2, (r, a, c) {
        var start = a.at(0).numValue().toInt();
        if (start < 0) start += value.length;
        var end = a.at(1).isUndefined ? value.length : a.at(1).numValue().toInt();
        if (end < 0) end += value.length;
        return JSString(value.substring(start, end));
      });
    }
    var index = int.tryParse(name) ?? -1;
    if (index >= 0 && index < value.length) {
      return JSString(value.substring(index, index + 1));
    }
    return super.get(name);
  }

  @override
  String toString() {
    final escaped = value.replaceAll('\\', '\\\\');
    if (escaped.contains("'")) return '"${escaped.replaceAll('"', '\\"')}"';
    return "'${escaped.replaceAll("'", "\\'")}'";
  }
}

/**
 * Class of objects with properties.
 */
final class JSObject extends JSValue {
  const JSObject(this.values);

  final Map<String, JSValue> values;

  @override
  bool boolValue() => true;

  @override
  num numValue() => double.nan;

  @override
  String stringValue() => '[object Object]';

  @override
  JSValue? get(String name) {
    if (name == 'hasOwnProperty') {
      // TODO this should be on the prototype
      return JSFunction('hasOwnProperty', 1, (r, a, ctx) {
        final name = a.at(0).stringValue();
        return JSBoolean(values.containsKey(name));
      });
    }
    final value = values[name];
    if (value != null) return value;
    final proto = values['__proto__'];
    if (proto != null) {
      return proto.get(name);
    }
    return JSValue.UNDEFINED;
  }

  @override
  bool set(String name, JSValue value) {
    values[name] = value;
    return true;
  }

  @override
  bool delete(String name) {
    return values.remove(name) != null;
  }
}

/**
 * Class of arrays which have indexed elements and a special `length` property in addition to
 * generic object properties.
 */
final class JSArray extends JSObject {
  JSArray(this.elements) : super({});

  final List<JSValue> elements;

  @override
  String stringValue() => '[object Array]';

  JSValue at(int index) => index >= 0 && index < elements.length ? elements[index] : JSValue.UNDEFINED;

  @override
  JSValue? get(String name) {
    if (name == 'length') return JSNumber(elements.length);
    if (name == 'push') {
      // TODO belongs to a prototype
      return JSFunction('push', 1, (r, a, c) {
        elements.addAll(a.elements);
        return JSNumber(elements.length);
      });
    }
    if (name == 'map') {
      // TODO belongs to a prototype
      return JSFunction('map', 1, (r, a, c) {
        final transform = a.at(0) as JSFunction;
        return JSArray(elements.map((element) => transform.call(JSValue.UNDEFINED, JSArray([element]), c)).toList());
      });
    }
    return at(int.tryParse(name) ?? -1);
  }

  @override
  bool set(String name, JSValue value) {
    final index = int.tryParse(name) ?? -1;
    if (name == 'length') {
      if (index < 0) {
        throw 'RangeError: Invalid array length';
      }
      elements.length = index;
      return true;
    }
    if (index >= 0) {
      while (elements.length <= index) {
        elements.add(JSValue.UNDEFINED);
      }
      elements[index] = value;
      return true;
    }
    return super.set(name, value);
  }

  @override
  bool delete(String name) {
    final index = int.tryParse(name) ?? -1;
    if (index >= 0 && index < elements.length) elements[index] = JSValue.UNDEFINED;
    return true;
  }
}

typedef Func = JSValue Function(JSValue receiver, JSArray arguments, JSObject env);

/**
 * Class of functions which has a callable Dart function object and a special
 * `length` property in addition to generic object properties. Use [call] 
 * to call the function's Dart function.
 */
final class JSFunction extends JSObject {
  JSFunction(this.name, this.length, this.func) : super({});

  final String? name;
  final int length;
  final Func func;

  JSValue call(JSValue receiver, JSArray arguments, JSObject env) {
    return func(receiver, arguments, env);
  }

  @override
  String stringValue() => '[object Function]';

  @override
  JSValue? get(String name) {
    if (name == 'length') {
      return JSNumber(length);
    }
    if (name == 'apply') {
      return JSFunction('apply', 2, (r, a, ctx) {
        return call(a.at(0), a.at(1) as JSArray, ctx);
      });
    }
    return super.get(name);
  }
}
