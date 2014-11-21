package com.appnovation.ppw_camera;

import android.content.Context;
import android.hardware.Camera;
import android.hardware.Camera.Size;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

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

    public PPWCameraPreview(Context context, Camera camera) {
        super(context);
        mCamera = camera;

        // Install a SurfaceHolder.Callback so we get notified when the
        // underlying surface is created and destroyed.
        mHolder = getHolder();
        mHolder.addCallback(this);
        Camera.CameraInfo cam = new Camera.CameraInfo();
        mCamFacing = cam.facing;
    }

    public void clearCamera() {
       if (mCamera != null) {
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
            mCamera.setPreviewDisplay(holder);
            mCamera.startPreview();
            PPWCameraActivity.takePictureMutex = true;
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

        } catch (Exception e){
            Log.d(TAG, "Error starting camera preview: " + e.getMessage());
        }
    }

//    public void flipCamera() {
//        if (mCamera != null) {
//            mCamera.stopPreview();
//            mCamera.release();
//            mCamera = null;
//        }
//
//        //swap the id of the camera to be used
//        switch (mCamFacing) {
//            case Camera.CameraInfo.CAMERA_FACING_BACK:
//                mCamFacing = Camera.CameraInfo.CAMERA_FACING_FRONT;
//                break;
//            default:
//                mCamFacing = Camera.CameraInfo.CAMERA_FACING_BACK;
//                break;
//        }
//        try {
//            mCamera = Camera.open(mCamFacing);
//            setupCamera();
//            mCamera.setPreviewDisplay(mHolder);
//            mCamera.startPreview();
//        } catch (IOException e) {
//            Log.d(TAG, "Error setting camera preview: " + e.getMessage());
//        }
//    }

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

    /**
     * Measure the view and its content to determine the measured width and the
     * measured height.
     */
    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int height = MeasureSpec.getSize(heightMeasureSpec);
        int width = MeasureSpec.getSize(widthMeasureSpec);

        if (width > height * preview_aspect_ratio) {
            width = (int) (height * preview_aspect_ratio + .5);
        } else {
            height = (int) (width / preview_aspect_ratio + .5);
        }

        setMeasuredDimension(width, height);
    }
}