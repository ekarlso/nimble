import os

import download, json, nimbleopts, nimbletypes, packageinfo, strutils

proc fromJson(obj: JSonNode): Pkg =
  ## Constructs a Pkg object from a JSON node.
  ##
  ## Aborts execution if the JSON node doesn't contain the required fields.
  result.name = obj.requiredField("name")
  result.repository = obj.requiredField("url")
  result.license = obj.requiredField("license")
  result.tags = @[]
  for t in obj["tags"]:
    result.tags.add(t.str)
  result.description = obj.requiredField("description")
  result.web = obj.optionalField("web")

proc getPkgList*(packagesPath: string): seq[Pkg] =
  ## Returns the list of packages found at the specified path.
  result = @[]
  let packages = parseFile(packagesPath)
  for p in packages:
    let pkg: Pkg = p.fromJson()
    result.add(pkg)

proc getPackage*(pkg: string, packagesPath: string, resPkg: var Pkg): bool =
  ## Searches ``packagesPath`` file saving into ``resPkg`` the found package.
  ##
  ## Pass in ``pkg`` the name of the package you are searching for. As
  ## convenience the proc returns a boolean specifying if the ``resPkg`` was
  ## successfully filled with good data.
  let packages = parseFile(packagesPath)
  for p in packages:
    if p["name"].str == pkg:
      resPkg = p.fromJson()
      return true

proc listPackages*(options: Options): seq[Pkg] =
  if not existsFile(options.getNimbleDir() / "packages.json"):
    raise newException(NimbleError, "Please run nimble update.")
  result = getPkgList(options.getNimbleDir() / "packages.json")

proc searchPackages*(options: Options): seq[Pkg] =
  assert options.action.typ == actionSearch

  ## Searches for matches in ``options.action.search``.
  ##
  ## Searches are done in a case insensitive way making all strings lower case.
  assert options.action.typ == actionSearch
  if options.action.search == @[]:
    raise newException(NimbleError, "Please specify a search string.")
  if not existsFile(options.getNimbleDir() / "packages.json"):
    raise newException(NimbleError, "Please run nimble update.")
  let pkgList = getPkgList(options.getNimbleDir() / "packages.json")

  result = newSeq[Pkg]()

  template onFound: stmt =
    result.add(pkg)
    #if options.queryVersions:
    #  echoPackageVersions(pkg)
    break

  for pkg in pkgList:
    for word in options.action.search:
      # Search by name.
      if word.toLower() in pkg.name.toLower():
        onFound()
      # Search by tag.
      for tag in pkg.tags:
        if word.toLower() in tag.toLower():
          onFound()
