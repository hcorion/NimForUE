# tooling for NimForUE
import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts / [buildcommon, buildscripts, nimforueconfig, nimcachebuild]

var taskOptions: Table[string, string]
let config = getNimForUEConfig()

type Task = object
  name: string
  description: string
  routine: proc(taskOptions: Table[string, string]) {.nimcall.}

var tasks: seq[tuple[name:string, t:Task]]

template task(taskName: untyped, desc: string, body: untyped): untyped =
  proc `taskName`(taskOptions: Table[string, string]) {.nimcall.} =
    let start = now()
    log ">>>> Task: " & astToStr(taskName) & " <<<<"
    body
    log "!!>> " & astToStr(taskName) & " Time: " & $(now() - start) & " <<<<"
  tasks.add (name:astToStr(taskName), t:Task(name: astToStr(taskName), description: desc, routine: `taskName`))


proc echoTasks() =
  log "Here are the task available: "
  for t in tasks:
    log("  " & t.name & (if t.name.len < 6: "\t\t" else: "\t") & t.t.description)

proc main() =
  if commandLineParams().join(" ").len == 0:
    log "nue: NimForUE tool"
    echoTasks()

  var p = initOptParser()
  var ts:Option[Task]
  for kind, key, val in p.getopt():
    case kind
    of cmdEnd: doAssert(false) # cannot happen with getopt
    of cmdShortOption, cmdLongOption:
      case key:
      of "h", "help":
        log "Usage, Commands and Options for nue"
        echoTasks()
        quit()
      else:
        taskOptions[key] = val
    of cmdArgument:
      let res = tasks.filterIt(it.name == key) #TODO: Match first characters if whole word doesn't match, so we don't need task aliases
      if res.len > 0:
        ts = some(res[0].t)
      elif ts.isSome():
        doAssert(not taskOptions.hasKey("args"), "TODO: accept more than one task argument")
        taskOptions["args"] = key
      else:
        log &"!! Unknown task {key}."
        echoTasks()

  if ts.isSome():
    ts.get().routine(taskOptions)


# --- Compile flags ---
const withPCH {.used.} = true
const withDebug = true

template d(def: string): untyped =
  ("define", def)

template passC(val: string): untyped =
  ("passC", val)

type Switches = seq[(string, string)]

let buildSwitches: Switches = @[
  ("outdir", "./Binaries/nim/"),
  ("mm", "orc"),
  ("backend", "cpp"),
  ("exceptions", "cpp"), #need to investigate further how to get Unreal exceptions and nim exceptions to work together so UE doesn't crash when generating an exception in cpp
  ("warning", "off"),
  d("useMalloc"),
  d("withReinstantiation"),
  d("genFilePath:" & quotes(config.genFilePath)),
  d("pluginDir:" & quotes(config.pluginDir)),
]

let targetSwitches: Switches =
  case config.targetConfiguration:
    of Debug, Development:
      var ts = @[("opt", "none")]
      if withDebug:
        ts &= @[("debugger", "native"), ("stacktrace", "on")]
      ts
    of Shipping:
      @[d("release")]

let platformSwitches: Switches =
  block:
    when defined windows:
      @[
        ("cc", "vcc"),
        passC("/MP"),
        passC("/std:c++17"),
      ]
    elif defined macosx:
      let platformDir = 
        if config.targetPlatform == Mac: 
          "Mac/x86_64" 
        else: 
          $config.targetPlatform
      #I'm pretty sure there will more specific handles for the other platforms
      #/Volumes/Store/Dropbox/GameDev/UnrealProjects/NimForUEDemo/MacOs/Plugins/NimForUE/Intermediate/Build/Mac/x86_64/UnrealEditor/Development/NimForUE/PCH.NimForUE.h.gch
      let pchPath = config.pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / $config.targetConfiguration / "NimForUE" / "PCH.NimForUE.h.gch"

      @[
        ("cc", "clang"),
        ("putenv", "MACOSX_DEPLOYMENT_TARGET=10.15"),
        passC("-stdlib=libc++"),
        passC("-x objective-c++"),
        passC("-fno-unsigned-char"),
        passC("-std=c++17"),
        passC("-fno-rtti"),
        passC("-fasm-blocks"),
        passC("-fvisibility-ms-compat"),
        passC("-fvisibility-inlines-hidden"),
        passC("-fno-delete-null-pointer-checks"),
        passC("-pipe"),
        passC("-fmessage-length=0"),
        passC("-Wno-macro-redefined"),
        passC("-Wno-duplicate-decl-specifier"),
        passC("-mincremental-linker-compatible"),
      ] &
        (if withPCH: @[passC("-include-pch " & pchPath)] else: @[])
    else:
      @[]

let includes: Switches =
  collect:
    for headerPath in getUEHeadersIncludePaths(config):
      passC("-I" & headerPath)
let symbols: Switches =
  collect:
    for symbolPath in getUESymbols(config):
      ("passL", symbolPath)

template fold(switches: Switches): untyped =
  switches.foldl(a & &" --{b[0]}:{b[1]}", "")

let buildFlags =
  fold(buildSwitches) &
  fold(targetSwitches) &
  fold(platformSwitches) &
  fold(includes) &
  fold(symbols)

# --- End Compile flags

# --- Define Tasks ---

let watchInterval = 500

task watch, "Monitors the components folder for changes to recompile.":
  proc ctrlc() {.noconv.} =
    log "Ending watcher"
    quit()

  setControlCHook(ctrlc)

  let updateCmd =
    when defined windows:
      ("nue.exe", ["guestpch"])
    elif defined macosx:
      ("/bin/zsh", ["nueMac.sh"])

  let srcDir = getCurrentDir() / "src/nimforue/"
  log &"Monitoring components for changes in \"{srcDir}\".  Ctrl+C to stop"
  var lastTimes = newTable[string, Time]()
  for path in walkDirRec(srcDir ):
    if not path.endsWith(".nim"):
      continue
    lastTimes[path] = getLastModificationTime(path)

  while true:
    for path in walkDirRec(srcDir ):
      if not path.endsWith(".nim"):
        continue
      var lastTime = getLastModificationTime(path)
      if path notin lastTimes:
        lastTimes[path] = Time()

      if lastTime > lastTimes[path]:
        lastTimes[path] = lastTime
        log(&"-- Recompiling {path} --")
        let p = startProcess(updateCmd[0], getCurrentDir(), updateCmd[1])

        for line in p.lines:
          if line.contains("Error:") or line.contains("fatal error") or line.contains("error C"):
            log(line, lgError)
          else:
            log(line)
        p.close

        log(&"-- Finished Recompiling {path} --")

    sleep watchInterval

task w, "Alias for watch":
  watch(taskOptions)

task guest, "Builds the main lib. The one that makes sense to hot reload.":
  generateFFIGenFile(config)
  doAssert(execCmd(&"nim cpp {buildFlags} --app:lib --nomain --d:genffi -d:withPCH --nimcache:.nimcache/guest src/nimforue.nim") == 0)
  copyNimForUELibToUEDir()

task guestpch, "Builds the hot reloading lib. Options -f to force rebuild, --nogen to compile from nimcache cpp sources without generating, --nolinedir turns off #line directives in cpp output.":
  generateFFIGenFile(config)

  var force = ""
  if "f" in taskOptions:
    force = "-f"
  var noGen = "nogen" in taskOptions
  var lineDir = if "nolinedir" in taskOptions: "off" else: "on"

  if not noGen:
    doAssert(execCmd(&"nim cpp {force} --lineDir:{lineDir} {buildFlags} --debugger:native --stacktrace:on --genscript --app:lib --nomain --d:genffi -d:withPCH --nimcache:.nimcache/guestpch src/nimforue.nim") == 0)

  if nimcacheBuild() == Success:
    copyNimForUELibToUEDir()

task g, "Alias to guestpch":
  guestpch(taskOptions)

task winpch, "For Windows, Builds the pch file for Unreal Engine via nim":
  winpch()

task pp, "Preprocess a file with MSVC":
  if "args" in taskOptions:
    preprocess(taskOptions["args"])
  else:
    quit("Usage: nue.exe pp relative_filepath\n\tThe filepath should be relative and the base directory and its sub-directories will be included for the compiler.\n\tExample: nue pp ./Source/NimForUE/Private/TestActor.cpp\n\tThe ./Source directory and its subdirectories will be included for preprocessing.")

task host, "Builds the host that's hooked to unreal":
  generateFFIGenFile(config)
  doAssert(execCmd("nim cpp --header:NimForUEFFI.h --threads --tlsEmulation:off --app:lib --nomain --d:host --nimcache:.nimcache/host src/hostnimforue/hostnimforue.nim") == 0)
  # copy header
  let ffiHeaderSrc = ".nimcache/host/NimForUEFFI.h"
  let ffiHeaderDest = "NimHeaders/NimForUEFFI.h"
  copyFile(ffiHeaderSrc, ffiHeaderDest)
  log("Copied " & ffiHeaderSrc & " to " & ffiHeaderDest)

  # copy lib
  let libDir = "./Binaries/nim"
  let libDirUE = libDir / "ue"
  createDir(libDirUE)

  let hostLibName = "hostnimforue"
  let baseFullLibName = getFullLibName(hostLibName)
  let fileFullSrc = libDir/baseFullLibName
  let fileFullDst = libDirUE/baseFullLibName

  try:
    copyFile(fileFullSrc, fileFullDst)
  except OSError as e:
    when defined windows: # This will fail on windows if the host dll is in use.
      quit("Error copying to " & fileFullDst & ". " & e.msg, QuitFailure)

  log("Copied " & fileFullSrc & " to " & fileFullDst)

  when defined windows:
    let weakSymbolsLib = hostLibName & ".lib"
    copyFile(libDir/weakSymbolsLib, libDirUE/weakSymbolsLib)
  elif defined macosx: #needed for dllimport in ubt mac only
    let dst = "/usr/local/lib" / baseFullLibName
    copyFile(fileFullSrc, dst)
    log("Copied " & fileFullSrc & " to " & dst)

task h, "Alias to host":
  host(taskOptions)


task cleanh, "Clean the .nimcache/host folder":
  removeDir(".nimcache/host")

task cleang, "Clean the .nimcache guestpch and winpch folder":
  removeDir(".nimcache/winpch")
  removeDir(".nimcache/guestpch")

task clean, "Clean the nimcache folder":
  cleanh(taskOptions)
  cleang(taskOptions)

task ubuild, "Calls Unreal Build Tool for your project":
  let curDir = getCurrentDir()
  let walkPattern = config.pluginDir & "/../../*.uproject"
  try:
    let uprojectFile = walkPattern.walkFiles.toSeq[0]
    setCurrentDir(config.engineDir)
    let buildCmd = r"Build\BatchFiles\" & (
      case config.targetPlatform
        of Win64: "Build.bat"
        of Mac: r"BatchFiles\Mac\Build.sh" # untested
      )

    doAssert(execCmd(buildCmd & " NimForUEDemoEditor " &
      $config.targetPlatform & " " &
      $config.targetConfiguration & " " &
      uprojectFile & " -waitmutex") == 0)
    setCurrentDir(curDir)
  except:
    log("Could not find uproject here: " & walkPattern & "\n", lgError)
    quit(QuitFailure)

task rebuild, "Cleans and rebuilds the host and guest":
  clean(taskOptions)
  host(taskOptions)
  ubuild(taskOptions)
  guestpch(taskOptions)

task dumpConfig, "Displays the config variables":
  dump config

# --- End Tasks ---

main()