{ stdenvNoCC, fetchurl, unzip, nodejs, makeWrapper }:
stdenvNoCC.mkDerivation rec {
  pname = "browser-control-mcp";
  version = "1.5.2";

  src = fetchurl {
    url = "https://github.com/eyalzh/browser-control-mcp/releases/download/v${version}/mcp-server-v${version}.dxt";
    hash = "sha256-5slrjoOm7RDbBPWqx44lF6fGjHdd1M6G3KKkbibnOwo=";
  };

  nativeBuildInputs = [ unzip makeWrapper ];

  unpackCmd = "unzip -q $curSrc -d source";
  sourceRoot = "source";

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname}
    cp -r . $out/lib/${pname}
    makeWrapper ${nodejs}/bin/node $out/bin/${pname} \
      --add-flags $out/lib/${pname}/dist/server.js
    runHook postInstall
  '';
}
