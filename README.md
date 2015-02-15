node-atem
========
A module to control Blackmagic Design ATEM Switchers.
**This module is under development now.**

Usage
--------
```javascript
var ATEM = require('node-atem');

var atem = new ATEM();
atem.connect('192.168.1.220') // Replace your ATEM Switcher IP

atem.setProgramInput(1);
atem.setPreviewInput(2);
atem.changeTransitionAuto();
```

```javascript
var ATEM = require('node-atem');

var atem = new ATEM();
atem.connect('192.168.1.220') // Replace your ATEM Switcher IP

atem.on('change', function() {
//  console.log(change);
});
```

Installation
--------
```shell
$ npm install node-atem --save
```

Demo
--------
See atem-web-controller.

Contributing
--------

Donate
--------
