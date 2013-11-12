package starling.display
{
	import flash.geom.Matrix;
	import starling.core.starling_internal;

	/**
	 * DisplayObject's member to hold position information so that we could plug in another system that manipulates this spatial object
	 *
	 * @author Duong Nguyen
	 */
	public class Spatial
	{
		use namespace starling_internal;

		starling_internal var mAlpha:Number=1;
		starling_internal var mOrientationChanged:Boolean;
		starling_internal var mPivotX:Number=0;
		starling_internal var mPivotY:Number=0;
		starling_internal var mRotation:Number=0;
		starling_internal var mScaleX:Number=1;
		starling_internal var mScaleY:Number=1;
		starling_internal var mSkewX:Number=0;
		starling_internal var mSkewY:Number=0;

		[Transient]
		starling_internal var mTransformationMatrix:Matrix;

		starling_internal var mVisible:Boolean=true;
		starling_internal var mX:Number=0;
		starling_internal var mY:Number=0;
		starling_internal var mZ:Number=0;

	}
}

