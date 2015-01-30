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
import android.media.ThumbnailUtils;
import android.view.SurfaceView;
import android.view.WindowManager;
import android.view.Display;
import android.graphics.Point;
import android.os.Build;

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

    private static final String FLASH_NAME_AUTO = "auto";
    private static final String FLASH_NAME_TORCH = "torch";
    private static final String FLASH_NAME_ON = "on";
    private static final String FLASH_NAME_OFF = "off";

    private static Camera mCamera;
    private PPWCameraPreview mPreview;
    private static HashMap<String,String> mDataOutput;
    private int mPhotoWidth;
    private int mPhotoHeight;
    private int mPreviewWidth;
    private int mPreviewHeight;
    private String mEncodingType;
    private int mQuality;
    private String mFlashType = null;

    public static boolean takePictureMutex = false;
    public boolean init = false;

    @Override
    public void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        init();
    }

    public void init() {
        if (init) {
            return;
        }
        init = true; //don't initialize more than once

        setContentView(getR("layout","activity_ppw_camera"));

        //output custom data
        mDataOutput = new HashMap<String,String>();

        //icon font face
        Typeface font = Typeface.createFromAsset(getAssets(), "flaticon_ppw_camera.ttf");

        //create a cropped border
        class CroppedCameraPreview extends FrameLayout {
            private SurfaceView cameraPreview;
            private int actualHeight = 0;
            private int actualWidth = 0;
            private int frameWidth = 0;
            private int frameHeight = 0;
            private int deltaWidth = 0;
            private int deltaHeight = 0;
            public CroppedCameraPreview( Context context, SurfaceView view) {
                super( context );
                cameraPreview = view;
                actualWidth = context.getResources().getDisplayMetrics().widthPixels;
                actualHeight = context.getResources().getDisplayMetrics().heightPixels;
                frameWidth = actualWidth;
                frameHeight = actualHeight;
                try
                {
                    WindowManager windowManager = (WindowManager)context.getSystemService(Context.WINDOW_SERVICE);
                    Display display = windowManager.getDefaultDisplay();

                    // includes window decorations (statusbar bar/menu bar)
                    if (Build.VERSION.SDK_INT >= 14 && Build.VERSION.SDK_INT < 17) {
                        actualWidth = (Integer) Display.class.getMethod("getRawWidth").invoke(display);
                        actualHeight = (Integer) Display.class.getMethod("getRawHeight").invoke(display);
                    }

                    // includes window decorations (statusbar bar/menu bar)
                    if (Build.VERSION.SDK_INT >= 17) {
                        Point realSize = new android.graphics.Point();
                        Display.class.getMethod("getRealSize", Point.class).invoke(display, realSize);
                        actualWidth = realSize.x;
                        actualHeight = realSize.y;
                    }

                } catch (Exception ignored)
                {
                }
            }
            @Override
            protected void onMeasure( int widthMeasureSpec, int heightMeasureSpec ) {
                int height = MeasureSpec.getSize(heightMeasureSpec);
                int width = MeasureSpec.getSize(widthMeasureSpec);
                if (width > height * PPWCameraPreview.preview_aspect_ratio) {
                    width = (int) (height * PPWCameraPreview.preview_aspect_ratio + .5);
                } else {
                    height = (int) (width / PPWCameraPreview.preview_aspect_ratio + .5);
                }
                deltaWidth = (int)(width - actualWidth);
                deltaHeight = (int)(height - actualHeight);
                setMeasuredDimension(width, height);
            }
            @Override
            protected void onLayout( boolean changed, int l, int t, int r, int b) {
                if (cameraPreview != null) {
                    float actualRatio = (actualWidth*1.f)/actualHeight;
                    if (PPWCameraPreview.preview_aspect_ratio >= actualRatio) {
                        cameraPreview.layout (deltaWidth,deltaHeight,actualWidth-deltaWidth,actualHeight-deltaHeight);
                    }
                    else if (frameHeight == actualHeight) {
                        cameraPreview.layout (0,0,frameWidth,frameHeight);
                    }
                    else {
                        cameraPreview.layout (0,0,deltaWidth-actualWidth,deltaHeight-actualHeight);
                    }
                }
            }
        }

        // Create our Preview view and set it as the content of our activity.
        mPreview = new PPWCameraPreview(this, getCameraInstance());
        FrameLayout preview = (FrameLayout) findViewById(getR("id","frame_camera_preview"));
        CroppedCameraPreview croppedPreview = new CroppedCameraPreview(this,mPreview);
        preview.addView(croppedPreview);
        croppedPreview.addView(mPreview);

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
                    // get an image from the camera
                    if (takePictureMutex) {
                        takePictureMutex = false;
                        Toast.makeText(PPWCameraActivity.this, "Saving...",Toast.LENGTH_SHORT).show();
                        try {
                            getCameraInstance().takePicture(mShutter, null, mPicture);
                        } catch (Exception e) {
                            Log.d(TAG,"exception on picture taking "+e.getMessage());
                            sendError();
                        }
                    }
                }
            }
        );

        mPhotoWidth = 640;
        mPhotoHeight = 480;
        mPreviewWidth = 640;
        mPreviewHeight = 480;
        mEncodingType = "jpg";
        mQuality = 100;
        mFlashType = FLASH_NAME_AUTO;

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
            mFlashType = options.optString("flashType",FLASH_NAME_AUTO);

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

        // Add a listener to the flash button
        Camera.Parameters params = getCameraInstance().getParameters();
        final Button flashButton = (Button) findViewById(getR("id","button_flash"));
        flashButton.setTypeface(font);
        final List<String> supportedFlash = params.getSupportedFlashModes();
        if (supportedFlash == null || params.getFlashMode() == null || !supportedFlash.contains(Camera.Parameters.FLASH_MODE_AUTO)) {
            flashButton.setVisibility(View.INVISIBLE); //hide if not supported
        }
        else {
            int defaultColor = Color.WHITE;
            int defaultIcon = getR("string","flash_auto_icon");
            String defaultFlash = Camera.Parameters.FLASH_MODE_AUTO;
            if (mFlashType.compareToIgnoreCase(FLASH_NAME_OFF) == 0 && supportedFlash.contains(Camera.Parameters.FLASH_MODE_OFF)) {
                defaultColor = Color.DKGRAY;
                defaultIcon = getR("string","flash_off_icon");
                defaultFlash = Camera.Parameters.FLASH_MODE_OFF;
            } else if (mFlashType.compareToIgnoreCase(FLASH_NAME_ON) == 0 && supportedFlash.contains(Camera.Parameters.FLASH_MODE_ON)) {
                defaultColor = Color.YELLOW;
                defaultIcon = getR("string","flash_on_icon");
                defaultFlash = Camera.Parameters.FLASH_MODE_ON;
            } else if (mFlashType.compareToIgnoreCase(FLASH_NAME_TORCH) == 0 && supportedFlash.contains(Camera.Parameters.FLASH_MODE_TORCH)) {
                defaultColor = Color.GREEN;
                defaultIcon = getR("string","flash_on_icon");
                defaultFlash = Camera.Parameters.FLASH_MODE_TORCH;
            }

            params.setFlashMode(defaultFlash);
            flashButton.setText(defaultIcon);
            getCameraInstance().setParameters(params);

            flashButton.setTextColor(defaultColor);
            GradientDrawable gd = (GradientDrawable)flashButton.getBackground();
            gd.setStroke(getPixelSP(2),defaultColor);
            ((GradientDrawable)closeButton.getBackground()).setStroke(getPixelSP(2),Color.WHITE);

            flashButton.setOnClickListener(
                new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        Camera.Parameters params = getCameraInstance().getParameters();
                        String currentFlash = params.getFlashMode();
                        Log.d(TAG,"current flash "+currentFlash);
                        String nextFlash = currentFlash;
                        if (currentFlash.compareTo(Camera.Parameters.FLASH_MODE_AUTO) == 0) {
                            if (supportedFlash.contains(Camera.Parameters.FLASH_MODE_TORCH)) {
                                nextFlash = Camera.Parameters.FLASH_MODE_TORCH;
                            }
                            else {
                                currentFlash = Camera.Parameters.FLASH_MODE_TORCH;
                            }
                        }
                        if (currentFlash.compareTo(Camera.Parameters.FLASH_MODE_TORCH) == 0) {
                            if (supportedFlash.contains(Camera.Parameters.FLASH_MODE_ON)) {
                                nextFlash = Camera.Parameters.FLASH_MODE_ON;
                            }
                            else {
                                currentFlash = Camera.Parameters.FLASH_MODE_ON;
                            }
                        }
                        if (currentFlash.compareTo(Camera.Parameters.FLASH_MODE_ON) == 0) {
                            if (supportedFlash.contains(Camera.Parameters.FLASH_MODE_OFF)) {
                                nextFlash = Camera.Parameters.FLASH_MODE_OFF;
                            }
                            else {
                                currentFlash = Camera.Parameters.FLASH_MODE_OFF;
                            }
                        }
                        if (currentFlash.compareTo(Camera.Parameters.FLASH_MODE_OFF) == 0) {
                            if (supportedFlash.contains(Camera.Parameters.FLASH_MODE_AUTO)) {
                                nextFlash = Camera.Parameters.FLASH_MODE_AUTO;
                            }
                        }
                        if (!supportedFlash.contains(nextFlash)) {
                            nextFlash = supportedFlash.get(0);
                        }
                        Log.d(TAG,"next flash "+nextFlash);
                        int nextColor = Color.WHITE;
                        int nextIcon = getR("string","flash_auto_icon");
                        mFlashType = FLASH_NAME_AUTO;
                        if (nextFlash.compareTo(Camera.Parameters.FLASH_MODE_OFF) == 0) {
                            nextColor = Color.DKGRAY;
                            nextIcon = getR("string","flash_off_icon");
                            mFlashType = FLASH_NAME_OFF;
                        } else if (nextFlash.compareTo(Camera.Parameters.FLASH_MODE_ON) == 0) {
                            nextColor = Color.YELLOW;
                            nextIcon = getR("string","flash_on_icon");
                            mFlashType = FLASH_NAME_ON;
                        } else if (nextFlash.compareTo(Camera.Parameters.FLASH_MODE_TORCH) == 0) {
                            nextColor = Color.GREEN;
                            nextIcon = getR("string","flash_on_icon");
                            mFlashType = FLASH_NAME_TORCH;
                        }
                        params.setFlashMode(nextFlash);
                        flashButton.setText(nextIcon);
                        getCameraInstance().setParameters(params);

                        //update color
                        flashButton.setTextColor(nextColor);
                        GradientDrawable gd = (GradientDrawable)flashButton.getBackground();
                        gd.setStroke(getPixelSP(2),nextColor);
                        ((GradientDrawable)closeButton.getBackground()).setStroke(getPixelSP(2),Color.WHITE);
                    }
                }
            );
        }
    }

    public int getR(String group, String key) {
        return getApplicationContext().getResources().getIdentifier(key, group, getApplicationContext().getPackageName());
    }

    private int getPixelSP(int pixels) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP,pixels,getResources().getDisplayMetrics());
    };

    public static Camera getCameraInstance(){
        if (mCamera!=null) {
            return mCamera;
        }

        Camera c = null;
        try {
            c = Camera.open();
            mCamera = c;
        }
        catch (Exception e){
            Log.e(TAG, "failed to open Camera");
            sendError();
        }
        return c;
    }

    private static void sendError() {
        PluginResult result = new PluginResult(PluginResult.Status.ERROR, "camera error");
        PPWCamera.callbackContext.sendPluginResult(result);
    }

    private Camera.ShutterCallback mShutter = new Camera.ShutterCallback() {

        @Override
        public void onShutter() {

        }
    };

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
                    output.put("flashType",mFlashType);
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
                sendError();
            }
            camera.cancelAutoFocus();
            camera.stopPreview();
            camera.startPreview();
            PPWCameraActivity.takePictureMutex = true;
        }
    };

    byte[] resizeImage(byte[] input) {
        Bitmap original = BitmapFactory.decodeByteArray(input, 0, input.length);

        //down scale and crop image
        Bitmap resized = ThumbnailUtils.extractThumbnail(original, mPhotoWidth, mPhotoHeight, ThumbnailUtils.OPTIONS_RECYCLE_INPUT);

        ByteArrayOutputStream blob = new ByteArrayOutputStream();
        if (mEncodingType.compareToIgnoreCase("png") == 0) {
            resized.compress(Bitmap.CompressFormat.PNG, mQuality, blob);
        } else {
            resized.compress(Bitmap.CompressFormat.JPEG, mQuality, blob);
        }
        return blob.toByteArray();
    }

    /*
     * HMAC SHA-512 encoding
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
        if (mPreview != null) {
            mCamera = null;
            mPreview.clearCamera(); // release the camera immediately to fix pause crash
        }
        init = false;
    }

    @Override
    protected void onResume() {
        super.onResume();
        init();
    }
}