/**
 * @description Runer for jsformater
 * support nodejs and v8 interpretator
 */
var fs = require('fs');
var exec = require('child_process').exec;

(function(contentPath, options, formatFile, fileType) {
  var cmd = '/usr/bin/semistandard "' + contentPath + '" --fix';
  if (fileType.substr(0, 6) === 'python') {
    var params = ['--in-place'];
    for (var i in fileType.substr(6)) {
      params.push('--aggressive');
    }
    cmd = '/usr/local/bin/autopep8 ' + params.join(' ') + ' "' + contentPath + '"';
  }
  exec(cmd, function(e, so, se) {
    fs.readFile(contentPath, {
      encoding: 'utf8'
    }, function(err, data) {
      if (!err) {
        console.log(data.replace(/[\r\n]+$/g, ''));
      }
    });
  });
}).apply(this, (typeof process === 'object' && process.argv.splice(3)));
