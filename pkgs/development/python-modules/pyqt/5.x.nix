{ lib, pythonPackages, pkg-config
, dbus
, qmake, lndir
, qtbase
, qtsvg
, qtdeclarative
, qtwebchannel
, withConnectivity ? false, qtconnectivity
, withMultimedia ? false, qtmultimedia
, withWebKit ? false, qtwebkit
, withWebSockets ? false, qtwebsockets
}:

let

  inherit (pythonPackages) buildPythonPackage python isPy3k dbus-python enum34 pyqt-builder;

  sip = if isPy3k then
    pythonPackages.sip
  else
    (pythonPackages.sip_4.override { sip-module = "PyQt5.sip"; }).overridePythonAttrs(oldAttrs: {
      # If we install sip in another folder, then we need to create a __init__.py as well
      # if we want to be able to import it with Python 2.
      # Python 3 could rely on it being an implicit namespace package, however,
      # PyQt5 we made an explicit namespace package so sip should be as well.
      postInstall = ''
        cat << EOF > $out/${python.sitePackages}/PyQt5/__init__.py
        from pkgutil import extend_path
        __path__ = extend_path(__path__, __name__)
        EOF
      '';
    });

  pyqt5_sip = buildPythonPackage rec {
    pname = "PyQt5_sip";
    version = "12.9.0";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "0cmfxb7igahxy74qkq199l6zdxrr75bnxris42fww3ibgjflir6k";
    };

    # There is no test code and the check phase fails with:
    # > error: could not create 'PyQt5/sip.cpython-38-x86_64-linux-gnu.so': No such file or directory
    doCheck = false;
  };

in buildPythonPackage rec {
  pname = "PyQt5";
  version = "5.15.4";
  format = if isPy3k then "pyproject" else "other";

  src = pythonPackages.fetchPypi {
    inherit pname version;
    sha256 = "1gp5jz71nmg58zsm1h4vzhcphf36rbz37qgsfnzal76i1mz5js9a";
  };

  outputs = [ "out" "dev" ];

  dontWrapQtApps = true;

  nativeBuildInputs = [
    pkg-config
    qmake
    lndir
    sip
    qtbase
    qtsvg
    qtdeclarative
    qtwebchannel
  ]
    ++ lib.optional withConnectivity qtconnectivity
    ++ lib.optional withMultimedia qtmultimedia
    ++ lib.optional withWebKit qtwebkit
    ++ lib.optional withWebSockets qtwebsockets
  ;

  buildInputs = [
    dbus
    qtbase
    qtsvg
    qtdeclarative
  ]
    ++ lib.optional withConnectivity qtconnectivity
    ++ lib.optional withWebKit qtwebkit
    ++ lib.optional withWebSockets qtwebsockets
    ++ lib.optional isPy3k pyqt-builder
  ;

  propagatedBuildInputs = [
    dbus-python
  ] ++ (if isPy3k then [ pyqt5_sip ] else [ sip enum34 ]);

  patches = [
    # Fix some wrong assumptions by ./configure.py and ./project.py
    # TODO: figure out how to send this upstream
    ./pyqt5-fix-dbus-mainloop-support.patch
  ];

  passthru = {
    inherit sip;
    multimediaEnabled = withMultimedia;
    webKitEnabled = withWebKit;
    WebSocketsEnabled = withWebSockets;
  };

  # Configure only needed when building with sip 4 (python 2)
  dontConfigure = isPy3k;

  configurePhase = ''
    runHook preConfigure

    export PYTHONPATH=$PYTHONPATH:$out/${python.sitePackages}

    ${python.executable} configure.py  -w \
      --confirm-license \
      --dbus-moduledir=$out/${python.sitePackages}/dbus/mainloop \
      --no-qml-plugin \
      --bindir=$out/bin \
      --destdir=$out/${python.sitePackages} \
      --stubsdir=$out/${python.sitePackages}/PyQt5 \
      --sipdir=$out/share/sip/PyQt5 \
      --designer-plugindir=$out/plugins/designer

    runHook postConfigure
  '';

  postInstall = lib.optionalString (!isPy3k) ''
    ln -s ${sip}/${python.sitePackages}/PyQt5/sip.* $out/${python.sitePackages}/PyQt5/
    for i in $out/bin/*; do
      wrapProgram $i --prefix PYTHONPATH : "$PYTHONPATH"
    done

    # Let's make it a namespace package
    cat << EOF > $out/${python.sitePackages}/PyQt5/__init__.py
    from pkgutil import extend_path
    __path__ = extend_path(__path__, __name__)
    EOF
  '';

  # Checked using pythonImportsCheck
  doCheck = false;

  pythonImportsCheck = [
    "PyQt5"
    "PyQt5.QtCore"
    "PyQt5.QtQml"
    "PyQt5.QtWidgets"
    "PyQt5.QtGui"
  ]
    ++ lib.optional withWebSockets "PyQt5.QtWebSockets"
    ++ lib.optional withWebKit "PyQt5.QtWebKit"
    ++ lib.optional withMultimedia "PyQt5.QtMultimedia"
    ++ lib.optional withConnectivity "PyQt5.QtConnectivity"
  ;

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Python bindings for Qt5";
    homepage    = "https://riverbankcomputing.com/";
    license     = licenses.gpl3Only;
    platforms   = platforms.mesaPlatforms;
    maintainers = with maintainers; [ sander ];
  };
}
