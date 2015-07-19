ATEM Specification
========
This document is the unofficial specification of control Blackmagic Design(BMD) ATEM Switcher.

Introduction
--------
Blackmagic ATEM Switcher can be controlled by UDP protocol, port 9910.

Packet specification
--------

### Send packet structure
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Flags  |    Packet Length    |          Session Id           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Echo Data           |               ?               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|               ?               | Packet Id |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Receive packet structure
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Flags  |    Packet Length    |          Session Id           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                ?                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                ?                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          Commands...                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Flags
```
Flags[0] = Pong
Flags[1] =
Flags[2] = Connected?
Flags[3] = Hello
Flags[4] = Ping
```

### Command structure
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Command Length         |           Checksum?           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Command Name                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Command Data...                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

----

文字はヌル文字以降は適当な値が入っていることがある。

### PrgI (Program Input)

Packet structure
```
0   1   2   3   4
+---+---+---+---+
| 0 |18 |Channel|
+---+---+---+---+
```

Packet log
```
PrgI <Buffer 00 00 00 05>
```

### PrvI (Preview Input)

Packet structure
```
0   1   2   3   4   5   6   7   8
+---+---+---+---+---+---+---+---+
| 0 |18 |Channel| 0 |4d |49 |50 |
+---+---+---+---+---+---+---+---+
```

Packet log
```
PrvI <Buffer 00 32 00 02 00 00 00 0a>
```

### InPr (Input Preference?)

Packet structure
```
0                                       1
0   1   2   3   4   5   6   7   8   9   0   1   2   3   4   5
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
|Channel|                       Name                        |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
|   Name    |     Label     | InMsk | Input | - | - | - | - |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| - | - | *Input = (0=Bar, 1=SDI, 2=HDMI, 256=None)
+---+---+
```

Packet log after label
```
InPr 0     <Buffer 01 00 01 00 01 f0 12 01 00 dc>
InPr 1     <Buffer 00 02 00 02 00 e0 12 01 01 a4>
InPr 2     <Buffer 00 02 00 02 00 b4 12 01 01 40>
InPr 3     <Buffer 00 03 00 02 00 00 12 01 01 e8>
InPr 4     <Buffer 00 03 00 01 00 8c 12 01 01 b8>
InPr 5     <Buffer 00 01 00 01 00 b8 12 01 01 80>
InPr 6     <Buffer 00 01 00 01 00 3c 12 01 01 84>
InPr 1000  <Buffer 00 00 01 00 02 a4 12 01 01 a2>
InPr 2001  <Buffer 01 00 01 00 03 c8 02 01 00 dc>
InPr 2002  <Buffer 01 00 01 00 03 00 02 01 00 14>
InPr 3010  <Buffer 01 00 01 00 04 e8 12 01 00 c8>
InPr 3011  <Buffer 01 00 01 00 05 8c 12 01 00 08>
InPr 3020  <Buffer 01 00 01 00 04 14 12 01 00 00>
InPr 3021  <Buffer 01 00 01 00 05 69 12 01 00 90>
InPr 10010 <Buffer 01 00 01 00 80 28 02 00 00 74>
InPr 10011 <Buffer 01 00 01 00 80 80 02 00 00 bc>
InPr 7001  <Buffer 01 00 01 00 80 00 02 00 00 00>
InPr 7002  <Buffer 01 00 01 00 80 6c 02 00 00 90>
```

### TrSS (Transition Style State)

Packet structure
```
0   1   2   3   4   5   6   7   8
+---+---+---+---+---+---+---+---+
| Style | 1 | - | - | - | 0 | 0 |
+---+---+---+---+---+---+---+---+
```

### FtbS (Fade to black State)
```
# Fade to black
# buf0 = ?
# 1 = blacking
# 2 = working
# 3 = frames
```

### AMLv (Audio Monitor Level)
If you get audio monitor level, must send `SALN (Send Audio Level Number)` command.


### AMIP (Audio Monitor Input Preference?)

Packet structure
```
0                                       1
0   1   2   3   4   5   6   7   8   9   0   1   2   3   4   5
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
|Channel| 0 | 1 |Channel|Channel|Sta| 3 | Gain  |  Pan  | 0 |
+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
| 5 | *Sta = (0=OFF, 1=ON, 2=AFV)
+---+
```

Send command specification
--------

## Input mapping
| #     | Name         |
| ----- | ------------ |
| 0     | Black        |
| 1     | Cam1         |
| 2     | Cam2         |
| 3     | Cam3         |
| 4     | Cam4         |
| 5     | Cam5         |
| 6     | Cam6         |
| 1000  | Color Bars   |
| 2001  | Color 1      |
| 2002  | Color 2      |
| 3010  | Media 1      |
| 3011  | Media 1 Key  |
| 3020  | Media 2      |
| 3021  | Media 2 Key  |
| 7001  | Clean Feed 1 |
| 7002  | Clean Feed 2 |
| 10010 | Program      |
| 10011 | Preview      |
