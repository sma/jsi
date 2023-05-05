// Copyright 2013 by Stefan Matthias Aust
part of jsi;

extension on JSObject {
  bool get isReturning => values.containsKey('return');
  bool get isBreaking => values.containsKey('break');
  bool get isThrowing => values.containsKey('throw');
  JSValue throwing(String message) {
    set('throw', JSString(message));
    return JSValue.UNDEFINED;
  }
}

JSBoolean doEqual(JSValue a, JSValue b) {
  return JSBoolean(a == b);
}

/**
 * A sequence of statements.
 */
final class Block {
  const Block(this.statements);

  final List<Statement> statements;

  @override
  String toString() => statements.join('\n');

  JSValue run(JSObject env) {
    for (var i = 0; i < statements.length; i++) {
      final r = statements[i].run(env);
      if (env.isReturning || env.isThrowing) return r;
      if (env.isBreaking) break;
    }
    return JSValue.UNDEFINED;
  }
}

/**
 * A statement.
 */
sealed class Statement {
  const Statement();

  JSValue run(JSObject env);
}

final class VarStatement extends Statement {
  const VarStatement(this.name, this.expr);

  final String name;
  final Expr? expr;

  @override
  String toString() => 'var $name${expr != null ? ' = $expr' : ''};';

  @override
  JSValue run(JSObject env) {
    env.set(name, expr?.run(env) ?? JSValue.UNDEFINED);
    return JSValue.UNDEFINED;
  }
}

final class WhileStatement extends Statement {
  const WhileStatement(this.expr, this.whileBlock);

  final Expr expr;
  final Block whileBlock;

  @override
  String toString() => 'while ($expr) { $whileBlock }';

  @override
  JSValue run(JSObject env) {
    while (expr.run(env).boolValue()) {
      final r = whileBlock.run(env);
      if (env.isReturning || env.isThrowing) return r;
      if (env.isBreaking) {
        env.delete('break');
        break;
      }
    }
    return JSValue.UNDEFINED;
  }
}

final class IfStatement extends Statement {
  const IfStatement(this.expr, this.thenBlock, this.elseBlock);

  final Expr expr;
  final Block thenBlock;
  final Block? elseBlock;

  @override
  String toString() => 'if ($expr) { $thenBlock }${elseBlock != null ? ' else { $elseBlock }' : ''}';

  @override
  JSValue run(JSObject env) {
    if (expr.run(env).boolValue()) {
      return thenBlock.run(env);
    }
    return elseBlock?.run(env) ?? JSValue.UNDEFINED;
  }
}

final class ThrowStatement extends Statement {
  const ThrowStatement(this.expr);

  final Expr expr;

  @override
  String toString() => 'throw $expr;';

  @override
  JSValue run(JSObject env) {
    return env.throwing(expr.run(env).stringValue());
  }
}

final class ReturnStatement extends Statement {
  const ReturnStatement(this.expr);

  final Expr? expr;

  @override
  String toString() => 'return $expr;';

  @override
  JSValue run(JSObject env) {
    final v = expr?.run(env) ?? JSValue.UNDEFINED;
    env.set('return', v);
    return v;
  }
}

final class BreakStatement extends Statement {
  @override
  String toString() => 'break;';

  @override
  JSValue run(JSObject env) {
    env.set('break', JSValue.TRUE);
    return JSValue.UNDEFINED;
  }
}

final class AssignStatement extends Statement {
  const AssignStatement(this.target, this.expr);

  final Target target;
  final Expr expr;

  @override
  String toString() => '$target = $expr;';

  @override
  JSValue run(JSObject env) {
    target.set(env, expr.run(env));
    return JSValue.UNDEFINED;
  }
}

final class ExprStatement extends Statement {
  const ExprStatement(this.expr);

  final Expr expr;

  @override
  String toString() => '$expr;';

  @override
  JSValue run(JSObject env) {
    return expr.run(env);
  }
}

/**
 * An [Expr] which qualifies as the left hand side of an assignment.
 */
abstract class Target {
  void set(JSObject env, JSValue value);
}

/**
 * An expression.
 */
sealed class Expr {
  const Expr();

  JSValue run(JSObject env);
}

final class LitExpr extends Expr {
  const LitExpr(this.value);

  final JSValue value;

  @override
  String toString() => value.toString();

  @override
  JSValue run(JSObject env) {
    return value;
  }
}

final class NameExpr extends Expr implements Target {
  const NameExpr(this.name);

  final String name;

  @override
  String toString() => name;

  @override
  JSValue run(JSObject env) {
    final value = env.get(name);
    if (value == null) return env.throwing('unbound name $name');
    return value;
  }

  @override
  void set(JSObject env, JSValue value) {
    if (env.isThrowing) return;
    for (;;) {
      if (env.values.containsKey(name)) {
        env.values[name] = value;
        break;
      }
      final outer = env.values['__proto__'];
      if (outer is! JSObject) {
        env.throwing('unknown name $name');
        break;
      }
      env = outer;
    }
  }
}

final class EqualExpr extends Expr {
  const EqualExpr(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  String toString() => '$left === $right';

  @override
  JSValue run(JSObject env) {
    return JSBoolean(left.run(env) == right.run(env));
  }
}

final class LessExpr extends Expr {
  const LessExpr(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  String toString() => '$left < $right';

  @override
  JSValue run(JSObject env) {
    return JSBoolean(left.run(env).numValue() < right.run(env).numValue());
  }
}

final class AddExpr extends Expr {
  const AddExpr(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  String toString() => '$left + $right';

  @override
  JSValue run(JSObject env) {
    final l = left.run(env);
    final r = right.run(env);
    if (l is JSString || r is JSString) {
      return JSString(l.stringValue() + r.stringValue());
    }
    return JSNumber(l.numValue() + r.numValue());
  }
}

final class MulExpr extends Expr {
  const MulExpr(this.left, this.right);

  final Expr left;
  final Expr right;

  @override
  String toString() => '$left * $right';

  @override
  JSValue run(JSObject env) {
    return JSNumber(left.run(env).numValue() * right.run(env).numValue());
  }
}

final class PosExpr extends Expr {
  const PosExpr(this.expr);

  final Expr expr;

  @override
  String toString() => '+$expr';

  @override
  JSValue run(JSObject env) {
    final v = expr.run(env);
    return v is JSNumber ? v : JSNumber(v.numValue());
  }
}

final class NegExpr extends Expr {
  const NegExpr(this.expr);

  final Expr expr;

  @override
  String toString() => '-$expr';

  @override
  JSValue run(JSObject env) {
    return JSNumber(-expr.run(env).numValue());
  }
}

final class NotExpr extends Expr {
  const NotExpr(this.expr);

  final Expr expr;

  @override
  String toString() => '!$expr';

  @override
  JSValue run(JSObject env) {
    return JSBoolean(!expr.run(env).boolValue());
  }
}

final class RefExpr extends Expr implements Target {
  const RefExpr(this.expr, this.index);

  final Expr expr;
  final Expr index;

  @override
  String toString() {
    final i = index;
    if (i is LitExpr && i.value is JSString) {
      return '$expr.${i.value.stringValue()}';
    }
    return '$expr[$index]';
  }

  @override
  JSValue run(JSObject env) {
    final name = index.run(env);
    final object = expr.run(env);
    if (env.isThrowing) return JSValue.UNDEFINED;
    final value = object.get(name.stringValue());
    if (value == null) {
      return env.throwing('unbound property $name of $object');
    }
    return value;
  }

  @override
  void set(JSObject env, JSValue value) {
    var object = expr.run(env);
    var name = index.run(env);
    if (env.isThrowing) return;
    object.set(name.stringValue(), value);
  }
}

final class ArrayExpr extends Expr {
  const ArrayExpr(this.args);

  final List<Expr> args;

  @override
  String toString() => "[${args.join(",")}]";

  @override
  JSValue run(JSObject env) {
    return JSArray(args.map((a) => a.run(env)).toList());
  }
}

final class ObjectExpr extends Expr {
  const ObjectExpr(this.args);

  final List<Expr> args;

  @override
  String toString() =>
      "{${Iterable.generate(args.length ~/ 2, (i) => '${args[i * 2]}: ${args[i * 2 + 1]}').join(",")}}";

  @override
  JSValue run(JSObject env) {
    var object = JSObject({});
    for (var i = 0; i < args.length; i += 2) {
      final name = args[i].run(env);
      final value = args[i + 1].run(env);
      if (env.isThrowing) break;
      object.set(name.stringValue(), value);
    }
    return object;
  }
}

final class InvocationExpr extends Expr {
  const InvocationExpr(this.expr, this.args);

  final Expr expr;
  final List<Expr> args;

  @override
  String toString() => "$expr(${args.join(",")})";

  @override
  JSValue run(JSObject env) {
    JSValue receiver, function;
    if (expr is RefExpr) {
      final refExpr = expr as RefExpr;
      receiver = refExpr.expr.run(env);
      final name = refExpr.index.run(env);
      final val = receiver.get(name.stringValue());
      if (val == null || val is JSUndefined) {
        return env.throwing('unknown method ${refExpr.index} for $receiver');
      }
      function = val;
    } else {
      receiver = env.get('global') ?? JSValue.UNDEFINED;
      function = expr.run(env);
    }
    if (env.isThrowing) return JSValue.UNDEFINED;
    if (function is JSFunction) {
      final arguments = JSArray(args.map((a) => a.run(env)).toList());
      if (env.isThrowing) return JSValue.UNDEFINED;
      return function.call(receiver, arguments, env);
    }
    return env.throwing('receiver $function is not a function');
  }
}

final class FunctionExpr extends Expr {
  const FunctionExpr(this.name, this.params, this.block);

  final String? name;
  final List<String> params;
  final Block block;

  @override
  String toString() => "function ${name ?? ''}(${params.join(",")}) { $block }";

  @override
  JSValue run(JSObject env) {
    return JSFunction(name, params.length, (JSValue receiver, JSArray arguments, JSObject callerEnv) {
      var funcEnv = JSObject({
        '__proto__': env,
        'this': receiver,
        'arguments': arguments,
      });
      for (var i = 0; i < params.length; i++) {
        funcEnv.set(params[i], arguments.at(i));
      }
      final v = block.run(funcEnv);
      if (funcEnv.isThrowing) {
        callerEnv.set('throw', funcEnv.get('throw')!);
      }
      return v;
    });
  }
}
