var PPWCamera = {
	getPicture: function(options, success, failure){
		cordova.exec(success, failure, "PPWCamera", "openCamera", [options]);
	}
};
module.exports = PPWCamera;
