import 'package:test/test.dart';
import 'package:jsi/jsi.dart' as jsi;

// parses and evaluates an expression, returning a string of the result of the evaluation
String pe(String exp) {
  var ctx = jsi.global();
  jsi.parse('var _ = $exp;').run(ctx);
  return '${ctx.get('_')}';
}

void main() {
  test('literal expressions', () {
    expect(pe('undefined'), 'undefined');
    expect(pe('null'), 'null');
    expect(pe('true'), 'true');
    expect(pe('false'), 'false');
    expect(pe('NaN'), 'NaN');
    expect(pe('Infinity'), 'Infinity');
    expect(pe('3'), '3');
    expect(pe('4.5'), '4.5');
  });

  test('+ unary operator', () {
    expect(pe('+undefined'), 'NaN');
    expect(pe('+null'), '0');
    expect(pe('+true'), '1');
    expect(pe('+false'), '0');
    expect(pe('+NaN'), 'NaN');
    expect(pe('+Infinity'), 'Infinity');
    expect(pe('+3'), '3');
    expect(pe('+4.5'), '4.5');
  });

  test('- unary operator', () {
    expect(pe('-undefined'), 'NaN');
    expect(pe('-null'), '0');
    expect(pe('-true'), '-1');
    expect(pe('-false'), '0');
    expect(pe('-NaN'), 'NaN');
    expect(pe('-Infinity'), '-Infinity');
    expect(pe('-3'), '-3');
    expect(pe('-4.5'), '-4.5');
  });

  test('+ operator', () {
    expect(pe('undefined + undefined'), 'NaN');
    expect(pe('null + null'), '0');
    expect(pe('true + true'), '2');
    expect(pe('false + false'), '0');
    expect(pe('NaN + NaN'), 'NaN');
    expect(pe('Infinity + Infinity'), 'Infinity');
    expect(pe('1 + 2'), '3');
    expect(pe('1.1 + 2.8'), '3.9');
  });

  test('array literals', () {
    expect(pe('[]'), '[object Array]');
    expect(pe('[1,2]'), '[object Array]');
    expect(pe('[1,2].length'), '2');
  });

  test('object literals', () {
    expect(pe('{}'), '[object Object]');
    expect(pe('{a:1}'), '[object Object]');
    expect(pe('{a:1}.length'), 'undefined');
  });
}
