{-# LANGUAGE RankNTypes #-}
module Language.SPO.Parser.PrimaryParser 
    ( whileParser
    ) where

import Control.Monad
import Data.Functor.Identity
import Data.Maybe
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Text.Parsec
import Text.Parsec.Text
import Text.Parsec.Expr
import Text.Parsec.Language
import qualified Text.Parsec.Token as Token

import Language.SPO.Parser.Types

type PPState = [M.Map T.Text PrimaryType]
type PParser = GenParser PPState
type POperatorTable a = OperatorTable T.Text PPState Identity a

data PrimaryType = 
      PT_
    | PTInt
    | PTFloat
    | PTBool
    | PTString
    | PTChar
    | PTArray PrimaryType (Maybe Int)
    | PTUser T.Text
      deriving (Show)

langDef :: forall u. GenLanguageDef T.Text u Identity
langDef = Token.LanguageDef
    { Token.commentStart    = "/*"
    , Token.commentEnd      = "*/"
    , Token.commentLine     = "//"
    , Token.nestedComments  = True
    , Token.identStart      = letter
    , Token.identLetter     = alphaNum <|> oneOf "_'"
    , Token.opStart         = Token.opLetter langDef
    , Token.opLetter        = oneOf ":!#$%&*+./<=>?@\\^|-~"
    , Token.reservedNames   = [ "if", "else"
                              , "while", "do"
                              , "true", "false"
                              , "native", "public", "normal", "static", "stock"
                              ,     "forward"
                              , "private", "protected"
                              , "new", "decl"
                              , "return"
                              , "class", "interface"
                              ]
    , Token.reservedOpNames = [ "+", "-", "*", "/", "++", "--"
                              , "|", "&", "^", "~", "<<", ">>"
                              , "<", ">", "<=", ">=", "==", "!="
                              , "="
                              , "!", "&&", "||"
                              ]
    , Token.caseSensitive   = True
    }

lexer :: forall u. Token.GenTokenParser T.Text u Identity
lexer = Token.makeTokenParser langDef

identifier :: PParser T.Text
identifier = Token.identifier lexer >>= return . T.pack

reserved   :: String -> PParser ()
reserved   = Token.reserved   lexer

reservedOp :: String -> PParser ()
reservedOp = Token.reservedOp lexer

charLiteral   :: PParser Char
charLiteral   = Token.charLiteral lexer

stringLiteral :: PParser T.Text
stringLiteral = Token.stringLiteral lexer >>= return . T.pack

symbol     :: String -> PParser String
symbol     = Token.symbol     lexer

integer    :: PParser Integer
integer    = Token.integer    lexer

semicolon  ::  PParser String
semicolon  = Token.semi       lexer

whiteSpace :: PParser ()
whiteSpace = Token.whiteSpace lexer

commaSep   :: PParser a -> PParser [a]
commaSep   = Token.commaSep   lexer

parens, braces ,{- angles,  -} brackets :: forall a. PParser a -> PParser a
parens     = Token.parens     lexer -- ()
braces     = Token.braces     lexer -- {}
--angles     = Token.angles     lexer -- <>
brackets   = Token.brackets   lexer -- []


-- Primary Parser

whileParser :: PParser Statement
whileParser = do
    whiteSpace
    modifyState ((:)M.empty)
    stmt <- statement
    eof
    return stmt

statement :: PParser Statement
statement = parens statement
        <|> statements

statements :: PParser Statement
statements = do
    list <- sepBy1 statement' whiteSpace
    return $ if length list == 1 then head list else StmtSeq list

statement' :: PParser Statement
statement' = try ifElseStmt
         <|> try funcStmt
         <|> forStmt
         <|> funcCallStmt
         <|> returnStmt
         <|> ifStmt
         <|> whileStmt
         <|> doWhileStmt
         <|> declStmt
         <|> newStmt
         <|> assignStmt

bracedStmt :: PParser Statement
bracedStmt = (try $ statement') 
         <|> braces statement

ifStmt' :: PParser (ExprBoolean, Statement)
ifStmt' = do 
    reserved "if"
    cond  <- parens exprBoolean
    stmt <- bracedStmt
    return (cond,stmt)

ifStmt :: PParser Statement
ifStmt = do 
    (cond, stmt) <- ifStmt'
    return $ StmtIf cond stmt

ifElseStmt :: PParser Statement
ifElseStmt = do 
    (cond, stmt1) <- ifStmt'
    reserved "else"
    stmt2 <- bracedStmt
    return $ StmtIfElse cond stmt1 stmt2
    
whileStmt :: PParser Statement
whileStmt = do 
    reserved "while"
    cond <- parens exprBoolean
    stmt <- bracedStmt
    return $ StmtWhile cond stmt
    
doWhileStmt :: PParser Statement
doWhileStmt = do 
    reserved "do"
    stmt <- bracedStmt
    reserved "while"
    cond <- parens exprBoolean
    _ <- semicolon
    return $ StmtDoWhile cond stmt

forStmt :: PParser Statement
forStmt = do
    reserved "for"
    (ini, cond, it) <- parens $ do
        ini <- newStmt
        cond <- exprBoolean
        _ <- semicolon
        it <- exprArithmetic
        return $ (ini, cond, it)
    stmt <- bracedStmt
    return $ StmtFor ini cond it stmt

assignStmt :: PParser Statement
assignStmt = do 
    var <- identifier
    marr <- arrayDeclaration
    reservedOp "="
    expr <- exprAssignment
    _ <- semicolon
    return $ StmtAss var marr expr

returnStmt :: PParser Statement
returnStmt = do
    reserved "return"
    expr <- exprAssignment
    _ <- semicolon
    return $ StmtReturn expr

declStmt :: PParser Statement
declStmt = do 
    reserved "decl"
    ms <- variableModifiers
    mtag <- tagDeclaration
    var <- identifier
    marr <- arrayDeclaration
    _ <- semicolon
    return $ StmtDecl ms mtag var marr
    
newStmt :: PParser Statement
newStmt = do 
    reserved "new"
    ms <- variableModifiers
    mtag <- tagDeclaration
    var <- identifier
    marr <- arrayDeclaration
    mexpr <- optionMaybe (try (reservedOp "=" >> exprAssignment))
    _ <- semicolon
    return $ StmtNew ms mtag var marr mexpr

funcStmt :: PParser Statement
funcStmt = do
    m <- opFuncModifier
    mtag <- tagDeclaration
    var <- identifier    
    args <- parens $ commaSep $ do
        ms <- funcArgModifiers
        matag <- tagDeclaration
        arg <- identifier
        marr <- optionMaybe $ symbol "[" >> symbol "]"
        expr <- optionMaybe $ do
            reservedOp "="
            exprAssignment
        return $ (ms, matag, arg, isJust marr, expr)
    stmt <- braces $ statement 
    return $ StmtFunc m mtag var args stmt

funcCallStmt :: PParser Statement
funcCallStmt = do 
    (var,expr) <- funcCallInternal
    _ <- semicolon
    return $ StmtFuncCall var expr

funcCallInternal :: PParser (T.Text, [ExprArithmetic])
funcCallInternal = do
    var <- identifier
    expr <- parens $ commaSep exprArithmetic
    return $ (var, expr)

opFuncModifier :: PParser OpFuncModifier
opFuncModifier = do
    ms <- many $ (reserved "native" >> return OpFNative)
             <|> (reserved "public" >> return OpFPublic)
             <|> (reserved "static" >> return OpFStatic)
             <|> (reserved "stock" >> return OpFStock)
             <|> (reserved "forward" >> return OpFForward)
    if null ms 
        then return OpFNormal
        else if length ms > 1 
            then fail "unpexpected modifier"
            else return $ head ms

funcArgModifiers :: PParser FuncArgModifiers
funcArgModifiers = many $ (reserved "const" >> return OpFAConst)
--                      <|> (reserved "in"    >> return OpFAIn)
--                      <|> (reserved "out"   >> return OpFAOut)

tagDeclaration :: PParser TagDeclaration
tagDeclaration = optionMaybe $ try $ do
    tag <- identifier <|> liftM T.pack (count 1 (char '_'))
    reservedOp ":"
    return tag

arrayDeclaration :: PParser ArrayDeclaration
arrayDeclaration = optionMaybe $ try $ do 
    reservedOp "["
    expr <- optionMaybe (try exprArithmetic)
    reservedOp "]"
    return expr

exprAssignment :: PParser ExprAssignment
exprAssignment = try (liftM ExprAssBool exprBoolean)
             <|> liftM ExprAssAr exprArithmetic
             <|> liftM ExprAssArrayInit (braces (commaSep exprArithmetic))

variableModifiers :: PParser VariableModifiers
variableModifiers = many $ (reserved "const"  >> return OpConst)
                       <|> (reserved "static" >> return OpStatic)
    

exprBoolean :: PParser ExprBoolean
exprBoolean = buildExpressionParser opBoolean termBoolean

exprArithmetic :: PParser ExprArithmetic
exprArithmetic = buildExpressionParser opArithmetic termArithmetic

opBoolean :: POperatorTable ExprBoolean
opBoolean = [ [Prefix (reservedOp "!"  >> return (ExprNot          ))          ]
            , [Infix  (reservedOp "&&" >> return (ExprBinBool OpAnd)) AssocLeft]
            , [Infix  (reservedOp "||" >> return (ExprBinBool OpOr )) AssocLeft]
            ]

opArithmetic :: POperatorTable ExprArithmetic
opArithmetic = 
    [ [Prefix  (reservedOp "-"  >> return (ExprUnaAr OpNegate))           ]
    , [Prefix  (reservedOp "~"  >> return (ExprUnaAr OpBNot))             ]
    , [Prefix  (reservedOp "++" >> return (ExprUnaAr OpPreInc))           ]
    , [Postfix (reservedOp "++" >> return (ExprUnaAr OpPostInc))          ]
    , [Prefix  (reservedOp "--" >> return (ExprUnaAr OpPreDec))           ]
    , [Postfix (reservedOp "--" >> return (ExprUnaAr OpPostDec))          ]
    , [Infix   (reservedOp "*"  >> return (ExprBinAr OpMul))     AssocLeft]
    , [Infix   (reservedOp "/"  >> return (ExprBinAr OpDiv))     AssocLeft]
    , [Infix   (reservedOp "+"  >> return (ExprBinAr OpAdd))     AssocLeft]
    , [Infix   (reservedOp "-"  >> return (ExprBinAr OpSub))     AssocLeft]
    , [Infix   (reservedOp "&"  >> return (ExprBinAr OpBAnd))    AssocLeft]
    , [Infix   (reservedOp "|"  >> return (ExprBinAr OpBOr))     AssocLeft]
    , [Infix   (reservedOp "^"  >> return (ExprBinAr OpBXor))    AssocLeft]
    , [Infix   (reservedOp "<<" >> return (ExprBinAr OpBLShift)) AssocLeft]
    , [Infix   (reservedOp ">>" >> return (ExprBinAr OpBRShift)) AssocLeft]
    ]

termArithmetic :: PParser ExprArithmetic
termArithmetic = parens exprArithmetic
             <|> try (do var <- identifier
                         expr <- brackets exprArithmetic
                         return $ ExprIndex var expr)
             <|> try (do (var,expr) <- funcCallInternal
                         return $ ExprFuncCall var expr)
             <|> liftM ExprVar identifier
             <|> liftM ExprInt integer
             <|> liftM ExprChar charLiteral
             <|> liftM ExprString stringLiteral

termBoolean :: PParser ExprBoolean
termBoolean = parens exprBoolean
          <|> (reserved "true"  >> return (ExprBool True ))
          <|> (reserved "false" >> return (ExprBool False))
          <|> exprRelational

exprRelational :: PParser ExprBoolean
exprRelational = do
    a1 <- exprArithmetic
    op <- relation
    a2 <- exprArithmetic
    return $ ExprBinRel op a1 a2

relation :: PParser OpBinRelational
relation = (reservedOp ">"  >> return OpGT)
       <|> (reservedOp ">=" >> return OpGE)
       <|> (reservedOp "<"  >> return OpLT)
       <|> (reservedOp "<=" >> return OpLE)
       <|> (reservedOp "==" >> return OpEq)
       <|> (reservedOp "!=" >> return OpNE)
