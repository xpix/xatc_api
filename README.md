# xatc_api
Api to get correct XATC gcode for different models and different cnc controllers

The RESTful Service is ready to a small test. 

Ok, what is happen here. In example, in some CNC controller we would replace the "M6 T3" Command with the complete XATC Gcode, then call via getJSON this URL:

```http://xpix.eu:8080/xatc/replace/[M6 Command]/[old toolnumber or zero]```

i.e.: (get T6 and put T3 back)
```
http://xpix.eu:8080/xatc/replace/M6 T6/3
http://xpix.eu:8080/xatc/replace/M6%20T6/3 (better url encoded)
```

Then you get the complete Gcode as JSON list, try it BUT this is experimental gcode and complete untested. It's just a demonstration what this service can do for you! :)

I have to test this complete Gcode with the new g2core Firmware from synthetos (https://github.com/synthetos/g2) .. i work on it on his new board gQuintic, more info's coming soon.

The Service is realized via perl framework http://www.mojolicious.org/
