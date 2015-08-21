/**
 * @description Runer for jsformater
 * support nodejs and v8 interpretator
 */
var fs = require('fs');
var exec = require('child_process').exec;

(function (contentPath) {
  exec('/usr/bin/semistandard "' + contentPath + '" --format', function (e, so, se) {
    fs.readFile(contentPath, {
      encoding: 'utf8'
    }, function (err, data) {
      if (!err) {
        console.log(data.replace(/[\r\n]+$/g, ''));
      }
    });
  });
}).apply(this, (typeof process === 'object' && process.argv.splice(3)));
