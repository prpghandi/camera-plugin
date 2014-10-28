var exec = require('cordova/exec');

exports.coolMethod = function(arg0, success, error) {
    exec(success, error, "ppw_camera_plugin", "coolMethod", [arg0]);
};
