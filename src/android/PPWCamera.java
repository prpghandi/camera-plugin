package com.appnovation.ppw_camera;

import java.io.File;
import java.io.Serializable;

import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.content.Intent;
import android.os.Bundle;
import android.os.Parcelable;
import android.provider.MediaStore;
import android.widget.Toast;
import android.util.Log;
import android.content.ContentValues;
import android.database.Cursor;

public class PPWCamera extends CordovaPlugin {

  private static final String TAG = "PPWCameraPlugin";

	public static final String ACTION_OPEN_CAMERA = "openCamera";
	public static final String ACTION_CLOSE_CAMERA = "closeCamera";

	public static CallbackContext openCameraCallbackContext;
	public static JSONArray openCameraJsonArrayArgs;

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callback) {

		if (!checkCameraHardware(cordova.getActivity().getApplicationContext())) {
			callback.error("Camera not found");
			return false;
    	}

	    if (action.compareToIgnoreCase(ACTION_CLOSE_CAMERA) == 0) {
	    	PPWCameraActivity a = PPWCameraActivity.getInstance();
	    	if (a != null) {
	    		a.finish();
	    		return true;
	    	}
	    	callback.error("camera could not be closed. camera activity is not available");
	    	return false;

	    }

	    if (action.compareToIgnoreCase(ACTION_OPEN_CAMERA) != 0) {
			callback.error("invalid command");
			return false;
	    }

		openCameraCallbackContext = callback;
    	openCameraJsonArrayArgs = args;

		try {
			if (this.cordova != null) {
				this.cordova.setActivityResultCallback(this);
				Intent i = new Intent(this.cordova.getActivity(), PPWCameraActivity.class);
				this.cordova.getActivity().startActivity(i);
			}
		}
		catch (Exception e) {
			System.err.println("Exception: " + e.getMessage());
			callback.error(e.getMessage());
			return false;
		}
		return true;
	}

		/** Check if this device has a camera */
	private boolean checkCameraHardware(Context context) {
	    if (context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA)){
			// this device has a camera
			return true;
	    } else {
			// no camera on this device
			return false;
	    }
	}
}