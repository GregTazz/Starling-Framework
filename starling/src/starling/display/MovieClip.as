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
	import flash.errors.IllegalOperationError;
	import flash.media.Sound;

	import starling.animation.IAnimatable;
	import starling.events.Event;
	import starling.textures.Texture;

	/** Dispatched whenever the movie has displayed its last frame. */
	[Event(name = "complete", type = "starling.events.Event")]
	/** A MovieClip is a simple way to display an animation depicted by a list of textures.
	 *
	 *  <p>Pass the frames of the movie in a vector of textures to the constructor. The movie clip
	 *  will have the width and height of the first frame. If you group your frames with the help
	 *  of a texture atlas (which is recommended), use the <code>getTextures</code>-method of the
	 *  atlas to receive the textures in the correct (alphabetic) order.</p>
	 *
	 *  <p>You can specify the desired framerate via the constructor. You can, however, manually
	 *  give each frame a custom duration. You can also play a sound whenever a certain frame
	 *  appears.</p>
	 *
	 *  <p>The methods <code>play</code> and <code>pause</code> control playback of the movie. You
	 *  will receive an event of type <code>Event.MovieCompleted</code> when the movie finished
	 *  playback. If the movie is looping, the event is dispatched once per loop.</p>
	 *
	 *  <p>As any animated object, a movie clip has to be added to a juggler (or have its
	 *  <code>advanceTime</code> method called regularly) to run. The movie will dispatch
	 *  an event of type "Event.COMPLETE" whenever it has displayed its last frame.</p>
	 *
	 *  @see starling.textures.TextureAtlas
	 */
	public class MovieClip extends Image implements IAnimatable
	{

		/** Creates a movie clip from the provided textures and with the specified default framerate.
		 *  The movie will have the size of the first frame. */
		public function MovieClip(textures:Vector.<Texture>, fps:Number = 12, sequencesNames:Vector.<String> = null, sequencesLengths:Vector.<int> = null)
		{
			if (textures.length > 0)
			{
				super(textures[0]);
				init(textures, fps, sequencesNames, sequencesLengths);
			}
			else
			{
				throw new ArgumentError("Empty texture array");
			}
		}

		private var mCurrentFrame:int;
		private var mCurrentTime:Number;

		private var mDefaultFrameDuration:Number;
		private var mDurations:Vector.<Number>;
		private var mFinalFrame:int;
		private var mFinalTime:Number;

		private var mLoop:Boolean;
		private var mPlaying:Boolean;
		private var mSequence:Sequence;
		private var mSequences:Vector.<Sequence>;
		private var mSounds:Vector.<Sound>;
		private var mStartFrame:int;
		private var mStartTime:Number;
		private var mStartTimes:Vector.<Number>;
		private var mTextures:Vector.<Texture>;

		// frame manipulation

		/** Adds an additional frame, optionally with a sound and a custom duration. If the
		 *  duration is omitted, the default framerate is used (as specified in the constructor). */
		public function addFrame(texture:Texture, sound:Sound = null, duration:Number = -1):void
		{
			addFrameAt(numFrames, texture, sound, duration);
		}

		/** Adds a frame at a certain index, optionally with a sound and a custom duration. */
		public function addFrameAt(frameID:int, texture:Texture, sound:Sound = null,
								   duration:Number = -1):void
		{
			if (frameID < 0 || frameID > numFrames)
				throw new ArgumentError("Invalid frame id");
			if (duration < 0)
				duration = mDefaultFrameDuration;

			mTextures.splice(frameID, 0, texture);
			mSounds.splice(frameID, 0, sound);
			mDurations.splice(frameID, 0, duration);

			if (frameID > 0 && frameID == numFrames)
				mStartTimes[frameID] = mStartTimes[frameID - 1] + mDurations[frameID - 1];
			else
				updateStartTimes();

			if (mSequences.length)
			{
				addToSequenceAt(frameID);
				updateCurrentSequence();
			}
			else
				mFinalTime += duration;
		}

		// IAnimatable

		/** @inheritDoc */
		public function advanceTime(passedTime:Number):void
		{
			var previousFrame:int       = mCurrentFrame;
			var restTime:Number         = 0.0;
			var breakAfterFrame:Boolean = false;

			if (mLoop && mCurrentTime == mFinalTime)
			{
				mCurrentTime = mStartTime;
				mCurrentFrame = mStartFrame;
			}

			if (mPlaying && passedTime > 0.0 && mCurrentTime < mFinalTime)
			{
				mCurrentTime += passedTime;

				while (mCurrentTime >= mStartTimes[mCurrentFrame] + mDurations[mCurrentFrame])
				{
					if (mCurrentFrame == mFinalFrame)
					{
						if (hasEventListener(Event.COMPLETE))
						{
							if (mCurrentFrame != previousFrame)
								texture = mTextures[mCurrentFrame];

							restTime = mCurrentTime - mFinalTime;
							mCurrentTime = mFinalTime;
							dispatchEventWith(Event.COMPLETE);
							breakAfterFrame = true;
						}

						if (mLoop)
						{
							mCurrentTime -= mFinalTime - mStartTime;
							mCurrentFrame = mStartFrame;
						}
						else
						{
							mCurrentTime = mFinalTime;
							breakAfterFrame = true;
						}
					}
					else
					{
						mCurrentFrame++;
					}

					var sound:Sound = mSounds[mCurrentFrame];
					if (sound)
						sound.play();
					if (breakAfterFrame)
						break;
				}
			}

			if (mCurrentFrame != previousFrame)
				texture = mTextures[mCurrentFrame];

			if (restTime)
				advanceTime(restTime);
		}

		/** The index of the frame that is currently displayed. */
		public function get currentFrame():int
		{
			return mCurrentFrame;
		}

		public function set currentFrame(value:int):void
		{
			mCurrentFrame = value;
			mCurrentTime = 0.0;

			for (var i:int = 0; i < value; ++i)
				mCurrentTime += getFrameDuration(i);

			texture = mTextures[mCurrentFrame];
			if (mSounds[mCurrentFrame])
				mSounds[mCurrentFrame].play();
		}

		/** The default number of frames per second. Individual frames can have different
		 *  durations. If you change the fps, the durations of all frames will be scaled
		 *  relatively to the previous value. */
		public function get fps():Number
		{
			return 1.0 / mDefaultFrameDuration;
		}

		public function set fps(value:Number):void
		{
			if (value <= 0)
				throw new ArgumentError("Invalid fps: " + value);

			var newFrameDuration:Number = 1.0 / value;
			var acceleration:Number     = newFrameDuration / mDefaultFrameDuration;
			mCurrentTime *= acceleration;
			mDefaultFrameDuration = newFrameDuration;

			for (var i:int = 0; i < numFrames; ++i)
			{
				var duration:Number = mDurations[i] * acceleration;
				mFinalTime = mFinalTime - mDurations[i] + duration;
				mDurations[i] = duration;
			}

			updateStartTimes();
		}

		/** Returns the duration of a certain frame (in seconds). */
		public function getFrameDuration(frameID:int):Number
		{
			if (frameID < 0 || frameID >= numFrames)
				throw new ArgumentError("Invalid frame id");
			return mDurations[frameID];
		}

		/** Returns the sound of a certain frame. */
		public function getFrameSound(frameID:int):Sound
		{
			if (frameID < 0 || frameID >= numFrames)
				throw new ArgumentError("Invalid frame id");
			return mSounds[frameID];
		}

		/** Returns the texture of a certain frame. */
		public function getFrameTexture(frameID:int):Texture
		{
			if (frameID < 0 || frameID >= numFrames)
				throw new ArgumentError("Invalid frame id");
			return mTextures[frameID];
		}

		public function getCurrentSequenceName():String
		{
			return mSequence ? mSequence.label : "none";
		}

		public function gotoAndPlay(sequence:String):void
		{
			mSequence = getSequenceByName(sequence);
			if (!mSequence)
				throw new ArgumentError("Invalid sequence name");

			updateCurrentSequence();
			play();
		}

		public function gotoAndStop(sequence:String):void
		{
			mSequence = getSequenceByName(sequence);
			if (!mSequence)
				throw new ArgumentError("Invalid sequence name");

			updateCurrentSequence();
			pause();
		}

		/** Indicates if a (non-looping) movie has come to its end. */
		public function get isComplete():Boolean
		{
			return !mLoop && mCurrentTime >= mFinalTime;
		}

		/** Indicates if the clip is still playing. Returns <code>false</code> when the end
		 *  is reached. */
		public function get isPlaying():Boolean
		{
			if (mPlaying)
				return mLoop || mCurrentTime < mFinalTime;
			else
				return false;
		}

		/** Indicates if the clip should loop. */
		public function get loop():Boolean
		{
			return mLoop;
		}

		public function set loop(value:Boolean):void
		{
			mLoop = value;
		}

		/** The total number of frames. */
		public function get numFrames():int
		{
			return mTextures.length;
		}

		/** Pauses playback. */
		public function pause():void
		{
			mPlaying = false;
		}

		// playback methods

		/** Starts playback. Beware that the clip has to be added to a juggler, too! */
		public function play():void
		{
			mPlaying = true;
		}

		/** Removes the frame at a certain ID. The successors will move down. */
		public function removeFrameAt(frameID:int):void
		{
			if (frameID < 0 || frameID >= numFrames)
				throw new ArgumentError("Invalid frame id");
			if (numFrames == 1)
				throw new IllegalOperationError("Movie clip must not be empty");

			mTextures.splice(frameID, 1);
			mSounds.splice(frameID, 1);
			mDurations.splice(frameID, 1);

			updateStartTimes();

			if (mSequences.length)
			{
				removeFromSequenceAt(frameID);
				updateCurrentSequence();
			}
			else
				mFinalTime -= getFrameDuration(frameID);
		}

		/** Sets the duration of a certain frame (in seconds). */
		public function setFrameDuration(frameID:int, duration:Number):void
		{
			if (frameID < 0 || frameID >= numFrames)
				throw new ArgumentError("Invalid frame id");
			mDurations[frameID] = duration;
			updateStartTimes();

			if (mSequences.length)
				updateCurrentSequence();
			else
			{
				mFinalTime -= getFrameDuration(frameID);
				mFinalTime += duration;
			}
		}

		/** Sets the sound of a certain frame. The sound will be played whenever the frame
		 *  is displayed. */
		public function setFrameSound(frameID:int, sound:Sound):void
		{
			if (frameID < 0 || frameID >= numFrames)
				throw new ArgumentError("Invalid frame id");
			mSounds[frameID] = sound;
		}

		/** Sets the texture of a certain frame. */
		public function setFrameTexture(frameID:int, texture:Texture):void
		{
			if (frameID < 0 || frameID >= numFrames)
				throw new ArgumentError("Invalid frame id");
			mTextures[frameID] = texture;
		}

		/** Stops playback, resetting "currentFrame" to zero. */
		public function stop():void
		{
			mPlaying = false;
			currentFrame = 0;
		}

		// properties  

		/** The total duration of the clip in seconds. */
		public function get totalTime():Number
		{
			return mFinalTime;
		}

		private function addToSequenceAt(frameID:int):void
		{
			var i:int = 0,
				l:int = mSequences.length,
				sequence:Sequence;
			for (i; i < l; ++i)
			{
				sequence = mSequences[i];
				if (sequence.start > frameID)
					++sequence.start;
				else if (sequence.start <= frameID && sequence.start + sequence.length > frameID)
					++sequence.length;
			}
		}

		private function getSequenceByName(label:String):Sequence
		{
			for (var i:int = 0, l:int = mSequences.length; i < l; ++i)
			{
				if (mSequences[i].label == label)
					return mSequences[i];
			}
			return null;
		}

		private function init(textures:Vector.<Texture>, fps:Number, sequencesNames:Vector.<String> = null, sequencesLengths:Vector.<int> = null):void
		{
			if (fps <= 0)
				throw new ArgumentError("Invalid fps: " + fps);
			var numFrames:int = textures.length,
				i:int;

			mDefaultFrameDuration = 1.0 / fps;
			mLoop = true;
			mPlaying = true;
			mCurrentTime = 0.0;
			mCurrentFrame = 0;
			mStartTime = 0.0;
			mStartFrame = 0;
			mFinalTime = mDefaultFrameDuration * numFrames;
			mTextures = textures.concat();
			mSounds = new Vector.<Sound>(numFrames);
			mDurations = new Vector.<Number>(numFrames);
			mStartTimes = new Vector.<Number>(numFrames);
			mSequences = new Vector.<Sequence>;

			for (i = 0; i < numFrames; ++i)
			{
				mDurations[i] = mDefaultFrameDuration;
				mStartTimes[i] = i * mDefaultFrameDuration;
			}

			if (sequencesNames && sequencesLengths)
			{
				// Check sequences name/length integrity with MovieClip
				// Note that if you choose to define sequences in the movie clip
				// sequences MUST be defined for the entire "timeline" of the clip
				if (sequencesLengths.length == sequencesNames.length && sequencesNames.length > 0)
				{
					var l:int = sequencesLengths.length,
						totalLength:int = 0,
						sequence:Sequence;
					for (i = 0; i < l; ++i)
					{
						sequence = new Sequence;
						sequence.label = sequencesNames[i];
						sequence.length = sequencesLengths[i];
						sequence.start = totalLength;
						mSequences.push(sequence);
						totalLength += sequence.length;
					}
					//gotoAndStop(sequencesNames[0]);

					if (totalLength != numFrames)
					{
						mSequence = null;
						mSequences.length = 0;
						throw new ArgumentError("Inconsistent sequences definitions");
					}
				}
				else
				{
					throw new ArgumentError("Inconsistent sequences definitions");
				}
				gotoAndPlay(sequencesNames[0]);
			}

		}

		private function removeFromSequenceAt(frameID:int):void
		{
			var i:int = 0,
				sequence:Sequence;
			for (i; i < mSequences.length; ++i)
			{
				sequence = mSequences[i];
				if (sequence.start > frameID)
					--sequence.start;
				else if (sequence.start <= frameID && sequence.start + sequence.length > frameID)
					--sequence.length;

				if (!sequence.length)
				{
					mSequences.splice(i, 1);
					--i;
				}
			}
		}

		private function updateCurrentSequence():void
		{
			mFinalFrame = mSequence.start + mSequence.length - 1;
			mStartTime = mStartTimes[mSequence.start];
			mStartFrame = mSequence.start;
			mFinalTime = mStartTimes[mFinalFrame] + mDurations[mFinalFrame];

			mCurrentTime = mStartTime;
			mCurrentFrame = mStartFrame;
			texture = mTextures[mCurrentFrame];
		}

		// helpers

		private function updateStartTimes():void
		{
			var numFrames:int = this.numFrames;

			mStartTimes.length = 0;
			mStartTimes[0] = 0;

			for (var i:int = 1; i < numFrames; ++i)
				mStartTimes[i] = mStartTimes[i - 1] + mDurations[i - 1];
		}
	}
}

class Sequence
{
	public var label:String;
	public var length:int;
	public var start:int;
}


