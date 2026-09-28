{
  lib,
  stdenv,
  cmake,
  alsa-lib,
  sqlite,
  asterisk,
  src,
}:
stdenv.mkDerivation {
  pname = "asterisk-chan-quectel";
  version = "0-unstable-${src.lastModifiedDate}";
  inherit src;

  nativeBuildInputs = [cmake];
  buildInputs = [alsa-lib sqlite asterisk];

  meta = {
    description = "Asterisk channel driver for Quectel modems";
    homepage = "https://github.com/harinworks-org/asterisk-chan-quectel";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
