(1001)
(T1  D=1.5 CR=0. - ZMIN=-4. - SCHAFTFRSER)
(T2  D=1.0 CR=0. - ZMIN=-4. - SCHAFTFRSER)
(T2  D=0.5 CR=0. - ZMIN=-4. - SCHAFTFRSER)

G0 G90 G94 G17
G21
G53 Z0.

(2D CONTOUR2)
M5
M9
T1 M6
M3 S8000
G54
M9
G0 X9.503 Y9.704
