var exec = require('cordova/exec');

exports.openCamera = function(arg0, success, error) {
    exec(success, error, "ppw_camera_plugin", "openCamera", [arg0]);
};
