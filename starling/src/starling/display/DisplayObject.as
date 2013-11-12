// =================================================================================================
//
//	Starling Framework
//	Copyright 2011 Gamua OG. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.display
{
	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.system.Capabilities;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import flash.utils.getQualifiedClassName;

	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.core.starling_internal;
	import starling.errors.AbstractClassError;
	import starling.errors.AbstractMethodError;
	import starling.events.EventDispatcher;
	import starling.events.TouchEvent;
	import starling.filters.FragmentFilter;
	import starling.utils.MatrixUtil;

	/** Dispatched when an object is added to a parent. */
	[Event(name = "added", type = "starling.events.Event")]
	/** Dispatched when an object is connected to the stage (directly or indirectly). */
	[Event(name = "addedToStage", type = "starling.events.Event")]
	/** Dispatched when an object is removed from its parent. */
	[Event(name = "removed", type = "starling.events.Event")]
	/** Dispatched when an object is removed from the stage and won't be rendered any longer. */
	[Event(name = "removedFromStage", type = "starling.events.Event")]
	/** Dispatched once every frame on every object that is connected to the stage. */
	[Event(name = "enterFrame", type = "starling.events.EnterFrameEvent")]
	/** Dispatched when an object is touched. Bubbles. */
	[Event(name = "touch", type = "starling.events.TouchEvent")]
	/**
	 *  The DisplayObject class is the base class for all objects that are rendered on the
	 *  screen.
	 *
	 *  <p><strong>The Display Tree</strong></p>
	 *
	 *  <p>In Starling, all displayable objects are organized in a display tree. Only objects that
	 *  are part of the display tree will be displayed (rendered).</p>
	 *
	 *  <p>The display tree consists of leaf nodes (Image, Quad) that will be rendered directly to
	 *  the screen, and of container nodes (subclasses of "DisplayObjectContainer", like "Sprite").
	 *  A container is simply a display object that has child nodes - which can, again, be either
	 *  leaf nodes or other containers.</p>
	 *
	 *  <p>At the base of the display tree, there is the Stage, which is a container, too. To create
	 *  a Starling application, you create a custom Sprite subclass, and Starling will add an
	 *  instance of this class to the stage.</p>
	 *
	 *  <p>A display object has properties that define its position in relation to its parent
	 *  (x, y), as well as its rotation and scaling factors (scaleX, scaleY). Use the
	 *  <code>alpha</code> and <code>visible</code> properties to make an object translucent or
	 *  invisible.</p>
	 *
	 *  <p>Every display object may be the target of touch events. If you don't want an object to be
	 *  touchable, you can disable the "touchable" property. When it's disabled, neither the object
	 *  nor its children will receive any more touch events.</p>
	 *
	 *  <strong>Transforming coordinates</strong>
	 *
	 *  <p>Within the display tree, each object has its own local coordinate system. If you rotate
	 *  a container, you rotate that coordinate system - and thus all the children of the
	 *  container.</p>
	 *
	 *  <p>Sometimes you need to know where a certain point lies relative to another coordinate
	 *  system. That's the purpose of the method <code>getTransformationMatrix</code>. It will
	 *  create a matrix that represents the transformation of a point in one coordinate system to
	 *  another.</p>
	 *
	 *  <strong>Subclassing</strong>
	 *
	 *  <p>Since DisplayObject is an abstract class, you cannot instantiate it directly, but have
	 *  to use one of its subclasses instead. There are already a lot of them available, and most
	 *  of the time they will suffice.</p>
	 *
	 *  <p>However, you can create custom subclasses as well. That way, you can create an object
	 *  with a custom render function. You will need to implement the following methods when you
	 *  subclass DisplayObject:</p>
	 *
	 *  <ul>
	 *    <li><code>function render(support:RenderSupport, parentAlpha:Number):void</code></li>
	 *    <li><code>function getBounds(targetSpace:DisplayObject,
	 *                                 resultRect:Rectangle=null):Rectangle</code></li>
	 *  </ul>
	 *
	 *  <p>Have a look at the Quad class for a sample implementation of the 'getBounds' method.
	 *  For a sample on how to write a custom render function, you can have a look at this
	 *  <a href="http://wiki.starling-framework.org/manual/custom_display_objects">article</a>
	 *  in the Starling Wiki.</p>
	 *
	 *  <p>When you override the render method, it is important that you call the method
	 *  'finishQuadBatch' of the support object. This forces Starling to render all quads that
	 *  were accumulated before by different render methods (for performance reasons). Otherwise,
	 *  the z-ordering will be incorrect.</p>
	 *
	 *  @see DisplayObjectContainer
	 *  @see Sprite
	 *  @see Stage
	 */
	public class DisplayObject extends EventDispatcher
	{
		use namespace starling_internal;

		/** Helper objects. */
		private static var sAncestors:Vector.<DisplayObject> = new <DisplayObject>[];
		private static var sHelperMatrix:Matrix              = new Matrix();
		private static var sHelperRect:Rectangle             = new Rectangle();

		/** @private */
		public function DisplayObject()
		{
			if (Capabilities.isDebugger &&
				getQualifiedClassName(this) == "starling.display::DisplayObject")
			{
				throw new AbstractClassError();
			}

			mSpatial.mX = mSpatial.mY = mSpatial.mPivotX = mSpatial.mPivotY = mSpatial.mRotation = mSpatial.mSkewX = mSpatial.mSkewY = 0.0;
			mSpatial.mScaleX = mSpatial.mScaleY = mSpatial.mAlpha = 1.0;
			mSpatial.mVisible = mTouchable = true;
			mBlendMode = BlendMode.AUTO;
			mSpatial.mTransformationMatrix = new Matrix();
			mSpatial.mOrientationChanged = mUseHandCursor = false;
		}

		// members
		starling_internal var mSpatial:Spatial               = new Spatial; // to hold spatial properties

		private var mBlendMode:String;

		private var mFilter:FragmentFilter;
		private var mName:String;
		private var mParent:DisplayObjectContainer;
		private var mTouchable:Boolean;
		private var mUseHandCursor:Boolean;

		// Transparent hit test related
		private var mHitTransparent:Boolean = true;
		private static var _temp_p:Point = new Point();
		private static var _hit_test_bd:BitmapData = new BitmapData(1, 1, true, 0x0);
		private static var _hit_test_rs:RenderSupport;

		public function get hitTransparent():Boolean
		{
			return mHitTransparent;
		}

		public function set hitTransparent(value:Boolean):void
		{
			if(value != mHitTransparent)
			{
				mHitTransparent = value;
			}
		}

		/** The opacity of the object. 0 = transparent, 1 = opaque. */
		public function get alpha():Number
		{
			return mSpatial.mAlpha;
		}

		public function set alpha(value:Number):void
		{
			mSpatial.mAlpha = value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
		}

		/** The topmost object in the display tree the object is part of. */
		public function get base():DisplayObject
		{
			var currentObject:DisplayObject = this;
			while (currentObject.mParent)
				currentObject = currentObject.mParent;
			return currentObject;
		}

		/** The blend mode determines how the object is blended with the objects underneath.
		 *   @default auto
		 *   @see starling.display.BlendMode */
		public function get blendMode():String
		{
			return mBlendMode;
		}

		public function set blendMode(value:String):void
		{
			mBlendMode = value;
		}

		/** The bounds of the object relative to the local coordinates of the parent. */
		public function get bounds():Rectangle
		{
			return getBounds(mParent);
		}

		/** Disposes all resources of the display object.
		  * GPU buffers are released, event listeners are removed, filters are disposed. */
		public function dispose():void
		{
			if (mFilter)
				mFilter.dispose();
			removeEventListeners();
		}

		/** The filter that is attached to the display object. The starling.filters
		 *  package contains several classes that define specific filters you can use.
		 *  Beware that you should NOT use the same filter on more than one object (for
		 *  performance reasons). */
		public function get filter():FragmentFilter
		{
			return mFilter;
		}

		public function set filter(value:FragmentFilter):void
		{
			mFilter = value;
		}

		/** Returns a rectangle that completely encloses the object as it appears in another
		 *  coordinate system. If you pass a 'resultRectangle', the result will be stored in this
		 *  rectangle instead of creating a new object. */
		public function getBounds(targetSpace:DisplayObject, resultRect:Rectangle = null):Rectangle
		{
			throw new AbstractMethodError("Method needs to be implemented in subclass");
			return null;
		}

		/** Creates a matrix that represents the transformation from the local coordinate system
		 *  to another. If you pass a 'resultMatrix', the result will be stored in this matrix
		 *  instead of creating a new object. */
		public function getTransformationMatrix(targetSpace:DisplayObject,
												resultMatrix:Matrix = null):Matrix
		{
			var commonParent:DisplayObject;
			var currentObject:DisplayObject;

			if (resultMatrix)
				resultMatrix.identity();
			else
				resultMatrix = new Matrix();

			if (targetSpace == this)
			{
				return resultMatrix;
			}
			else if (targetSpace == mParent || (targetSpace == null && mParent == null))
			{
				resultMatrix.copyFrom(transformationMatrix);
				return resultMatrix;
			}
			else if (targetSpace == null || targetSpace == base)
			{
				// targetCoordinateSpace 'null' represents the target space of the base object.
				// -> move up from this to base

				currentObject = this;
				while (currentObject != targetSpace)
				{
					resultMatrix.concat(currentObject.transformationMatrix);
					currentObject = currentObject.mParent;
				}

				return resultMatrix;
			}
			else if (targetSpace.mParent == this) // optimization
			{
				targetSpace.getTransformationMatrix(this, resultMatrix);
				resultMatrix.invert();

				return resultMatrix;
			}

			// 1. find a common parent of this and the target space

			commonParent = null;
			currentObject = this;

			while (currentObject)
			{
				sAncestors.push(currentObject);
				currentObject = currentObject.mParent;
			}

			currentObject = targetSpace;
			while (currentObject && sAncestors.indexOf(currentObject) == -1)
				currentObject = currentObject.mParent;

			sAncestors.length = 0;

			if (currentObject)
				commonParent = currentObject;
			else
				throw new ArgumentError("Object not connected to target");

			// 2. move up from this to common parent

			currentObject = this;
			while (currentObject != commonParent)
			{
				resultMatrix.concat(currentObject.transformationMatrix);
				currentObject = currentObject.mParent;
			}

			if (commonParent == targetSpace)
				return resultMatrix;

			// 3. now move up from target until we reach the common parent

			sHelperMatrix.identity();
			currentObject = targetSpace;
			while (currentObject != commonParent)
			{
				sHelperMatrix.concat(currentObject.transformationMatrix);
				currentObject = currentObject.mParent;
			}

			// 4. now combine the two matrices

			sHelperMatrix.invert();
			resultMatrix.concat(sHelperMatrix);

			return resultMatrix;
		}

		/** Transforms a point from global (stage) coordinates to the local coordinate system.
		 *  If you pass a 'resultPoint', the result will be stored in this point instead of
		 *  creating a new object. */
		public function globalToLocal(globalPoint:Point, resultPoint:Point = null):Point
		{
			getTransformationMatrix(base, sHelperMatrix);
			sHelperMatrix.invert();
			return MatrixUtil.transformCoords(sHelperMatrix, globalPoint.x, globalPoint.y, resultPoint);
		}

		/** Indicates if an object occupies any visible area. (Which is the case when its 'alpha',
		 *  'scaleX' and 'scaleY' values are not zero, and its 'visible' property is enabled.) */
		public function get hasVisibleArea():Boolean
		{
			return mSpatial.mAlpha != 0.0 && mSpatial.mVisible && mSpatial.mScaleX != 0.0 && mSpatial.mScaleY != 0.0;
		}

		/** The height of the object in pixels. */
		public function get height():Number
		{
			return getBounds(mParent, sHelperRect).height;
		}

		public function set height(value:Number):void
		{
			scaleY = 1.0;
			var actualHeight:Number = height;
			if (actualHeight != 0.0)
				scaleY = value / actualHeight;
		}

		/** Returns the object that is found topmost beneath a point in local coordinates, or nil if
		 *  the test fails. If "forTouch" is true, untouchable and invisible objects will cause
		 *  the test to fail. */
		public function hitTest(localPoint:Point, forTouch:Boolean = false):DisplayObject
		{
			// on a touch test, invisible or untouchable objects cause the test to fail
			if (forTouch && (!mSpatial.mVisible || !mTouchable))
				return null;

			// otherwise, check bounding box
			if(mHitTransparent)
			{
				if (getBounds(this, sHelperRect).containsPoint(localPoint))
					return this;
				else
					return null;
			}
			else
			{
				// Basic bounds test first
				if (!getBounds(this).containsPoint(localPoint)) return null;

				if (_hit_test_rs==null) _hit_test_rs = new RenderSupport();
				_hit_test_rs.nextFrame();

				// The second parameter here, alpha, doesn't seem to do anything...
				// it draws a fully opaque background either way...
				_hit_test_rs.clear(0xf203b4,1);
				var context:Context3D = Starling.current.context;

				// The below seems to draw "this" in the parent's coordinate space,
				// so transform localPoint to parent space
				this.localToGlobal(localPoint, _temp_p);
				parent.globalToLocal(_temp_p, _temp_p);
				_hit_test_rs.setOrthographicProjection(_temp_p.x, _temp_p.y,
													   1,
													   1);

				_hit_test_rs.transformMatrix(this);
				_hit_test_rs.pushMatrix();
				_hit_test_bd.setPixel32(0,0,0);
				this.render(_hit_test_rs, 1.0);
				_hit_test_rs.popMatrix();
				_hit_test_rs.finishQuadBatch();
				context.drawToBitmapData(_hit_test_bd);

				// We'd prefer this test, but the above always renders solid backgrounds...
				//if (((_hit_test_bd.getPixel32(0,0) >> 24) & 0xff) > 0x20) {
				if (_hit_test_bd.getPixel32(0,0) != 0xfff203b4) {
					return this;
				} else {
					return null;
				}
			}
		}

		/** Transforms a point from the local coordinate system to global (stage) coordinates.
		 *  If you pass a 'resultPoint', the result will be stored in this point instead of
		 *  creating a new object. */
		public function localToGlobal(localPoint:Point, resultPoint:Point = null):Point
		{
			getTransformationMatrix(base, sHelperMatrix);
			return MatrixUtil.transformCoords(sHelperMatrix, localPoint.x, localPoint.y, resultPoint);
		}

		/** The name of the display object (default: null). Used by 'getChildByName()' of
		 *  display object containers. */
		public function get name():String
		{
			return mName;
		}

		public function set name(value:String):void
		{
			mName = value;
		}

		/** The display object container that contains this display object. */
		public function get parent():DisplayObjectContainer
		{
			return mParent;
		}

		/** The x coordinate of the object's origin in its own coordinate space (default: 0). */
		public function get pivotX():Number
		{
			return mSpatial.mPivotX;
		}

		public function set pivotX(value:Number):void
		{
			if (mSpatial.mPivotX != value)
			{
				mSpatial.mPivotX = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** The y coordinate of the object's origin in its own coordinate space (default: 0). */
		public function get pivotY():Number
		{
			return mSpatial.mPivotY;
		}

		public function set pivotY(value:Number):void
		{
			if (mSpatial.mPivotY != value)
			{
				mSpatial.mPivotY = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** Removes the object from its parent, if it has one. */
		public function removeFromParent(dispose:Boolean = false):void
		{
			if (mParent)
				mParent.removeChild(this, dispose);
		}

		/** Renders the display object with the help of a support object. Never call this method
		 *  directly, except from within another render method.
		 *  @param support Provides utility functions for rendering.
		 *  @param parentAlpha The accumulated alpha value from the object's parent up to the stage. */
		public function render(support:RenderSupport, parentAlpha:Number):void
		{
			throw new AbstractMethodError("Method needs to be implemented in subclass");
		}

		/** The root object the display object is connected to (i.e. an instance of the class
		 *  that was passed to the Starling constructor), or null if the object is not connected
		 *  to the stage. */
		public function get root():DisplayObject
		{
			var currentObject:DisplayObject = this;
			while (currentObject.mParent)
			{
				if (currentObject.mParent is Stage)
					return currentObject;
				else
					currentObject = currentObject.parent;
			}

			return null;
		}

		/** The rotation of the object in radians. (In Starling, all angles are measured
		 *  in radians.) */
		public function get rotation():Number
		{
			return mSpatial.mRotation;
		}

		public function set rotation(value:Number):void
		{
			value = normalizeAngle(value);

			if (mSpatial.mRotation != value)
			{
				mSpatial.mRotation = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** The horizontal scale factor. '1' means no scale, negative values flip the object. */
		public function get scaleX():Number
		{
			return mSpatial.mScaleX;
		}

		public function set scaleX(value:Number):void
		{
			if (mSpatial.mScaleX != value)
			{
				mSpatial.mScaleX = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** The vertical scale factor. '1' means no scale, negative values flip the object. */
		public function get scaleY():Number
		{
			return mSpatial.mScaleY;
		}

		public function set scaleY(value:Number):void
		{
			if (mSpatial.mScaleY != value)
			{
				mSpatial.mScaleY = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** The horizontal skew angle in radians. */
		public function get skewX():Number
		{
			return mSpatial.mSkewX;
		}

		public function set skewX(value:Number):void
		{
			value = normalizeAngle(value);

			if (mSpatial.mSkewX != value)
			{
				mSpatial.mSkewX = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** The vertical skew angle in radians. */
		public function get skewY():Number
		{
			return mSpatial.mSkewY;
		}

		public function set skewY(value:Number):void
		{
			value = normalizeAngle(value);

			if (mSpatial.mSkewY != value)
			{
				mSpatial.mSkewY = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/**
		 * replace the original spatial with a derived Spatial instance.
		 * Useful when we want to hook up Starling with another system that manipulates Spatial
		 *
		 * @param t The spatial to set
		 */
		public function set spatial(s:Spatial):void
		{
			if (!s.mTransformationMatrix)
				s.mTransformationMatrix = this.mSpatial.mTransformationMatrix;
			this.mSpatial = s;
		}

		/** The stage the display object is connected to, or null if it is not connected
		 *  to the stage. */
		public function get stage():Stage
		{
			return this.base as Stage;
		}

		/** Indicates if this object (and its children) will receive touch events. */
		public function get touchable():Boolean
		{
			return mTouchable;
		}

		public function set touchable(value:Boolean):void
		{
			mTouchable = value;
		}

		// properties

		/** The transformation matrix of the object relative to its parent.
		 *
		 *  <p>If you assign a custom transformation matrix, Starling will try to figure out
		 *  suitable values for <code>x, y, scaleX, scaleY,</code> and <code>rotation</code>.
		 *  However, if the matrix was created in a different way, this might not be possible.
		 *  In that case, Starling will apply the matrix, but not update the corresponding
		 *  properties.</p>
		 *
		 *  @returns CAUTION: not a copy, but the actual object! */
		public function get transformationMatrix():Matrix
		{
			if (mSpatial.mOrientationChanged)
			{
				mSpatial.mOrientationChanged = false;

				if (mSpatial.mSkewX == 0.0 && mSpatial.mSkewY == 0.0)
				{
					// optimization: no skewing / rotation simplifies the matrix math

					if (mSpatial.mRotation == 0.0)
					{
						mSpatial.mTransformationMatrix.setTo(mSpatial.mScaleX, 0.0, 0.0, mSpatial.mScaleY,
															 mSpatial.mX - mSpatial.mPivotX * mSpatial.mScaleX, mSpatial.mY - mSpatial.mPivotY * mSpatial.mScaleY);
					}
					else
					{
						var cos:Number = Math.cos(mSpatial.mRotation);
						var sin:Number = Math.sin(mSpatial.mRotation);
						var a:Number   = mSpatial.mScaleX * cos;
						var b:Number   = mSpatial.mScaleX * sin;
						var c:Number   = mSpatial.mScaleY * -sin;
						var d:Number   = mSpatial.mScaleY * cos;
						var tx:Number  = mSpatial.mX - mSpatial.mPivotX * a - mSpatial.mPivotY * c;
						var ty:Number  = mSpatial.mY - mSpatial.mPivotX * b - mSpatial.mPivotY * d;

						mSpatial.mTransformationMatrix.setTo(a, b, c, d, tx, ty);
					}
				}
				else
				{
					mSpatial.mTransformationMatrix.identity();
					mSpatial.mTransformationMatrix.scale(mSpatial.mScaleX, mSpatial.mScaleY);
					MatrixUtil.skew(mSpatial.mTransformationMatrix, mSpatial.mSkewX, mSpatial.mSkewY);
					mSpatial.mTransformationMatrix.rotate(mSpatial.mRotation);
					mSpatial.mTransformationMatrix.translate(mSpatial.mX, mSpatial.mY);

					if (mSpatial.mPivotX != 0.0 || mSpatial.mPivotY != 0.0)
					{
						// prepend pivot transformation
						mSpatial.mTransformationMatrix.tx = mSpatial.mX - mSpatial.mTransformationMatrix.a * mSpatial.mPivotX
							- mSpatial.mTransformationMatrix.c * mSpatial.mPivotY;
						mSpatial.mTransformationMatrix.ty = mSpatial.mY - mSpatial.mTransformationMatrix.b * mSpatial.mPivotX
							- mSpatial.mTransformationMatrix.d * mSpatial.mPivotY;
					}
				}
			}

			return mSpatial.mTransformationMatrix;
		}

		public function set transformationMatrix(matrix:Matrix):void
		{
			mSpatial.mOrientationChanged = false;
			mSpatial.mTransformationMatrix.copyFrom(matrix);

			mSpatial.mX = matrix.tx;
			mSpatial.mY = matrix.ty;

			mSpatial.mScaleX = Math.sqrt(matrix.a * matrix.a + matrix.b * matrix.b);
			mSpatial.mSkewY = Math.acos(matrix.a / mSpatial.mScaleX);

			if (!isEquivalent(matrix.b, mSpatial.mScaleX * Math.sin(mSpatial.mSkewY)))
			{
				mSpatial.mScaleX *= -1;
				mSpatial.mSkewY = Math.acos(matrix.a / mSpatial.mScaleX);
			}

			mSpatial.mScaleY = Math.sqrt(matrix.c * matrix.c + matrix.d * matrix.d);
			mSpatial.mSkewX = Math.acos(matrix.d / mSpatial.mScaleY);

			if (!isEquivalent(matrix.c, -mSpatial.mScaleY * Math.sin(mSpatial.mSkewX)))
			{
				mSpatial.mScaleY *= -1;
				mSpatial.mSkewX = Math.acos(matrix.d / mSpatial.mScaleY);
			}

			if (isEquivalent(mSpatial.mSkewX, mSpatial.mSkewY))
			{
				mSpatial.mRotation = mSpatial.mSkewX;
				if (mSpatial.mScaleX < 0 && mSpatial.mScaleY < 0)
					mSpatial.mRotation += Math.PI;
				mSpatial.mSkewX = mSpatial.mSkewY = 0;
			}
			else
			{
				mSpatial.mRotation = 0;
			}
		}

		/** Indicates if the mouse cursor should transform into a hand while it's over the sprite.
		 *  @default false */
		public function get useHandCursor():Boolean
		{
			return mUseHandCursor;
		}

		public function set useHandCursor(value:Boolean):void
		{
			if (value == mUseHandCursor)
				return;
			mUseHandCursor = value;

			if (mUseHandCursor)
				addEventListener(TouchEvent.TOUCH, onTouch);
			else
				removeEventListener(TouchEvent.TOUCH, onTouch);
		}

		/** The visibility of the object. An invisible object will be untouchable. */
		public function get visible():Boolean
		{
			return mSpatial.mVisible;
		}

		public function set visible(value:Boolean):void
		{
			mSpatial.mVisible = value;
		}

		/** The width of the object in pixels. */
		public function get width():Number
		{
			return getBounds(mParent, sHelperRect).width;
		}

		public function set width(value:Number):void
		{
			// this method calls 'this.scaleX' instead of changing t.mScaleX directly.
			// that way, subclasses reacting on size changes need to override only the scaleX method.

			scaleX = 1.0;
			var actualWidth:Number = width;
			if (actualWidth != 0.0)
				scaleX = value / actualWidth;
		}

		/** The x coordinate of the object relative to the local coordinates of the parent. */
		public function get x():Number
		{
			return mSpatial.mX;
		}

		public function set x(value:Number):void
		{
			if (mSpatial.mX != value)
			{
				mSpatial.mX = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** The y coordinate of the object relative to the local coordinates of the parent. */
		public function get y():Number
		{
			return mSpatial.mY;
		}

		public function set y(value:Number):void
		{
			if (mSpatial.mY != value)
			{
				mSpatial.mY = value;
				mSpatial.mOrientationChanged = true;
			}
		}

		/** The z coordinate of the object relative to the local coordinates of the parent. */
		public function get z():Number
		{
			return mSpatial.mZ;
		}

		public function set z(value:Number):void
		{
			if (mSpatial.mZ != value)
			{
				mSpatial.mZ = value;
			}
		}

		// internal methods

		/** @private */
		internal function setParent(value:DisplayObjectContainer):void
		{
			// check for a recursion
			var ancestor:DisplayObject = value;
			while (ancestor != this && ancestor != null)
				ancestor = ancestor.mParent;

			if (ancestor == this)
				throw new ArgumentError("An object cannot be added as a child to itself or one " +
										"of its children (or children's children, etc.)");
			else
				mParent = value;
		}

		// helpers

		private final function isEquivalent(a:Number, b:Number, epsilon:Number = 0.0001):Boolean
		{
			return (a - epsilon < b) && (a + epsilon > b);
		}

		private final function normalizeAngle(angle:Number):Number
		{
			// move into range [-180 deg, +180 deg]
			while (angle < -Math.PI)
				angle += Math.PI * 2.0;
			while (angle > Math.PI)
				angle -= Math.PI * 2.0;
			return angle;
		}

		private function onTouch(event:TouchEvent):void
		{
			Mouse.cursor = event.interactsWith(this) ? MouseCursor.BUTTON : MouseCursor.AUTO;
		}
	}
}

