// Copyright 2013 by Stefan Matthias Aust
part of '../jsi.dart';

// ------------scanner-------------------------------------------------------------------------------------------------

final _re = RegExp(
  r'\s+|' //                                 whitespace
  r'//.*$|/\*[\s\S]*\*/|' //                 line/block comments
  r'(\d+(?:\.\d*)?(?:[eE][-+]?\d+)?|' //     number
  r'\w+|' //                                 name
  r''''(?:\\.|[^'])*'|"(?:\\.|[^"])*"|''' // string
  r'/(?:\\.|[^/])+/g?m?i?|' //               regular expression
  r'[!=]==|[<>]=?|[-+*/%!]|' //              operators
  r'[()\[\]{},;.:=])|(.)', //                syntax
  multiLine: true,
);

late Iterator<Match> _matches;
late String _source;
late String? _current;
late int _index;

// initialize the parser with the given source string to produce a token stream
void initialize(String s) {
  _source = s;
  _matches = _re.allMatches(s).iterator;
  _current = next();
}

// returns the next token from the token stream
String? next() {
  if (_matches.moveNext()) {
    var match = _matches.current;
    if (match[2] != null) {
      throw 'invalid character ${match[2]}';
    }
    if (match[1] != null) {
      _index = match.start;
      return match[1]!;
    }
    return next();
  }
  return null;
}

// if the current token is the given one, consume it and return true; otherwise consume nothing and return false
bool at(String token) {
  if (_current == null) {
    throw 'unexpected end of stream';
  }
  if (_current == token) {
    _current = next();
    return true;
  }
  return false;
}

// returns the current token and consume it
String consume() {
  var value = _current!;
  _current = next();
  return value;
}

// throws an error if the current token (which is otherwise consumed) is not the given one
void expect(String token) {
  if (!at(token)) {
    throw 'expected $token but found $_current ${atLine()}';
  }
}

// returns the line number of the current token
String atLine() {
  return ' at ${(_source.substring(0, _index).replaceAll(RegExp(r'[^\n]'), '').length + 1)}';
}

// ------------parser--------------------------------------------------------------------------------------------------

// parses the given source string and returns an AST representation of the source
Block parse(String s) {
  var stmts = <Statement>[];
  initialize(s);
  while (_current != null) {
    stmts.add(parseStatement());
  }
  return Block(stmts);
}

Statement parseStatement() {
  if (at('var')) {
    var name = parseName();
    Expr? expr;
    if (at('=')) {
      expr = parseExpression();
    }
    expect(';');
    return VarStatement(name, expr);
  }
  if (at('function')) {
    var func = parseFunction();
    if (func.name == null) {
      throw 'function statements require function name ${atLine()}';
    }
    return VarStatement(func.name!, func);
  }
  if (at('if')) {
    return parseIf();
  }
  if (at('while')) {
    expect('(');
    var expr = parseExpression();
    expect(')');
    return WhileStatement(expr, parseBlock());
  }
  if (at('break')) {
    expect(';');
    return BreakStatement();
  }
  if (at('throw')) {
    var expr = parseExpression();
    expect(';');
    return ThrowStatement(expr);
  }
  if (at('return')) {
    Expr? expr;
    if (!at(';')) {
      expr = parseExpression();
      expect(';');
    }
    return ReturnStatement(expr);
  }
  var expr = parseExpression();
  Statement stmt;
  if (at('=')) {
    if (expr is! Target) {
      throw 'invalid left hand side ${atLine()}';
    }
    stmt = AssignStatement(expr as Target, parseExpression());
  } else {
    stmt = ExprStatement(expr);
  }
  expect(';');
  return stmt;
}

Statement parseIf() {
  expect('(');
  var cond = parseExpression();
  expect(')');
  var thenBody = parseBlock();
  Block? elseBody;
  if (at('else')) {
    if (at('if')) {
      elseBody = Block([parseIf()]);
    } else {
      elseBody = parseBlock();
    }
  }
  return IfStatement(cond, thenBody, elseBody);
}

Block parseBlock() {
  var stmts = <Statement>[];
  expect('{');
  while (!at('}')) {
    stmts.add(parseStatement());
  }
  return Block(stmts);
}

Expr parseExpression() {
  var expr = parseComparison();
  if (at('===')) {
    expr = EqualExpr(expr, parseComparison());
  }
  return expr;
}

Expr parseComparison() {
  var expr = parseTerm();
  if (at('<')) {
    expr = LessExpr(expr, parseTerm());
  }
  return expr;
}

Expr parseTerm() {
  var expr = parseFactor();
  while (at('+')) {
    expr = AddExpr(expr, parseFactor());
  }
  return expr;
}

Expr parseFactor() {
  var expr = parseUnary();
  while (at('*')) {
    expr = MulExpr(expr, parseUnary());
  }
  return expr;
}

Expr parseUnary() {
  if (at('+')) {
    return PosExpr(parseUnary());
  }
  if (at('-')) {
    return NegExpr(parseUnary());
  }
  if (at('!')) {
    return NotExpr(parseUnary());
  }
  var expr = parsePrimary();
  while (true) {
    if (at('.')) {
      expr = RefExpr(expr, LitExpr(JSString(parseName())));
    } else if (at('[')) {
      expr = RefExpr(expr, parseExpression());
      expect(']');
    } else if (at('(')) {
      var args = <Expr>[];
      if (!at(')')) {
        args.add(parseExpression());
        while (at(',')) {
          args.add(parseExpression());
        }
        expect(')');
      }
      expr = InvocationExpr(expr, args);
    } else {
      break;
    }
  }
  return expr;
}

Expr parsePrimary() {
  if (at('(')) {
    var expr = parseExpression();
    expect(')');
    return expr;
  }
  if (at('true')) {
    return LitExpr(JSValue.TRUE);
  }
  if (at('false')) {
    return LitExpr(JSValue.FALSE);
  }
  if (at('null')) {
    return LitExpr(JSValue.NULL);
  }
  if (at('function')) {
    return parseFunction();
  }
  final cur = _current!; // otherwise, the first `at` would have failed
  if (cur.startsWith("'") || cur.startsWith('"')) {
    assert(cur.endsWith(cur[0]));
    consume();
    return LitExpr(JSString(cur.substring(1, cur.length - 1)));
  }
  if (cur.startsWith('/')) {
    final i = cur.lastIndexOf('/');
    assert(i != -1);
    consume();
    return InvocationExpr(NameExpr('RegExp'), [
      LitExpr(JSString(cur.substring(1, i))),
      LitExpr(JSString(cur.substring(i + 1))),
    ]);
  }
  if (RegExp(r'^\d').hasMatch(cur)) {
    return LitExpr(JSNumber(double.parse(consume())));
  }
  if (RegExp(r'^\w').hasMatch(cur)) {
    return NameExpr(consume());
  }
  if (at('[')) {
    var args = <Expr>[];
    if (!at(']')) {
      args.add(parseExpression());
      while (at(',')) {
        args.add(parseExpression());
      }
      expect(']');
    }
    return ArrayExpr(args);
  }
  if (at('{')) {
    var args = <Expr>[];
    if (!at('}')) {
      var expr = parseExpression();
      if (expr is NameExpr) {
        expr = LitExpr(JSString((expr).name));
      }
      args.add(expr);
      expect(':');
      args.add(parseExpression());
      while (at(',')) {
        var expr = parseExpression();
        if (expr is NameExpr) {
          expr = LitExpr(JSString((expr).name));
        }
        args.add(expr);
        expect(':');
        args.add(parseExpression());
      }
      expect('}');
    }
    return ObjectExpr(args);
  }
  throw 'unknown primary $cur ${atLine()}';
}

FunctionExpr parseFunction() {
  String? name;
  var params = <String>[];
  if (!at('(')) {
    name = parseName();
    expect('(');
  }
  if (!at(')')) {
    params.add(parseName());
    while (at(',')) {
      params.add(parseName());
    }
    expect(')');
  }
  return FunctionExpr(name, params, parseBlock());
}

String parseName() {
  if (RegExp(r'^\w').hasMatch(_current!)) {
    return consume();
  }
  throw 'name expected ${atLine()}';
}
