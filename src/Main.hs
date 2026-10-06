-- | Demo / manual test driver for the "Expr" interpreter.
--
-- Run with:  runghc -isrc src/Main.hs
-- or:        ghc -Wall -isrc -o expr-demo src/Main.hs && ./expr-demo
module Main (main) where

import Expr
  ( Expr (..)
  , BExpr (..)
  , Env
  , eval
  , pretty
  , simplify
  , freeVars
  , depth
  , substitute
  , evalBatch
  , batchSummary
  )

-- --------------------------------------------------------------------------
-- Part B test harness
-- --------------------------------------------------------------------------

-- | A labelled test case: expression, environment, and expected result.
data Case = Case
  { label    :: String
  , expr     :: Expr
  , env      :: Env
  , expected :: Either String Double
  }

cases :: [Case]
cases =
  [ Case "1) literal"
      (Lit 42)
      []
      (Right 42)

  , Case "2) variable lookup"
      (Var "x")
      [("x", 10)]
      (Right 10)

  , Case "3) arithmetic: (x + 3) * 2"
      (Mul (Add (Var "x") (Lit 3)) (Lit 2))
      [("x", 4)]
      (Right 14)

  , Case "4) division by zero -> Left"
      (Div (Lit 5) (Sub (Var "y") (Var "y")))
      [("y", 3)]
      (Left "Division by zero")

  , Case "5) undefined variable -> Left"
      (Add (Var "z") (Lit 1))
      []
      (Left "Undefined variable: z")

  , Case "6) let binding: let x = 5 in x * x"
      (Let "x" (Lit 5) (Mul (Var "x") (Var "x")))
      []
      (Right 25)

  , Case "7) nested let (inner shadows outer)"
      (Let "x" (Lit 1) (Let "x" (Lit 2) (Add (Var "x") (Lit 1))))
      []
      (Right 3)

  , Case "8) if/BExpr: if x > 0 then x else 0 - x"
      (If (Gt (Var "x") (Lit 0)) (Var "x") (Sub (Lit 0) (Var "x")))
      [("x", -7)]
      (Right 7)

  , Case "9) if condition itself errors -> Left propagates"
      (If (Gt (Var "missing") (Lit 0)) (Lit 1) (Lit 2))
      []
      (Left "Undefined variable: missing")
  ]

runCase :: Case -> (Bool, String)
runCase c =
  let actual = eval (env c) (expr c)
      ok     = actual == expected c
      status = if ok then "PASS" else "FAIL"
  in ( ok
     , unlines
         [ status ++ "  " ++ label c
         , "    pretty     : " ++ pretty (expr c)   -- <-- now shows infix form
         , "    env        : " ++ show (env c)
         , "    expected   : " ++ show (expected c)
         , "    actual     : " ++ show actual
         ]
     )

-- --------------------------------------------------------------------------
-- Part C: simplify demos
-- --------------------------------------------------------------------------

simplifyDemos :: [(String, Expr)]
simplifyDemos =
  [ ("x + 0",                   Add (Var "x") (Lit 0))
  , ("0 + x",                   Add (Lit 0) (Var "x"))
  , ("x * 1",                   Mul (Var "x") (Lit 1))
  , ("x * 0",                   Mul (Var "x") (Lit 0))
  , ("(x + 0) * 1",             Mul (Add (Var "x") (Lit 0)) (Lit 1))
  , ("if True then x else y",   If (BLit True) (Var "x") (Var "y"))
  , ("3 + 4  (constant fold)",  Add (Lit 3) (Lit 4))
  , ("2 * (5 - 5) (fold+zero)", Mul (Lit 2) (Sub (Lit 5) (Lit 5)))
  ]

-- --------------------------------------------------------------------------
-- Pretty-printer demos
-- --------------------------------------------------------------------------

prettyDemos :: [(String, Expr)]
prettyDemos =
  [ ("(x+3)*2",             Mul (Add (Var "x") (Lit 3)) (Lit 2))
  , ("a - (b - c)",         Sub (Var "a") (Sub (Var "b") (Var "c")))
  , ("let x=5 in x*x",      Let "x" (Lit 5) (Mul (Var "x") (Var "x")))
  , ("if x>0 then x else -x"
    , If (Gt (Var "x") (Lit 0)) (Var "x") (Sub (Lit 0) (Var "x")))
  ]

-- --------------------------------------------------------------------------
-- Free-variable demos
-- --------------------------------------------------------------------------

freeVarDemos :: [(String, Expr)]
freeVarDemos =
  [ ("x + y",               Add (Var "x") (Var "y"))
  , ("let x=1 in x+y",      Let "x" (Lit 1) (Add (Var "x") (Var "y")))
  , ("let x=y in x+z",      Let "x" (Var "y") (Add (Var "x") (Var "z")))
  , ("if x>0 then y else z" , If (Gt (Var "x") (Lit 0)) (Var "y") (Var "z"))
  ]

-- --------------------------------------------------------------------------
-- Substitution demos
-- --------------------------------------------------------------------------

substDemos :: [(String, String, Expr, Expr)]
--            label     var  replacement  target-expression
substDemos =
  [ ( "x |-> 5  in  x + y"
    , "x", Lit 5, Add (Var "x") (Var "y") )
  , ( "x |-> 5  in  let x=1 in x  (shadowed, body unchanged)"
    , "x", Lit 5, Let "x" (Lit 1) (Var "x") )
  , ( "x |-> y+1  in  x*x"
    , "x", Add (Var "y") (Lit 1), Mul (Var "x") (Var "x") )
  ]

-- --------------------------------------------------------------------------
-- Main
-- --------------------------------------------------------------------------

main :: IO ()
main = do
  -- ------------------------------------------------------------------ Part B
  putStrLn "=== Part B: eval - expected vs actual (with pretty-printed expr) ==="
  results <- mapM (\c -> putStr (snd (runCase c)) >> pure (fst (runCase c))) cases
  let passed = length (filter id results)
  putStrLn (show passed ++ " / " ++ show (length cases) ++ " cases passed")

  -- ------------------------------------------------------- Part C: simplify
  putStrLn "\n=== Part C: simplify (algebraic identities + constant folding) ==="
  mapM_
    (\(descr, e) ->
        putStrLn ("  " ++ descr
               ++ "\n    before : " ++ pretty e
               ++ "\n    after  : " ++ pretty (simplify e)))
    simplifyDemos

  -- --------------------------------------------------- Part C: batch + fold
  putStrLn "\n=== Part C: batch evaluation (curried map) + summary (foldr) ==="
  let sharedEnv = [("x", 10), ("y", 0)]
      batch =
        [ Add (Var "x") (Lit 5)    -- succeeds: 15.0
        , Div (Lit 1) (Var "y")    -- fails:    division by zero
        , Var "z"                  -- fails:    undefined variable
        , Mul (Var "x") (Var "x")  -- succeeds: 100.0
        ]
      -- Partial application: `eval sharedEnv` :: Expr -> Either String Double
      evalShared = eval sharedEnv
  putStrLn   ("  individual results    : " ++ show (map evalShared batch))
  putStrLn   ("  evalBatch (successes) : " ++ show (evalBatch sharedEnv batch))
  let (successes, failures) = batchSummary sharedEnv batch
  putStrLn   ("  batchSummary          : " ++ show successes
           ++ " succeeded, " ++ show failures ++ " failed")

  -- ------------------------------------------------ Supplementary: pretty
  putStrLn "\n=== Supplementary: pretty-printer (infix, minimal parens) ==="
  mapM_
    (\(descr, e) ->
        putStrLn ("  " ++ descr ++ "  ==>  " ++ pretty e))
    prettyDemos

  -- --------------------------------------------- Supplementary: freeVars
  putStrLn "\n=== Supplementary: free variable analysis ==="
  mapM_
    (\(descr, e) ->
        putStrLn ("  freeVars (" ++ descr ++ ")  ==>  " ++ show (freeVars e)))
    freeVarDemos

  -- ---------------------------------------------- Supplementary: depth
  putStrLn "\n=== Supplementary: expression tree depth ==="
  let depthDemos =
        [ ("Lit 42",                Lit 42)
        , ("x + 3",                 Add (Var "x") (Lit 3))
        , ("(x+3)*2",               Mul (Add (Var "x") (Lit 3)) (Lit 2))
        , ("let x=5 in x*x",        Let "x" (Lit 5) (Mul (Var "x") (Var "x")))
        ]
  mapM_
    (\(descr, e) ->
        putStrLn ("  depth (" ++ descr ++ ")  ==>  " ++ show (depth e)))
    depthDemos

  -- ------------------------------------------ Supplementary: substitute
  putStrLn "\n=== Supplementary: capture-avoiding substitution ==="
  mapM_
    (\(descr, x, s, e) ->
        let result = substitute x s e
        in putStrLn ("  " ++ descr
                  ++ "\n    result : " ++ pretty result))
    substDemos