module Pack.CmdLn.Opts

import Data.String
import Libraries.Utils.Path
import Pack.CmdLn.Types
import Pack.Core.Types
import Pack.Config.Types
import System.Console.GetOpt

%default total

bootstrap : Config s -> Config s
bootstrap = {bootstrap := True}

withSrc : Config s -> Config s
withSrc = {withSrc := True}

setDB : String -> Config s -> Config s
setDB s = {collection := MkDBName s}

setPrompt : Bool -> Config s -> Config s
setPrompt b = {safetyPrompt := b}

setScheme : String -> Config s -> Config s
setScheme s = {scheme := parse s}

-- command line options with description
descs : List $ OptDescr (Config Nothing -> Config Nothing)
descs = [ MkOpt ['p'] ["package-set"]   (ReqArg setDB "<db>")
            """
            Set the curated package set to use. At the
            moment, this defaults to `HEAD`, so the latest commits
            of all packages will be used. This is bound to change
            once we have a reasonably stable package set.
            """
        , MkOpt ['s'] ["scheme"]   (ReqArg setScheme "<exec>")
            """
            Sets the scheme executable for installing the Idris2 compiler.
            As a default, this is set to `scheme`.
            """
        , MkOpt [] ["bootstrap"]   (NoArg bootstrap)
            """
            Use bootstrapping when building the Idris2 compiler.
            This is for users who don't have a recent version of
            the Idris2 compiler on their `$PATH`. Compiling Idris2
            will take considerably longer with this option set.
            """
        , MkOpt [] ["prompt"]   (NoArg $ setPrompt True)
            """
            Prompt before installing a potentially unsafe package
            with custom build hooks.
            """
        , MkOpt [] ["no-prompt"]   (NoArg $ setPrompt False)
            """
            Don't prompt before installing a potentially unsafe package
            with custom build hooks.
            """
        , MkOpt [] ["with-src"]   (NoArg withSrc)
            """
            Include the source code of a library when installing
            it. This allows some editor plugins to jump to the
            definitions of functions and data types in other
            modules.
            """
        ]

export
optionNames : List String
optionNames = foldMap names descs
  where names : OptDescr a -> List String
        names (MkOpt sns lns _ _) =
          map (\c => "-\{String.singleton c}") sns ++ map ("--" ++) lns


cmd : List String -> Either PackErr Cmd
cmd []                         = Right PrintHelp
cmd ["help"]                   = Right PrintHelp
cmd ["update-db"]              = Right UpdateDB
cmd ["check-db", db]           = Right $ CheckDB (MkDBName db)
cmd ("exec" :: file :: args)   = Right $ Exec (fromString file) args
cmd ["extract-from-head", p]   = Right $ FromHEAD (parse p)
cmd ["build", file]            = Right $ Build (parse file)
cmd ["typecheck", file]        = Right $ Typecheck (parse file)
cmd ("install" :: xs)          = Right $ Install (map fromString xs)
cmd ("remove" :: xs)           = Right $ Remove (map fromString xs)
cmd ("install-app" :: xs)      = Right $ InstallApp (map fromString xs)
cmd ["completion",a,b]         = Right $ Completion a b
cmd ["completion-script",f]    = Right $ CompletionScript f
cmd xs                         = Left  $ UnknownCommand xs

||| Given a root directory for *pack* and a db version,
||| generates the application
||| config from a list of command line arguments.
export
applyArgs :  (init : Config Nothing)
          -> (args : List String)
          -> Either PackErr (Config Nothing, Cmd)
applyArgs init args =
  case getOpt RequireOrder descs args of
       MkResult opts n  []      []       =>
         let conf = foldl (flip apply) init opts
          in map (conf,) (cmd n)

       MkResult _    _ (u :: _) _        => Left (UnknownArg u)
       MkResult _    _ _        (e :: _) => Left (ErroneousArg e)

--------------------------------------------------------------------------------
--          Usage Info
--------------------------------------------------------------------------------

progName : String
progName = "pack"

||| Application info printed with the `--help` action.
export
usageInfo : String
usageInfo = """
  Usage: \{progName} [options] COMMAND [args]

  Options:
  \{usageInfo "" descs}

  Commands:
    help
      Print this help text.

    build <.ipkg file>
      Build a local package given as an `.ipkg` file.

    typecheck <.ipkg file>
      Typecheck a local package given as an `.ipkg` file.

    install [package or .ipkg file...]
      Install the given package(s) and/or local .ipkg files.

    install-with-src [package or .ipkg file...]
      Install the given package(s) and/or local .ipkg files
      together with their sources.

    install-app [package or .ipkg file...]
      Install the given application(s).

    remove [package or .ipkg file...]
      Remove installed librarie(s).

    update-db
      Update the pack data base by downloading the package collections
      from https://github.com/stefan-hoeck/idris2-pack-db.

    exec <package or .ipkg file> [args]
      Build and run an executable given either as
      an `.ipkg` file or a known package from the
      database passing it the given command line arguments.

    check-db <repository>
      Check the given package collection by freshly
      building and installing its designated Idris2 executable
      followed by installing all listed packages.

    extract-from-head <output file>
      Extracts a new unstable data collection from the HEAD
      colletion by querying the GitHub repository of every
      package for the latest commit and writing everything in
      a new file and stores it in the given file.
  """