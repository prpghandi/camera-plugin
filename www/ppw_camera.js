var PPWCamera = {
	getPicture: function(options, success, failure){
		cordova.exec(success, failure, "PPWCamera", "openCamera", [options]);
	},
	closeCamera: function(options, success, failure) {
		cordova.exec(success, failure, "PPWCamera", "closeCamera", [options]);
	}
};
module.exports = PPWCamera;
