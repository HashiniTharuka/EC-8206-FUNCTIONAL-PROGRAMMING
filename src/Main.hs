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
  , simplify
  , evalBatch
  , batchSummary
  )

-- --------------------------------------------------------------------------
-- Test harness
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
         , "    expression : " ++ show (expr c)
         , "    env        : " ++ show (env c)
         , "    expected   : " ++ show (expected c)
         , "    actual     : " ++ show actual
         ]
     )

-- --------------------------------------------------------------------------
-- simplify demos  (simplify :: Expr -> Expr, so output uses Expr constructors)
-- --------------------------------------------------------------------------

simplifyDemos :: [(String, Expr)]
simplifyDemos =
  [ ("x + 0",              Add (Var "x") (Lit 0))
  , ("0 + x",              Add (Lit 0) (Var "x"))
  , ("x * 1",              Mul (Var "x") (Lit 1))
  , ("x * 0",              Mul (Var "x") (Lit 0))
  , ("(x + 0) * 1",        Mul (Add (Var "x") (Lit 0)) (Lit 1))
  , ("if True then x else y", If (BLit True) (Var "x") (Var "y"))
  ]

-- --------------------------------------------------------------------------
-- Main
-- --------------------------------------------------------------------------

main :: IO ()
main = do
  putStrLn "=== Part B: eval sample evaluations (expected vs actual) ==="
  results <- mapM (\c -> putStr (snd (runCase c)) >> pure (fst (runCase c))) cases
  let passed = length (filter id results)
  putStrLn (show passed ++ " / " ++ show (length cases) ++ " cases passed")

  putStrLn "\n=== Part C: simplify demos (Expr -> Expr, no SimpExpr) ==="
  mapM_
    (\(descr, e) ->
        putStrLn (descr ++ "  ==>  " ++ show (simplify e)))
    simplifyDemos

  putStrLn "\n=== Part C: batch evaluation (map/filter) + summary (foldr) ==="
  let sharedEnv = [("x", 10), ("y", 0)]
      batch =
        [ Add (Var "x") (Lit 5)   -- succeeds: 15.0
        , Div (Lit 1) (Var "y")   -- fails: division by zero
        , Var "z"                 -- fails: undefined variable
        , Mul (Var "x") (Var "x") -- succeeds: 100.0
        ]
      -- Partial application: `eval sharedEnv` is a curried, reusable
      -- function of type `Expr -> Either String Double`.
      evalShared = eval sharedEnv
  putStrLn ("individual results : " ++ show (map evalShared batch))
  putStrLn ("evalBatch (successes only) : " ++ show (evalBatch sharedEnv batch))
  let (successes, failures) = batchSummary sharedEnv batch
  putStrLn ("batchSummary : " ++ show successes ++ " succeeded, "
            ++ show failures ++ " failed")