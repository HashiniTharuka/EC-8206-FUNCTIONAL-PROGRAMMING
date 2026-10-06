---
title: "EC 8206 – Functional Programming: Project Assignment"
subtitle: "A Type-Safe Arithmetic Expression Interpreter in Haskell"
author: "Fernando H.T."
date: "2026-07-20"
---

## How to Run

Requires GHC (tested on GHC 9.10.3). Two files: `src/Expr.hs` (the
interpreter library) and `src/Main.hs` (a demo/test driver).

```
ghc -Wall -isrc -o expr-demo src/Main.hs src/Expr.hs
./expr-demo
```

or, without compiling first:

```
runghc -isrc src/Main.hs
```

`Main.hs` runs 9 labelled evaluation cases (each printing the
pretty-printed infix form and the `Either` result), 8 `simplify` demos
(including constant folding), a batch-evaluation demo, and supplementary
demos for `pretty`, `freeVars`, `depth`, and `substitute`. The project
compiles cleanly under `-Wall` with zero incomplete-pattern warnings,
confirming `eval` and `simplify` cover every constructor of `Expr` and `BExpr`.

## Additional Capabilities (Supplementary)

Beyond the rubric requirements, `src/Expr.hs` provides four supplementary
utilities that demonstrate further Haskell idioms:

| Function | Signature | Purpose |
|---|---|---|
| `pretty` | `Expr -> String` | Infix renderer; inserts parens only where precedence or left-associativity requires them |
| `freeVars` | `Expr -> [String]` | Collects free variable names using `nub` and list-difference `(\\)`, respecting `Let` scope |
| `depth` | `Expr -> Int` | Maximum nesting depth of the expression tree; atoms have depth 0 |
| `substitute` | `String -> Expr -> Expr -> Expr` | Capture-avoiding substitution; stops at `Let` boundaries where the target variable is shadowed |

`simplify` was also extended with **constant folding**: when both operands
of an arithmetic operator are `Lit` values the result is computed
immediately (e.g. `simplify (Add (Lit 3) (Lit 4))` → `Lit 7.0`), so a
single bottom-up pass can collapse entire constant sub-trees.

## Sample Evaluations (Expected vs Actual)

All nine cases below are taken verbatim from a real run of `./expr-demo`
(source in `src/Main.hs`); every one reports `PASS`.

| # | Pretty form | Env | Expected | Actual |
|---|---|---|---|---|
| 1 | `42.0` | `[]` | `Right 42.0` | `Right 42.0` |
| 2 | `x` | `[x=10]` | `Right 10.0` | `Right 10.0` |
| 3 | `(x + 3.0) * 2.0` | `[x=4]` | `Right 14.0` | `Right 14.0` |
| 4 | `5.0 / (y - y)` | `[y=3]` | `Left "Division by zero"` | `Left "Division by zero"` |
| 5 | `z + 1.0` | `[]` | `Left "Undefined variable: z"` | `Left "Undefined variable: z"` |
| 6 | `let x = 5.0 in x * x` | `[]` | `Right 25.0` | `Right 25.0` |
| 7 | `let x = 1.0 in let x = 2.0 in x + 1.0` | `[]` | `Right 3.0` | `Right 3.0` |
| 8 | `if x > 0.0 then x else 0.0 - x` | `[x=-7]` | `Right 7.0` | `Right 7.0` |
| 9 | `if missing > 0.0 then 1.0 else 2.0` | `[]` | `Left "Undefined variable: missing"` | `Left "Undefined variable: missing"` |

Case 9 shows error propagation *through* the condition of an `If`: the
error surfaces from `evalB`, is threaded up by `eval`'s `do`-block, and
never reaches the branches.

`simplify` (bottom-up rewriting with constant folding) turns `x + 0`,
`0 + x`, `x * 1` and `(x + 0) * 1` all into `Var "x"`; `x * 0` into
`Lit 0.0`; `if True then x else y` into `Var "x"`; `3.0 + 4.0` into
`Lit 7.0`; and `2.0 * (5.0 - 5.0)` into `Lit 0.0` — eight identities
against a rubric minimum of three. For the batch demo, `env = [x=10, y=0]`
and batch `[x+5, 1/y, z, x*x]` give individual results `[Right 15.0, Left
"Division by zero", Left "Undefined variable: z", Right 100.0]`;
`evalBatch` (via `Data.Either.rights . map (eval env)`) keeps only
`[15.0, 100.0]`, and `batchSummary` (via `foldr`) reports `2 succeeded,
2 failed`.

## Part D — Comparative Analysis: Functional vs. Imperative `eval`

The same evaluator, written imperatively in Python, using mutable
exception state instead of an algebraic result type:

```python
def eval_expr(env, expr):
    kind = expr[0]
    if kind == "lit":
        return expr[1]
    if kind == "var":
        if expr[1] not in env:
            raise KeyError(f"Undefined variable: {expr[1]}")
        return env[expr[1]]
    if kind == "let":
        new_env = dict(env)          # mutate a *copy*
        new_env[expr[1]] = eval_expr(env, expr[2])
        return eval_expr(new_env, expr[3])
    l, r = eval_expr(env, expr[1]), eval_expr(env, expr[2])
    if kind == "add": return l + r
    if kind == "sub": return l - r
    if kind == "mul": return l * r
    if kind == "div":
        if r == 0:
            raise ZeroDivisionError("Division by zero")
        return l / r
```

**Error representation and propagation.** Haskell encodes failure in the
*type* — `Either String Double` — so a division by zero or an undefined
variable is an ordinary value flowing through `<$>`, `<*>`, and
`do`-notation exactly like a success value. The signature `eval :: Env
-> Expr -> Either String Double` itself documents that failure is
possible; GHC forces every call site to pattern-match `Left`/`Right`
before touching the number. Python instead relies on *exceptions*:
`eval_expr`'s signature gives no hint that it can fail,
`KeyError`/`ZeroDivisionError` unwind the call stack invisibly, and a
caller that forgets a `try/except` crashes the whole program at run
time rather than being caught at compile time. Errors are "out of band"
in Python and "in band" in Haskell.

**Mutable state.** The Python `add`/`sub`/`mul`/`div` cases have no
mutation, but `let`-style scoping needs one: `new_env[name] = ...`
mutates a dictionary — exactly the aliasing bug class (forgetting to
copy `env`, mutating a scope an outer closure still references) that a
large share of interpreter bugs comes from. The Haskell `Let` case
(`eval ((x, v) : env) body`) never mutates `env`; it conses onto a *new*
list, leaving the caller's original environment and every other
in-flight evaluation untouched. Immutability here removes a whole class
of "who changed the environment under me" bugs by construction.

**Bugs the type checker rules out before the program runs.** Because
`Expr` is a closed algebraic data type, GHC's exhaustiveness checker
(this project compiles warning-free under `-Wall`) statically
guarantees `eval` and `simplify` handle every constructor. Python's
`kind`-string dispatch has no such guarantee: a typo like `"dvi"`, or a
forgotten branch for a new node kind, fails silently or with a generic
runtime error, uncaught until that path executes. Likewise, `eval`'s
signature makes the *possibility* of failure part of the type, so using
a bare `Double` where an `Either String Double` was returned is a
compile error in Haskell, not a runtime surprise as it would be in
Python.

## Part E — Reflection: Purity, Immutability, and Impossible States

**Pure functions.** `eval` and `simplify` are pure in the strict sense:
given the same `Env`/`Expr` arguments they always return the same
result, performing no I/O, no mutation, and no hidden reads of external
state. `eval`'s only inputs are its two arguments and its only output is
its `Either` return value. This is what makes the sample-evaluation
table earlier trustworthy as documentation: `eval [("x",4)] (Mul (Add
(Var "x") (Lit 3)) (Lit 2))` will produce `Right 14.0` today, tomorrow,
and from a concurrent caller, because there is no shared state for a
second call to disturb. It is also what makes `simplify` safe to call
bottom-up on subtrees (`simplify (Add l r) = addId (simplify l)
(simplify r)`): each recursive call is independent, so evaluation order
cannot change the result — a property that would need proof, not
assumption, if "simplify the left subtree" could mutate something the
right subtree also reads.

**Immutability.** Nowhere in `Expr.hs` is an existing value changed in
place. `Let` (`eval env (Let x rhs body) = eval ((x, v) : env) body`)
*extends* the environment by consing a new binding onto the existing
list — the caller's original `env` is untouched and can still be used
afterwards, e.g. to evaluate a sibling expression under the old
bindings. `simplify` does not edit an `Expr` in place either; it builds
a brand-new tree, so `simplify e` and `e` coexist as independent values
(why `Main.hs` can print both the original and simplified form of the
same `e`). Because nothing is mutated, a value produced by this
interpreter is valid for its whole lifetime — the guarantee
`batchSummary`'s single `foldr` pass over `evalAll env exprs` relies on:
no earlier `Either` result can be invalidated while a later one is
computed.

**`Expr`'s shape makes invalid expressions impossible (or catches them
early).** `Expr` is a sum type with eight constructors, each carrying
exactly the fields that make sense for that case: `Lit` carries a
`Double` and nothing else, `Div` carries exactly two sub-expressions,
and — crucially — `If`'s first field has type `BExpr`, not `Expr`. That
choice is enforced entirely by the type checker: `If (Lit 1) t e` cannot
be constructed, because `Lit 1 :: Expr` and `If` demands a `BExpr` in
that position — the compiler rejects the program before it ever runs,
rather than `eval` discovering at run time that the "condition" isn't
boolean. Compare the stringly-typed Python sketch in Part D, where every
node is just a tagged tuple: `("if", 5, t, e)` type-checks fine and only
fails, if at all, deep inside `eval_expr` with a confusing `TypeError`.
The remaining failures that the type system genuinely cannot rule out —
dividing by an expression that *evaluates* to zero, or looking up a
variable never bound — are exactly the two cases Part B asks `eval` to
handle, and both are caught at the earliest point a *value-dependent*
check can be caught: evaluation time, reported through `Left`, never as
an exception unwinding the stack. Static types and `Either` together
form one continuous line of defence — invalid *shapes* rejected at
compile time, invalid *values* rejected at evaluation time, neither ever
a crash.
