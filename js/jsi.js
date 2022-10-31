// jsi is a JS interpreter for the good parts of JS, written in JS, which is able to run itself

// whitespace		\s+
// line comment		\/\/.*$
// block comment	\/\*[\s\S]*\*\/
// number			\d+(\.\d*)?([eE][-+]?\d+)?
// name				\w+
// string			'(\\.|[^'])*' | "(\\.|[^"])*"
// regular expr.	\/(\\.|[^\/])+\/g?m?i?
// operators		[!=]== | [<>]=? | && | \|\ | [-+*\/%!=]
// syntax			[()\[\]{},;.:]
var RE = /\s+|\/\/.*$|(\d+(?:\.\d*)?(?:[eE][-+]?\d+)?|\w+|'(?:\\.|[^'])*'|"(?:\\.|[^"])*"|\/(?:\\.|[^\/])+\/g?m?i?|[!=]==|[<>]=?|[()\[\]{},;.:=+\-!])|(.)/gm;

var source;
var current;
var index;

// initialize the parser with the given source string to produce a token stream
function initialize(s) {
	source = s;
	current = next();
}

// returns the next token from the token stream
function next() {
	var match = RE.exec(source);
	if (match) {
		if (match[2]) {
			throw 'invalid character ' + match[2];
		}
		if (match[1]) {
			index = match.index;
			return match[1];
		}
		return next();
	}
	return null;
}

// if the current token is the given one, consume it and return true; otherwise consume nothing and return false
function at(token) {
	if (current === null) {
		throw 'unexpected end of stream';
	}
	if (current === token) {
		current = next();
		return true;
	}
}

// returns the current token and consume it
function consume() {
	var value = current;
	current = next();
	return value;
}

// throws an error if the current token (which is otherwise consumed) is not the given one
function expect(token) {
	if (!at(token)) {
		throw 'expected ' + token + ' but found ' + current + atLine();
	}
}

// returns the line number of the current token
function atLine() {
	return ' at ' + (source.slice(0, index).replace(/[^\n]/g, '').length + 1);
}

// ------------parser------------------------------------------------------------------

// parses the given source string and returns an AST representation of the source
function parse(s) {
	var stmts = [];
	initialize(s);
	while (current) {
		stmts.push(parseStatement());
	}
	return {type: 'block', stmts: stmts};
}

function parseStatement() {
	if (at('var')) {
		var name = parseName();
		var expr = null;
		if (at("=")) {
			expr = parseExpression();
		}
		expect(';');
		return {type: 'var', name: name, expr: expr};
	}
	if (at('function')) {
		var func = parseFunction();
		return {type: 'var', name: func.name, expr: func};
	}
	if (at('if')) {
		return parseIf();
	}
	if (at('while')) {
		expect('(');
		var cond = parseExpression();
		expect(')');
		return {type: 'while', cond: cond, body: parseBlock()};
	}
	if (at('break')) {
		expect(';');
		return {type: 'break'};
	}
	if (at('throw')) {
		var expr = parseExpression();
		expect(';');
		return {type: 'throw', expr: expr};
	}
	if (at('return')) {
		var expr = null;
		if (!at(';')) {
			expr = parseExpression();
			expect(';');
		}
		return {type: 'return', expr: expr};
	}
	var expr = parseExpression();
	var stmt;
	if (at('=')) {
		stmt = {type: 'set', target: expr, expr: parseExpression()};
	} else {
		stmt = {type: 'stmt', expr: expr};
	}
	expect(';');
	return stmt;
}

function parseIf() {
	expect('(');
	var cond = parseExpression();
	expect(')');
	var thenBody = parseBlock();
	var elseBody = null;
	if (at('else')) {
		if (at('if')) {
			elseBody = {type: 'block', stmts: [parseIf()]};
		} else {
			elseBody = parseBlock();
		}
	}
	return {type: 'if', cond: cond, thenBody: thenBody, elseBody: elseBody};
}

function parseBlock() {
	var stmts = [];
	expect('{');
	while (!at('}')) {
		stmts.push(parseStatement());
	}
	return {type: 'block', stmts: stmts};
}

function parseExpression() {
	var expr = parseComparison();
	if (at('===')) {
		expr = {type: 'eq', left: expr, right: parseComparison()};
	}
	return expr;
}

function parseComparison() {
	var expr = parseTerm();
	if (at('<')) {
		expr = {type: 'lt', left: expr, right: parseTerm()};
	}
	return expr;
}

function parseTerm() {
	var expr = parseFactor();
	while (at('+')) {
		expr = {type: 'add', left: expr, right: parseFactor()};
	}
	return expr;
}

function parseFactor() {
	var expr = parseUnary();
	while (at('*')) {
		expr = {type: 'mul', left: expr, right: parseUnary()};
	}
	return expr;
}

function parseUnary() {
	if (at('-')) {
		return {type: 'neg', expr: parseUnary()};
	}
	if (at('!')) {
		return {type: 'not', expr: parseUnary()};
	}
	var expr = parsePrimary();
	while (true) {
		if (at('.')) {
			expr = {type: 'ref', expr: expr, index: {type: 'lit', value: parseName()}};
		} else if (at('[')) {
			expr = {type: 'ref', expr: expr, index: parseExpression()};
			expect(']');
		} else if (at('(')) {
			var args = [];
			if (!at(')')) {
				args.push(parseExpression());
				while (at(',')) {
					args.push(parseExpression());
				}
				expect(')');
			}
			expr = {type: 'inv', expr: expr, args: args};
		} else {
			break;
		}
		
	}
	return expr;
}

function parsePrimary() {
	if (at('(')) {
		var expr = parseExpression();
		expect(')');
		return expr;
	}
	if (at('true')) {
		return {type: 'lit', value: true};
	}
	if (at('false')) {
		return {type: 'lit', value: false};
	}
	if (at('null')) {
		return {type: 'lit', value: null};
	}
	if (at('function')) {
		return parseFunction();
	}
	if (/^['"]/.test(current)) {
		return {type: 'lit', value: consume().slice(1, -1)};
	}
	if (/^\//.test(current)) {
		var re = consume();
        var match = /\/(.*)\/(g?m?i?)/.exec(re);
		return {type: 'lit', value: RegExp(match[1], match[2])};
	}
	if (/^\d/.test(current)) {
		return {type: 'lit', value: parseFloat(consume())};
	}
	if (/^\w/.test(current)) {
		return {type: 'name', name: consume()};
	}
	if (at('[')) {
		var args = [];
		if (!at(']')) {
			args.push(parseExpression());
			while (at(',')) {
				args.push(parseExpression());
			}
			expect(']');
		}
		return {type: 'array', args: args};
	}
	if (at('{')) {
		var args = [];
		if (!at('}')) {
			var expr = parseExpression();
			if (expr.type === 'name') {
				expr = {type: 'lit', value: expr.name};
			}
			args.push(expr);
			expect(':');
			args.push(parseExpression());
			while (at(',')) {
				var expr = parseExpression();
				if (expr.type === 'name') {
					expr = {type: 'lit', value: expr.name};
				}
				args.push(expr);
				expect(':');
				args.push(parseExpression());
			}
			expect('}');
		}
		return {type: 'object', args: args};
	}
	throw 'unknown primary ' + current + atLine();
}

function parseFunction() {
	var name = null;
	var params = [];
	if (!at('(')) {
		name = parseName();
		expect('(');
	}
	if (!at(')')) {
		params.push(parseName());
		while (at(',')) {
			params.push(parseName());
		}
		expect(')');
	}
	return {type: 'function', name: name, params: params, body: parseBlock()};
}

function parseName() {
	if (/^\w/.test(current)) {
		return consume();
	}
	throw 'name expected ' + atLine();
}


var s = require('fs').readFileSync('js/jsi.js', 'utf-8');
console.log("begin parse");
var ast = parse(s);
console.log("end parse");

// ------------evaluator---------------------------------------------------------------

function run(ast, env) {
	return run_methods[ast.type](ast, env);
}

var run_methods = {
	"block": function (ast, env) {
		var i = 0;
		var l = ast.stmts.length;
		while (i < l) {
			var r = run(ast.stmts[i], env);
			if (env.returning) {
				return r;
			}
			if (env.breaking) {
				break;
			}
			i = i + 1;
		}
	},
	"var": function (ast, env) {
		if (ast.expr) {
			env[ast.name] = run(ast.expr, env);
		} else {
			env[ast.name] = undefined;
		}
	},
	"function": function (ast, env) {
		return function () {
			var env2 = Object.create(env);
			env2.this = this;
			env2.arguments = arguments;
			var i = 0;
			while (i < ast.params.length) {
				env2[ast.params[i]] = arguments[i];
				i = i + 1;
			}
			return run(ast.body, env2);
		};
	},
	"inv": function (ast, env) {
		var target;
		var func;
		if (ast.expr.type === 'ref') {
			target = run(ast.expr.expr, env);
			func = target[run(ast.expr.index, env)];
		} else {
			target = global;
			func = run(ast.expr, env);
		}
		var args = ast.args.map(function (arg) { return run(arg, env); });
        if (func === undefined) {
            throw "TypeError: not a function";
        }
		return func.apply(target, args);
	},
	"ref": function (ast, env) {
		var object = run(ast.expr, env);
		var index = run(ast.index, env);
		if (object === undefined) {
			throw "TypeError: undefined has no properties";
		}
		return object[index];
	},
	"name": function (ast, env) {
		return env[ast.name];
	},
	"lit": function (ast, env) {
		return ast.value;
	},
	"stmt": function (ast, env) {
		return run(ast.expr, env);
	},
	"set": function (ast, env) {
		return set(ast.target, env, run(ast.expr, env));
	},
	"if": function (ast, env) {
		if (run(ast.cond, env)) {
			return run(ast.thenBody, env);
		} else if (ast.elseBody) {
			return run(ast.elseBody, env);
		}
	},
	"return": function (ast, env) {
		env.returning = true;
		if (ast.expr) {
			return run(ast.expr, env);
		}
	},
	"array": function (ast, env) {
		return ast.args.map(function (arg) { return run(arg, env); });
	},
	"object": function (ast, env) {
		var object = {};
		var i = 0;
		while (i < ast.args.length) {
			object[run(ast.args[i], env)] = run(ast.args[i + 1], env);
			i = i + 2;
		}
		return object;
	},
	"while": function (ast, env) {
		while (run(ast.cond, env)) {
			var r = run(ast.body, env);
			if (env.returning) {
				return r;
			}
			if (env.breaking) {
				env.breaking = false;
				break;
			}
		}
	},
	"eq": function (ast, env) {
		var left = run(ast.left, env);
		var right = run(ast.right, env);
		return left === right;
	},
	"throw": function (ast, env) {
		throw run(ast.expr, env);
	},
	"add": function (ast, env) {
		var left = run(ast.left, env);
		var right = run(ast.right, env);
		return left + right;
	},
	"lt": function (ast, env) {
		var left = run(ast.left, env);
		var right = run(ast.right, env);
		return left < right;
	},
	"break": function (ast, env) {
		env.breaking = true;
	},
	"not": function (ast, env) {
		return !run(ast.expr, env);
	},
	"neg": function (ast, env) {
		return -run(ast.expr, env);
	}
};

function set(ast, env, value) {
	return set_methods[ast.type](ast, env, value);
}

var set_methods = {
	"name": function (ast, env, value) {
		while (env) {
			if (env.hasOwnProperty(ast.name)) {
				env[ast.name] = value;
				return value;
			}
			env = env.__proto__;
		}
		throw 'runtime exception, unknown name ' + ast.name;
	},
	"ref": function (ast, env, value) {
		run(ast.expr, env)[run(ast.index, env)] = value;
	}
	
};

console.log("begin");

run(ast, {
	require: require,
	console: console,
	RegExp: RegExp,
	parseFloat: parseFloat,
	Object: Object
});

console.log("end");

// global functions and methods used:
//
// console.log()
// RegExp(), RegExp.prototype.exec(), RegExp.prototype.test()*
// String.prototype.slice()*, String.prototype.replace()**
// Array.prototype.push(), Array.prototype.map()***
// parseFloat()
// Function.prototype.apply()
// Object.create(), Object.prototype.hasOwnProperty()
// global****
//    * could be expressed with RegExp.exec()
//    ** only for counting newlines
//    *** could be expressed by for loop
//    **** var global = this;