A JavaScript Interpreter written in
Dart That Can Evaluate Itself by Evaluating Itself
=============================

In 2013 I took an even older JavaScript interpreter of mine, written in a subset of JavaScript that is able to interpret itself, and ported its ~500 lines of codes to Dart. In 2021 I rediscovered that project and ported it to sound null-safe Dart 2.13, slightly changing the way AST nodes are represented.

The result is a somewhat hackish proof of concept of nearly 3x the size of the original. I originally wrote this code to learn Dart, I think. I also found an article `jsi-in-dart.mdown` (in German) where I reported (mainly to myself) what I needed to change or extend.

Should you write an interpreter the way I did? Probably not.

I still like how compact and tiny `jsi.js` is. The AST is JSON-serializable and I originally used this feature to bootstrap a JSI-AST-Interpreter in Objective-C and in Java to have an embeddable cross-platform JavaScript interpreter for mobile devices. In its current form it is and was mainly a proof of concept and not a production ready library. (We continued with a Lisp-like language that had a simpler runtime with with less edge cases than JavaScript.)
