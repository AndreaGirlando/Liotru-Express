# Manrope

Fonte: https://github.com/google/fonts/tree/main/ofl/manrope
Licenza SIL OFL 1.1, inclusa in `OFL.txt`.

`Manrope.ttf` è la fonte variabile originale (asse `wght`, default 200).
Gli altri cinque TTF sono istanze statiche 400–800, generate con FontTools
4.61.1 e `instantiateVariableFont(..., {"wght": weight}, updateFontNames=True)`.
Il file originale è conservato per riprodurle; solo le istanze statiche e la
licenza vengono incluse nell’APK. Questo evita che il renderer scelga il peso
200 originale anche quando l’interfaccia richiede un titolo in grassetto.
