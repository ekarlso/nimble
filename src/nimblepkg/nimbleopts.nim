import json, strutils

import config, os, packageinfo, version

type
  ActionType* = enum
    actionNil, actionUpdate, actionInit, actionInstall, actionSearch,
    actionList, actionBuild, actionPath, actionUninstall, actionRegister

  Action* = object
    case typ*: ActionType
    of actionNil, actionList, actionBuild, actionRegister: nil
    of actionUpdate:
      optionalURL*: string # Overrides default package list.
    of actionInstall, actionPath, actionUninstall:
      optionalName*: seq[string] # \
      # When this is @[], installs package from current dir.
      packages*: seq[PkgTuple] # Optional only for actionInstall.
    of actionSearch:
      search*: seq[string] # Search string.
    of actionInit:
      projName*: string
    else:nil

  ForcePrompt* = enum
    dontForcePrompt, forcePromptYes, forcePromptNo

  Options* = object
    forcePrompts*: ForcePrompt
    queryVersions*: bool
    queryInstalled*: bool
    action*: Action
    config*: Config
    nimbleData*: JsonNode ## Nimbledata.json
    registryUrl*: string
    registryToken*: string


proc getNimbleDir*(options: Options): string =
  options.config.nimbleDir

proc getPkgsDir*(options: Options): string =
  options.config.nimbleDir / "pkgs"

proc getBinDir*(options: Options): string =
  options.config.nimbleDir / "bin"

proc prompt*(options: Options, question: string = ""): bool =
  ## Asks an interactive question and returns the result.
  ##
  ## The proc will return immediately without asking the user if the global
  ## forcePrompts has a value different than dontForcePrompt.
  case options.forcePrompts
  of forcePromptYes:
    echo(question & " -> [forced yes]")
    return true
  of forcePromptNo:
    echo(question & " -> [forced no]")
    return false
  of dontForcePrompt:
    echo(question & " [y/N]")
    let yn = stdin.readLine()
    case yn.normalize
    of "y", "yes":
      return true
    of "n", "no":
      return false
    else:
      return false
