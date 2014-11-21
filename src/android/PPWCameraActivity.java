package com.appnovation.ppw_camera;

import org.apache.cordova.PluginResult;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.hardware.Camera;
import android.os.Bundle;
import android.os.Environment;
import android.os.StatFs;
import android.text.format.Formatter;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.UnsupportedEncodingException;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.List;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

public class PPWCameraActivity extends Activity {

    public static final String TAG = "PPWCameraActivity";

    private static final String SECRET_KEY = "password";

    private Camera mCamera;
    private PPWCameraPreview mPreview;
    private static HashMap<String,String> mDataOutput;
    private int mPhotoWidth;
    private int mPhotoHeight;
    private int mPreviewWidth;
    private int mPreviewHeight;
    private String mEncodingType;
    private int mQuality;

    public static boolean takePictureMutex = false;

    @Override
    public void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        setContentView(getR("layout","activity_ppw_camera"));

        //output custom data
        mDataOutput = new HashMap<String,String>();

        //icon font face
        Typeface font = Typeface.createFromAsset(getAssets(), "flaticon_ppw_camera.ttf");

        // Create an instance of Camera
        mCamera = getCameraInstance();

        // Create our Preview view and set it as the content of our activity.
        mPreview = new PPWCameraPreview(this, mCamera);
        FrameLayout preview = (FrameLayout) findViewById(getR("id","frame_camera_preview"));
        preview.addView(mPreview);

        // Add a listener to the Close button
        final Button closeButton = (Button) findViewById(getR("id","button_exit"));
        closeButton.setTypeface(font);
        closeButton.setText(getR("string","close_icon"));
        closeButton.setOnClickListener(
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        finish();
                    }
                }
        );

        // Add a listener to the Capture button
        Button captureButton = (Button) findViewById(getR("id","button_capture"));
        captureButton.setTypeface(font);
        captureButton.setText(getR("string","camera_icon"));
        captureButton.setOnClickListener(
            new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    try {
                        // get an image from the camera
                        if (takePictureMutex) {
                            Toast.makeText(PPWCameraActivity.this, "Saving...",Toast.LENGTH_SHORT).show();
                            mCamera.takePicture(null, null, mPicture);
                            takePictureMutex = false;
                        }
                    } catch (Exception e) {
                        Log.d(TAG,"exception on picture taking "+e.getMessage());
                    }
                }
            }
        );

        // Add a listener to the flash button
        Camera.Parameters params = mCamera.getParameters();
        final Button flashButton = (Button) findViewById(getR("id","button_flash"));
        flashButton.setTypeface(font);
        final List<String> supportedFlash = params.getSupportedFlashModes();
        if (supportedFlash == null || params.getFlashMode() == null) {
            flashButton.setVisibility(View.INVISIBLE); //hide if not supported
        }
        else {
            if (supportedFlash.contains(Camera.Parameters.FLASH_MODE_AUTO)) {
                flashButton.setText(getR("string","flash_auto_icon"));
                params.setFlashMode(Camera.Parameters.FLASH_MODE_AUTO);
            }

            mCamera.setParameters(params);
            flashButton.setOnClickListener(
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        Camera.Parameters params = mCamera.getParameters();
                        String currentFlash = params.getFlashMode();
                        Log.d(TAG,"current flash "+currentFlash);
                        String nextFlash = currentFlash;
                        if (currentFlash.compareTo(Camera.Parameters.FLASH_MODE_AUTO) == 0) {
                            nextFlash = Camera.Parameters.FLASH_MODE_ON;
                        } else if (currentFlash.compareTo(Camera.Parameters.FLASH_MODE_ON) == 0) {
                            nextFlash = Camera.Parameters.FLASH_MODE_OFF;
                        } else {
                            nextFlash = Camera.Parameters.FLASH_MODE_AUTO;
                        }
                        if (!supportedFlash.contains(nextFlash)) {
                            nextFlash = supportedFlash.get(0);
                        }
                        Log.d(TAG,"next flash "+nextFlash);
                        int nextColor = Color.WHITE;
                        int nextIcon = getR("string","flash_auto_icon");
                        if (nextFlash.compareTo(Camera.Parameters.FLASH_MODE_OFF) == 0) {
                            nextColor = Color.DKGRAY;
                            nextIcon = getR("string","flash_off_icon");
                        } else if (nextFlash.compareTo(Camera.Parameters.FLASH_MODE_ON) == 0) {
                            nextColor = Color.YELLOW;
                            nextIcon = getR("string","flash_on_icon");
                        }
                        params.setFlashMode(nextFlash);
                        flashButton.setText(nextIcon);
                        mCamera.setParameters(params);

                        //update color
                        flashButton.setTextColor(nextColor);
                        GradientDrawable gd = (GradientDrawable)flashButton.getBackground();
                        gd.setStroke(getPixelSP(2),nextColor);
                        ((GradientDrawable)closeButton.getBackground()).setStroke(getPixelSP(2),Color.WHITE);
                    }
                }
            );
        }

        // Add listener to switch camera button
//        Button switchButton = (Button) findViewById(R.id.button_switch);
//        if(Camera.getNumberOfCameras() == 1){
//            switchButton.setVisibility(View.INVISIBLE);
//        }
//        else {
//            switchButton.setOnClickListener(
//                new View.OnClickListener() {
//                    @Override
//                    public void onClick(View v) {
//                        if (mPreview != null) {
//                            mPreview.flipCamera();
//                        }
//                    }
//                }
//            );
//        }

        mPhotoWidth = 640;
        mPhotoHeight = 480;
        mPreviewWidth = 640;
        mPreviewHeight = 480;
        mEncodingType = "jpg";
        mQuality = 100;

        //scroll through overlay options
        if (PPWCamera.jsonArrayArgs != null && PPWCamera.jsonArrayArgs.length() > 0) {
            Log.d(TAG,""+PPWCamera.jsonArrayArgs.toString());

            JSONObject options = PPWCamera.jsonArrayArgs.optJSONObject(0);
            mPhotoWidth = options.optInt("targetWidth", 640);
            mPhotoHeight = options.optInt("targetHeight",480);
            mPreviewWidth = options.optInt("previewWidth", 640);
            mPreviewHeight = options.optInt("previewHeight",480);
            mEncodingType = options.optString("encodingType", "jpg");
            mQuality = options.optInt("quality", 100);

            //adjust camera preview
            if (mPreviewHeight > 0 && mPreviewWidth > 0 && mPhotoWidth > 0) {
                PPWCameraPreview.picture_aspect_ratio = ((double) mPhotoWidth) / mPhotoHeight;
                PPWCameraPreview.preview_aspect_ratio = ((double) mPreviewWidth) / mPreviewHeight;
                PPWCameraPreview.picture_size_max_width = mPhotoWidth;
                PPWCameraPreview.preview_size_max_width = mPreviewWidth;
            }

            JSONArray overlay = options.optJSONArray("overlay");
            if (overlay != null) {
                for (int i=0;i<overlay.length();++i) {

                    JSONObject item = overlay.optJSONObject(i);
                    String type = item.optString("type");
                    if (type != null) {

                        RelativeLayout layout = (RelativeLayout) findViewById(getR("id","container"));
                        RelativeLayout.LayoutParams rp = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.WRAP_CONTENT, RelativeLayout.LayoutParams.WRAP_CONTENT);
                        String position = item.optString("position");
                        if (position != null) {
                            if (position.contains("bottom")) {
                                rp.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM);
                            } else if (position.contains("top")) {
                                rp.addRule(RelativeLayout.ALIGN_PARENT_TOP);
                            } else if (position.startsWith("center")) {
                                rp.addRule(RelativeLayout.CENTER_VERTICAL);
                            }
                            if (position.contains("left")) {
                                rp.addRule(RelativeLayout.ALIGN_PARENT_LEFT);
                            } else if (position.contains("right")) {
                                rp.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
                            } else if (position.endsWith("center")) {
                                rp.addRule(RelativeLayout.CENTER_HORIZONTAL);
                            }
                        }
                        int top = getPixelSP(item.optInt("top", 0));
                        int left = getPixelSP(item.optInt("left", 0));
                        int bottom = getPixelSP(item.optInt("bottom", 0));
                        int right = getPixelSP(item.optInt("right", 0));
                        rp.setMargins(left,top,right,bottom);

                        TextView view = null;
                        if (type.compareToIgnoreCase("text") == 0) {

                            //add a new text view
                            view = new TextView(this);
                            view.setText(item.optString("value", "error"));
                            view.setTextColor(Color.WHITE);
                            view.setShadowLayer(2, -1, 1, Color.BLACK);

                        }
                        else if (type.compareToIgnoreCase("carousel") == 0) {

                            class tagItem {
                                public int count;
                                public JSONArray value;
                                public String id;
                                public String initial;
                            };

                            //add a new button
                            view = new Button(this);
                            tagItem t = new tagItem();
                            t.value = item.optJSONArray("value");
                            t.id = item.optString("id");
                            t.initial = item.optString("initial","");
                            t.count = 0;
                            for(int j=0; j<t.value.length(); ++j) {
                                if (t.initial.compareTo(t.value.optString(j,""))==0) {
                                    t.count = j;
                                }
                            }
                            view.setTag(t);
                            String selected = t.value.optString(t.count,"error");
                            view.setText(selected);
                            view.setTextColor(Color.WHITE);
                            view.setShadowLayer(2, -1, 1, Color.BLACK);
                            Drawable bg = view.getBackground();
                            if (bg != null) {
                                bg.setAlpha(25);
                            }
                            mDataOutput.put(t.id,selected);
                            view.setOnClickListener(new View.OnClickListener() {
                                public void onClick(View v) {
                                    tagItem t = (tagItem)v.getTag();
                                    t.count++;
                                    if (t.count >= t.value.length()) {
                                        t.count = 0;
                                    }
                                    String selected = t.value.optString(t.count,"error");
                                    ((TextView)v).setText(selected);
                                    mDataOutput.put(t.id, selected);
                                }
                            });

                        }

                        if (view != null) {
                            view.setTextSize(TypedValue.COMPLEX_UNIT_SP,item.optInt("size",12));
                            view.setLayoutParams(rp);
                            layout.addView(view);
                        }
                    }
                }
            }
        }
    }

    public int getR(String group, String key) {
        return getApplicationContext().getResources().getIdentifier(key, group, getApplicationContext().getPackageName());
    }

    private int getPixelSP(int pixels) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP,pixels,getResources().getDisplayMetrics());
    };

    /** A safe way to get an instance of the Camera object. */
    public static Camera getCameraInstance(){
        Camera c = null;
        try {
            c = Camera.open(); // attempt to get a Camera instance
        }
        catch (Exception e){
            // Camera is not available (in use or does not exist)
        }
        return c; // returns null if camera is unavailable
    }

    private Camera.PictureCallback mPicture = new Camera.PictureCallback() {

        @Override
        public void onPictureTaken(byte[] imageData, Camera camera) {

            String timeStamp = String.valueOf(System.currentTimeMillis());
            String FILENAME = timeStamp + "."+mEncodingType;

            try {
                //check disk space
                File path = Environment.getDataDirectory();
                StatFs stat = new StatFs(path.getPath());
                long blockSize = stat.getBlockSize();
                long availableBlocks = stat.getAvailableBlocks();
                long availableBytes = blockSize*availableBlocks;
                byte[] imageResize = resizeImage(imageData);

                if (availableBytes <= imageResize.length) {

                    String availSize = Formatter.formatFileSize(PPWCameraActivity.this, availableBytes);

                    new AlertDialog.Builder(PPWCameraActivity.this)
                            .setTitle("Unable to Save - Disk Full")
                            .setMessage("Available space: " + availSize)
                            .setIcon(android.R.drawable.ic_dialog_alert)
                            .show();
                }

                //save if space available
                else {
                    //create new
                    FileOutputStream fos = openFileOutput(FILENAME, Context.MODE_PRIVATE);
                    fos.write(imageResize);
                    fos.close();

                    String imagePath = getFilesDir() + "/" + FILENAME;

                    String hash = hmacSha512(bytesToHex(imageResize), SECRET_KEY);

                    JSONObject output = new JSONObject();
                    output.put("imageURI",imagePath);
                    output.put("lastModifiedDate",timeStamp);
                    output.put("size",imageResize.length);
                    output.put("type",mEncodingType);
                    output.put("hash",hash);
                    if (!mDataOutput.isEmpty()) {
                        JSONObject data = new JSONObject();
                        for (HashMap.Entry<String, String> entry : mDataOutput.entrySet()) {
                            data.put(entry.getKey(),entry.getValue());
                        }
                        output.put("data",data);
                    }

                    Log.d(TAG, output.toString());
                    PluginResult result = new PluginResult(PluginResult.Status.OK, output);
                    result.setKeepCallback(true);
                    PPWCamera.callbackContext.sendPluginResult(result);
                }

            } catch (Exception e) {
                Log.d(TAG, "File not found Error: " + e.getMessage());
            }
            camera.stopPreview();
            camera.startPreview();
            takePictureMutex = true;
        }
    };

    byte[] resizeImage(byte[] input) {
        Bitmap original = BitmapFactory.decodeByteArray(input, 0, input.length);
        Bitmap resized = Bitmap.createScaledBitmap(original, mPhotoWidth, mPhotoHeight, true);
        ByteArrayOutputStream blob = new ByteArrayOutputStream();
        if (mEncodingType.compareToIgnoreCase("png") == 0) {
            resized.compress(Bitmap.CompressFormat.PNG, mQuality, blob);
        } else {
            resized.compress(Bitmap.CompressFormat.JPEG, mQuality, blob);
        }
        return blob.toByteArray();
    }

    /*
     * HMAC SHA-1 encoding
     */
    private static String hmacSha512(String value, String key)
            throws UnsupportedEncodingException, NoSuchAlgorithmException,
            InvalidKeyException {
        String type = "HmacSHA512";
        SecretKeySpec secret = new SecretKeySpec(key.getBytes(), type);
        Mac mac = Mac.getInstance(type);
        mac.init(secret);
        byte[] bytes = mac.doFinal(value.getBytes());
        return bytesToHex(bytes);
    }

    private final static char[] hexArray = "0123456789abcdef".toCharArray();
    private static String bytesToHex(byte[] bytes) {
        char[] hexChars = new char[bytes.length * 2];
        int v;
        for (int j = 0; j < bytes.length; j++) {
            v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        return new String(hexChars);
    }

    @Override
    protected void onPause() {
        super.onPause();
        releaseCamera();              // release the camera immediately on pause event
    }

    private void releaseCamera(){
        if (mCamera != null){
            mCamera.release();        // release the camera for other applications
            mCamera = null;
        }
    }
}