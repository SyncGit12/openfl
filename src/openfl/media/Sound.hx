package openfl.media;

#if !flash
import haxe.Int64;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.IOErrorEvent;
import openfl.net.URLRequest;
import openfl.utils.ByteArray;
import openfl.utils.Future;
#if (js && html5)
import lime.media.AudioManager;
import lime.media.WebAudioContext;
import openfl.events.SampleDataEvent;
#end
#if lime_openal
import lime.media.openal.ALBuffer;
import lime.media.openal.ALSource;
import lime.media.AudioManager;
import lime.media.OpenALAudioContext;
import openfl.events.SampleDataEvent;
import lime.utils.ArrayBufferView;
import lime.utils.Int16Array;
#end
#if lime
import openfl.utils._internal.UInt8Array;
import lime.media.AudioBuffer;
import lime.media.AudioSource;
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(lime.media.AudioBuffer)
@:access(lime.utils.AssetLibrary)
@:access(openfl.media.SoundMixer)
@:access(openfl.media.SoundChannel.new)
@:autoBuild(openfl.utils._internal.AssetsMacro.embedSound())
class Sound extends EventDispatcher
{
	/**
		Returns the currently available number of bytes in this sound object. This
		property is usually useful only for externally loaded files.
	**/
	public var bytesLoaded(default, null):Int;

	/**
		Returns the total number of bytes in this sound object.
	**/
	public var bytesTotal(default, null):Int;

	public var id3(get, never):ID3Info;

	public var isBuffering(default, null):Bool;

	// @:noCompletion @:dox(hide) @:require(flash10_1) public var isURLInaccessible (default, null):Bool;
	public var length(get, never):Float;

	public var url(default, null):String;

	#if lime
	@:noCompletion private var __buffer:AudioBuffer;
	#end

	#if (js && html5)
	public var sampleRate(get, never):Int;

	private var __audioContext:WebAudioContext = null;
	private var __processor:js.html.audio.ScriptProcessorNode;
	private var __sampleData:SampleDataEvent;
	private var __firstRun:Bool = true;
	#end

	#if lime_openal
	public var sampleRate(get, never):Int;

	private var __ALAudioContext:OpenALAudioContext = null;
	private var __sampleData:SampleDataEvent;
	private var __source:ALSource;
	private var __outputBuffer:ByteArray;
	private var __bufferView:ArrayBufferView;
	private var __buffers:Array<ALBuffer>;
	private var __numberOFBuffers:Int = 3;
	private var __listenerRemoved:Bool = false;
	private var __emptyBuffers:Array<ALBuffer>;
	#end

	#if openfljs
	@:noCompletion private static function __init__()
	{
		untyped Object.defineProperties(Sound.prototype, {
			"id3": {get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_id3 (); }")},
			"length": {get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_length (); }")},
		});
	}
	#end

	public function new(stream:URLRequest = null, context:SoundLoaderContext = null)
	{
		super(this);

		bytesLoaded = 0;
		bytesTotal = 0;
		isBuffering = false;
		url = null;

		if (stream != null)
		{
			load(stream, context);
		}
		#if (js && html5)
		if (stream == null && AudioManager.context != null)
		{
			switch (AudioManager.context.type)
			{
				case WEB:
					__audioContext = AudioManager.context.web;
				default:
			}
		}
		#end
		#if lime_openal
		if (stream == null && AudioManager.context != null)
		{
			switch (AudioManager.context.type)
			{
				case OPENAL:
					__ALAudioContext = AudioManager.context.openal;
				default:
			}
		}
		#end
	}

	/**
		Closes the stream, causing any download of data to cease. No data may
		be read from the stream after the `close()` method is called.

		@throws IOError The stream could not be closed, or the stream was not
						open.
	**/
	public function close():Void
	{
		#if lime
		if (__buffer != null)
		{
			__buffer.dispose();
			__buffer = null;
		}
		#end
	}

	#if false
	// @:noCompletion @:dox(hide) @:require(flash10) public function extract (target:ByteArray, length:Float, startPosition:Float = -1):Float;
	#end

	#if lime
	/**
		Creates a new Sound from an AudioBuffer immediately.

		@param	buffer	An AudioBuffer instance
		@returns	A new Sound
	**/
	public static function fromAudioBuffer(buffer:AudioBuffer):Sound
	{
		var sound = new Sound();
		sound.__buffer = buffer;
		return sound;
	}
	#end

	public static function fromFile(path:String):Sound
	{
		#if lime
		return fromAudioBuffer(AudioBuffer.fromFile(path));
		#else
		return null;
		#end
	}

	public function load(stream:URLRequest, context:SoundLoaderContext = null):Void
	{
		url = stream.url;

		#if lime
		#if (js && html5)
		var defaultLibrary = lime.utils.Assets.getLibrary("default"); // TODO: Improve this

		if (defaultLibrary != null && defaultLibrary.cachedAudioBuffers.exists(url))
		{
			AudioBuffer_onURLLoad(defaultLibrary.cachedAudioBuffers.get(url));
		}
		else
		{
			AudioBuffer.loadFromFile(url).onComplete(AudioBuffer_onURLLoad).onError(function(_)
			{
				AudioBuffer_onURLLoad(null);
			});
		}
		#else
		AudioBuffer.loadFromFile(url).onComplete(AudioBuffer_onURLLoad).onError(function(_)
		{
			AudioBuffer_onURLLoad(null);
		});
		#end
		#end
	}

	public function loadCompressedDataFromByteArray(bytes:ByteArray, bytesLength:Int):Void
	{
		if (bytes == null || bytesLength <= 0)
		{
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
			return;
		}

		if (bytes.position > 0 || bytes.length > bytesLength)
		{
			var copy = new ByteArray(bytesLength);
			copy.writeBytes(bytes, bytes.position, bytesLength);
			bytes = copy;
		}

		#if lime
		__buffer = AudioBuffer.fromBytes(bytes);

		if (__buffer == null)
		{
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		}
		else
		{
			dispatchEvent(new Event(Event.COMPLETE));
		}
		#else
		dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		#end
	}

	public static function loadFromFile(path:String):Future<Sound>
	{
		#if lime
		return AudioBuffer.loadFromFile(path).then(function(audioBuffer)
		{
			return Future.withValue(fromAudioBuffer(audioBuffer));
		});
		#else
		return cast Future.withError("Cannot load audio file");
		#end
	}

	public static function loadFromFiles(paths:Array<String>):Future<Sound>
	{
		#if lime
		return AudioBuffer.loadFromFiles(paths).then(function(audioBuffer)
		{
			return Future.withValue(fromAudioBuffer(audioBuffer));
		});
		#else
		return cast Future.withError("Cannot load audio files");
		#end
	}

	public function loadPCMFromByteArray(bytes:ByteArray, samples:Int, format:String = "float", stereo:Bool = true, sampleRate:Float = 44100):Void
	{
		if (bytes == null)
		{
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
			return;
		}

		var bitsPerSample = (format == "float" ? 32 : 16); // "short"
		var channels = (stereo ? 2 : 1);
		var bytesLength = Std.int(samples * channels * (bitsPerSample / 8));

		if (bytes.position > 0 || bytes.length > bytesLength)
		{
			var copy = new ByteArray(bytesLength);
			copy.writeBytes(bytes, bytes.position, bytesLength);
			bytes = copy;
		}

		#if lime
		var audioBuffer = new AudioBuffer();
		audioBuffer.bitsPerSample = bitsPerSample;
		audioBuffer.channels = channels;
		audioBuffer.data = new UInt8Array(bytes);
		audioBuffer.sampleRate = Std.int(sampleRate);

		__buffer = audioBuffer;

		dispatchEvent(new Event(Event.COMPLETE));
		#else
		dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		#end
	}

	public function play(startTime:Float = 0.0, loops:Int = 0, sndTransform:SoundTransform = null):SoundChannel
	{
		#if lime
		if (SoundMixer.__soundChannels.length >= SoundMixer.MAX_ACTIVE_CHANNELS)
		{
			return null;
		}

		if (sndTransform == null)
		{
			sndTransform = new SoundTransform();
		}
		else
		{
			sndTransform = sndTransform.clone();
		}

		var pan = SoundMixer.__soundTransform.pan + sndTransform.pan;

		if (pan > 1) pan = 1;
		if (pan < -1) pan = -1;

		var volume = SoundMixer.__soundTransform.volume * sndTransform.volume;

		var source = new AudioSource(__buffer);
		source.offset = Std.int(startTime);
		if (loops > 1) source.loops = loops - 1;

		source.gain = volume;

		var position = source.position;
		position.x = pan;
		position.z = -1 * Math.sqrt(1 - Math.pow(pan, 2));
		source.position = position;
		#if (js && html5)
		if (__audioContext != null && __buffer == null)
		{
			__sampleData = new SampleDataEvent(SampleDataEvent.SAMPLE_DATA);
			dispatchEvent(__sampleData);
			__processor = __audioContext.createScriptProcessor(@:privateAccess __sampleData.getBufferSize(), 0, 2);
			__processor.connect(__audioContext.destination);
			__processor.onaudioprocess = onSample;
			#if (haxe_ver >= 4.2)
			__audioContext.resume();
			#else
			Reflect.callMethod(__audioContext, Reflect.field(__audioContext, "resume"), []);
			#end
		}
		#end
		#if lime_openal
		if (__ALAudioContext != null && __buffer == null)
		{
			__listenerRemoved = false;
			__sampleData = new SampleDataEvent(SampleDataEvent.SAMPLE_DATA);
			dispatchEvent(__sampleData);
			var bufferSize:Int = 0;
			__source = __ALAudioContext.createSource();
			__ALAudioContext.sourcef(__source, __ALAudioContext.GAIN, 1);
			__ALAudioContext.source3f(__source, __ALAudioContext.POSITION, 0, 0, 0);
			__ALAudioContext.sourcef(__source, __ALAudioContext.PITCH, 1.0);

			__buffers = __ALAudioContext.genBuffers(__numberOFBuffers);
			__outputBuffer = new ByteArray();
			__bufferView = new lime.utils.Int16Array(__outputBuffer);

			for (a in 0...__numberOFBuffers)
			{
				if (bufferSize == 0)
				{
					bufferSize = @:privateAccess __sampleData.getBufferSize();
					@:privateAccess __sampleData.getSamples(__outputBuffer);
					__ALAudioContext.bufferData(__buffers[a], __ALAudioContext.FORMAT_STEREO16, __bufferView, bufferSize * 4, 44100);
				}
				else
				{
					dispatchEvent(__sampleData);
					@:privateAccess __sampleData.getSamples(__outputBuffer);
					__ALAudioContext.bufferData(__buffers[a], __ALAudioContext.FORMAT_STEREO16, __bufferView, bufferSize * 4, 44100);
				}
			}

			__ALAudioContext.sourceQueueBuffers(__source, __numberOFBuffers, __buffers);

			__ALAudioContext.sourcePlay(__source);
			lime.app.Application.current.onUpdate.add(watchBuffers);
		}
		#end

		return new SoundChannel(source, sndTransform);
		#else
		return null;
		#end
	}

	#if (js && html5)
	private function onSample(event:js.html.audio.AudioProcessingEvent):Void
	{
		if (__firstRun)
		{
			__firstRun = false;
		}
		else
		{
			dispatchEvent(__sampleData);
		}
		@:privateAccess __sampleData.getSamples(event);
	}

	override public function removeEventListener(type:String, listener:Dynamic->Void, useCapture:Bool = false):Void
	{
		super.removeEventListener(type, listener, useCapture);
		if (type == SampleDataEvent.SAMPLE_DATA && __processor != null)
		{
			__processor.disconnect();
			__processor.onaudioprocess = null;
			__processor = null;
		}
	}

	private function get_sampleRate():Int
	{
		return Std.int(__audioContext.sampleRate);
	}
	#end

	#if lime_openal
	private function watchBuffers(i:Int):Void
		{
			var bufferState = __ALAudioContext.getSourcei(__source, __ALAudioContext.BUFFERS_PROCESSED);
	
			if (bufferState > 0)
			{
				__emptyBuffers = __ALAudioContext.sourceUnqueueBuffers(__source, bufferState);
				for (a in 0...__emptyBuffers.length)
				{
					lime.app.Application.current.onUpdate.remove(watchBuffers);
					__ALAudioContext.sourceStop((__source));
					__ALAudioContext.deleteSource(__source);
					__ALAudioContext.deleteBuffers(__buffers);
					__ALAudioContext = null;
					__emptyBuffers = null;
					__source = null;
					__buffer = null;
				}
	
				if (__ALAudioContext.getSourcei(__source, __ALAudioContext.SOURCE_STATE) != __ALAudioContext.PLAYING)
				{
					__ALAudioContext.sourcePlay(__source);
				}
			}
			/*if (__listenerRemoved)
			{
				lime.app.Application.current.onUpdate.remove(watchBuffers);
				__ALAudioContext.sourceStop((__source));
				__ALAudioContext.deleteSource(__source);
				__ALAudioContext.deleteBuffers(__buffers);
				__ALAudioContext = null;
				__emptyBuffers = null;
				__source = null;
				__buffer = null;
			}*/
		}

	private function get_sampleRate():Int
	{
		return 44100;
	}

	override public function removeEventListener(type:String, listener:Dynamic->Void, useCapture:Bool = false):Void
	{
		super.removeEventListener(type, listener, useCapture);
		if (type == SampleDataEvent.SAMPLE_DATA && __ALAudioContext != null)
		{
			__listenerRemoved = true;
		}
	}
	#end

	// Get & Set Methods
	@:noCompletion private function get_id3():ID3Info
	{
		return new ID3Info();
	}

	@:noCompletion private function get_length():Int
	{
		#if lime
		if (__buffer != null)
		{
			#if (js && html5 && howlerjs)
			return Std.int(__buffer.src.duration() * 1000);
			#else
			if (__buffer.data != null)
			{
				var samples = (__buffer.data.length * 8) / (__buffer.channels * __buffer.bitsPerSample);
				return Std.int(samples / __buffer.sampleRate * 1000);
			}
			else if (__buffer.__srcVorbisFile != null)
			{
				var samples = Int64.toInt(__buffer.__srcVorbisFile.pcmTotal());
				return Std.int(samples / __buffer.sampleRate * 1000);
			}
			else
			{
				return 0;
			}
			#end
		}
		#end

		return 0;
	}

	// Event Handlers
	#if lime
	@:noCompletion private function AudioBuffer_onURLLoad(buffer:AudioBuffer):Void
	{
		if (buffer == null)
		{
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		}
		else
		{
			__buffer = buffer;
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
	#end
}
#else
typedef Sound = flash.media.Sound;
#end
