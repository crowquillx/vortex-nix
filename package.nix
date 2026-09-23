{
  lib,
  stdenv,
  src,
  autoPatchelfHook,
  copyDesktopItems,
  dotnetCorePackages,
  electron_42-bin,
  fetchPnpmDeps,
  fetchurl,
  fontconfig,
  gitMinimal,
  makeDesktopItem,
  makeWrapper,
  node-gyp,
  nodejs_24,
  pnpm_11,
  pnpmConfigHook,
  pkg-config,
  python3,
  steam-run-free,
  writeShellScript,
}:

let
  version = "2.7.0";

  pnpm = pnpm_11.override { nodejs-slim = nodejs_24; };
  electron = electron_42-bin;

  levelPivot = fetchurl {
    url = "https://nexus-mods.github.io/duckdb-level-pivot/current_release/v1.5.1/linux_amd64/level_pivot.duckdb_extension.gz";
    hash = "sha256-+CKjeCbhl1VXrv+7MPwaea1KEEi0VaQpugtr8DEBMGU=";
  };

  # pnpm's deploy command needs the original archives for Git-hosted
  # dependencies. fetchPnpmDeps installs their contents but does not retain
  # those archives in the form deploy expects.
  gitDependencyTarballs =
    map
      (
        line:
        let
          match = builtins.match ".*integrity: (sha[0-9]+-[A-Za-z0-9+/=]+), tarball: https://codeload.github.com/([^ }]+)/tar.gz/([0-9a-f]+).*" line;
        in
        if match == null then
          throw "Unsupported Git dependency resolution in pnpm-lock.yaml: ${line}"
        else
          let
            repository = builtins.elemAt match 1;
            revision = builtins.elemAt match 2;
            url = "https://codeload.github.com/${repository}/tar.gz/${revision}";
          in
          {
            inherit repository revision url;
            archive = fetchurl {
              inherit url;
              hash = builtins.head match;
            };
          }
      )
      (
        builtins.filter (
          line: lib.hasInfix "resolution:" line && lib.hasInfix "https://codeload.github.com/" line
        ) (lib.splitString "\n" (builtins.readFile "${src}/pnpm-lock.yaml"))
      );

  dotnetProbe = writeShellScript "dotnetprobe" ''
    requiredMajor="''${1:-9}"
    version=""
    while read -r runtime candidate _; do
      if [[ "$runtime" == "Microsoft.NETCore.App" ]]; then
        version="$candidate"
      fi
    done < <(${dotnetCorePackages.runtime_9_0}/bin/dotnet --list-runtimes)
    if [[ -z "$version" ]]; then
      echo "Error: Could not find the .NET runtime" >&2
      exit 1
    fi
    actualMajor="''${version%%.*}"
    if (( actualMajor < requiredMajor )); then
      echo "Error: Requires .NET $requiredMajor or higher but found .NET $version" >&2
      exit 1
    fi
    echo "Success: Found .NET $version"
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "vortex";
  inherit version src;

  patches = [ ./vortex-linux.patch ];

  pnpmDeps = fetchPnpmDeps {
    pname = "${finalAttrs.pname}-pnpm-deps";
    inherit (finalAttrs) version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-BzqaPe3aaERc5gN399/Z4zBYPlIFXIXQAhfrtoWqGZ4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    gitMinimal
    makeWrapper
    node-gyp
    nodejs_24
    pnpm
    pnpmConfigHook
    pkg-config
    (python3.withPackages (ps: [ ps.setuptools ]))
  ];

  buildInputs = [
    fontconfig
    (lib.getLib stdenv.cc.cc)
  ];

  env = {
    CI = "1";
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    NO_PARALLEL = "1";
    NX_DAEMON = "false";
    NX_NATIVE_COMMAND_RUNNER = "false";
    NX_TASKS_RUNNER_DYNAMIC_OUTPUT = "false";
    PNPM_CONFIG_REPORTER = "append-only";
    VORTEX_SKIP_SUBMODULES = "1";
    VORTEX_VERSION = version;
    npm_config_runtime = "electron";
    npm_config_target = "42.3.3";
    npm_config_nodedir = electron.headers;
  };

  postPatch = ''
    ${lib.concatMapStringsSep "\n" (dependency: ''
      substituteInPlace pnpm-workspace.yaml pnpm-lock.yaml \
        --replace-quiet \
          "github:${dependency.repository}#${dependency.revision}" \
          "file:${dependency.archive}"
      substituteInPlace pnpm-lock.yaml \
        --replace-fail "${dependency.url}" "file:${dependency.archive}"
    '') gitDependencyTarballs}

    substituteInPlace src/main/package.json \
      --replace-fail '"version": "1.0.0"' '"version": "${version}"'

    # Generic Linux Proton binaries need NixOS' FHS runner. The environment
    # variable preserves upstream behaviour on other distributions.
    substituteInPlace src/renderer/src/util/linux/proton.ts \
      --replace-fail \
        'executable: path.join(protonPath, "proton"),' \
        'executable: process.env.VORTEX_PROTON_WRAPPER || path.join(protonPath, "proton"),' \
      --replace-fail \
        'args: ["run", exePath, ...args],' \
        'args: process.env.VORTEX_PROTON_WRAPPER ? [path.join(protonPath, "proton"), "run", exePath, ...args] : ["run", exePath, ...args],'

    # This derivation only produces the Linux build, so do not ask the asset
    # preparation step to download the Windows copy as well.
    substituteInPlace src/main/duckdb-extensions.json \
      --replace-fail \
        '"platforms": ["windows_amd64", "linux_amd64"]' \
        '"platforms": ["linux_amd64"]'

    # The build normally downloads this extension. Supply the pinned artifact
    # so the derivation remains network-independent.
    mkdir -p src/main/build/duckdb-extensions/v1.5.1/linux_amd64
    gzip -dc ${levelPivot} > src/main/build/duckdb-extensions/v1.5.1/linux_amd64/level_pivot.duckdb_extension

    # The upstream helper is a tiny .NET version check. Shipping an equivalent
    # script avoids an otherwise network-dependent self-contained .NET build.
    mkdir -p tools/dotnetprobe/dist
    cp ${dotnetProbe} tools/dotnetprobe/dist/dotnetprobe
    python3 - <<'PYTHON'
    import json
    from pathlib import Path

    path = Path("tools/dotnetprobe/project.json")
    project = json.loads(path.read_text())
    target = project["targets"]["build"]
    target["options"]["command"] = "test -x dist/dotnetprobe"
    target["inputs"] = []
    target["cache"] = False
    path.write_text(json.dumps(project))
    PYTHON
  '';

  buildPhase = ''
    runHook preBuild

    node-gyp rebuild \
      --directory extensions/theme-switcher/node_modules/font-scanner

    pnpm cross-env NODE_ENV=production \
      pnpm nx run @vortex/main:build --output-style=stream --parallel=4

    # gamebryo-plugin-management is deliberately not built by upstream on
    # Linux. Do not bundle extensions which require it, otherwise they try to
    # download the unavailable dependency at startup and display an error.
    rm -rf \
      src/main/build/bundledPlugins/gamebryo-archive-check \
      src/main/build/bundledPlugins/gamebryo-plugin-indexlock

    pushd src/main
    pnpm cross-env \
      pnpm_config_inject_workspace_packages=true \
      pnpm_config_ignore_scripts=true \
      pnpm_config_node_linker=hoisted \
      pnpm_config_offline=true \
      pnpm -F @vortex/main deploy ./dist
    node dist/prepare-dist-package.mjs

    pushd dist
    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist

    ../node_modules/.bin/electron-builder \
      --config ./electron-builder.config.json \
      --publish never \
      --linux dir \
      --x64 \
      -c.electronDist=electron-dist \
      -c.electronVersion=${electron.version} \
      -c.compression=store
    popd
    popd

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/vortex
    cp -r dist/linux-unpacked/resources $out/share/vortex/
    find $out/share/vortex -type f -name '*.musl.node' -delete
    install -Dm755 ${dotnetProbe} \
      $out/share/vortex/resources/app.asar.unpacked/assets/dotnetprobe

    makeWrapper ${lib.getExe electron} $out/bin/vortex \
      --add-flags $out/share/vortex/resources/app.asar \
      --unset ELECTRON_RUN_AS_NODE \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          (lib.getLib stdenv.cc.cc)
          stdenv.cc.cc.libgcc
        ]
      } \
      --set DOTNET_ROOT ${dotnetCorePackages.runtime_9_0}/share/dotnet \
      --set ELECTRON_TRASH gio \
      --set IGNORE_UPDATES yes \
      --set VORTEX_PROTON_WRAPPER ${lib.getExe steam-run-free} \
      --inherit-argv0

    makeWrapper $out/bin/vortex $out/bin/vortex-nxm \
      --add-flags --download

    install -Dm644 assets/images/vortex.png \
      $out/share/icons/hicolor/256x256/apps/vortex.png

    runHook postInstall
  '';

  preFixup = ''
    restoreDuckDbExtension() {
      # DuckDB verifies a signed metadata footer. patchelf changes the file and
      # invalidates that footer, so restore it after autoPatchelf has run.
      gzip -dc ${levelPivot} > \
        $out/share/vortex/resources/app.asar.unpacked/duckdb-extensions/v1.5.1/linux_amd64/level_pivot.duckdb_extension
    }
    postFixupHooks+=(restoreDuckDbExtension)
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "vortex";
      desktopName = "Vortex";
      genericName = "Mod Manager";
      comment = "Mod manager for PC games from Nexus Mods";
      exec = "vortex";
      icon = "vortex";
      categories = [
        "Game"
        "Utility"
      ];
      startupWMClass = "Vortex";
      keywords = [
        "mod"
        "mods"
        "modding"
        "nexus"
        "games"
      ];
    })
    (makeDesktopItem {
      name = "vortex-nxm";
      desktopName = "Vortex NXM Handler";
      noDisplay = true;
      exec = "vortex-nxm %u";
      mimeTypes = [ "x-scheme-handler/nxm" ];
    })
  ];

  meta = {
    description = "Nexus Mods' mod manager";
    homepage = "https://github.com/Nexus-Mods/Vortex";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "vortex";
  };
})
