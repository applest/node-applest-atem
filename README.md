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

atem.changeProgramInput(1);
atem.changePreviewInput(2);
atem.autoTransition();
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
1. Fork it ( https://github.com/miyukki/node-atem )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
