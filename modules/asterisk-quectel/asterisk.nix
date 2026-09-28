{
  symlinkJoin,
  makeBinaryWrapper,
  asterisk,
  chan-quectel,
}:
# services.asterisk loads modules from ${package}/lib/asterisk/modules only,
# so chan_quectel has to be joined into the package
symlinkJoin {
  name = "asterisk-quectel-${asterisk.version}";
  paths = [asterisk chan-quectel];
  nativeBuildInputs = [makeBinaryWrapper];

  # services.asterisk seeds /var/lib/asterisk from var/: real files, not
  # symlinks into a store path that is later garbage collected. The CLI's
  # built-in config points into the store, so give it the system's config.
  postBuild = ''
    rm -r $out/var
    cp -r ${asterisk}/var $out/var
    for bin in asterisk rasterisk; do
      rm $out/bin/$bin
      makeBinaryWrapper ${asterisk}/bin/$bin $out/bin/$bin --add-flags "-C /etc/asterisk/asterisk.conf"
    done
  '';

  passthru = {inherit (asterisk) version;};
}
