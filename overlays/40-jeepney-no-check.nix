final: prev: {
  python313Packages = prev.python313Packages.overrideScope (
    pyFinal: pyPrev: {
      jeepney = pyPrev.jeepney.overridePythonAttrs (old: {
        doCheck = false;
        pythonImportsCheck = [ ];
      });
    }
  );
}
