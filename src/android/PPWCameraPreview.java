package com.appnovation.ppw_camera;

import android.content.Context;
import android.hardware.Camera;
import android.hardware.Camera.Size;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.ScaleGestureDetector;
import android.view.MotionEvent;
import android.graphics.Rect;
import java.util.ArrayList;

import java.io.IOException;
import java.util.List;

public class PPWCameraPreview extends SurfaceView implements SurfaceHolder.Callback {

    public static final String TAG = "PPWCameraPreview";

    //editable values for camera setup
    public static double picture_aspect_ratio = 4.0 / 3.0;
    public static double preview_aspect_ratio = 16.0 / 9.0;
    public static int picture_size_max_width = 640;
    public static int preview_size_max_width = 1920;

    private SurfaceHolder mHolder;
    private Camera mCamera;
    private int mCamFacing;
    private boolean mFocusMutex = false;

    //scale properties
    private float mScaleFactor = 1.f;
    private ScaleGestureDetector mScaleDetector;

    public PPWCameraPreview(Context context, Camera camera) {
        super(context);
        mCamera = camera;
        mScaleDetector = new ScaleGestureDetector(context, new ScaleListener());

        // Install a SurfaceHolder.Callback so we get notified when the
        // underlying surface is created and destroyed.
        mHolder = getHolder();
        mHolder.addCallback(this);
        mHolder.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS);
        Camera.CameraInfo cam = new Camera.CameraInfo();
        mCamFacing = cam.facing;
        mFocusMutex = true;
    }

    public void clearCamera() {
       if (mCamera != null) {
            if (mHolder != null) {
                mHolder.removeCallback(this);
            }
            mCamera.stopPreview();
            mCamera.release();
            mCamera = null;
       }
    }

    private Camera getCamInstance() {
        if (mCamera != null) {
            return mCamera;
        }
        mCamera = PPWCameraActivity.getCameraInstance();
        return mCamera;
    }

    public void surfaceCreated(SurfaceHolder holder) {
        // The Surface has been created, now tell the camera where to draw the preview.
        try {
            mCamera = getCamInstance();
            setupCamera();
            Camera.Parameters p = mCamera.getParameters();
            List<String> supportedFocusModes = p.getSupportedFocusModes();
            if (supportedFocusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO)) {
                p.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
            }
            mCamera.setParameters(p);
            mCamera.setPreviewDisplay(holder);
            mCamera.startPreview();
            PPWCameraActivity.mTakePictureMutex = true;
        } catch (IOException e) {
            Log.d(TAG, "Error setting camera preview: " + e.getMessage());
        }
    }

    public void surfaceDestroyed(SurfaceHolder holder) {
        // empty. Take care of releasing the Camera preview in your activity.
        clearCamera();
    }

    public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {
        // If your preview can change or rotate, take care of those events here.
        // Make sure to stop the preview before resizing or reformatting it.

        if (mHolder.getSurface() == null){
          // preview surface does not exist
          return;
        }

        // stop preview before making changes
        try {
            mCamera.stopPreview();
        } catch (Exception e){
          // ignore: tried to stop a non-existent preview
        }

        // set preview size and make any resize, rotate or
        // reformatting changes here

        // start preview with new settings
        try {
            mCamera.setPreviewDisplay(mHolder);
            mCamera.startPreview();
            PPWCameraActivity.mTakePictureMutex = true;
        } catch (Exception e){
            Log.d(TAG, "Error starting camera preview: " + e.getMessage());
        }
    }

    protected Size determineBestSize(List<Camera.Size> sizes, int widthThreshold, double ratio) {
        Size bestSize = null;

        for (Size currentSize : sizes) {
            boolean isDesiredRatio = ((currentSize.width * ratio) - currentSize.height) < 1;
            boolean isBetterSize = (bestSize == null || currentSize.width > bestSize.width);
            boolean isInBounds = currentSize.width <= widthThreshold;

            if (isDesiredRatio && isInBounds && isBetterSize) {
                bestSize = currentSize;
            }
        }

        if (bestSize == null) {
            return sizes.get(0);
        }

                
        return bestSize;
    }

    private Size determineBestPreviewSize(Camera.Parameters parameters) {
        List<Size> sizes = parameters.getSupportedPreviewSizes();

        return determineBestSize(sizes, preview_size_max_width, preview_aspect_ratio);
    }

    private Size determineBestPictureSize(Camera.Parameters parameters) {
        List<Size> sizes = parameters.getSupportedPictureSizes();

        return determineBestSize(sizes, picture_size_max_width, picture_aspect_ratio);
    }

    /**
     * Setup the camera parameters.
     */
    public void setupCamera() {
        Camera.Parameters parameters = mCamera.getParameters();

        Size bestPreviewSize = determineBestPreviewSize(parameters);
        Size bestPictureSize = determineBestPictureSize(parameters);

        parameters.setPreviewSize(bestPreviewSize.width, bestPreviewSize.height);
        parameters.setPictureSize(bestPictureSize.width, bestPictureSize.height);

        mCamera.setParameters(parameters);
    }

    private Rect focusArea(float x, float y) {
        Rect touchRect = new Rect(
            (int)(x - 100), 
            (int)(y - 100), 
            (int)(x + 100), 
            (int)(y + 100));

        final Rect targetFocusRect = new Rect(
            touchRect.left * 2000/this.getWidth() - 1000,
            touchRect.top * 2000/this.getHeight() - 1000,
            touchRect.right * 2000/this.getWidth() - 1000,
            touchRect.bottom * 2000/this.getHeight() - 1000);

        return targetFocusRect;
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        mScaleDetector.onTouchEvent(event);
        if(event.getAction() == MotionEvent.ACTION_DOWN && event.getPointerCount()==1 && mFocusMutex) {
            mFocusMutex = false;
            try {
                mCamera.cancelAutoFocus();
                Rect focusRect = focusArea(event.getX(), event.getY());
                List<Camera.Area> focusList = new ArrayList<Camera.Area>();
                Camera.Area focusArea = new Camera.Area(focusRect, 1000);
                focusList.add(focusArea);
                Camera.Parameters p = mCamera.getParameters();
                if (p.getMaxNumFocusAreas()>0) {
                    p.setFocusAreas(focusList);
                }
                if (p.getMaxNumMeteringAreas()>0) {
                    p.setMeteringAreas(focusList);
                }
                mCamera.setParameters(p);
                mCamera.autoFocus(new Camera.AutoFocusCallback() {
                    @Override
                    public void onAutoFocus(boolean success, Camera camera) {
                        Camera.Parameters params = camera.getParameters();
                        if (params.getFlashMode() != null && params.getFlashMode().compareToIgnoreCase(Camera.Parameters.FLASH_MODE_TORCH) == 0) {
                            params.setFlashMode(Camera.Parameters.FLASH_MODE_OFF); //turn flash on/off to fix disabling itself on focus
                            camera.setParameters(params);
                            params.setFlashMode(Camera.Parameters.FLASH_MODE_TORCH);
                            camera.setParameters(params);
                        }
                        if (success) {
                            camera.cancelAutoFocus();
                        }
                        mFocusMutex = true;
                    }
                });
            } catch (Exception e) {
                Log.d(TAG, "Tap focus error: " + e.getMessage());
                mFocusMutex = true;
            }
        }
        return true;
    }

    public class ScaleListener extends ScaleGestureDetector.SimpleOnScaleGestureListener {
        @Override
        public boolean onScale(ScaleGestureDetector detector) {
            Camera.Parameters p = mCamera.getParameters();
            if (p.isZoomSupported()) {
                mScaleFactor *= detector.getScaleFactor();
                int maxZoom = p.getMaxZoom();
                int nextZoom = (int)((mScaleFactor - 1)*maxZoom);
                if ( nextZoom > maxZoom ) {
                    nextZoom = p.getMaxZoom();
                    mScaleFactor = 2;
                }
                if ( nextZoom < 0 ) {
                    nextZoom = 0;
                    mScaleFactor = 1;
                }
                p.setZoom(nextZoom);
                mCamera.setParameters(p);
            }
            mFocusMutex = true;
            return true;
        }
    }
}