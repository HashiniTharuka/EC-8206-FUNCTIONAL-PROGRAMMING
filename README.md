# EC 8206 – Functional Programming Project

**A Type-Safe Arithmetic Expression Interpreter in Haskell**

> University of Ruhuna · Department of Electrical and Information Engineering  
> Module: EC 8206 – Functional Programming  
> Assessment: Individual Project (20% of module marks)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Installation & Setup](#installation--setup)
5. [Project Structure](#project-structure)
6. [How to Build](#how-to-build)
7. [How to Run](#how-to-run)
8. [Module API Reference](#module-api-reference)
9. [Sample Output](#sample-output)
10. [Running with Cabal](#running-with-cabal)
11. [Troubleshooting](#troubleshooting)
12. [Academic Integrity](#academic-integrity)

---

## Project Overview

This project implements a **small, type-safe arithmetic expression interpreter** in Haskell, covering:

- An **algebraic data type** (`Expr`) for arithmetic expressions with `Let` bindings and `If`/boolean sub-expressions (`BExpr`)
- An **evaluator** (`eval`) that propagates errors cleanly through `Either String Double` — no runtime exceptions
- A **simplifier** (`simplify`) with algebraic identity rewrites and constant folding
- **Higher-order functions**: `map`, `filter` (`Data.Either.rights`), `foldr`, and curried partial application
- Supplementary utilities: **pretty-printer**, **free-variable analysis**, **expression depth**, and **capture-avoiding substitution**

---

## Features

| Part | What is implemented |
|------|-------------------|
| **Part A** | `Expr` ADT with 8 constructors; `BExpr` boolean sub-language; `type Env = [(String, Double)]` |
| **Part B** | `eval :: Env -> Expr -> Either String Double` — handles division-by-zero and undefined variables without crashing |
| **Part C** | `simplify` (8 identities + constant folding), `evalBatch` (map + rights), `batchSummary` (foldr), curried partial application |
| **Supplementary** | `pretty`, `freeVars`, `depth`, `substitute` |

---

## Prerequisites

| Tool | Minimum version | Notes |
|------|----------------|-------|
| [GHC](https://www.haskell.org/ghc/) | 9.4 or later | Tested on **GHC 9.10.3** |
| [Cabal](https://www.haskell.org/cabal/) | 3.6 or later | Tested on **cabal-install 3.16.1.0** |

> **No external packages are required.** The project depends only on `base` (the standard Haskell library).

### Installing GHC and Cabal

The easiest way on any platform is to use [GHCup](https://www.haskell.org/ghcup/):

**Linux / macOS:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
```

**Windows (PowerShell — run as Administrator):**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Invoke-WebRequest https://www.haskell.org/ghcup/sh/bootstrap-haskell.ps1 -UseBasicParsing))) -ArgumentList $true
```

After installation, confirm both tools are available:
```bash
ghc --version   # should print: The Glorious Glasgow Haskell Compilation System, version X.Y.Z
cabal --version # should print: cabal-install version X.Y.Z
```

---

## Installation & Setup

1. **Clone or unzip** the project into a folder of your choice.

2. **Verify the source files are present:**
   ```
   EC8206_FunctionalProgramming/
   ├── EC8206.cabal
   ├── src/
   │   ├── Expr.hs      ← interpreter library
   │   └── Main.hs      ← demo / test driver
   └── report/
       └── report.md
   ```

3. *(Optional)* **Update the Cabal package index** (needed the first time):
   ```bash
   cabal update
   ```

No further installation steps are needed — there are no third-party dependencies.

---

## Project Structure

```
EC8206_FunctionalProgramming/
│
├── EC8206.cabal          # Cabal build configuration
├── expr-demo.exe         # Pre-built Windows executable (if present)
│
├── src/
│   ├── Expr.hs           # Core library module (Expr, BExpr, eval, simplify, …)
│   └── Main.hs           # Demo driver: runs all test cases and feature demos
│
└── report/
    ├── report.md         # Written report (Parts D & E, sample evaluations)
    └── report.docx       # Same report in Word format for submission
```

### Key source files

| File | Role |
|------|------|
| [`src/Expr.hs`](src/Expr.hs) | **All interpreter logic.** Defines `Expr`, `BExpr`, `Env`, `eval`, `evalB`, `simplify`, `pretty`, `freeVars`, `depth`, `substitute`, `evalBatch`, `batchSummary`. |
| [`src/Main.hs`](src/Main.hs) | **Demo / test driver.** Imports `Expr` and runs labelled test cases, simplify demos, batch evaluation, and supplementary function demos. |

---

## How to Build

### Option 1 — Direct GHC (recommended for simplicity)

From inside the project root directory:

```bash
ghc -Wall -isrc -o expr-demo src/Main.hs src/Expr.hs
```

| Flag | Purpose |
|------|---------|
| `-Wall` | Enable all warnings — the project produces **zero warnings** |
| `-isrc` | Add `src/` to the module search path so `import Expr` resolves correctly |
| `-o expr-demo` | Name the output executable `expr-demo` |

### Option 2 — Cabal build

```bash
cabal build
```

The compiled binary will be placed under `dist-newstyle/`. Use `cabal run` (see below) to avoid finding it manually.

---

## How to Run

### After direct GHC build

**Linux / macOS:**
```bash
./expr-demo
```

**Windows (PowerShell):**
```powershell
.\expr-demo.exe
```

### Without compiling (interpreted mode)

```bash
runghc -isrc src/Main.hs
```

> `-isrc` is required so GHC can find `Expr.hs` when running `Main.hs` directly.

### Via Cabal

```bash
cabal run expr-demo
```

---

## Module API Reference

All public functions are exported from `Expr` and documented with Haddock comments in [`src/Expr.hs`](src/Expr.hs).

### Types

```haskell
data Expr
  = Lit Double          -- numeric literal
  | Var String          -- variable reference
  | Add Expr Expr       -- addition
  | Sub Expr Expr       -- subtraction
  | Mul Expr Expr       -- multiplication
  | Div Expr Expr       -- division (returns Left on divide-by-zero)
  | Let String Expr Expr  -- local binding:  let x = rhs in body
  | If  BExpr Expr Expr   -- conditional:   if cond then t else e

data BExpr
  = BLit Bool           -- boolean literal
  | Eq  Expr Expr       -- equality (==)
  | Lt  Expr Expr       -- less-than (<)
  | Gt  Expr Expr       -- greater-than (>)
  | Not BExpr           -- logical not
  | And BExpr BExpr     -- logical and
  | Or  BExpr BExpr     -- logical or

type Env = [(String, Double)]   -- variable environment
```

### Core functions

```haskell
-- Evaluate an expression. Returns Left with an error message on failure.
eval  :: Env -> Expr  -> Either String Double

-- Evaluate a boolean expression.
evalB :: Env -> BExpr -> Either String Bool

-- Simplify using algebraic identities and constant folding.
-- Returns a new Expr; the original is never modified.
simplify  :: Expr  -> Expr
simplifyB :: BExpr -> BExpr
```

### Pretty-printing

```haskell
-- Render as an infix string with minimal parentheses.
pretty  :: Expr  -> String
prettyB :: BExpr -> String
```

### Structural analysis

```haskell
-- Free (unbound) variable names, respecting Let scope.
freeVars  :: Expr  -> [String]
freeVarsB :: BExpr -> [String]

-- Maximum nesting depth (atoms = 0, each operator = +1).
depth  :: Expr  -> Int
depthB :: BExpr -> Int
```

### Substitution

```haskell
-- Replace every free occurrence of a variable with an expression.
-- Stops substituting inside a Let body that re-binds the same name.
substitute  :: String -> Expr -> Expr  -> Expr
substituteB :: String -> Expr -> BExpr -> BExpr
```

### Batch operations

```haskell
-- Map eval over a list, collecting all Either results.
evalAll :: Env -> [Expr] -> [Either String Double]

-- Return only the successful Double results.
evalBatch :: Env -> [Expr] -> [Double]

-- Count (successes, failures) using a single foldr pass.
batchSummary :: Env -> [Expr] -> (Int, Int)
```

---

## Sample Output

Running `.\expr-demo.exe` (or `./expr-demo`) prints:

```
=== Part B: eval - expected vs actual (with pretty-printed expr) ===
PASS  1) literal
    pretty     : 42.0
    env        : []
    expected   : Right 42.0
    actual     : Right 42.0
PASS  4) division by zero -> Left
    pretty     : 5.0 / (y - y)
    env        : [("y",3.0)]
    expected   : Left "Division by zero"
    actual     : Left "Division by zero"
PASS  5) undefined variable -> Left
    pretty     : z + 1.0
    env        : []
    expected   : Left "Undefined variable: z"
    actual     : Left "Undefined variable: z"
... (9/9 cases pass)

=== Part C: simplify (algebraic identities + constant folding) ===
  x + 0
    before : x + 0.0
    after  : x
  3 + 4  (constant fold)
    before : 3.0 + 4.0
    after  : 7.0
  2 * (5 - 5) (fold+zero)
    before : 2.0 * (5.0 - 5.0)
    after  : 0.0

=== Part C: batch evaluation (curried map) + summary (foldr) ===
  individual results    : [Right 15.0,Left "Division by zero",Left "Undefined variable: z",Right 100.0]
  evalBatch (successes) : [15.0,100.0]
  batchSummary          : 2 succeeded, 2 failed

=== Supplementary: pretty-printer (infix, minimal parens) ===
  (x+3)*2  ==>  (x + 3.0) * 2.0
  a - (b - c)  ==>  a - (b - c)

=== Supplementary: free variable analysis ===
  freeVars (let x=1 in x+y)  ==>  ["y"]

=== Supplementary: capture-avoiding substitution ===
  x |-> 5  in  let x=1 in x  (shadowed, body unchanged)
    result : let x = 1.0 in x
```

---

## Running with Cabal

If you prefer the Cabal workflow:

```bash
# First time only — update the package index
cabal update

# Build the project
cabal build

# Build and run in one step
cabal run expr-demo

# Clean all build artefacts
cabal clean
```

> **Note:** `cabal run` may print a build-progress line before the program output. This is normal.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `ghc: command not found` | GHC is not on your `PATH`. Install via [GHCup](https://www.haskell.org/ghcup/) and restart your terminal. |
| `Could not find module 'Expr'` | You forgot the `-isrc` flag. Run: `ghc -Wall -isrc -o expr-demo src/Main.hs src/Expr.hs` |
| `src/Main.hs: commitBuffer: invalid argument` | Your terminal uses a non-UTF-8 code page (common on Windows). Run: `chcp 65001` in PowerShell before executing the binary, or use Windows Terminal. |
| `cabal: The program 'ghc' is required but it could not be found` | GHC is not installed or not on `PATH`. Install via GHCup (see [Prerequisites](#prerequisites)). |
| Compilation warnings about incomplete patterns | Should not occur — the project is designed to compile with zero `-Wall` warnings. If you see any, ensure you are using the unmodified source files. |

---

## Academic Integrity

This is an individual assignment submitted for EC 8206 – Functional Programming,
University of Ruhuna. All code was written by the student named in the report.

Any external references consulted are cited in `report/report.md`. Unattributed
use of AI-generated or third-party code constitutes academic misconduct under
university policy.
