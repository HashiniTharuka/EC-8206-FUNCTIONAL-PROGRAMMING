-- | A small, type-safe arithmetic expression language with evaluation,
-- pretty-printing, simplification (with constant folding), free-variable
-- analysis, structural metrics, and capture-avoiding substitution.
--
-- EC 8206 Functional Programming — Project Assignment
-- Part A (language design), Part B (evaluation), Part C (higher-order
-- functions), plus supplementary utilities (pretty, freeVars, substitute,
-- depth).
module Expr
  ( Expr (..)
  , BExpr (..)
  , Env
    -- * Evaluation
  , eval
  , evalB
    -- * Pretty-printing
  , pretty
  , prettyB
    -- * Simplification (with constant folding)
  , simplify
  , simplifyB
    -- * Structural analysis
  , freeVars
  , freeVarsB
  , depth
  , depthB
    -- * Capture-avoiding substitution
  , substitute
  , substituteB
    -- * Batch operations
  , evalAll
  , evalBatch
  , batchSummary
  ) where

import Data.List   (nub, (\\))
import Data.Either (rights)

-- --------------------------------------------------------------------------
-- Part A: Language design
-- --------------------------------------------------------------------------

-- | Arithmetic expressions.
--
-- 'Let' and 'If' are the two constructors that give 'Expr' a genuine
-- second "shape": 'Let' introduces local, immutable bindings, and 'If'
-- branches on a small boolean sub-language ('BExpr') rather than on
-- 'Expr' itself.  Together they turn 'Expr' from "numbers glued together
-- by arithmetic" into a real sum type with structurally distinct cases
-- that 'eval' must handle differently.
data Expr
  = Lit Double
  | Var String
  | Add Expr Expr
  | Sub Expr Expr
  | Mul Expr Expr
  | Div Expr Expr
  | Let String Expr Expr
  | If  BExpr  Expr Expr
  deriving (Show, Eq)

-- | A minimal boolean sub-language used only to drive 'If'.
-- Comparisons take two arithmetic 'Expr's and produce a 'Bool'.
data BExpr
  = BLit Bool
  | Eq  Expr Expr
  | Lt  Expr Expr
  | Gt  Expr Expr
  | Not BExpr
  | And BExpr BExpr
  | Or  BExpr BExpr
  deriving (Show, Eq)

-- | Variable bindings: a simple association list from name to value.
type Env = [(String, Double)]

-- --------------------------------------------------------------------------
-- Part B: Evaluation
-- --------------------------------------------------------------------------

-- | Evaluate an expression under an environment.
--
-- Every failure is reported through 'Left' rather than a runtime exception:
-- division by zero and references to undefined variables are both ordinary
-- values of type @Either String Double@, not crashes.
eval :: Env -> Expr -> Either String Double
eval _   (Lit n)          = Right n
eval env (Var x)          =
  case lookup x env of
    Just v  -> Right v
    Nothing -> Left ("Undefined variable: " ++ x)
eval env (Add l r)        = (+)  <$> eval env l <*> eval env r
eval env (Sub l r)        = (-)  <$> eval env l <*> eval env r
eval env (Mul l r)        = (*)  <$> eval env l <*> eval env r
eval env (Div l r)        = do
  num <- eval env l
  den <- eval env r
  if den == 0 then Left "Division by zero" else Right (num / den)
eval env (Let x rhs body) = do
  v <- eval env rhs
  eval ((x, v) : env) body
eval env (If cond t e)    = do
  b <- evalB env cond
  if b then eval env t else eval env e

-- | Evaluate a boolean expression under an environment.  Delegates
-- arithmetic sub-expressions back to 'eval', so errors (division by zero,
-- undefined variable) inside a condition still propagate as 'Left'.
evalB :: Env -> BExpr -> Either String Bool
evalB _   (BLit b)   = Right b
evalB env (Eq  l r)  = (==) <$> eval  env l <*> eval  env r
evalB env (Lt  l r)  = (<)  <$> eval  env l <*> eval  env r
evalB env (Gt  l r)  = (>)  <$> eval  env l <*> eval  env r
evalB env (Not b)    = not  <$> evalB env b
evalB env (And l r)  = (&&) <$> evalB env l <*> evalB env r
evalB env (Or  l r)  = (||) <$> evalB env l <*> evalB env r

-- --------------------------------------------------------------------------
-- Pretty-printing (supplementary)
-- --------------------------------------------------------------------------

-- | Render an expression as a human-readable infix string, inserting
-- parentheses only where needed to preserve operator precedence and
-- left-associativity.
--
-- >>> pretty (Mul (Add (Var "x") (Lit 3)) (Lit 2))
-- "(x + 3.0) * 2.0"
-- >>> pretty (Sub (Lit 5) (Sub (Lit 2) (Lit 1)))
-- "5.0 - (2.0 - 1.0)"
pretty :: Expr -> String
pretty (Lit n)
  | n < 0     = "(" ++ show n ++ ")"
  | otherwise = show n
pretty (Var x)      = x
pretty (Add l r)    = prettyL 1 l ++ " + " ++ prettyL 1 r
pretty (Sub l r)    = prettyL 1 l ++ " - " ++ prettyR 1 r
pretty (Mul l r)    = prettyL 2 l ++ " * " ++ prettyL 2 r
pretty (Div l r)    = prettyL 2 l ++ " / " ++ prettyR 2 r
pretty (Let x e b)  = "let " ++ x ++ " = " ++ pretty e ++ " in " ++ pretty b
pretty (If  c t e)  = "if " ++ prettyB c
                   ++ " then " ++ pretty t
                   ++ " else " ++ pretty e

-- | Render a boolean expression as a human-readable string.
prettyB :: BExpr -> String
prettyB (BLit True)  = "true"
prettyB (BLit False) = "false"
prettyB (Eq  l r)    = pretty l ++ " == " ++ pretty r
prettyB (Lt  l r)    = pretty l ++ " < "  ++ pretty r
prettyB (Gt  l r)    = pretty l ++ " > "  ++ pretty r
prettyB (Not b)      = "not (" ++ prettyB b ++ ")"
prettyB (And l r)    = prettyB l ++ " && " ++ prettyB r
prettyB (Or  l r)    = prettyB l ++ " || " ++ prettyB r

-- Operator precedence: higher = tighter binding.
-- Let/If are at 0 so they are always wrapped when nested inside arithmetic.
exprPrec :: Expr -> Int
exprPrec (Let _ _ _) = 0
exprPrec (If  _ _ _) = 0
exprPrec (Add _ _)   = 1
exprPrec (Sub _ _)   = 1
exprPrec (Mul _ _)   = 2
exprPrec (Div _ _)   = 2
exprPrec _           = 3   -- Lit, Var: never need wrapping

paren :: String -> String
paren s = "(" ++ s ++ ")"

-- Left operand: wrap only if strictly lower precedence.
prettyL :: Int -> Expr -> String
prettyL p e = if exprPrec e < p then paren (pretty e) else pretty e

-- Right operand: wrap if lower-or-equal (enforces left-associativity for
-- operators like '-' and '/').
prettyR :: Int -> Expr -> String
prettyR p e = if exprPrec e <= p then paren (pretty e) else pretty e

-- --------------------------------------------------------------------------
-- Part C: Higher-order functions — simplification
-- --------------------------------------------------------------------------

-- | Rewrite an expression using algebraic identities *and* constant folding,
-- working bottom-up so that simplifying the children can expose further
-- rewrites at the parent.
--
-- Identities handled:
--   x + 0  ==>  x,   0 + x  ==>  x,   Lit a + Lit b  ==>  Lit (a+b)
--   x - 0  ==>  x,   x - x  ==>  0,   Lit a - Lit b  ==>  Lit (a-b)
--   x * 0  ==>  0,   0 * x  ==>  0,   x * 1  ==>  x,  1 * x  ==>  x
--   Lit a * Lit b  ==>  Lit (a*b)
--   x / 1  ==>  x,   Lit a / Lit b (b≠0)  ==>  Lit (a/b)
--   if True  then t else _  ==>  t
--   if False then _ else e  ==>  e
simplify :: Expr -> Expr
simplify (Add l r)        = addId (simplify l) (simplify r)
simplify (Sub l r)        = subId (simplify l) (simplify r)
simplify (Mul l r)        = mulId (simplify l) (simplify r)
simplify (Div l r)        = divId (simplify l) (simplify r)
simplify (Let x rhs body) = Let x (simplify rhs) (simplify body)
simplify (If cond t e)    = ifId  (simplifyB cond) (simplify t) (simplify e)
simplify e@(Lit _)        = e
simplify e@(Var _)        = e

-- | Simplify arithmetic sub-expressions inside a 'BExpr'.
simplifyB :: BExpr -> BExpr
simplifyB (Eq  l r)  = Eq  (simplify l) (simplify r)
simplifyB (Lt  l r)  = Lt  (simplify l) (simplify r)
simplifyB (Gt  l r)  = Gt  (simplify l) (simplify r)
simplifyB (Not b)    = Not (simplifyB b)
simplifyB (And l r)  = And (simplifyB l) (simplifyB r)
simplifyB (Or  l r)  = Or  (simplifyB l) (simplifyB r)
simplifyB b@(BLit _) = b

-- Helper rules (all called after children are already simplified):

addId :: Expr -> Expr -> Expr
addId (Lit a) (Lit b) = Lit (a + b)   -- constant folding
addId l       (Lit 0) = l             -- x + 0  -->  x
addId (Lit 0) r       = r             -- 0 + x  -->  x
addId l       r       = Add l r

subId :: Expr -> Expr -> Expr
subId (Lit a) (Lit b) = Lit (a - b)   -- constant folding
subId l       (Lit 0) = l             -- x - 0  -->  x
subId l       r
  | l == r            = Lit 0         -- x - x  -->  0
  | otherwise         = Sub l r

mulId :: Expr -> Expr -> Expr
mulId (Lit a) (Lit b) = Lit (a * b)   -- constant folding
mulId _       (Lit 0) = Lit 0         -- x * 0  -->  0
mulId (Lit 0) _       = Lit 0         -- 0 * x  -->  0
mulId l       (Lit 1) = l             -- x * 1  -->  x
mulId (Lit 1) r       = r             -- 1 * x  -->  x
mulId l       r       = Mul l r

divId :: Expr -> Expr -> Expr
divId (Lit a) (Lit b)
  | b /= 0            = Lit (a / b)   -- constant folding (guard: b≠0)
divId l       (Lit 1) = l             -- x / 1  -->  x
divId l       r       = Div l r

ifId :: BExpr -> Expr -> Expr -> Expr
ifId (BLit True)  t _ = t             -- if True  then t else e  -->  t
ifId (BLit False) _ e = e             -- if False then t else e  -->  e
ifId cond         t e = If cond t e

-- --------------------------------------------------------------------------
-- Structural analysis (supplementary)
-- --------------------------------------------------------------------------

-- | Collect all *free* variable names in an expression (no duplicates).
-- Variables bound by a 'Let' are not considered free inside that body.
--
-- >>> freeVars (Let "x" (Var "y") (Add (Var "x") (Var "z")))
-- ["y","z"]
freeVars :: Expr -> [String]
freeVars (Lit _)          = []
freeVars (Var x)          = [x]
freeVars (Add l r)        = nub (freeVars l ++ freeVars r)
freeVars (Sub l r)        = nub (freeVars l ++ freeVars r)
freeVars (Mul l r)        = nub (freeVars l ++ freeVars r)
freeVars (Div l r)        = nub (freeVars l ++ freeVars r)
freeVars (Let x rhs body) = nub (freeVars rhs ++ (freeVars body \\ [x]))
freeVars (If cond t e)    = nub (freeVarsB cond ++ freeVars t ++ freeVars e)

-- | Free variables inside a 'BExpr'.
freeVarsB :: BExpr -> [String]
freeVarsB (BLit _)   = []
freeVarsB (Eq  l r)  = nub (freeVars l ++ freeVars r)
freeVarsB (Lt  l r)  = nub (freeVars l ++ freeVars r)
freeVarsB (Gt  l r)  = nub (freeVars l ++ freeVars r)
freeVarsB (Not b)    = freeVarsB b
freeVarsB (And l r)  = nub (freeVarsB l ++ freeVarsB r)
freeVarsB (Or  l r)  = nub (freeVarsB l ++ freeVarsB r)

-- | Maximum nesting depth of an expression tree.
-- Atoms ('Lit', 'Var') have depth 0; every other constructor adds 1.
--
-- >>> depth (Mul (Add (Var "x") (Lit 1)) (Lit 2))
-- 2
depth :: Expr -> Int
depth (Lit _)          = 0
depth (Var _)          = 0
depth (Add l r)        = 1 + max (depth l) (depth r)
depth (Sub l r)        = 1 + max (depth l) (depth r)
depth (Mul l r)        = 1 + max (depth l) (depth r)
depth (Div l r)        = 1 + max (depth l) (depth r)
depth (Let _ rhs body) = 1 + max (depth rhs)  (depth body)
depth (If cond t e)    = 1 + maximum [depthB cond, depth t, depth e]

-- | Maximum nesting depth of a boolean expression.
depthB :: BExpr -> Int
depthB (BLit _)   = 0
depthB (Eq  l r)  = 1 + max (depth  l) (depth  r)
depthB (Lt  l r)  = 1 + max (depth  l) (depth  r)
depthB (Gt  l r)  = 1 + max (depth  l) (depth  r)
depthB (Not b)    = 1 + depthB b
depthB (And l r)  = 1 + max (depthB l) (depthB r)
depthB (Or  l r)  = 1 + max (depthB l) (depthB r)

-- --------------------------------------------------------------------------
-- Capture-avoiding substitution (supplementary)
-- --------------------------------------------------------------------------

-- | Replace every free occurrence of variable @x@ with expression @s@,
-- stopping at 'Let' boundaries where @x@ is shadowed so that bound
-- variables are not accidentally captured.
--
-- >>> substitute "x" (Lit 5) (Add (Var "x") (Var "y"))
-- Add (Lit 5.0) (Var "y")
-- >>> substitute "x" (Lit 9) (Let "x" (Lit 1) (Var "x"))
-- Let "x" (Lit 1.0) (Var "x")   -- x shadowed in body: inner x unchanged
substitute :: String -> Expr -> Expr -> Expr
substitute x s (Var y)
  | x == y            = s
  | otherwise         = Var y
substitute _ _ (Lit n) = Lit n
substitute x s (Add l r) = Add (substitute x s l) (substitute x s r)
substitute x s (Sub l r) = Sub (substitute x s l) (substitute x s r)
substitute x s (Mul l r) = Mul (substitute x s l) (substitute x s r)
substitute x s (Div l r) = Div (substitute x s l) (substitute x s r)
substitute x s (Let y rhs body)
  | x == y    = Let y (substitute x s rhs) body            -- shadowed in body
  | otherwise = Let y (substitute x s rhs) (substitute x s body)
substitute x s (If cond t e) =
  If (substituteB x s cond) (substitute x s t) (substitute x s e)

-- | Substitute inside a 'BExpr'.
substituteB :: String -> Expr -> BExpr -> BExpr
substituteB _ _ (BLit b)   = BLit b
substituteB x s (Eq  l r)  = Eq  (substitute x s l) (substitute x s r)
substituteB x s (Lt  l r)  = Lt  (substitute x s l) (substitute x s r)
substituteB x s (Gt  l r)  = Gt  (substitute x s l) (substitute x s r)
substituteB x s (Not b)    = Not (substituteB x s b)
substituteB x s (And l r)  = And (substituteB x s l) (substituteB x s r)
substituteB x s (Or  l r)  = Or  (substituteB x s l) (substituteB x s r)

-- --------------------------------------------------------------------------
-- Part C: Higher-order functions — batch operations
-- --------------------------------------------------------------------------

-- | Apply the partially-applied evaluator @eval env@ across a list of
-- expressions.  This is the explicit currying point: 'eval' receives just
-- its first argument, yielding a reusable @Expr -> Either String Double@
-- function that 'map' distributes over the batch.
evalAll :: Env -> [Expr] -> [Either String Double]
evalAll env = map (eval env)

-- | Evaluate a batch of expressions and return only the successes.
-- Uses 'Data.Either.rights', which is equivalent to
-- @map fromRight . filter isRight@ but without a partial match.
evalBatch :: Env -> [Expr] -> [Double]
evalBatch env = rights . evalAll env

-- | Evaluate a batch of expressions and report how many succeeded versus
-- failed, using a single 'foldr' pass.
batchSummary :: Env -> [Expr] -> (Int, Int)
batchSummary env exprs = foldr tally (0, 0) (evalAll env exprs)
  where
    tally (Right _) (s, f) = (s + 1, f)
    tally (Left  _) (s, f) = (s, f + 1)
