
All Versions
Page Discussion View source History
love
When beginning to write games using LÖVE, the most important parts of the API are the callbacks: love.load to do one-time setup of your game, love.update which is used to manage your game's state frame-to-frame, and love.draw which is used to render the game state onto the screen.

More interactive games will override additional callbacks in order to handle input from the user, and other aspects of a full-featured game.

LÖVE provides default placeholders for these callbacks, which you can override inside your own code by creating your own function with the same name as the callback:

-- Load some default values for our rectangle.
function love.load()
    x, y, w, h = 20, 20, 60, 20
end

-- Increase the size of the rectangle every frame.
function love.update(dt)
    w = w + 1
    h = h + 1
end

-- Draw a coloured rectangle.
function love.draw()
    -- In versions prior to 11.0, color component values are (0, 102, 102)
    love.graphics.setColor(0, 0.4, 0.4)
    love.graphics.rectangle("fill", x, y, w, h)
end
Modules
love.audio	Provides of audio interface for playback/recording sound.		
love.data	Provides functionality for creating and transforming data.	Added since 11.0	
love.event	Manages events, like keypresses.	Added since 0.6.0	
love.filesystem	Provides an interface to the user's filesystem.		
love.font	Allows you to work with fonts.	Added since 0.7.0	
love.graphics	Drawing of shapes and images, management of screen geometry.		
love.image	Provides an interface to decode encoded image data.		
love.joystick	Provides an interface to connected joysticks.	Added since 0.5.0	
love.keyboard	Provides an interface to the user's keyboard.		
love.math	Provides system-independent mathematical functions.	Added since 0.9.0	
love.mouse	Provides an interface to the user's mouse.		
love.physics	Can simulate 2D rigid body physics in a realistic manner.	Added since 0.4.0	
love.sound	This module is responsible for decoding sound files.		
love.system	Provides access to information about the user's system.	Added since 0.9.0	
love.thread	Allows you to work with threads.	Added since 0.7.0	
love.timer	Provides high-resolution timing functionality.		
love.touch	Provides an interface to touch-screen presses.	Added since 0.10.0	
love.video	This module is responsible for decoding and streaming video files.	Added since 0.10.0	
love.window	Provides an interface for the program's window.	Added since 0.9.0	
Third-party modules
lua-enet	Multiplayer networking module for games.	Added since 0.9.0	
socket	Module for HTTP, TCP, and UDP networking.	Added since 0.5.0	
utf8	Provides basic support for manipulating UTF-8 strings.	Added since 0.9.2	
Functions
love.getVersion	Gets the current running version of LÖVE.	Added since 0.9.1	
love.hasDeprecationOutput	Gets whether LÖVE displays warnings when using deprecated functionality.	Added since 11.0	
love.isVersionCompatible	Gets whether the given version is compatible with the current running version of LÖVE.	Added since 0.10.0	
love.setDeprecationOutput	Sets whether LÖVE displays warnings when using deprecated functionality.	Added since 11.0	
Types
Data	The superclass of all data.		
Object	The superclass of all LÖVE types.		
Variant	The types supported by love.thread and love.event.		
Callbacks
All callbacks are only called in main thread.

General
Config Files	Game configuration settings.		
love.draw	Callback function used to draw on the screen every frame.		
love.errhand	The error handler, used to display error messages.		Deprecated in 11.0
love.errorhandler	The error handler, used to display error messages.	Added since 11.0	
love.load	This function is called exactly once at the beginning of the game.		
love.lowmemory	Callback function triggered when the system is running out of memory on mobile devices.	Added since 0.10.0	
love.quit	Callback function triggered when the game is closed.	Added since 0.7.0	
love.run	The main callback function, containing the main loop. A sensible default is used when left out.		
love.threaderror	Callback function triggered when a Thread encounters an error.	Added since 0.9.0	
love.update	Callback function used to update the state of the game every frame.		
Window
love.directorydropped	Callback function triggered when a directory is dragged and dropped onto the window.	Added since 0.10.0	
love.displayrotated	Called when the device display orientation changed.	Added since 11.3	
love.filedropped	Callback function triggered when a file is dragged and dropped onto the window.	Added since 0.10.0	
love.focus	Callback function triggered when window receives or loses focus.	Added since 0.7.0	
love.mousefocus	Callback function triggered when window receives or loses mouse focus.	Added since 0.9.0	
love.resize	Called when the window is resized.	Added since 0.9.0	
love.visible	Callback function triggered when window is shown or hidden.	Added since 0.9.0	
Keyboard
love.keypressed	Callback function triggered when a key is pressed.		
love.keyreleased	Callback function triggered when a keyboard key is released.		
love.textedited	Called when the candidate text for an IME has changed.	Added since 0.10.0	
love.textinput	Called when text has been entered by the user.	Added since 0.9.0	
Mouse
love.mousemoved	Callback function triggered when the mouse is moved.	Added since 0.9.2	
love.mousepressed	Callback function triggered when a mouse button is pressed.		
love.mousereleased	Callback function triggered when a mouse button is released.		
love.wheelmoved	Callback function triggered when the mouse wheel is moved.	Added since 0.10.0	
Joystick
love.gamepadaxis	Called when a Joystick's virtual gamepad axis is moved.	Added since 0.9.0	
love.gamepadpressed	Called when a Joystick's virtual gamepad button is pressed.	Added since 0.9.0	
love.gamepadreleased	Called when a Joystick's virtual gamepad button is released.	Added since 0.9.0	
love.joystickadded	Called when a Joystick is connected.	Added since 0.9.0	
love.joystickaxis	Called when a joystick axis moves.	Added since 0.9.0	
love.joystickhat	Called when a joystick hat direction changes.	Added since 0.9.0	
love.joystickpressed	Called when a joystick button is pressed.		
love.joystickreleased	Called when a joystick button is released.		
love.joystickremoved	Called when a Joystick is disconnected.	Added since 0.9.0	
Touch
love.touchmoved	Callback function triggered when a touch press moves inside the touch screen.	Added since 0.10.0	
love.touchpressed	Callback function triggered when the touch screen is touched.	Added since 0.10.0	
love.touchreleased	Callback function triggered when the touch screen stops being touched.	Added since 0.10.0	


All Versions
Page Discussion View source History
love.audio
Provides of audio interface for playback/recording sound.

Types
RecordingDevice	Represents an audio input device capable of recording sounds.	Added since 11.0	
Source	A Source represents audio you can play back.		
Functions
love.audio.getActiveEffects	Gets a list of the names of the currently enabled effects.	Added since 11.0	
love.audio.getActiveSourceCount	Gets the current number of simultaneously playing sources.	Added since 11.0	
love.audio.getDistanceModel	Returns the distance attenuation model.	Added since 0.8.0	
love.audio.getDopplerScale	Gets the global scale factor for doppler effects.	Added since 0.9.2	
love.audio.getEffect	Gets the settings associated with an effect.	Added since 11.0	
love.audio.getMaxSceneEffects	Gets the maximum number of active effects.	Added since 11.0	
love.audio.getMaxSourceEffects	Gets the maximum number of active Effects for each Source.	Added since 11.0	
love.audio.getNumSources	Gets the current number of simultaneously playing sources.		Removed in 0.9.0
love.audio.getOrientation	Returns the orientation of the listener.		
love.audio.getPosition	Returns the position of the listener.		
love.audio.getRecordingDevices	Gets a list of RecordingDevices on the system.	Added since 11.0	
love.audio.getSourceCount	Gets the current number of simultaneously playing sources.	Added since 0.9.0	Deprecated in 11.0
love.audio.getVelocity	Returns the velocity of the listener.		
love.audio.getVolume	Returns the master volume.		
love.audio.isEffectsSupported	Gets whether Effects are supported in the system.	Added since 11.0	
love.audio.newQueueableSource	Creates a new Source usable for real-time generated sound playback with Source:queue.	Added since 11.0	
love.audio.newSource	Creates a new Source from a file, SoundData, or Decoder.		
love.audio.pause	Pauses specific or all currently played Sources.		
love.audio.play	Plays the specified Source.		
love.audio.resume	Resumes all audio.		Removed in 11.0
love.audio.rewind	Rewinds all playing audio.		Removed in 11.0
love.audio.setDistanceModel	Sets the distance attenuation model.	Added since 0.8.0	
love.audio.setDopplerScale	Sets a global scale factor for doppler effects.	Added since 0.9.2	
love.audio.setEffect	Defines an effect that can be applied to a Source.	Added since 11.0	
love.audio.setMixWithSystem	Sets whether the system should mix the audio with the system's audio.	Added since 11.0	
love.audio.setOrientation	Sets the orientation of the listener.		
love.audio.setPosition	Sets the position of the listener.		
love.audio.setVelocity	Sets the velocity of the listener.		
love.audio.setVolume	Sets the master volume.		
love.audio.stop	Stops currently played sources.		
Enums
DistanceModel	The different distance models.	Added since 0.8.0	
EffectType	Different types of audio effects.	Added since 11.0	
EffectWaveform	Types of waveforms for ringmodulator effect.	Added since 11.0	
SourceType	Types of audio sources.		
TimeUnit	Units that represent time.	Added since 0.8.0	


See Also
love
Tutorial:Audio
Audio Formats


All Versions
Page Discussion View source History
love.data
Available since LÖVE 11.0
This module is not supported in earlier versions.
Provides functionality for creating and transforming data.

Types
ByteData	Data object containing arbitrary bytes in an contiguous memory.	Added since 11.0	
CompressedData	Byte data compressed using a specific algorithm.	Added since 0.10.0	
Data	The superclass of all data.		
Functions
love.data.compress	Compresses a string or data using a specific compression algorithm.	Added since 11.0	
love.data.decode	Decode Data or a string from any of the EncodeFormats to Data or string.	Added since 11.0	
love.data.decompress	Decompresses a CompressedData or previously compressed string or Data object.	Added since 11.0	
love.data.encode	Encode Data or a string to a Data or string in one of the EncodeFormats.	Added since 11.0	
love.data.getPackedSize	Gets the size in bytes that a given format used with love.data.pack will use.	Added since 11.0	
love.data.hash	Compute message digest using specific hash algorithm.	Added since 11.0	
love.data.newByteData	Creates a new Data object containing arbitrary bytes.	Added since 11.0	
love.data.newDataView	Creates a new Data referencing a subsection of an existing Data object.	Added since 11.0	
love.data.pack	Packs (serializes) simple Lua values.	Added since 11.0	
love.data.unpack	Unpacks (deserializes) a byte-string or Data into simple Lua values.	Added since 11.0	
Enums
CompressedDataFormat	Compressed data formats.	Added since 0.10.0	
ContainerType	Return type of data-returning functions.	Added since 11.0	
EncodeFormat	Encoding format used to encode or decode data.	Added since 11.0	
HashFunction	Hash algorithm of hash function.	Added since 11.0


All Versions
Page Discussion View source History
love.event
Available since LÖVE 0.6.0
This module is not supported in earlier versions.
Manages events, like keypresses.

It is possible to define new events by appending the table love.handlers. Such functions can be invoked as usual, via love.event.push using the table index as an argument.

Functions
love.event.clear	Clears the event queue.	Added since 0.7.2	
love.event.poll	Returns an iterator for messages in the event queue.	Added since 0.6.0	
love.event.pump	Pump events into the event queue.	Added since 0.6.0	
love.event.push	Adds an event to the event queue.	Added since 0.6.0	
love.event.quit	Exits or restarts the LÖVE program.	Added since 0.8.0	
love.event.wait	Like love.event.poll(), but blocks until there is an event in the queue.	Added since 0.6.0	
Enums
Event	Arguments to love.event.push() and the like.	Added since 0.6.0


All Versions
Page Discussion View source History
love.filesystem
Provides an interface to the user's filesystem.

This module provides access to files in specific places:

The root folder of the .love archive (or source directory)
The root folder of the game's save directory.
The folder containing the game's .love archive (or source directory), but only if specific conditions are met.
Each game is granted a single directory on the system where files can be saved through love.filesystem. This is the only directory where love.filesystem can write files. These directories will typically be found in something like:

OS	Path	Alternative	Notes
Windows	C:\Users\user\AppData\Roaming\LOVE	%appdata%\LOVE\	When fused, save directory will be created directly inside AppData, rather than as a sub-directory of LOVE.
macOS	/Users/user/Library/Application Support/LOVE/	-	-
Linux	$XDG_DATA_HOME/love/	~/.local/share/love/	-
Android	/data/data/org.love2d.android/files/save/	/sdcard/Android/data/org.love2d.android/files/save/	The alternative path is used when activating t.externalstorage config option. Neither path is accessible through device directly due to Android restrictions.
Files that are opened for write or append will always be created in the save directory. The same goes for other operations that involve writing to the filesystem, like createDirectory.

Files that are opened for read will be looked for in the save directory, and then in the .love archive (in that order). So if a file with a certain filename (and path) exist in both the .love archive and the save folder, the one in the save directory takes precedence.

Note: All paths are relative to the .love archive and save directory. (except for the get*Directory() calls)

It is recommended to set your game's identity first in your conf.lua. You can set it with love.filesystem.setIdentity as well.

Types
DroppedFile	Represents a file dropped from the window.	Added since 0.10.0	
File	Represents a file on the filesystem.		
FileData	Data representing the contents of a file.		
Functions
love.filesystem.append	Append data to an existing file.	Added since 0.9.0	
love.filesystem.areSymlinksEnabled	Gets whether love.filesystem follows symbolic links.	Added since 0.9.2	
love.filesystem.createDirectory	Creates a directory.	Added since 0.9.0	
love.filesystem.enumerate	Returns all the files and subdirectories in the directory.	Added since 0.3.0	Removed in 0.9.0
love.filesystem.exists	Check whether a file or directory exists.		Deprecated in 11.0
love.filesystem.getAppdataDirectory	Returns the application data directory (could be the same as getUserDirectory)		
love.filesystem.getCRequirePath	Gets the filesystem paths that will be searched for c libraries when require is called.	Added since 11.0	
love.filesystem.getDirectoryItems	Returns all the files and subdirectories in the directory.	Added since 0.9.0	
love.filesystem.getIdentity	Gets the write directory name for your game.	Added since 0.9.0	
love.filesystem.getInfo	Gets information about the specified file or directory.	Added since 11.0	
love.filesystem.getLastModified	Gets the last modification time of a file.	Added since 0.7.1	Deprecated in 11.0
love.filesystem.getRealDirectory	Gets the absolute path of the directory containing a filepath.	Added since 0.9.2	
love.filesystem.getRequirePath	Gets the filesystem paths that will be searched when require is called.	Added since 0.10.0	
love.filesystem.getSaveDirectory	Gets the full path to the designated save directory.	Added since 0.5.0	
love.filesystem.getSize	Gets the size in bytes of a file.	Added since 0.9.0	Deprecated in 11.0
love.filesystem.getSource	Returns the full path to the .love file or directory.	Added since 0.9.0	
love.filesystem.getSourceBaseDirectory	Returns the full path to the directory containing the .love file.	Added since 0.9.0	
love.filesystem.getUserDirectory	Returns the path of the user's directory		
love.filesystem.getWorkingDirectory	Gets the current working directory.	Added since 0.5.0	
love.filesystem.init	Initializes love.filesystem, will be called internally, so should not be used explicitly.		
love.filesystem.isDirectory	Check whether something is a directory.		Deprecated in 11.0
love.filesystem.isFile	Check whether something is a file.		Deprecated in 11.0
love.filesystem.isFused	Gets whether the game is in fused mode or not.	Added since 0.9.0	
love.filesystem.isSymlink	Gets whether a filepath is actually a symbolic link.	Added since 0.9.2	Deprecated in 11.0
love.filesystem.lines	Iterate over the lines in a file.	Added since 0.5.0	
love.filesystem.load	Loads a Lua file (but does not run it).	Added since 0.5.0	
love.filesystem.mkdir	Creates a directory.		Removed in 0.9.0
love.filesystem.mount	Mounts a zip file or folder in the game's save directory for reading.	Added since 0.9.0	
love.filesystem.newFile	Creates a new File object.		
love.filesystem.newFileData	Creates a new FileData object from a file on disk, or from a string in memory.	Added since 0.7.0	
love.filesystem.read	Read the contents of a file.		
love.filesystem.remove	Removes a file (or directory).		
love.filesystem.setCRequirePath	Sets the filesystem paths that will be searched for c libraries when require is called.	Added since 11.0	
love.filesystem.setIdentity	Sets the write directory for your game.		
love.filesystem.setRequirePath	Sets the filesystem paths that will be searched when require is called.	Added since 0.10.0	
love.filesystem.setSource	Sets the source of the game, where the code is present. Used internally.		
love.filesystem.setSymlinksEnabled	Sets whether love.filesystem follows symbolic links.	Added since 0.9.2	
love.filesystem.unmount	Unmounts a zip file or folder previously mounted with love.filesystem.mount.	Added since 0.9.0	
love.filesystem.write	Write data to a file.		
Enums
FileDecoder	How to decode a given FileData.	Added since 0.7.0	Removed in 11.0
FileMode	The different modes you can open a File in.		
FileType	The type of a file.	Added since 11.0	


See Also
love


All Versions
Page Discussion View source History
love.font
Available since LÖVE 0.7.0
This module is not supported in earlier versions.
Allows you to work with fonts.

Types
FontData	A FontData represents a font.	Added since 0.7.0	Removed in 0.8.0
GlyphData	A GlyphData represents a drawable symbol of a font.	Added since 0.7.0	
Rasterizer	A Rasterizer represents font data and glyphs.	Added since 0.7.0	
Functions
love.font.newBMFontRasterizer	Creates a new BMFont Rasterizer.	Added since 0.10.0	
love.font.newFontData	Creates a new FontData.	Added since 0.7.0	Removed in 0.8.0
love.font.newGlyphData	Creates a new GlyphData.	Added since 0.7.0	
love.font.newImageRasterizer	Creates a new Image Rasterizer.	Added since 0.10.0	
love.font.newRasterizer	Creates a new Rasterizer.	Added since 0.7.0	
love.font.newTrueTypeRasterizer	Creates a new TrueType Rasterizer.	Added since 0.10.0	
Enums
HintingMode	True Type hinting mode.	Added since 0.10.0	
PixelFormat	Pixel formats for Textures, ImageData, and CompressedImageData.	Added since 11.0	
See Also
Font
love
love.graphics.newFont


All Versions
Page Discussion View source History
love.graphics
The primary responsibility for the love.graphics module is the drawing of lines, shapes, text, Images and other Drawable objects onto the screen. Its secondary responsibilities include loading external files (including Images and Fonts) into memory, creating specialized objects (such as ParticleSystems or Canvases) and managing screen geometry.

LÖVE's coordinate system is rooted in the upper-left corner of the screen, which is at location (0, 0). The x axis is horizontal: larger values are further to the right. The y axis is vertical: larger values are further towards the bottom. It is worth noting that the location (0, 0) aligns with the upper-left corner of the pixel as well, meaning that for some functions you may encounter off-by-one problems in the render output when drawing 1 pixel wide lines. You can try aligning the coordinate system with the center of pixels rather than their upper-left corner. Do this by passing x+0.5 and y+0.5 or using love.graphics.translate().

The LÖVE coordinate system

In many cases, you draw images or shapes in terms of their upper-left corner (See the picture above).


A note about angles in LÖVE: Angles are expressed in terms of radians, with values in the range of 0 to 2pi (approximately 6.28); you may be more used to working in terms of degrees. Because of how the coordinate system is set up, with an origin in the upper left corner, angles in LÖVE may seem a bit backwards: 0 points right (along the X axis), ¼pi points diagonally down and to the right, ½pi points directly down (along the Y axis), with increasing values continuing clockwise.


Many of the functions are used to manipulate the graphics coordinate system, which is essentially the way coordinates are mapped to the display. You can change the position, scale, and even change rotation in this way.



Types
Canvas	Off-screen render target.	Added since 0.8.0	
Drawable	Superclass for all things that can be drawn on screen.		
Font	Defines the shape of characters than can be drawn onto the screen.		
Framebuffer	Off-screen render target.	Added since 0.7.0	Removed in 0.8.0
Image	Drawable image type.		
Mesh	A 2D polygon mesh used for drawing arbitrary textured shapes.	Added since 0.9.0	
ParticleSystem	Used to create cool effects, like fire.		
PixelEffect	Pixel shader effect.	Added since 0.8.0	Removed in 0.9.0
Quad	A quadrilateral with texture coordinate information.		
Shader	Shader effect.	Added since 0.9.0	
SpriteBatch	Store image positions in a buffer, and draw it in one call.		
Text	Drawable text.	Added since 0.10.0	
Texture	Superclass for drawable objects which represent a texture.	Added since 0.9.1	
Video	A drawable video.	Added since 0.10.0	
Functions
Drawing
love.graphics.arc	Draws an arc.	Added since 0.8.0	
love.graphics.circle	Draws a circle.		
love.graphics.clear	Clears the screen or active Canvas to the specified color.		
love.graphics.discard	Discards the contents of the screen or active Canvas.	Added since 0.10.0	
love.graphics.draw	Draws objects on screen.		
love.graphics.drawInstanced	Draws many instances of a Mesh with a single draw call, using hardware geometry instancing.	Added since 11.0	
love.graphics.drawLayer	Draws a layer of an Array Texture.	Added since 11.0	
love.graphics.drawq	Draw a Quad with the specified Image on screen.		Removed in 0.9.0
love.graphics.ellipse	Draws an ellipse.	Added since 0.10.0	
love.graphics.flushBatch	Immediately renders any pending automatically batched draws.	Added since 11.0	
love.graphics.line	Draws lines between points.		
love.graphics.point	Draws a point.	Added since 0.3.0	Removed in 0.10.0
love.graphics.points	Draws one or more points.	Added since 0.10.0	
love.graphics.polygon	Draw a polygon.	Added since 0.4.0	
love.graphics.present	Displays the results of drawing operations on the screen.		
love.graphics.print	Draws text on screen. If no Font is set, one will be created and set (once) if needed.		
love.graphics.printf	Draws formatted text, with word wrap and alignment.		
love.graphics.quad	Draws a quadrilateral shape.		Removed in 0.9.0
love.graphics.rectangle	Draws a rectangle.	Added since 0.3.2	
love.graphics.stencil	Draws geometry as a stencil.	Added since 0.10.0	
love.graphics.triangle	Draws a triangle.		Removed in 0.9.0


Object Creation
love.graphics.captureScreenshot	Creates a screenshot once the current frame is done.	Added since 11.0	
love.graphics.newArrayImage	Creates a new array Image.	Added since 11.0	
love.graphics.newCanvas	Creates a new Canvas.	Added since 0.8.0	
love.graphics.newCubeImage	Creates a new cubemap Image.	Added since 11.0	
love.graphics.newFont	Creates a new Font from a TrueType Font or BMFont file.		
love.graphics.newFramebuffer	Creates a new Framebuffer.	Added since 0.7.0	Removed in 0.8.0
love.graphics.newImage	Creates a new Image.		
love.graphics.newImageFont	Creates a new Font by loading a specifically formatted image.	Added since 0.2.0	
love.graphics.newMesh	Creates a new Mesh.	Added since 0.9.0	
love.graphics.newParticleSystem	Creates a new ParticleSystem.		
love.graphics.newPixelEffect	Creates a new PixelEffect.	Added since 0.8.0	Removed in 0.9.0
love.graphics.newQuad	Creates a new Quad.		
love.graphics.newScreenshot	Creates a screenshot and returns the ImageData.		Removed in 11.0
love.graphics.newShader	Creates a new Shader.	Added since 0.9.0	
love.graphics.newSpriteBatch	Creates a new SpriteBatch.		
love.graphics.newStencil	Creates a new stencil.	Added since 0.8.0	Removed in 0.9.0
love.graphics.newText	Creates a new drawable Text object.	Added since 0.10.0	
love.graphics.newVideo	Creates a new Video.	Added since 0.10.0	
love.graphics.newVolumeImage	Creates a new volume Image.	Added since 11.0	
love.graphics.setNewFont	Creates and sets a new Font.	Added since 0.8.0	
love.graphics.validateShader	Validates shader code.	Added since 11.0	


Graphics State
love.graphics.getBackgroundColor	Gets the current background color.		
love.graphics.getBlendMode	Gets the blending mode.	Added since 0.2.0	
love.graphics.getCanvas	Returns the current target Canvas.	Added since 0.8.0	
love.graphics.getColor	Gets the current color.		
love.graphics.getColorMask	Gets the active color components used when drawing.	Added since 0.9.0	
love.graphics.getColorMode	Gets the color mode (which controls how images are affected by the current color).	Added since 0.2.0	Removed in 0.9.0
love.graphics.getDefaultFilter	Returns the default scaling filters used with Images, Canvases, and Fonts.	Added since 0.9.0	
love.graphics.getDefaultImageFilter	Returns the default scaling filters.	Added since 0.8.0	Removed in 0.9.0
love.graphics.getDepthMode	Gets the current depth test mode and whether writing to the depth buffer is enabled.	Added since 11.0	
love.graphics.getFont	Gets the current Font object.	Added since 0.9.0	
love.graphics.getFrontFaceWinding	Gets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing.	Added since 11.0	
love.graphics.getLineJoin	Gets the line join style.		
love.graphics.getLineStipple	Gets the current line stipple.		Removed in 0.8.0
love.graphics.getLineStyle	Gets the line style.	Added since 0.3.2	
love.graphics.getLineWidth	Gets the current line width.	Added since 0.3.2	
love.graphics.getMeshCullMode	Gets whether back-facing triangles in a Mesh are culled.	Added since 11.0	
love.graphics.getPixelEffect	Returns the current PixelEffect.	Added since 0.8.0	Removed in 0.9.0
love.graphics.getPointSize	Gets the point size.		
love.graphics.getPointStyle	Gets the current point style.		Removed in 0.10.0
love.graphics.getScissor	Gets the current scissor box.	Added since 0.4.0	
love.graphics.getShader	Gets the current Shader.	Added since 0.9.0	
love.graphics.getStackDepth	Gets the current depth of the transform / state stack (the number of pushes without corresponding pops).	Added since 11.0	
love.graphics.getStencilTest	Gets the current stencil test configuration.	Added since 0.10.0	
love.graphics.intersectScissor	Sets the scissor to the rectangle created by the intersection of the specified rectangle with the existing scissor.	Added since 0.10.0	
love.graphics.isActive	Gets whether the graphics module is able to be used.	Added since 0.10.0	
love.graphics.isGammaCorrect	Gets whether gamma-correct rendering is enabled.	Added since 0.10.0	
love.graphics.isSupported	Checks for the support of graphics related functions.	Added since 0.8.0	Removed in 0.10.0
love.graphics.isWireframe	Gets whether wireframe mode is used when drawing.	Added since 0.9.1	
love.graphics.reset	Resets the current graphics settings.		
love.graphics.setBackgroundColor	Sets the background color.		
love.graphics.setBlendMode	Sets the blending mode.	Added since 0.2.0	
love.graphics.setCanvas	Captures drawing operations to a Canvas	Added since 0.8.0	
love.graphics.setColor	Sets the color used for drawing.		
love.graphics.setColorMask	Sets the color mask. Enables or disables specific color components when rendering.	Added since 0.9.0	
love.graphics.setColorMode	Sets the color mode (which controls how images are affected by the current color).	Added since 0.2.0	Removed in 0.9.0
love.graphics.setDefaultFilter	Sets the default scaling filters used with Images, Canvases, and Fonts.	Added since 0.9.0	
love.graphics.setDefaultImageFilter	Sets the default scaling filters.	Added since 0.8.0	Removed in 0.9.0
love.graphics.setDepthMode	Configures depth testing and writing to the depth buffer.	Added since 11.0	
love.graphics.setFont	Set an already-loaded Font as the current font.		
love.graphics.setFrontFaceWinding	Sets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing.	Added since 11.0	
love.graphics.setInvertedStencil	Defines an inverted stencil.	Added since 0.8.0	Removed in 0.10.0
love.graphics.setLine	Sets the line width and style.		Removed in 0.9.0
love.graphics.setLineJoin	Sets the line join style.		
love.graphics.setLineStipple	Sets the line stipple pattern.		Removed in 0.8.0
love.graphics.setLineStyle	Sets the line style.	Added since 0.3.2	
love.graphics.setLineWidth	Sets the line width.	Added since 0.3.2	
love.graphics.setMeshCullMode	Sets whether back-facing triangles in a Mesh are culled.	Added since 11.0	
love.graphics.setPixelEffect	Routes drawing operations through a pixel shader.	Added since 0.8.0	Removed in 0.9.0
love.graphics.setPoint	Sets the point size and style.		Removed in 0.9.0
love.graphics.setPointSize	Sets the point size.		
love.graphics.setPointStyle	Sets the point style.		Removed in 0.10.0
love.graphics.setRenderTarget	Captures drawing operations to a Framebuffer	Added since 0.7.0	Removed in 0.8.0
love.graphics.setScissor	Sets or disables scissor.	Added since 0.4.0	
love.graphics.setShader	Routes drawing operations through a shader.	Added since 0.9.0	
love.graphics.setStencil	Defines or releases a stencil.	Added since 0.8.0	Removed in 0.10.0
love.graphics.setStencilTest	Configures or disables stencil testing.	Added since 0.10.0	
love.graphics.setWireframe	Sets whether wireframe lines will be used when drawing.	Added since 0.9.1	


Coordinate System
love.graphics.applyTransform	Applies the given Transform object to the current coordinate transformation.	Added since 11.0	
love.graphics.inverseTransformPoint	Converts the given 2D position from screen-space into global coordinates.	Added since 11.0	
love.graphics.origin	Resets the current coordinate transformation.	Added since 0.9.0	
love.graphics.pop	Pops the current coordinate transformation from the transformation stack.		
love.graphics.push	Copies and pushes the current coordinate transformation to the transformation stack.		
love.graphics.replaceTransform	Replaces the current coordinate transformation with the given Transform object.	Added since 11.0	
love.graphics.rotate	Rotates the coordinate system in two dimensions.		
love.graphics.scale	Scales the coordinate system in two dimensions.		
love.graphics.shear	Shears the coordinate system.	Added since 0.8.0	
love.graphics.transformPoint	Converts the given 2D position from global coordinates into screen-space.	Added since 11.0	
love.graphics.translate	Translates the coordinate system in two dimensions.		


Window
love.graphics.checkMode	Checks if a display mode is supported.		Removed in 0.9.0
love.graphics.getCaption	Gets the window caption.		Removed in 0.9.0
love.graphics.getDPIScale	Gets the DPI scale factor of the window.	Added since 11.0	
love.graphics.getDimensions	Gets the width and height of the window.	Added since 0.9.0	
love.graphics.getHeight	Gets the height in pixels of the window.	Added since 0.2.1	
love.graphics.getMode	Returns the current display mode.	Added since 0.8.0	Removed in 0.9.0
love.graphics.getModes	Gets a list of supported fullscreen modes.		Removed in 0.9.0
love.graphics.getPixelDimensions	Gets the width and height in pixels of the window.	Added since 11.0	
love.graphics.getPixelHeight	Gets the height in pixels of the window.	Added since 11.0	
love.graphics.getPixelWidth	Gets the width in pixels of the window.	Added since 11.0	
love.graphics.getWidth	Gets the width in pixels of the window.	Added since 0.2.1	
love.graphics.hasFocus	Checks if the game window has keyboard focus.	Added since 0.8.0	Removed in 0.9.0
love.graphics.isCreated	Checks if the window has been created.		Removed in 0.9.0
love.graphics.setCaption	Sets the window caption.		Removed in 0.9.0
love.graphics.setIcon	Set window icon.	Added since 0.7.0	Removed in 0.9.0
love.graphics.setMode	Changes the display mode.		Removed in 0.9.0
love.graphics.toggleFullscreen	Toggles fullscreen.		Removed in 0.9.0


System Information
love.graphics.getCanvasFormats	Gets the available Canvas formats, and whether each is supported.	Added since 0.9.2	
love.graphics.getCompressedImageFormats	Gets the available compressed image formats, and whether each is supported.	Added since 0.9.2	Removed in 11.0
love.graphics.getImageFormats	Gets the pixel formats usable for Images, and whether each is supported.	Added since 11.0	
love.graphics.getMaxImageSize	Gets the max supported width or height of Images and Canvases.	Added since 0.9.0	Removed in 0.10.0
love.graphics.getMaxPointSize	Gets the max supported point size.		Removed in 0.10.0
love.graphics.getRendererInfo	Gets information about the system's video card and drivers.	Added since 0.9.0	
love.graphics.getStats	Gets performance-related rendering statistics.	Added since 0.9.2	
love.graphics.getSupported	Gets the optional graphics features and whether they're supported.	Added since 0.10.0	
love.graphics.getSystemLimit	Gets the system-dependent maximum value for a love.graphics feature.	Added since 0.9.1	Removed in 0.10.0
love.graphics.getSystemLimits	Gets the system-dependent maximum values for love.graphics features.	Added since 0.10.0	
love.graphics.getTextureTypes	Gets the available texture types, and whether each is supported.	Added since 11.0	
Enums
AlignMode	Text alignment.		
ArcType	Different types of arcs that can be drawn.	Added since 0.10.1	
AttributeDataType	Data types used in a Mesh's vertex format.	Added since 0.9.0	
BlendAlphaMode	Different ways alpha affects color blending.	Added since 0.10.0	
BlendMode	Different ways to do color blending.	Added since 0.2.0	
BufferDataUsage	Usage hints for SpriteBatches, Meshes, and GraphicsBuffers to optimize data storage and access.	Added since 0.8.0	
CanvasFormat	Canvas texture formats.	Added since 0.9.0	
ColorMode	Controls how drawn images are affected by current color.	Added since 0.2.0	Removed in 0.9.0
CompareMode	Different types of stencil test and depth test comparisons.	Added since 0.10.0	
CullMode	How Mesh geometry is culled when rendering.	Added since 11.0	
DrawMode	Controls whether shapes are drawn as an outline, or filled.		
FilterMode	How the image is filtered when scaling.		
GraphicsFeature	Graphics features that can be checked for with love.graphics.getSupported.	Added since 0.8.0	
GraphicsLimit	Types of system-dependent graphics limits.	Added since 0.9.1	
IndexDataType	Vertex map datatype.	Added since 11.0	
LineJoin	Line join style.		
LineStyle	The styles in which lines are drawn.		
MeshDrawMode	How a Mesh's vertices are used when drawing.	Added since 0.9.0	
MipmapMode	Controls whether a Canvas has mipmaps, and its behaviour when it does.	Added since 11.0	
PixelFormat	Pixel formats for Textures, ImageData, and CompressedImageData.	Added since 11.0	
PointStyle	How points should be drawn.		Removed in 0.10.0
StackType	Graphics state stack types used with love.graphics.push.	Added since 0.9.2	
StencilAction	How a stencil function modifies the stencil values of pixels it touches.	Added since 0.10.0	
TextureFormat	Controls the canvas texture format.	Added since 0.9.0	Removed in 0.10.0
TextureType	Types of textures (2D, cubemap, etc.)	Added since 11.0	
VertexAttributeStep	The frequency at which a vertex shader fetches the vertex attribute's data from the Mesh when it's drawn.	Added since 11.0	
VertexWinding	Vertex winding.	Added since 11.0	
WrapMode	How the image wraps inside a large Quad.		
See Also
love


All Versions
Page Discussion View source History
love.image
Provides an interface to decode encoded image data.

Types
CompressedImageData	Compressed image data designed to stay compressed in RAM and on the GPU.	Added since 0.9.0	
ImageData	Raw (decoded) image data.		
Functions
love.image.isCompressed	Determines whether a file can be loaded as CompressedImageData.	Added since 0.9.0	
love.image.newCompressedData	Create a new CompressedImageData object from a compressed image file.	Added since 0.9.0	
love.image.newEncodedImageData	Encodes ImageData.		Removed in 0.8.0
love.image.newImageData	Creates a new ImageData object.		
Enums
CompressedImageFormat	Compressed image data formats.	Added since 0.9.0	
ImageEncodeFormat	Image file formats supported by ImageData:encode.		
PixelFormat	Pixel formats for Textures, ImageData, and CompressedImageData.	Added since 11.0	
See Also
love
Image - the love.graphics data type
Image Formats
love.graphics.newImage


All Versions
Page Discussion View source History
love.joystick
Available since LÖVE 0.5.0
This module is not supported in earlier versions.
Provides an interface to connected joysticks.

Types
Joystick	Represents a physical joystick.	Added since 0.9.0	
Functions
love.joystick.close	Closes a joystick.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getAxes	Returns the position of each axis.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getAxis	Returns the direction of the axis.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getBall	Returns the change in ball position.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getGamepadMappingString	Gets the full gamepad mapping string of the Joysticks which have the given GUID, or nil if the GUID isn't recognized as a gamepad.	Added since 11.3	
love.joystick.getHat	Returns the direction of a hat.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getJoystickCount	Gets the number of connected joysticks.	Added since 0.9.0	
love.joystick.getJoysticks	Gets a list of connected Joysticks.	Added since 0.9.0	
love.joystick.getName	Returns the name of a joystick.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getNumAxes	Returns the number of axes on the joystick.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getNumBalls	Returns the number of balls on the joystick.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getNumButtons	Returns the number of buttons on the joystick.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getNumHats	Returns the number of hats on the joystick.	Added since 0.5.0	Removed in 0.9.0
love.joystick.getNumJoysticks	Returns how many joysticks are available.	Added since 0.5.0	Removed in 0.9.0
love.joystick.isDown	Checks if a button on a joystick is pressed.	Added since 0.5.0	Removed in 0.9.0
love.joystick.isOpen	Checks if the joystick is open.	Added since 0.5.0	Removed in 0.9.0
love.joystick.loadGamepadMappings	Loads a gamepad mappings string or file created with love.joystick.saveGamepadMappings.	Added since 0.9.2	
love.joystick.open	Opens up a joystick to be used.	Added since 0.5.0	Removed in 0.9.0
love.joystick.saveGamepadMappings	Saves the virtual gamepad mappings of all recently-used Joysticks that are recognized as gamepads.	Added since 0.9.2	
love.joystick.setGamepadMapping	Binds a virtual gamepad input to a button, axis or hat.	Added since 0.9.2	
Enums
GamepadAxis	Virtual gamepad axes.	Added since 0.9.0	
GamepadButton	Virtual gamepad buttons.	Added since 0.9.0	
JoystickHat	Joystick hat positions.	Added since 0.5.0	
JoystickInputType	Types of Joystick inputs.	Added since 0.9.0	
See Also
love
love.gamepadpressed
love.gamepadreleased
love.joystickpressed
love.joystickreleased
love.joystickadded
love.joystickremoved


All Versions
Page Discussion View source History
love.keyboard
Provides an interface to the user's keyboard.

Functions
love.keyboard.getKeyFromScancode	Gets the key corresponding to the given hardware scancode.	Added since 0.9.2	
love.keyboard.getKeyRepeat	Returns the delay and interval of key repeating.		Removed in 0.9.0
love.keyboard.getScancodeFromKey	Gets the hardware scancode corresponding to the given key.	Added since 0.9.2	
love.keyboard.hasKeyRepeat	Gets whether key repeat is enabled.	Added since 0.9.0	
love.keyboard.hasScreenKeyboard	Gets whether screen keyboard is supported.	Added since 0.10.0	
love.keyboard.hasTextInput	Gets whether text input events are enabled.	Added since 0.9.0	
love.keyboard.isDown	Checks whether a certain key is down.		
love.keyboard.isScancodeDown	Checks whether the specified Scancodes are pressed.	Added since 0.10.0	
love.keyboard.setKeyRepeat	Enables or disables key repeat for love.keypressed.		
love.keyboard.setTextInput	Enables or disables text input events.	Added since 0.9.0	
Enums
KeyConstant	All the keys you can press.		
Scancode	Keyboard scancodes.	Added since 0.9.2	
See Also
love
love.keypressed
love.keyreleased


All Versions
Page Discussion View source History
love.math
Available since LÖVE 0.9.0
This module is not supported in earlier versions.
Provides system-independent mathematical functions.

Types
BezierCurve	A Bézier curve object that can evaluate and render Bézier curves of arbitrary degree.	Added since 0.9.0	
RandomGenerator	A random number generation object which has its own random state.	Added since 0.9.0	
Transform	Object containing a coordinate system transformation.	Added since 11.0	
Functions
love.math.colorFromBytes	Converts a color from 0..255 to 0..1 range.	Added since 11.3	
love.math.colorToBytes	Converts a color from 0..1 to 0..255 range.	Added since 11.3	
love.math.compress	Compresses a string or data using a specific compression algorithm.	Added since 0.10.0	Deprecated in 11.0
love.math.decompress	Decompresses a CompressedData or previously compressed string or Data object.	Added since 0.10.0	Deprecated in 11.0
love.math.gammaToLinear	Converts a color from gamma-space (sRGB) to linear-space (RGB).	Added since 0.9.1	
love.math.getRandomSeed	Gets the seed of the random number generator.	Added since 0.9.0	
love.math.getRandomState	Gets the current state of the random number generator.	Added since 0.9.1	
love.math.isConvex	Checks whether a polygon is convex.	Added since 0.9.0	
love.math.linearToGamma	Converts a color from linear-space (RGB) to gamma-space (sRGB).	Added since 0.9.1	
love.math.newBezierCurve	Creates a new BezierCurve object.	Added since 0.9.0	
love.math.newRandomGenerator	Creates a new RandomGenerator object.	Added since 0.9.0	
love.math.newTransform	Creates a new Transform object.	Added since 11.0	
love.math.noise	Generates a Simplex noise value in 1-4 dimensions.	Added since 0.9.0	
love.math.random	Get uniformly distributed pseudo-random number	Added since 0.9.0	
love.math.randomNormal	Get a normally distributed pseudo random number.	Added since 0.9.0	
love.math.setRandomSeed	Sets the seed of the random number generator.	Added since 0.9.0	
love.math.setRandomState	Sets the current state of the random number generator.	Added since 0.9.1	
love.math.triangulate	Decomposes a simple polygon into triangles.	Added since 0.9.0	
Enums
See Also
love


All Versions
Page Discussion View source History
love.mouse
Provides an interface to the user's mouse.

Types
Cursor	Represents a hardware cursor.	Added since 0.9.0	
Functions
love.mouse.getCursor	Gets the current Cursor.	Added since 0.9.0	
love.mouse.getPosition	Returns the current position of the mouse.	Added since 0.3.2	
love.mouse.getRelativeMode	Gets whether relative mode is enabled for the mouse.	Added since 0.9.2	
love.mouse.getSystemCursor	Gets a Cursor object representing a system-native hardware cursor.	Added since 0.9.0	
love.mouse.getX	Returns the current x-position of the mouse.		
love.mouse.getY	Returns the current y-position of the mouse.		
love.mouse.hasCursor	Gets whether cursor functionality is supported.	Added since 0.10.0	Removed in 11.0
love.mouse.isCursorSupported	Gets whether cursor functionality is supported.	Added since 11.0	
love.mouse.isDown	Checks whether a certain button is down.		
love.mouse.isGrabbed	Checks if the mouse is grabbed.		
love.mouse.isVisible	Checks if the cursor is visible.		
love.mouse.newCursor	Creates a new hardware Cursor object from an image.	Added since 0.9.0	
love.mouse.setCursor	Sets the current mouse cursor.	Added since 0.9.0	
love.mouse.setGrab	Grabs the mouse and confines it to the window.		Removed in 0.9.0
love.mouse.setGrabbed	Grabs the mouse and confines it to the window.	Added since 0.9.0	
love.mouse.setPosition	Sets the current position of the mouse.		
love.mouse.setRelativeMode	Sets whether relative mode is enabled for the mouse.	Added since 0.9.2	
love.mouse.setVisible	Sets the current visibility of the cursor.		
love.mouse.setX	Sets the current X position of the mouse.	Added since 0.9.0	
love.mouse.setY	Sets the current Y position of the mouse.	Added since 0.9.0	
Enums
CursorType	Types of hardware cursors.	Added since 0.9.0	
MouseConstant	Mouse buttons.		Removed in 0.10.0
See Also
love
love.mousepressed
love.mousereleased
love.mousemoved
love.wheelmoved


All Versions
Page Discussion View source History
love.physics
Available since LÖVE 0.4.0
This module is not supported in earlier versions.
Can simulate 2D rigid bodies in a realistic manner. This module is essentially just a binding to Box2D (version 2.3.0 - manual).

For simpler (and more common) use cases, a small number of libraries exist, which are usually more popularly used than love.physics and can be found here: https://github.com/love2d-community/awesome-love2d#physics

Types
Body	Bodies are objects with velocity and position.		
Contact	Contacts are objects created to manage collisions in worlds.		
Fixture	Fixtures attach shapes to bodies.	Added since 0.8.0	
Joint	Attach multiple bodies together to interact in unique ways.		
Shape	Shapes are objects used to control mass and collisions.		
World	A world is an object that contains all bodies and joints.		
Functions
love.physics.getDistance	Returns the two closest points between two fixtures and their distance.	Added since 0.8.0	
love.physics.getMeter	Returns the meter scale factor.	Added since 0.8.0	
love.physics.newBody	Creates a new body.		
love.physics.newChainShape	Creates a new ChainShape.	Added since 0.8.0	
love.physics.newCircleShape	Creates a new CircleShape.		
love.physics.newDistanceJoint	Creates a DistanceJoint between two bodies.		
love.physics.newEdgeShape	Creates a new EdgeShape.	Added since 0.8.0	
love.physics.newFixture	Creates and attaches a fixture.	Added since 0.8.0	
love.physics.newFrictionJoint	A FrictionJoint applies friction to a body.	Added since 0.8.0	
love.physics.newGearJoint	Create a GearJoint connecting two Joints.		
love.physics.newMotorJoint	Creates a joint between two bodies which controls the relative motion between them.	Added since 0.9.0	
love.physics.newMouseJoint	Create a joint between a body and the mouse.		
love.physics.newPolygonShape	Creates a new PolygonShape.		
love.physics.newPrismaticJoint	Creates a PrismaticJoint between two bodies.		
love.physics.newPulleyJoint	Creates a PulleyJoint to join two bodies to each other and the ground.		
love.physics.newRectangleShape	Shorthand for creating rectangular PolygonShapes.		
love.physics.newRevoluteJoint	Creates a pivot joint between two bodies.		
love.physics.newRopeJoint	Creates a joint between two bodies that enforces a max distance between them.	Added since 0.8.0	
love.physics.newWeldJoint	A WeldJoint essentially glues two bodies together.	Added since 0.8.0	
love.physics.newWheelJoint	Creates a wheel joint.	Added since 0.8.0	
love.physics.newWorld	Creates a new World.		
love.physics.setMeter	Sets the meter scale factor.	Added since 0.8.0	
Enums
BodyType	The types of a Body.		
JointType	Different types of joints.		
ShapeType	The different types of Shapes, as returned by Shape:getType.		
Notes
Box2D's architecture, concepts, and terminologies.
Box2D basic overview.png

See Also
love
Tutorial:Physics
Tutorial:PhysicsCollisionCallbacks
Box2D Gotchas (recommended reading)


All Versions
Page Discussion View source History
love.sound
This module is responsible for decoding sound files. It can't play the sounds, see love.audio for that.

Types
Decoder	An object which can gradually decode a sound file.		
SoundData	Contains raw audio samples.		
Functions
love.sound.newDecoder	Attempts to find a decoder for the encoded sound data in the specified file.		
love.sound.newSoundData	Creates a new SoundData.		


See Also
love
Audio Formats


All Versions
Page Discussion View source History
love.system
Available since LÖVE 0.9.0
This module is not supported in earlier versions.
Provides access to information about the user's system.

Functions
love.system.getClipboardText	Gets text from the clipboard.	Added since 0.9.0	
love.system.getOS	Gets the current operating system.	Added since 0.9.0	
love.system.getPowerInfo	Gets information about the system's power supply.	Added since 0.9.0	
love.system.getProcessorCount	Gets the amount of logical processors in the system.	Added since 0.9.0	
love.system.hasBackgroundMusic	Gets whether another application on the system is playing music in the background.	Added since 11.0	
love.system.openURL	Opens a URL with the user's web or file browser.	Added since 0.9.1	
love.system.setClipboardText	Puts text in the clipboard.	Added since 0.9.0	
love.system.vibrate	Causes the device to vibrate, if possible.	Added since 0.10.0	
Enums
PowerState	The basic state of the system's power supply.	Added since 0.9.0	
See Also
love


All Versions
Page Discussion View source History
love.thread
Available since LÖVE 0.7.0
This module is not supported in earlier versions.
Allows you to work with threads.

Threads are separate Lua environments, running in parallel to the main code. As their code runs separately, they can be used to compute complex operations without adversely affecting the frame rate of the main thread. However, as they are separate environments, they cannot access the variables and functions of the main thread, and communication between threads is limited.

All LÖVE objects (userdata) are shared among threads so you'll only have to send their references across threads. You may run into concurrency issues if you manipulate an object or global love state on multiple threads at the same time.


When a Thread is started, it only loads love.data, love.filesystem, and love.thread module. Every other module has to be loaded with require.


LÖVE provides a default implementation of the love.threaderror callback in order to see errors from threads. It can be overwritten and customized, and Thread:getError can also be used.



O.png	The love.graphics, love.window, love.joystick, love.keyboard, love.mouse, and love.touch modules have several restrictions and therefore can only be used in the main thread.	 


O.png	If LÖVE is programmatically restarted, all active threads must stop their work and the main thread must wait for them to finish, otherwise LOVE may fail to start again.	 


Types
Channel	An object which can be used to send and receive data between different threads.	Added since 0.9.0	
Thread	A Thread represents a thread.	Added since 0.7.0	
Functions
love.thread.getChannel	Creates or retrieves a named thread channel.	Added since 0.9.0	
love.thread.getThread	Look for a thread and get its object.	Added since 0.7.0	Removed in 0.9.0
love.thread.getThreads	Get all threads.	Added since 0.7.0	Removed in 0.9.0
love.thread.newChannel	Creates a new unnamed thread channel.	Added since 0.9.0	
love.thread.newThread	Creates a new Thread from a filename, string or FileData object containing Lua code.	Added since 0.7.0	


Examples
A simple example showing the general usage of a thread and using channels for communication.

-- This is the code that's going to run on the our thread. It should be moved
-- to its own dedicated Lua file, but for simplicity's sake we'll create it
-- here.
local threadCode = [[
-- Receive values sent via thread:start
local min, max = ...

for i = min, max do
    -- The Channel is used to handle communication between our main thread and
    -- this thread. On each iteration of the loop will push a message to it which
    -- we can then pop / receive in the main thread.
    love.thread.getChannel( 'info' ):push( i )
end
]]

local thread -- Our thread object.
local timer = 0  -- A timer used to animate our circle.

function love.load()
    thread = love.thread.newThread( threadCode )
    thread:start( 99, 1000 )
end

function love.update( dt )
    timer = timer + dt
end

function love.draw()
    -- Get the info channel and pop the next message from it.
    local info = love.thread.getChannel( 'info' ):pop()
    if info then
        love.graphics.print( info, 10, 10 )
    end

    -- We smoothly animate a circle to show that the thread isn't blocking our main thread.
    love.graphics.circle( 'line', 100 + math.sin( timer ) * 20, 100 + math.cos( timer ) * 20, 20 )
end
See Also
love
love.threaderror


All Versions
Page Discussion View source History
love.timer
Provides high-resolution timing functionality.

Functions
love.timer.getAverageDelta	Returns the average delta time over the last second.	Added since 0.9.0	
love.timer.getDelta	Returns the time between the last two frames.		
love.timer.getFPS	Returns the current frames per second.	Added since 0.2.1	
love.timer.getMicroTime	Returns the value of a timer with microsecond precision.		Removed in 0.9.0
love.timer.getTime	Returns the precise amount of time since some time in the past.	Added since 0.3.2	
love.timer.sleep	Pauses the current thread for the specified amount of time.	Added since 0.2.1	
love.timer.step	Measures the time between two frames.


All Versions
Page Discussion View source History
love.touch
Available since LÖVE 0.10.0
This module is not supported in earlier versions.
Provides an interface to touch-screen presses.

Functions
love.touch.getPosition	Gets the current position of the specified touch-press.	Added since 0.10.0	
love.touch.getPressure	Gets the current pressure of the specified touch-press.	Added since 0.10.0	
love.touch.getTouches	Gets a list of all active touch-presses.	Added since 0.10.0	
See Also
love
love.touchpressed
love.touchreleased
love.touchmoved


All Versions
Page Discussion View source History
love.video
Available since LÖVE 0.10.0
This module is not supported in earlier versions.
This module is responsible for decoding, controlling, and streaming video files.

It can't draw the videos, see love.graphics.newVideo and Video objects for that.

Types
VideoStream	An object which decodes, streams, and controls Videos.	Added since 0.10.0	
Functions
love.video.newVideoStream	Creates a new VideoStream.	Added since 0.10.0	
See Also
love
love.graphics.newVideo
Video


All Versions
Page Discussion View source History
love.window
Available since LÖVE 0.9.0
This module is not supported in earlier versions.

Provides an interface for modifying and retrieving information about the program's window.

Functions
love.window.close	Closes the window.	Added since 0.10.0	
love.window.fromPixels	Converts a number from pixels to density-independent units.	Added since 0.9.2	
love.window.getDPIScale	Gets the DPI scale factor associated with the window.	Added since 11.0	
love.window.getDesktopDimensions	Gets the width and height of the desktop.	Added since 0.9.0	
love.window.getDimensions	Gets the width and height of the window.	Added since 0.9.0	Removed in 0.10.0
love.window.getDisplayCount	Gets the number of connected monitors.	Added since 0.9.0	
love.window.getDisplayName	Gets the name of a display.	Added since 0.9.2	
love.window.getDisplayOrientation	Gets current device display orientation.	Added since 11.3	
love.window.getFullscreen	Gets whether the window is fullscreen.	Added since 0.9.0	
love.window.getFullscreenModes	Gets a list of supported fullscreen modes.	Added since 0.9.0	
love.window.getHeight	Gets the height of the window.	Added since 0.9.0	Removed in 0.10.0
love.window.getIcon	Gets the window icon.	Added since 0.9.0	
love.window.getMode	Gets the display mode and properties of the window.	Added since 0.9.0	
love.window.getPixelScale	Gets the DPI scale factor associated with the window.	Added since 0.9.1	Removed in 11.0
love.window.getPosition	Gets the position of the window on the screen.	Added since 0.9.2	
love.window.getSafeArea	Gets unobstructed area inside the window.	Added since 11.3	
love.window.getTitle	Gets the window title.	Added since 0.9.0	
love.window.getVSync	Gets current vsync value.	Added since 11.3	
love.window.getWidth	Gets the width of the window.	Added since 0.9.0	Removed in 0.10.0
love.window.hasFocus	Checks if the game window has keyboard focus.	Added since 0.9.0	
love.window.hasMouseFocus	Checks if the game window has mouse focus.	Added since 0.9.0	
love.window.isCreated	Checks if the window has been created.	Added since 0.9.0	Removed in 0.10.0
love.window.isDisplaySleepEnabled	Gets whether the display is allowed to sleep while the program is running.	Added since 0.10.0	
love.window.isMaximized	Gets whether the Window is currently maximized.	Added since 0.10.2	
love.window.isMinimized	Gets whether the Window is currently minimized.	Added since 11.0	
love.window.isOpen	Checks if the window is open.	Added since 0.10.0	
love.window.isVisible	Checks if the game window is visible.	Added since 0.9.0	
love.window.maximize	Makes the window as large as possible.	Added since 0.10.0	
love.window.minimize	Minimizes the window to the system's task bar / dock.	Added since 0.9.2	
love.window.requestAttention	Causes the window to request the attention of the user if it is not in the foreground.	Added since 0.10.0	
love.window.restore	Restores the size and position of the window if it was minimized or maximized.	Added since 11.0	
love.window.setDisplaySleepEnabled	Sets whether the display is allowed to sleep while the program is running.	Added since 0.10.0	
love.window.setFullscreen	Enters or exits fullscreen.	Added since 0.9.0	
love.window.setIcon	Sets the window icon.	Added since 0.9.0	
love.window.setMode	Sets the display mode and properties of the window.	Added since 0.9.0	
love.window.setPosition	Sets the position of the window on the screen.	Added since 0.9.2	
love.window.setTitle	Sets the window title.	Added since 0.9.0	
love.window.setVSync	Sets vertical synchronization mode.	Added since 11.3	
love.window.showMessageBox	Displays a message box above the love window.	Added since 0.9.2	
love.window.toPixels	Converts a number from density-independent units to pixels.	Added since 0.9.2	
love.window.updateMode	Sets the display mode and properties of the window, without modifying unspecified properties.	Added since 11.0	
Enums
DisplayOrientation	Types of device display orientation.	Added since 11.3	
FullscreenType	Types of fullscreen modes.	Added since 0.9.0	
MessageBoxType	Types of message box dialogs.	Added since 0.9.2	
See Also
love
love.resize
love.focus
love.mousefocus
love.visible


All Versions
Page Discussion View source History
lua-enet
Available since LÖVE 0.9.0
This module is not supported in earlier versions.


O.png	Official documentation for lua-enet is available here. ENet's features are listed on its homepage. The official documentation may have typos. The documentation on this wiki reflects Löve's implementation, meaning it should be safe to follow what's written here.	 


lua-enet is a binding to the ENet library for Lua. It comes included with LÖVE.

ENet's purpose is to provide a relatively thin, simple and robust network communication layer for games on top of UDP (User Datagram Protocol).The primary feature it provides is optional reliable, in-order delivery of packets.

ENet omits certain higher level networking features such as authentication, lobbying, server discovery, encryption, or other similar tasks that are particularly application specific so that the library remains flexible, portable, and easily embeddable.

Types
Type	Description
host	An ENet host for communicating with peers.
peer	An ENet peer which data packets may be sent or received from.
event	A simple table containing information on an event.
Functions
Function	Description
host_create	Returns a new host.
linked_version	Returns the included ENet's version string.
Examples
server.lua

-- server.lua
local enet = require "enet"
local host = enet.host_create("localhost:6789")
while true do
  local event = host:service(100)
  while event do
    if event.type == "receive" then
      print("Got message: ", event.data, event.peer)
      event.peer:send( "pong" )
    elseif event.type == "connect" then
      print(event.peer, "connected.")
    elseif event.type == "disconnect" then
      print(event.peer, "disconnected.")
    end
    event = host:service()
  end
end
client.lua

-- client.lua
local enet = require "enet"
local host = enet.host_create()
local server = host:connect("localhost:6789")
while true do
  local event = host:service(100)
  while event do
    if event.type == "receive" then
      print("Got message: ", event.data, event.peer)
      event.peer:send( "ping" )
    elseif event.type == "connect" then
      print(event.peer, "connected.")
      event.peer:send( "ping" )
    elseif event.type == "disconnect" then
      print(event.peer, "disconnected.")
    end
    event = host:service()
  end
end
This is another example that creates a server (receiver) and a client (sender) on the same computer with the same script. The client will say "Hi" to the server endlessly because ClientSend() is called inside love.update.

enet = require "enet"

enethost = nil
hostevent = nil
clientpeer = nil

function love.load(args)

	-- establish host for receiving msg
	enethost = enet.host_create("localhost:6750")
	
	-- establish a connection to host on same PC
	enetclient = enet.host_create()
        clientpeer = enetclient:connect("localhost:6750")

end

function love.update(dt)
	ServerListen()	
	ClientSend()
end

function love.draw()
end

function ServerListen()

	hostevent = enethost:service(100)
	
	if hostevent then
		print("Server detected message type: " .. hostevent.type)
		if hostevent.type == "connect" then 
			print(hostevent.peer, "connected.")
		end
		if hostevent.type == "receive" then
			print("Received message: ", hostevent.data, hostevent.peer)
		end
	end
end

function ClientSend()
	enetclient:service(100)
	clientpeer:send("Hi")
end

All Versions
Page Discussion View source History
socket
Available since LÖVE 0.5.0
This module is not supported in earlier versions.
Implements a luasocket module for TCP/UDP networking. The luasocket module is bundled with love binary, but in order to use it, you need to require the module like this:

local socket = require("socket")
Notes
Prior to 11.0, LÖVE doesn't fully supports non-blocking TCP connections on Windows
Starting with LÖVE 11.0, require("socket") no longer creates a global variable.
When using blocking operations (network connect/read/write, or socket.sleep), the whole LÖVE main loop will be blocked, and it is usually a bad idea. So use only non-blocking operations if possible, or use it in a thread.
Reference Manual
For detailed usage, see the reference manual (backup link).

See Also
love
Tutorial:Networking with UDP
lua-enet
grease

All Versions
Page Discussion View source History
utf8
Available since LÖVE 0.9.2
This module is not supported in earlier versions.

This library provides basic support for handling UTF-8 encoded strings.

It provides all its functions inside the table returned by require("utf8"). This library does not provide any support for Unicode other than handling UTF-8 encoding. Any operation that needs the meaning of a character, such as character classification, is outside its scope.

For detailed usage, see the reference manual.

O.png	The utf8.char function does not work correctly in 0.9.2; However, it is not an issue since 0.10.0	 




Examples
Print text the user writes, and erase it using the UTF-8 module.

local utf8 = require("utf8")

function love.load()
    text = "Type away! -- "

    -- enable key repeat so backspace can be held down to trigger love.keypressed multiple times.
    love.keyboard.setKeyRepeat(true)
end

function love.textinput(t)
    text = text .. t
end

function love.keypressed(key)
    if key == "backspace" then
        -- get the byte offset to the last UTF-8 character in the string.
        local byteoffset = utf8.offset(text, -1)

        if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            text = string.sub(text, 1, byteoffset - 1)
        end
    end
end

function love.draw()
    love.graphics.printf(text, 0, 0, love.graphics.getWidth())
end
See Also
love
love.textinput