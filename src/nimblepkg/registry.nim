import  httpclient, os, json, strutils

import nimbleopts, packageinfo

type
  RegistryOptions = object
    url*: string
    token*: string

proc newRegistryOpts(): RegistryOptions =
  result = RegistryOptions()

proc getInput(): string =
  result = ""
  while result == "":
    result = readLine(stdin)

proc getHeaders(options: Options): string =
  var token: string
  if options.registryToken != nil:
    token = options.registryToken
  else:
    token = options.config.registryToken

  result = "Content-Type:application/json\c\LAuthorization:Bearer $#\c\L" % token

proc getRegistryUrl*(options: Options): string =
  if options.registryUrl != nil:
    result =  options.registryUrl
  else:
    result = options.config.registryUrl

proc fromJson(obj: JSonNode): Pkg =
  ## Constructs a Package object from a JSON node.
  ##
  ## Aborts execution if the JSON node doesn't contain the required fields.
  result.name = obj.requiredField("name")
  result.repository = obj.requiredField("repository")
  result.license = obj.requiredField("license")
  result.tags = @[]
  for t in obj["tags"]:
    result.tags.add(t.str)
  result.description = obj.requiredField("description")
  result.web = obj.optionalField("web")

proc register*(options: Options) =
  var
    pkgInfo = getPkgInfo(getCurrentDir())
    pkg = pkgInfo.toPkg
    rel = pkgInfo.release
    resp: Response
    url = getRegistryUrl(options)
    licenses = newSeq[string]()

  resp = get(url & "/licenses")
  for i in parseJson(resp.body):
    licenses.add(i["name"].str)

  if pkg.license notin licenses:
    quit("License $# is invalid.. Needs to be one of: \n'$#'" % [$pkg.license, join(licenses, ", ")])

  echo("Enter package homepage if any")
  pkg.web = getInput()

  echo("Enter package repository url if any")
  pkg.repository = getInput()

  echo("Enter package tags seperated by ',' or ' '.")
  let
    tagsStr = getInput()
  pkg.tags = tagsStr.replace(" ", ",").split(",")

  echo("About to create package, does the below information seem correct?")
  var pkgDetails = ""
  for k, v in %pkg:
    pkgDetails.add(k & " -> " & $v & "\n")

  if options.prompt(pkgDetails):
    let
      headers = getHeaders(options)
      pkgJson = %pkg

    resp = post(url & "/packages", headers, $pkgJson)
    if resp.status.startsWith("201"):
      echo("Package created succesfully!")
    else:
      echo("ERROR: $#" % resp.body)

#proc search*(url: string, )

proc upload*(options: Options) =
  echo("FOO")

proc listPackages*(opts: RegistryOptions, params = ""): seq[Pkg] =
  result = newSeq[Pkg]()
  let
    pkgUrl = opts.url & "/packages" & params
    response = get(pkgUrl)
    jArray = parseJson(response.body)

  for jNode in jArray:
      result.add(jNode.toPkg)

proc searchPackages*(opts: RegistryOptions, names: seq[string], tags: seq[string]): seq[Pkg] =
  var params = newSeq[string]()
  params.add("name" & "=" & names.join(","))
  params.add("tag" & "=" & tags.join(","))

  result = listPackages(opts, params = "?" & join(params, "&"))

proc searchPackages*(opts: RegistryOptions, names: seq[string]): seq[Pkg] =
  result = searchPackages(opts, names, newSeq[string]())

proc getPackage*(opts: RegistryOptions, name: string): Pkg =
  let
    pkgUrl = opts.url & "/packages/$#" % name
    response = get(pkgUrl)
    jNode = parseJson(response.body)
  result = fromJson(jNode)

proc listReleases*(opts: RegistryOptions, packageName: string): seq[Release] =
  result = newSeq[Release]()

  let
    url = opts.url & "/packages/$#/releases" % packageName
    response = get(url)
    releasesJson = parseJson(response.body)

  for releaseJson in releasesJson:
    result.add(releaseJson.toRelease)

# Legacy interface
proc listPackages*(options: Options): seq[Pkg] =
  var regOpts = newRegistryOpts()
  regOpts.url = getRegistryUrl(options)
  result = listPackages(regOpts)

proc searchPackages*(options: Options): seq[Pkg] =
  var regOpts = newRegistryOpts()
  regOpts.url = getRegistryUrl(options)

  result = searchPackages(regOpts, options.action.search, options.action.search)

proc listReleases*(options: Options, packageName: string): seq[Release] =
  var regOpts = newRegistryOpts()
  regOpts.url = getRegistryUrl(options)

  result = listReleases(regOpts, packageName)

proc getPackage*(options: Options, name: string): Pkg =
  var regOpts = newRegistryOpts()
  regOpts.url = getRegistryUrl(options)
  result = getPackage(regOpts, name)