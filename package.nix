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
  version = "2.3.0";

  pnpm = pnpm_11.override { nodejs-slim = nodejs_24; };
  electron = electron_42-bin;

  levelPivot = fetchurl {
    url = "https://nexus-mods.github.io/duckdb-level-pivot/current_release/v1.5.1/linux_amd64/level_pivot.duckdb_extension.gz";
    hash = "sha256-AThZxVr2SnbkegSTpoKhIdKfzh9lyR4863qgYRzLpDo=";
  };

  nexusApiSchema = fetchurl {
    url = "https://api.nexusmods.com/openapi.yaml";
    hash = "sha256-CpyTUyjH9msOMxOI5QPdLRQQlHzmEN7ls9WlzEy+Co0=";
  };

  # pnpm's deploy command needs the original archives for Git-hosted
  # dependencies. fetchPnpmDeps installs their contents but does not retain
  # those archives in the form deploy expects.
  gitDependencyTarballs = [
    (fetchurl {
      name = "7z-bin.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/7z-bin/tar.gz/3298c42e69e3220dc39694bc2f610c077c3e213a";
      hash = "sha512-5CSzuhfDSqMUAz2sHpwgD8sUjg+VLqp30xeSyPnLQvWX9gLTxG5Sk6CkF0ckuDGnbE1zHduU2DvSCAl7CxQZZw==";
    })
    (fetchurl {
      name = "nexus-api.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-nexus-api/tar.gz/97ad222d2d7aca05e581390eb85be9af22833fba";
      hash = "sha512-+78ynmZZCtkbSljcu5wTVktuUwRgexyecsWCGWkJvxvKHql8hNNhsmPMCfDBQPKWT20WijfYVMJ589nAD/yhrQ==";
    })
    (fetchurl {
      name = "bbcode-to-react.tar.gz";
      url = "https://codeload.github.com/TanninOne/bbcode-to-react/tar.gz/c67356006470e5066ea447e04a3968dca367339d";
      hash = "sha512-JCnCmMGZ0KRA5ZNnt0/fSA925S+tEiod6UwS+h5G2veMJHWhNMRv26udPcQ4Yj6EBG593dE+jbbfm22cN9K06Q==";
    })
    (fetchurl {
      name = "bsatk.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-bsatk/tar.gz/5a3d15fae2177bfb0a42b794d3afb21eda563c59";
      hash = "sha512-x0ygf1FRt9qc22ffqKoSpwZwct/dNw8CVh3R9Djiyi3OzmGf1soOdWwFXwysHC3JEkSoeXKV0EXzPeGdOG8Q4Q==";
    })
    (fetchurl {
      name = "drivelist.tar.gz";
      url = "https://codeload.github.com/TanninOne/drivelist/tar.gz/720d1890db11482ec05fc0f6aa176cfa6e6844dd";
      hash = "sha512-hhu4lTOqu9NsxCdlmBU6IiG5q4CmfTIEaREKilE53AxTdAqaJeV8TFn/gds8i0MCw4KXD66y/scwlIRu2L/yAQ==";
    })
    (fetchurl {
      name = "electron-redux.tar.gz";
      url = "https://codeload.github.com/TanninOne/electron-redux/tar.gz/66bbd9d389579806e8c4ebd87bd513a668cc64a8";
      hash = "sha512-3JEjTg+Sj6ABicP0k7xhE0xNyC2Dc6oTdhPWrHxSrCY7PXGHFBfubaaD4c0u+GfKxhsSxDBOT+GqywBXjVzc9w==";
    })
    (fetchurl {
      name = "json-socket.tar.gz";
      url = "https://codeload.github.com/foi/node-json-socket/tar.gz/d56c8e2938fa4284c4001b815d9b6e4a92b5c07b";
      hash = "sha512-UQ1HXQfzmW4YvvKaMVnZa0eTtr9y0fkvNBLFSQT7ulOm+U2231U+7Pw+kM7k3AzB6lBT7s9nzK1avEOFqctxUQ==";
    })
    (fetchurl {
      name = "loot.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-loot/tar.gz/7b6028fb2caeb3a2af6a0c3d68630c033cc01e8d";
      hash = "sha512-/bqsW+y5n7JJNUiclZpvIFxT4DWVa7PXnQLHpiWQZvQ4FB1zW1XbC8brJTh6SAebh9E8MyUEnst/jQZhJ1hwtA==";
    })
    (fetchurl {
      name = "modmeta-db.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/modmeta-db/tar.gz/daa8935b6e38e255ec192c908adfce35d47c0336";
      hash = "sha512-TCtHcETebXwNlKz4h4sSbod4aUCycvS8J9mlknKJFhCxJZoU3VmZUzKYi7GHe6ERTMM5dYZc8FBePy72Jgu/Vw==";
    })
    (fetchurl {
      name = "node-7z.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-7z/tar.gz/b75def8d0d7d81a03f4526c52b8ada9a34a06479";
      hash = "sha512-hFgO6i7T1ZGj3QwgI4OhpbevPJRQI6DBJq1h2VFxPnyO6Nx9NLTu76EmokUDqUMo0ei7IqMOwwD1soEC3IqWUQ==";
    })
    (fetchurl {
      name = "permissions.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-permissions/tar.gz/7c1b6f1d6437f2238be51316de823b0fbd63e4c0";
      hash = "sha512-fhaMTn3oR2R31Xpp2Prb849j4tVh2Skav4IskygXGCQquP1ZgqrwrkvT9krDywxY85gRi5QGYdKN/9uysrgTCg==";
    })
    (fetchurl {
      name = "rimraf.tar.gz";
      url = "https://codeload.github.com/TanninOne/rimraf/tar.gz/7b8b70d4e8783cd233fca3283cf1f930af4e39c2";
      hash = "sha256-G2qc0YFw/zBg5lFD/bWCtVu+KU49JvWSIQFRtako7U8=";
    })
    (fetchurl {
      name = "simple-vdf.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/vdf-parser/tar.gz/df279ff89cb480597544d3029e12f90cb8c79464";
      hash = "sha512-H52FVQ84mJle6bqHMDCRpQMFjzgdJMdJznliEG41ZZvhsGZTK1RaJPYWrkx+ce7+zRqNjvCUMWo3b7vEVTZ1PA==";
    })
    (fetchurl {
      name = "turbowalk.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-turbowalk/tar.gz/3502f6ffc3f9eb55fe1c9c097b4e4772edce0c0f";
      hash = "sha512-GPt3rDAkgrD72xxVLWKVXuLhcTP0Wg6Pt3S8t97WZ9S9O1ifZ2QOoMhLocKStHTkLlAEkisnB81QidQ/PxsdZA==";
    })
    (fetchurl {
      name = "vortex-parse-ini.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/vortex-parse-ini/tar.gz/2425af99d1cff2331ccf3aacfa892c314e99e18d";
      hash = "sha512-iB8Btg2VWED+nYlOqyt0xFoGbZIbQkiAny3J1ftI9IcbKwQweEfQ0uTYgXZZba9p6O8EaTCLXBvRe/m/uMUCqg==";
    })
    (fetchurl {
      name = "wholocks.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-wholocks/tar.gz/28da3bcf312312e577d7c636799a59011998b4af";
      hash = "sha512-lWy1M2tsoySZShiQZrfFKJi02k3y2Cx1XahGB5Tz5AI2P166F0o4d3lpUM81/AQsTV8NfRdhHNrNsjYst9H3Ww==";
    })
    (fetchurl {
      name = "winapi-bindings.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/node-winapi-bindings/tar.gz/faa92afe3320731e98abc15b3f5f19c60896d7c1";
      hash = "sha512-6EWxHP64L7nc/VBb/szJflKBvG2VnZ5cSd//R8ocau7UgrtMINm7MMHxcw8+EX9Z4BU+L0dF4rz6yQpwt5/Alw==";
    })
    (fetchurl {
      name = "7z-bin-legacy.tar.gz";
      url = "https://codeload.github.com/Nexus-Mods/7z-bin/tar.gz/025786f01319526b56400b0410af6268adc1125c";
      hash = "sha256-Tf84krgoWQSh/1yH0DO5Fik83fTq1iYkguZVQwxKAXw=";
    })
  ];

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
    hash = "sha256-TLuLIdNxIrKbzt8/ynHKWP4hQSrSFF3/zEXuZpWYbsI=";
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
    NX_TASKS_RUNNER_DYNAMIC_OUTPUT = "false";
    PNPM_CONFIG_REPORTER = "append-only";
    VORTEX_SKIP_SUBMODULES = "1";
    VORTEX_VERSION = version;
    npm_config_runtime = "electron";
    npm_config_target = "42.3.3";
    npm_config_nodedir = electron.headers;
  };

  postPatch = ''
    pinGitDependency() {
      local repository="$1"
      local revision="$2"
      local archive="$3"

      substituteInPlace pnpm-workspace.yaml \
        --replace-fail \
          "git+https://github.com/$repository#$revision" \
          "file:$archive"
      substituteInPlace pnpm-lock.yaml \
        --replace-fail \
          "git+https://github.com/$repository#$revision" \
          "file:$archive"
      substituteInPlace pnpm-lock.yaml \
        --replace-fail \
          "https://codeload.github.com/$repository/tar.gz/$revision" \
          "file:$archive"
    }

    pinGitDependency Nexus-Mods/7z-bin 3298c42e69e3220dc39694bc2f610c077c3e213a ${builtins.elemAt gitDependencyTarballs 0}
    pinGitDependency Nexus-Mods/node-nexus-api 97ad222d2d7aca05e581390eb85be9af22833fba ${builtins.elemAt gitDependencyTarballs 1}
    pinGitDependency TanninOne/bbcode-to-react c67356006470e5066ea447e04a3968dca367339d ${builtins.elemAt gitDependencyTarballs 2}
    pinGitDependency Nexus-Mods/node-bsatk 5a3d15fae2177bfb0a42b794d3afb21eda563c59 ${builtins.elemAt gitDependencyTarballs 3}
    pinGitDependency TanninOne/drivelist 720d1890db11482ec05fc0f6aa176cfa6e6844dd ${builtins.elemAt gitDependencyTarballs 4}
    pinGitDependency TanninOne/electron-redux 66bbd9d389579806e8c4ebd87bd513a668cc64a8 ${builtins.elemAt gitDependencyTarballs 5}
    pinGitDependency foi/node-json-socket d56c8e2938fa4284c4001b815d9b6e4a92b5c07b ${builtins.elemAt gitDependencyTarballs 6}
    pinGitDependency Nexus-Mods/node-loot 7b6028fb2caeb3a2af6a0c3d68630c033cc01e8d ${builtins.elemAt gitDependencyTarballs 7}
    pinGitDependency Nexus-Mods/modmeta-db daa8935b6e38e255ec192c908adfce35d47c0336 ${builtins.elemAt gitDependencyTarballs 8}
    pinGitDependency Nexus-Mods/node-7z b75def8d0d7d81a03f4526c52b8ada9a34a06479 ${builtins.elemAt gitDependencyTarballs 9}
    pinGitDependency Nexus-Mods/node-permissions 7c1b6f1d6437f2238be51316de823b0fbd63e4c0 ${builtins.elemAt gitDependencyTarballs 10}
    pinGitDependency TanninOne/rimraf 7b8b70d4e8783cd233fca3283cf1f930af4e39c2 ${builtins.elemAt gitDependencyTarballs 11}
    pinGitDependency Nexus-Mods/vdf-parser df279ff89cb480597544d3029e12f90cb8c79464 ${builtins.elemAt gitDependencyTarballs 12}
    pinGitDependency Nexus-Mods/node-turbowalk 3502f6ffc3f9eb55fe1c9c097b4e4772edce0c0f ${builtins.elemAt gitDependencyTarballs 13}
    pinGitDependency Nexus-Mods/vortex-parse-ini 2425af99d1cff2331ccf3aacfa892c314e99e18d ${builtins.elemAt gitDependencyTarballs 14}
    pinGitDependency Nexus-Mods/node-wholocks 28da3bcf312312e577d7c636799a59011998b4af ${builtins.elemAt gitDependencyTarballs 15}
    pinGitDependency Nexus-Mods/node-winapi-bindings faa92afe3320731e98abc15b3f5f19c60896d7c1 ${builtins.elemAt gitDependencyTarballs 16}
    substituteInPlace pnpm-lock.yaml \
      --replace-fail \
        "https://codeload.github.com/Nexus-Mods/7z-bin/tar.gz/025786f01319526b56400b0410af6268adc1125c" \
        "file:${builtins.elemAt gitDependencyTarballs 17}"

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

    # API bindings are normally generated from a live endpoint. Build from a
    # fixed snapshot so that Nix's network-isolated build remains reproducible.
    substituteInPlace packages/nexus-api-v3/package.json \
      --replace-fail \
        'https://api.nexusmods.com/openapi.yaml' \
        '${nexusApiSchema}'

    # The build normally downloads this extension. Supply the pinned artifact
    # so the derivation remains network-independent.
    mkdir -p src/main/build/duckdb-extensions/v1.5.1/linux_amd64
    gzip -dc ${levelPivot} > src/main/build/duckdb-extensions/v1.5.1/linux_amd64/level_pivot.duckdb_extension

    # The upstream helper is a tiny .NET version check. Shipping an equivalent
    # script avoids an otherwise network-dependent self-contained .NET build.
    mkdir -p tools/dotnetprobe/dist
    cp ${dotnetProbe} tools/dotnetprobe/dist/dotnetprobe
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
      exec = "vortex-nxm %u";
      icon = "vortex";
      categories = [
        "Game"
        "Utility"
      ];
      mimeTypes = [ "x-scheme-handler/nxm" ];
      startupWMClass = "Vortex";
      keywords = [
        "mod"
        "mods"
        "modding"
        "nexus"
        "games"
      ];
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
