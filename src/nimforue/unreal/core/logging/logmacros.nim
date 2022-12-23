import ../containers/unrealstring
import std / [macros, strformat, strutils, genAsts, paths]
import logverbosity

macro ueLogImpl*(category: untyped, verbosity: ELogVerbosity, msg: string): untyped =
  result = nnkStmtList.newTree()
  var fstr = genSym(nskLet, "fstr")
  fstr = genSym(nskLet, fstr.repr.replace("_", ""))
  let lo = lineInfoObj(msg)
  let linfo = relativePath(lo.filename.Path, getProjectPath().Path).string & &"({lo.line}) "
  let metaAst = genAst(fstr, linfo, msg):
    let fstr = makeFString(linfo & " " & msg)

  result.add(
    metaAst,
    nnkPragma.newTree(
      nnkExprColonExpr.newTree(ident("emit"), newStrLitNode(&"""UE_LOG({category.strVal}, {verbosity}, TEXT("%s"), *{fstr})"""))
    )
  )

macro defineLogCategory*(category: untyped, defaultVerbosity: ELogVerbosity, compileTimeVerbosity: ELogVerbosity): untyped = 
  let loggers = genAst(category) do:
    template `category Log`*(msg: string) =
      ueLogImpl(category, Log, msg)
    template `category Warning`(msg: string) =
      ueLogImpl(category, Warning, msg)
    template `category Error`(msg: string) =
      ueLogImpl(category, Error, msg)

  nnkStmtList.newTree(
    newCall(ident"once", 
      nnkStmtList.newTree(
        nnkPragma.newTree(
          nnkExprColonExpr.newTree(ident("emit"), newStrLitNode(&"DECLARE_LOG_CATEGORY_EXTERN({category.strVal}, {defaultVerbosity}, {compileTimeVerbosity});"))
        ),
        nnkPragma.newTree(
          nnkExprColonExpr.newTree(ident("emit"), newStrLitNode(&"DEFINE_LOG_CATEGORY({category.strVal});"))
        )
      )
    ),
    loggers
  )
