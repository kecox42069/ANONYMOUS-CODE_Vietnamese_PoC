if (!("LayerMovie" in ::getroottable()))
{
	::LayerMovie <- null;
}

if (!("DrawMovie" in ::getroottable()))
{
	::DrawMovie <- null;
}

if (!("ShortMovie" in ::getroottable()))
{
	::ShortMovie <- null;
}

this.printf("LayerMovie:%s DrawMovie:%s\n", ::LayerMovie, this.DrawMovie);
this.printf("ShortMovie:%s\n", ::ShortMovie);
class this.NoisePicture extends ::LayerRawTex
{
	constructor( owner, noise )
	{
		::LayerRawTex.constructor(owner, noise.width, noise.height);
		this.generateNoise();
		this._thread = ::fork(function ( info )
		{
			while (info.owner != null)
			{
				info.owner.generateNoise();

				for( local _itvl = info.interval; _itvl > 0; _itvl -= this.System.getPassedFrame() )
				{
					::suspend();
				}
			}
		}, {
			owner = this.weakref(),
			interval = noise.noise
		});
	}

	function destructor()
	{
		if (this._thread)
		{
			this._thread.exit();
			this._thread = null;
		}

		::LayerRawTex.destructor();
	}

	_thread = null;
}

class this.TilePicture extends ::LayerPicture
{
	constructor( owner, tile )
	{
		::LayerPicture.constructor(owner, tile.data);
		this._tw = tile.data.width;
		this._th = tile.data.height;
		this._width = tile.width;
		this._height = tile.height;
		this._tilex = 0;
		this._tiley = 0;
		this._updateImage();
	}

	function getVariable( name )
	{
		switch(name)
		{
		case "tilex":
			return this._tilex;

		case "tiley":
			return this._tiley;
		}
	}

	function setVariable( name, value )
	{
		switch(name)
		{
		case "tilex":
			this._tilex = ::tonumber(value);
			this._updateImage();
			break;

		case "tiley":
			this._tiley = ::tonumber(value);
			this._updateImage();
			break;
		}
	}

	_tw = 0;
	_th = 0;
	_width = 0;
	_height = 0;
	_tilex = 0;
	_tiley = 0;
	function _updateImage()
	{
		this.clearImageRange();
		local x = this._tilex;
		local y = this._tiley;

		if (this._tw > 0 && this._th > 0)
		{
			x = x % this._tw;
			y = y % this._th;

			if (x > 0)
			{
				x -= this._tw;
			}

			if (y > 0)
			{
				y -= this._th;
			}

			while (y < this._height)
			{
				local x2 = x;

				while (x2 < this._width)
				{
					local dx = x2;
					local dy = y;
					local sx = 0;
					local sy = 0;
					local sw = this._tw;
					local sh = this._th;

					if (dx < 0)
					{
						sx -= dx;
						sw += dx;
						dx = 0;
					}

					if (dy < 0)
					{
						sy -= dy;
						sh += dy;
						dy = 0;
					}

					if (dx + sw > this._width)
					{
						sw = this._width - dx;
					}

					if (dy + sh > this._height)
					{
						sh = this._height - dy;
					}

					this.assignImageRange(sx, sy, sx + sw, sy + sh, dx, dy);
					x2 += this._tw;
				}

				y += this._th;
			}
		}
	}

}

class this.RollPicture extends ::Object
{
	constructor( owner, roll )
	{
		::Object.constructor();
		this._owner = owner.weakref();
		local images;
		local labels;

		if ("images" in roll)
		{
			images = roll.images;
			labels = roll.labels;
		}
		else
		{
			images = [];
			labels = {};
			local inames = {};

			foreach( i, info in roll.data.root.imageList )
			{
				if (info != null)
				{
					inames[info.label] <- i;
				}
			}

			foreach( info in roll.data.root.rollinfo )
			{
				if (info != null)
				{
					if (typeof info[0] == "string")
					{
						labels[info[0]] <- info[1];
					}
					else
					{
						local imageName = info[2];

						if (imageName in inames)
						{
							local image = ::Image(roll.data, imageName);
							images.append({
								x = info[0],
								y = info[1],
								image = image
							});
						}
						else
						{
							this.printf("failed to load rollimage:%s\n", imageName);
						}
					}
				}
			}

			roll.images <- images;
			roll.labels <- labels;
		}

		this._pictures = [];
		this._maxy = 0;

		foreach( info in images )
		{
			local image = info.image;
			local picture = ::LayerPicture(this._owner, image);
			local x = ::toint(info.x);
			local y = ::toint(info.y);
			picture.setCoord(x, y);
			this._pictures.append(picture);
			this._maxy = ::max(info.y, this._maxy);
		}

		if ("*__rollMax__" in labels)
		{
			this._maxy = labels["*__rollMax__"];
		}

		this._startPos = "rollbegin" in roll ? ::getval(labels, roll.rollbegin, 0) : 0;
		this._endPos = "rollend" in roll ? ::getval(labels, roll.rollend, this._maxy) : this._maxy;
	}

	function setOpacity( opacity )
	{
		foreach( picture in this._pictures )
		{
			picture.setOpacity(opacity);
		}
	}

	function setVisible( v )
	{
		this._visible = v;

		foreach( picture in this._pictures )
		{
			picture.setVisible(v);
		}
	}

	function setOffset( x, y )
	{
		if (x != this._offsetx || y != this._offsety)
		{
			this._offsetx = x;
			this._offsety = y;
			this._updateOffset();
		}
	}

	function setRollvalue( value )
	{
		if (this._rollvalue != value)
		{
			this._rollvalue = value;
			this._updateOffset();
		}
	}

	function getRollvalue()
	{
		return this._rollvalue;
	}

	function setVariable( name, value )
	{
		switch(name)
		{
		case "roll":
			this.setRollvalue(this._startPos + (this._endPos - this._startPos) * value);
			break;

		case "rollvalue":
			this.setRollvalue(value);
			break;
		}
	}

	function getVariable( name )
	{
		switch(name)
		{
		case "roll":
			return (this.getRollvalue() - this._startPos) / (this._endPos - this._startPos);

		case "rollvalue":
			return this.getRollvalue();
		}
	}

	_owner = null;
	_pictures = null;
	_maxy = 0;
	_startPos = 0;
	_endPos = 0;
	_rollvalue = 0;
	_offsetx = 0;
	_offsety = 0;
	_visible = 0;
	function _updateOffset()
	{
		foreach( i, picture in this._pictures )
		{
			picture.setOffset(this._offsetx, this._offsety + this._rollvalue);
			local y = picture.getTop() - (this._offsety + this._rollvalue);
			picture.visible = this._visible && y > -720 && y < 720;
		}
	}

}

class this.MotionData extends ::Object
{
	data = null;
	emote = false;
	function createMotion( data, rename = null )
	{
		local id = this._owner.registerMotionResource(data);

		if (rename != null)
		{
			local list = this._owner.getMotionCharaNameList(id);

			foreach( n in list )
			{
				foreach( r, v in rename )
				{
					if (n.find(r) == 0)
					{
						if (v == null || v == "")
						{
							this._owner.removeMotionChara(id, n);
						}
						else
						{
							this._owner.renameMotionChara(id, n, v);
						}
					}
				}
			}
		}

		return id;
	}

	constructor( owner, data = null, rename = null )
	{
		::Object.constructor();
		this._owner = owner.weakref();
		this.data = data;

		if (data != null)
		{
			local base;

			if (typeof data == "array")
			{
				base = data[0];
				this._id = [];

				foreach( i, v in data )
				{
					this._id.append(this.createMotion(v, rename));
				}
			}
			else
			{
				base = data;
				this._id = this.createMotion(data, rename);
			}

			this.emote = ("metadata" in base.root) && ("format" in base.root.metadata) && base.root.metadata.format == "emote";
		}
	}

	function getBase()
	{
		if (typeof this.data == "array")
		{
			return this.data[0];
		}
		else
		{
			return this.data;
		}
	}

	function destructor()
	{
		if (this._owner != null && this._id != null)
		{
			if (typeof this._id == "array")
			{
				foreach( i, v in this._id )
				{
					this._owner.unregisterMotionResource(v);
				}
			}
			else
			{
				this._owner.unregisterMotionResource(this._id);
			}
		}
		else
		{
			this.printf("WANING:dont unregister motiondata!! (owner removed)\n");
		}

		::Object.destructor();
	}

	function cloneObj( newowner = null )
	{
		if (newowner != null && this._owner != newowner)
		{
			return ::MotionData(newowner, this.data);
		}

		return this;
	}

	_id = null;
	_owner = null;
}

class this.MotionPicture extends ::Motion
{
	_owner = null;
	constructor( owner, another = null )
	{
		::Motion.constructor(owner, another);
		this._owner = owner.weakref();
		this.eventEnabled = true;
	}

	function onAction( label, action )
	{
		if (this._owner != null && "onMotionAction" in this._owner)
		{
			this._owner.onMotionAction(label, action);
		}
	}

	function _callMotionChange()
	{
		if (this._owner != null && "onMotionChange" in this._owner)
		{
			this._owner.onMotionChange();
		}
	}

	function playMotion( motion, flag = 0 )
	{
		this.play(motion, flag);
		this._callMotionChange();
	}

	function setOptions( _options )
	{
		if ("chara" in _options)
		{
			this.setChara(_options.chara);
		}

		if ("motion" in _options)
		{
			this.play(_options.motion, ::getval(_options, "flag", 1));
			this._callMotionChange();
		}

		if ("tickCount" in _options)
		{
			this.tickCount = _options.tickCount;
		}

		if ("variables" in _options)
		{
			local vars = _options.variables;

			if (typeof vars == "string")
			{
				vars = this.eval(vars);
			}

			foreach( name, value in vars )
			{
				this.setVariable(name, value);
			}
		}
	}

	function canDispSync()
	{
		return this.getLoopTime() < 0 && this.getPlaying();
	}

	function dispSync()
	{
		if (this.getPlaying())
		{
			this.skipToSync();
		}
	}

}

class this.EmotePicture extends ::Emote
{
	_owner = null;
	_main = null;
	_diff = null;
	_motion = null;
	constructor( owner, origpicture, data )
	{
		this._owner = owner.weakref();

		if (origpicture instanceof ::EmotePicture)
		{
			this._motion = data;
			::Emote.constructor(owner, this._motion.data.getBase());
			this.assignState(origpicture);
			this._main = origpicture._main;
			this._diff = origpicture._diff;
		}
		else
		{
			this._motion = data;
			::Emote.constructor(owner, this._motion.data.getBase());
			this._motion.ignoreAutoStopTimelineList <- this._owner.calcParam("ignoreAutoStopTimelineList");
			this._main = {};
			this._diff = {};

			foreach( name in this.getMainTimelineLabelList() )
			{
				this._main[name] <- true;
			}

			foreach( name in this.getDiffTimelineLabelList() )
			{
				this._diff[name] <- true;
			}
		}

		if (this._motion.color != null)
		{
			this.setColor(this.ARGB2RGBA(4278190080 | this._motion.color));
		}
		else
		{
			this.setColor(this.ARGB2RGBA(4286611584));
		}
	}

	function setVariableEx( name, value, time = 0, accel = 0 )
	{
		if (typeof accel == "string")
		{
			switch(accel.tolower())
			{
			case "accel":
				accel = 1;

			case "decel":
				accel = -1;

			case "acdec":
				accel = 0;

			case "accos":
				accel = 0;

			case "const":
				accel = 0;
			}
		}

		accel = ::tonumber(accel);
		time = time * 60 / 1000;

		switch(name)
		{
		case "meshdivisionratio":
		case "bustscale":
		case "hairscale":
		case "partsscale":
			this._motion[name] <- value;
		}

		this.setVariable(name, value, time, accel);
		  // [056]  OP_JMP            0      0    0    0
	}

	function getVariable( name )
	{
		switch(name)
		{
		case "meshdivisionratio":
		case "bustscale":
		case "hairscale":
		case "partsscale":
			return this._motion[name];
		}

		return ::Emote.getVariable(name);
	}

	function onVoiceFlip( value )
	{
		::Emote.setVariable("face_talk", value);
	}

	function eval( exp )
	{
		if (this._owner != null && "eval" in this._owner)
		{
			return this._owner.eval(exp);
		}

		return ::eval(exp);
	}

	function _playTimeline( name, ratio = 1.0, time = 0, easing = 0 )
	{
		if (this.getTimelinePlaying(name))
		{
			if (name in this._diff)
			{
				this.setTimelineBlendRatio(name, ratio, time * 60 / 1000, easing);
			}
		}
		else if (name in this._main)
		{
			this.playTimeline(name, 1);
		}
		else if (name in this._diff)
		{
			this.playTimeline(name, 3);
			this.setTimelineBlendRatio(name, 0, 0, 0);
			this.setTimelineBlendRatio(name, ratio, time * 60 / 1000, easing);
		}
	}

	function _stopTimeline( name, time = 0, easing = 0 )
	{
		if (this.getTimelinePlaying(name))
		{
			if (name in this._main)
			{
				this.stopTimeline(name);
			}
			else if (name in this._diff)
			{
				this.fadeOutTimeline(name, time * 60 / 1000, easing);
			}
		}
	}

	function onSetOptions( _options )
	{
		if ("timelines" in _options || "timeline" in _options)
		{
			local stoptls = this.getPlayingTimelineInfoList();

			foreach( tl in stoptls )
			{
				if (!this._motion.ignoreAutoStopTimelineList.includes(tl.label))
				{
					this._stopTimeline(tl.label, 300);
				}
			}
		}
	}

	function _setOptions( _options )
	{
		if ("variables" in _options)
		{
			local vars = _options.variables;

			if (typeof vars == "string")
			{
				vars = this.eval(vars);
			}

			if (vars != null)
			{
				foreach( name, value in vars )
				{
					this.setVariable(name, value);
				}
			}
		}

		local time = ::getint(_options, "time", 0);
		local easing = ::getint(_options, "easing", 0);
		local ratio = ::getint(_options, "ratio", 1.0);

		if ("timelines" in _options)
		{
			if (typeof _options.timelines == "string")
			{
				local stoptls = this.getPlayingTimelineInfoList();
				local tls = _options.timelines.split(":");
				local e = {};

				foreach( tl in tls )
				{
					e[tl] <- true;
				}

				foreach( tl in stoptls )
				{
					if (!(tl.label in e))
					{
						this._stopTimeline(tl.label);
					}
				}

				foreach( tl in tls )
				{
					this._playTimeline(tl);
				}
			}
			else
			{
				local stoptls = this.getPlayingTimelineInfoList();
				local tls = _options.timelines;
				local e = {};

				if (tls != null)
				{
					foreach( tl in tls )
					{
						e[tl] <- true;
					}
				}

				foreach( tl in stoptls )
				{
					if (!(tl.label in e))
					{
						this._stopTimeline(tl.label);
					}
				}

				if (tls != null)
				{
					foreach( tl in tls )
					{
						this._playTimeline(tl.label, ::getfloat(tl, "blendRatio", 1.0));
					}
				}
			}
		}

		if ("stoptimeline" in _options)
		{
			local timeline = _options.stoptimeline;

			if (typeof timeline == "table")
			{
				this._setOptions(timeline);
			}
			else if (typeof timeline == "array")
			{
				foreach( tl in timeline )
				{
					this._setOptions(tl);
				}
			}
			else if (timeline == 1 || timeline == "")
			{
				local tls = this.getPlayingTimelineInfoList();

				foreach( tl in tls )
				{
					this._stopTimeline(tl.label, time, easing);
				}
			}
			else
			{
				local tls = timeline.split(":");

				foreach( tl in tls )
				{
					this._stopTimeline(tl, time, easing);
				}
			}
		}

		if ("timeline" in _options)
		{
			local timeline = _options.timeline;

			if (typeof timeline == "table")
			{
				this._setOptions(timeline);
			}
			else if (typeof timeline == "array")
			{
				foreach( tl in timeline )
				{
					this._setOptions(tl);
				}
			}
			else if (timeline == 1 || timeline == "")
			{
				local tls = this.getPlayingTimelineInfoList();

				foreach( tl in tls )
				{
					this._stopTimeline(tl.label, time, easing);
				}
			}
			else
			{
				local tls = timeline.split(":");

				foreach( tl in tls )
				{
					this._playTimeline(tl, ratio, time, easing);
				}
			}
		}

		if ("color" in _options)
		{
			if (_options.color == "")
			{
				this._motion.color = null;
				this.setColor(this.ARGB2RGBA(4286611584), time * 60 / 1000, easing);
			}
			else
			{
				this._motion.color = ::toint(_options.color);
				this.setColor(this.ARGB2RGBA(4278190080 | this._motion.color), time * 60 / 1000, easing);
			}
		}
	}

	function setOptions( _options )
	{
		this.onSetOptions(_options);
		this._setOptions(_options);
	}

	function canDispSync()
	{
		return this.getAnimating();
	}

	function dispSync()
	{
		if (this.getAnimating())
		{
			this.pass();
		}
	}

}

class this.TextPicture extends ::TextRender
{
	_owner = null;
	constructor( owner, elm )
	{
		this._owner = owner.weakref();
		::TextRender.constructor(owner);
		this.setDefault(this.convertPSBValue(elm));
		local width = ::getint(elm, "width", this.SCWIDTH);
		local height = ::getint(elm, "height", this.SCHEIGHT);
		this.setRenderSize(width, height);
		this.clear();
		this.render(elm.text, 0, 0, 0, false);
		this.done();
	}

	function onEval( name )
	{
		local ret = this._owner.eval(name);

		if (ret == null)
		{
			ret = " ";
		}

		return ret;
	}

	function findFont( size, face = null, type = 0, vector = true )
	{
		local ret = this._owner.findFont(size, face, type, vector);

		if (ret == null && face != null)
		{
			ret = this._owner.findFont(size, null, type, vector);
		}

		return ret;
	}

	function findRubyFont( size )
	{
		return this.findFont(size, "ruby");
	}

}

class this.BasicPicture extends ::Object
{
	constructor( owner )
	{
		::Object.constructor();
		this._owner = owner.weakref();
		this._defaultAfx = "DEFAULT_AFX" in this._owner ? this._owner.DEFAULT_AFX : 0;
		this._defaultAfy = "DEFAULT_AFY" in this._owner ? this._owner.DEFAULT_AFY : 0;
	}

	function destructor()
	{
		this.clear();
		::Object.destructor();
	}

	function getImageForMotion()
	{
		if (this._rawimage instanceof ::RawImage)
		{
			return this._rawimage;
		}

		if (this._image instanceof ::Image)
		{
			return this._image;
		}

		if (this._image instanceof ::DoubleImage)
		{
			return this._image.imageList[0];
		}

		return null;
	}

	function onVoiceFlip( value )
	{
		if ("onVoiceFlip" in this._picture)
		{
			this._picture.onVoiceFlip(value);
		}

		if (this.isImage() || this.isMotion())
		{
			this.setVariable("lip", value);
		}
	}

	function isEmote()
	{
		return this._picture instanceof ::Emote;
	}

	function isMotion()
	{
		return this._picture instanceof ::Motion;
	}

	function isImage()
	{
		return this._picture != null && this._image != null;
	}

	function contains( x, y )
	{
		if (this._picture instanceof ::Emote)
		{
			return this._picture.contains("hit_body", x, y);
		}

		return ("contains" in this._picture) && this._picture.contains(x, y);
	}

	function containsShape( shape, x, y )
	{
		if (this._picture instanceof ::Emote)
		{
			return this._picture.contains(shape, x, y);
		}

		return false;
	}

	function clear()
	{
		this._imageLeft = 0;
		this._imageTop = 0;
		this.curStorage = -1;

		if (this._picture != null)
		{
			if ("clear" in this._picture)
			{
				this._picture.clear();
			}

			if ("setVisible" in this._picture)
			{
				this._picture.setVisible(false);
			}
		}

		this._picture = null;
		this._motion = null;
		this._imageinfo = null;
		this._image = null;
		this._color = null;
		this._roll = null;
		this._tile = null;
		this._noise = null;
		this._text = null;
		this._movie = null;
		this._rawimage = null;
		this._live2d = null;
		this._options = null;
		this._imgWidth = 0;
		this._imgHeight = 0;
		this._afx = 0;
		this._afy = 0;
		this._width = 0;
		this._height = 0;
		this._resolution = 1.0;
	}

	function loadImage( elm )
	{
		this.initVariable();

		if (typeof elm == "instance" && (elm instanceof ::RawImage))
		{
			this._rawimage = elm;
			this._imgWidth = elm.width;
			this._imgHeight = elm.height;
			this._createPicture();
		}
		else if (typeof elm == "instance" && (elm instanceof ::PSBObject))
		{
			this._loadImage(elm);
			this._createPicture();
		}
		else if (typeof elm == "string")
		{
			local data = this.loadImageData(elm);

			if (data != null)
			{
				this._loadImage(data);
				this.curStorage = elm;
			}

			this._createPicture();
		}
		else if (typeof elm == "table")
		{
			local data = ::getval(elm, "imagedata");
			local storage = ::getval(elm, "storage");

			if (storage == null)
			{
				storage = ::getval(elm, "file");
			}

			if (storage == null)
			{
				this.clear();

				if ("chara" in elm)
				{
					this._motion = {
						type = "motion",
						data = null
					};
					this._options = {
						chara = elm.chara
					};
					this._options.motion <- "motion" in elm ? elm.motion : "show";
					this._options.flag <- "flag" in elm ? elm.flag : 1;

					if ("variables" in elm)
					{
						this._options.variables <- elm.variablesag;
					}
				}
				else
				{
					if ("data" in elm)
					{
						local data = elm.data;

						if (typeof data == "instance" && (data instanceof ::RawImage))
						{
							this._rawimage = data;
							this._imgWidth = data.width;
							this._imgHeight = data.height;
						}
						else
						{
							this._imgWidth = ::getint(elm, "width");
							this._imgHeight = ::getint(elm, "height");
							this._rawimage = {
								data = data,
								width = this._imgWidth,
								height = this._imgHeight
							};
						}
					}
					else if ("roll" in elm)
					{
						if (data == null)
						{
							local l;
							local storage = elm.roll;
							l = storage.find(".");

							if (storage != null && l > 0)
							{
								storage = storage.substr(0, l);
							}

							data = this.loadImageData(storage);
						}

						if (data != null)
						{
							this._roll = {
								data = data
							};

							if ("rollbegin" in elm)
							{
								this._roll.rollbegin <- elm.rollbegin;
							}

							if ("rollend" in elm)
							{
								this._roll.rollend <- elm.rollend;
							}
						}
					}
					else
					{
						if (("options" in elm) && ("resolution" in elm.options) && elm.options.resolution != "")
						{
							this._resolution = ::getfloat(elm.options, "resolution") / 100.0;
						}

						local r = this.getResolution();
						this._imgWidth = ::getint(elm, "width", this.SCWIDTH) * r;
						this._imgHeight = ::getint(elm, "height", this.SCHEIGHT) * r;

						if ("text" in elm)
						{
							this._text = elm;
						}
						else if ("noise" in elm)
						{
							this._noise = {
								noise = ::getint(elm, "noise"),
								width = this._imgWidth,
								height = this._imgHeight
							};
						}
						else if ("capture" in elm)
						{
							this.printf("\x00e3\x0082\x00ad\x00e3\x0083\x00a3\x00e3\x0083\x0097\x00e3\x0083\x0081\x00e3\x0083\x00a3\x00e5\x00ae\x009f\x00e8\x00a1\x008c:%s,%s\n", this._imgWidth, this._imgHeight);

							if (this._owner != null && "getImageCapture" in this._owner)
							{
								local capture = this._owner.getImageCapture();

								if (capture)
								{
									this._rawimage = ::RawImage(this._imgWidth, this._imgHeight);
									local bounds = this._owner.getScreenBounds();
									local sx = this.tofloat(this._imgWidth) / bounds.width;
									local sy = this.tofloat(this._imgHeight) / bounds.height;

									if (sx == sy)
									{
										capture.storeThumbnail(this._rawimage, sx);
										this._rawimage.fillAlpha();
									}
									else
									{
										local img = ::RawImage(bounds.width, bounds.height);
										capture.storeThumbnail(img, 1.0);
										img.fillAlpha();
										this._rawimage.stretchCopy(0, 0, this._imgWidth, this._imgHeight, img, 0, 0, img.width, img.height);
									}

									local blur = this.getint(elm, "blur", 0);
									local blurx = this.getint(elm, "blurx", blur);
									local blury = this.getint(elm, "blury", blur);
									local iter = this.getint(elm, "iter", 1);

									if (blurx > 0 || blury > 0)
									{
										this._rawimage.boxBlur(blurx, blury, iter);
									}
								}
								else
								{
									this.printf("\x00e3\x0082\x00ad\x00e3\x0083\x00a3\x00e3\x0083\x0097\x00e3\x0083\x0081\x00e3\x0083\x00a3\x00e3\x0081\x00aa\x00e3\x0081\x0097\n");
								}
							}

							if (this._rawimage == null)
							{
								this._color = {
									color = 4287137928,
									width = this._imgWidth,
									height = this._imgHeight
								};
							}
						}
						else
						{
							local opac = ::getint(elm, "coloropacity", 255);
							this._color = {
								color = this.evalColor(::getval(elm, "color", 8947848)) | opac << 24,
								width = this._imgWidth,
								height = this._imgHeight
							};
						}
					}

					this._options = ::getval(elm, "options");
				}

				this._createPicture();
			}
			else if (storage != this.curStorage)
			{
				local l;
				local ext;
				l = storage.rfind(".");

				if (storage != null && l > 0)
				{
					ext = storage.substr(l + 1);
				}

				switch(ext)
				{
				case "psb":
				case "mtn":
					if (data == null)
					{
						data = this.loadImageData(storage);
					}

					if (data == null)
					{
						this.printf("failed to load motion:%s\n", storage);
					}
					else
					{
						this.clear();
						data = ::MotionData(this._owner, data);

						if (data.emote)
						{
							this._motion = {
								type = "emote",
								data = data,
								color = null,
								meshdivisionratio = 1,
								bustscale = 1,
								hairscale = 1,
								partsscale = 1
							};
						}
						else
						{
							this._motion = {
								type = "motion",
								data = data
							};
						}
					}

					break;

				case "amv":
					local _isLoop = false;

					if ("options" in elm)
					{
						_isLoop = ::getbool(elm.options, "loop", false);
					}

					this._initMovie(storage.substr(0, l), true, _isLoop);
					break;

				case "mpg":
				case "wmv":
					local _isLoop = false;

					if ("options" in elm)
					{
						_isLoop = ::getbool(elm.options, "loop", false);
					}

					this._initMovie(storage.substr(0, l), false, _isLoop);
					break;

				case "l2d":
				case "live2d":
					if (data == null)
					{
						data = this.loadBinary("image/" + storage);
					}

					if (data == null)
					{
						this.printf("failed to load live2d data:%s\n", storage);
					}
					else
					{
						this.clear();
						this._live2d = {
							filename = storage,
							data = data
						};
					}

					break;

				default:
					if ("movie" in elm)
					{
						if (elm.movie == "movie")
						{
							this._initMovie(storage, false, ::getbool(elm, "loop", false));
						}
						else if (elm.movie == "amovie")
						{
							this._initMovie(storage, true, ::getbool(elm, "loop", false));
						}
					}
					else if ("tile" in elm)
					{
						if (data == null)
						{
							data = this.loadImageData(storage);
						}

						local image = ::Image(data);
						this.clear();

						if (image)
						{
							this._imgWidth = ::getval(elm, "width", image.width);
							this._imgHeight = ::getval(elm, "height", image.height);
							this._tile = {
								data = image,
								width = this._imgWidth,
								height = this._imgHeight
							};
						}
					}
					else if ("roll" in elm)
					{
						this.printf("\x00e3\x0083\x00ad\x00e3\x0083\x00bc\x00e3\x0083\x00ab\x00e7\x0094\x00bb\x00e5\x0083\x008f:%s\n", storage);

						if (data == null)
						{
							local l;
							l = storage.find(".");

							if (storage != null && l > 0)
							{
								storage = storage.substr(0, l);
							}

							data = this.loadImageData(storage);
						}

						if (data != null)
						{
							this._roll = {
								data = data
							};

							if ("rollbegin" in elm)
							{
								this._roll.rollbegin <- elm.rollbegin;
							}

							if ("rollend" in elm)
							{
								this._roll.rollend <- elm.rollend;
							}
						}
					}
					else
					{
						if (data == null)
						{
							data = this.loadImageData(storage);
						}

						if (data != null)
						{
							this._loadImage(data);
							this.curStorage = storage;
						}

						if ("width" in elm)
						{
							this._imgWidth = ::toint(elm.width);
						}

						if ("height" in elm)
						{
							this._imgHeight = ::toint(elm.height);
						}
					}

					break;
				}

				this._options = ::getval(elm, "options");
				this._createPicture();
				this.curStorage = storage;
			}
			else
			{
				this._options = ::getval(elm, "options");
				this._updatePicture();
			}
		}

		this._initOptions();
		this._updatePosition();
	}

	function updateEnvironment( elm )
	{
		if (this._picture instanceof ::Emote)
		{
			if ("wind" in elm)
			{
				local wind = elm.wind;
				this._picture.startWind(wind.start, wind.goal, wind.speed, wind.min, wind.max);
			}
		}
	}

	function fill( w, h, color )
	{
		this.clear();
		this._color = {
			color = color,
			width = w,
			height = h
		};
		this._imgWidth = w;
		this._imgHeight = h;
		this._createPicture();
		this._initOptions();
		this._updatePosition();
	}

	function copyImage( origpicture )
	{
		this.clear();
		this._resolution = origpicture._resolution;
		this._width = origpicture._width;
		this._height = origpicture._height;
		this._imageLeft = origpicture._imageLeft;
		this._imageTop = origpicture._imageTop;
		this._imgWidth = origpicture._imgWidth;
		this._imgHeight = origpicture._imgHeight;
		this._afx = origpicture._afx;
		this._afy = origpicture._afy;
		this.curStorage = origpicture.curStorage;
		this._options = origpicture._options;

		if (origpicture._motion != null)
		{
			local origmotion = origpicture._motion;
			local data = origmotion.data != null ? origmotion.data.cloneObj(this._owner) : null;

			if (origmotion.type == "emote")
			{
				this._motion = {
					type = origmotion.type,
					data = data,
					color = origmotion.color,
					meshdivisionratio = origmotion.meshdivisionratio,
					bustscale = origmotion.bustscale,
					hairscale = origmotion.hairscale,
					partsscale = origmotion.partsscale,
					ignoreAutoStopTimelineList = origmotion.ignoreAutoStopTimelineList
				};
			}
			else
			{
				this._motion = {
					type = origmotion.type,
					data = data
				};
			}
		}
		else if (origpicture._live2d != null)
		{
			this._live2d = origpicture._live2d;
		}
		else if (origpicture._image != null)
		{
			this._imageinfo = origpicture._imageinfo;
			this._image = origpicture._image;
			this._lip = origpicture._lip;
			this._eye = origpicture._eye;
		}
		else if (origpicture._noise != null)
		{
			this._noise = origpicture._noise;
		}
		else if (origpicture._text != null)
		{
			this._text = origpicture._text;
		}
		else if (origpicture._color != null)
		{
			this._color = origpicture._color;
		}
		else if (origpicture._roll != null)
		{
			this._roll = origpicture._roll;
		}
		else if (origpicture._tile != null)
		{
			this._tile = origpicture._tile;
		}
		else if (origpicture._movie != null)
		{
			this._movie = origpicture._movie;
			this.printf("movie\x00e8\x00a4\x0087\x00e8\x00a3\x00bd\n");
		}
		else if (origpicture._rawimage != null)
		{
			this._rawimage = origpicture._rawimage;
		}

		this._createPicture(origpicture._picture);
		this._updatePosition();
	}

	function setOptions( options )
	{
		this._options = options;
		this._updatePicture();
		this._initOptions();
		this._updatePosition();
	}

	function getWidth()
	{
		return this._width;
	}

	function setWidth( v )
	{
		if (this._width != v)
		{
			this._width = v;
			this._calcArea();
		}
	}

	function getHeight()
	{
		return this._height;
	}

	function setHeight( v )
	{
		if (this._width != v)
		{
			this._width = v;
			this._calcArea();
		}
	}

	function setSize( width, height )
	{
		this._width = width;
		this._height = height;
		this._calcArea();
	}

	function getImageLeft()
	{
		return this._imageLeft;
	}

	function setImageLeft( v )
	{
		if (this._imageLeft != v)
		{
			this._imageLeft = v;
			this._calcArea();
		}
	}

	function getImageTop()
	{
		return this._imageTop;
	}

	function setImageTop( v )
	{
		if (this._imageTop != v)
		{
			this._imageTop = v;
			this._calcArea();
		}
	}

	function setScale( x, y )
	{
		this._scalex = x;
		this._scaley = y;
		this._updateImagePosition();
	}

	function setOffset( x, y )
	{
		this._offx = x;
		this._offy = y;
		this._updateImagePosition();
	}

	function getVisible( v )
	{
		return this._visible;
	}

	function setVisible( v )
	{
		if (this._visible != v)
		{
			this._picture.setVisible(v);
			this._visible = v;
		}
	}

	function setSpeed( speed )
	{
		if (this._picture != null && "setSpeed" in this._picture)
		{
			this._picture.setSpeed(speed);
		}
	}

	function setOpacity( o )
	{
		if (this._picture != null && "setOpacity" in this._picture)
		{
			this._picture.setOpacity(o);
		}
	}

	function setType( type )
	{
		if (this._picture != null && "setBlendMode" in this._picture)
		{
			this._picture.setBlendMode(type);
		}
	}

	function setRaster( raster )
	{
		this._raster = raster;

		if (raster != 0)
		{
			if (this._picture == null || !(this._picture instanceof ::DoubleLayerRaster))
			{
				this._calcArea();
			}

			if (this._picture != null && (this._picture instanceof ::DoubleLayerRaster))
			{
				this._picture.raster = raster;
			}
		}
		else if (this._picture == null || (this._picture instanceof ::DoubleLayerRaster))
		{
			this._calcArea();
		}
	}

	function setRasterlines( rasterLines )
	{
		this._rasterLines = rasterLines;

		if (this._picture != null && (this._picture instanceof ::DoubleLayerRaster))
		{
			this._picture.rasterLines = rasterLines;
		}
	}

	function setRastercycle( rasterCycle )
	{
		this._rasterCycle = rasterCycle;

		if (this._picture != null && (this._picture instanceof ::DoubleLayerRaster))
		{
			this._picture.rasterCycle = rasterCycle;
		}
	}

	function reset()
	{
		this.setRaster(0);
		this.setRasterlines(100);
		this.setRastercycle(1000);
		this.setDistortion(0);
	}

	function setDistortion( distortion )
	{
		this._distortion = distortion;

		if (this._picture != null && (this._picture instanceof ::DoubleLayerPicture))
		{
			if (this._distortion > 0)
			{
				local modParam = {
					width = this._picture.width,
					height = this._picture.height,
					frameX = this._distortionFrameX,
					frameY = this._distortionFrameY,
					linesX = this._distortionLinesX * this.SPEC_SCALE,
					linesY = this._distortionLinesY * this.SPEC_SCALE,
					ampX = this._distortionAmpX * this.SPEC_SCALE,
					ampY = this._distortionAmpY * this.SPEC_SCALE
				};
				this._picture.setMeshSize(this._distortionMeshSize * this.SPEC_SCALE);
				this._distortionModList = this._picture.registerVertexModulator(modParam);
			}
			else if (this._distortionModList != null)
			{
				this._picture.unregisterVertexModulator(this._distortionModList);
				this._distortionModList.clear();
				this._distortionModList = null;
			}
		}
	}

	function setDistortionlines( lines )
	{
		this._distortionLinesX = this._distortionLinesY = lines;
	}

	function setDistortionlinesX( lines )
	{
		this._distortionLinesX = lines;
	}

	function setDistortionlinesY( lines )
	{
		this._distortionLinesY = lines;
	}

	function setDistortionframe( frame )
	{
		this._distortionFrameX = this._distortionFrameY = frame;
	}

	function setDistortionframeX( frame )
	{
		this._distortionFrameX = frame;
	}

	function setDistortionframeY( frame )
	{
		this._distortionFrameY = frame;
	}

	function setDistortionamp( amp )
	{
		this._distortionAmpX = this._distortionAmpY = amp;
	}

	function setDistortionampX( amp )
	{
		this._distortionAmpX = amp;
	}

	function setDistortionampY( amp )
	{
		this._distortionAmpY = amp;
	}

	function setDistortionmeshsize( size )
	{
		this._distortionMeshSize = size;
	}

	function canMove( name )
	{
		if (this._picture instanceof ::Emote)
		{
			switch(name)
			{
			case "$meshdivisionratio":
			case "$bustscale":
			case "$hairscale":
			case "$partsscale":
				return false;
			}

			return name.charAt(0) == "$";
		}

		return false;
	}

	function initVariable()
	{
		this._lip = 0;
		this._eye = 2;
		this._faceover = null;
	}

	function setVariable( name, value, time = 0, accel = 0 )
	{
		if ("setVariableEx" in this._picture)
		{
			this._picture.setVariableEx(name, value, time, accel);
		}
		else if ("setVariable" in this._picture)
		{
			this._picture.setVariable(name, value);
		}
		else
		{
			switch(name)
			{
			case "lip":
				local no = this.toint(value, 0);

				if (this._lip != no)
				{
					this._lip = no;
					this._updatePicture();
				}

				break;

			case "eye":
				local no = this.toint(value, 0);

				if (this._eye != no)
				{
					this._eye = no;
					this._updatePicture();
				}

				break;

			case "face":
				if (this._faceover != value)
				{
					this._faceover = value;
					this._updatePicture();
				}

				break;
			}
		}
	}

	function getVariable( name )
	{
		if ("getVariable" in this._picture)
		{
			return this._picture.getVariable(name);
		}
		else
		{
			switch(name)
			{
			case "lip":
				return this._lip;

			case "eye":
				return this._eye;
			}
		}
	}

	function isMotion()
	{
		return this._picture instanceof ::Motion;
	}

	function isPlayingMotion()
	{
		return (this._picture instanceof ::Motion) && this._picture.visible && this._picture.playing;
	}

	function playMotion( motion, flag = 0 )
	{
		if (this._picture instanceof ::MotionPicture)
		{
			this._picture.playMotion(motion, flag);
		}
	}

	function pauseMotion( state )
	{
		if ((this._picture instanceof ::Motion) && this._picture.visible && this._picture.playing)
		{
			this._picture.pause(state);
		}
		else if (this._picture instanceof ::LayerMovie)
		{
		}
	}

	function getLayerMotion( name )
	{
		if (this._picture instanceof ::Motion)
		{
			return this._picture.getLayerMotion(name);
		}
	}

	function canWaitMovie()
	{
		return (this._picture instanceof ::Motion) && this._picture.visible && this._picture.playing || (this._picture instanceof ::LayerMovie) && this._picture.visible && this._picture.playing || (this._movie instanceof ::DrawMovie) && this._picture.visible;
	}

	function getPlayingMovie()
	{
		return (this._picture instanceof ::LayerMovie) && this._picture.visible && this._picture.playing || (this._movie instanceof ::DrawMovie) && this._picture.visible && this._movie.getPlaying();
	}

	function stopMovie()
	{
		if (this._picture instanceof ::Motion)
		{
			if (this._picture.getPlaying())
			{
				this._picture.skipToSync();
			}
		}
		else if (this._picture instanceof ::LayerMovie)
		{
			this._picture = null;
			this._movie = null;
		}
		else if (this._movie instanceof ::DrawMovie)
		{
			this._movie.stop();
			this._picture = null;
			this._movie = null;
			this.printf("movie\x00e5\x0081\x009c\x00e6\x00ad\x00a2\n");
		}
	}

	function canDispSync()
	{
		if ("canDispSync" in this._picture)
		{
			return this._picture.canDispSync();
		}

		return false;
	}

	function dispSync()
	{
		if ("dispSync" in this._picture)
		{
			this._picture.dispSync();
		}
	}

	function onScale( scale )
	{
		if (this._picture != null && "onScale" in this._picture)
		{
			this._picture.onScale(scale);
		}
	}

	_owner = null;
	_imageinfo = null;
	_lip = 0;
	_eye = 2;
	_faceover = null;
	_image = null;
	_color = null;
	_motion = null;
	_roll = null;
	_tile = null;
	_noise = null;
	_text = null;
	_movie = null;
	_rawimage = null;
	_live2d = null;
	_picture = null;
	_options = null;
	_imgWidth = 0;
	_imgHeight = 0;
	_visible = true;
	curStorage = -1;
	_width = 0;
	_height = 0;
	_imageLeft = 0;
	_imageTop = 0;
	_raster = 0;
	_rasterLines = 0;
	_rasterCycle = 0;
	_distortion = 0;
	_distortionLinesX = 1024;
	_distortionLinesY = 1024;
	_distortionFrameX = 360;
	_distortionFrameY = 720;
	_distortionAmpX = 32;
	_distortionAmpY = 32;
	_distortionMeshSize = 16;
	_distortionModList = null;
	_resolution = 1.0;
	_defaultAfx = 0;
	_defaultAfy = 0;
	_afx = 0;
	_afy = 0;
	_afxValue = 0;
	_afyValue = 0;
	_scalex = 1.0;
	_scaley = 1.0;
	_rot = 0;
	_offx = 0;
	_offy = 0;
	_imagex = 0;
	_imagey = 0;
	_imagezoom = 1.0;
	_imagerot = 0;
	function suspend()
	{
		if (this._owner != null && "suspend" in this._owner)
		{
			this._owner.suspend();
		}
		else
		{
			::suspend();
		}
	}

	function eval( exp )
	{
		if (this._owner != null && "eval" in this._owner)
		{
			return this._owner.eval(exp);
		}

		return ::eval(exp);
	}

	function loadData( storage )
	{
		if (this._owner != null && "loadData" in this._owner)
		{
			return this._owner.loadData(storage);
		}
		else
		{
			return ::loadData(storage);
		}
	}

	function _calcArea()
	{
		this._createPicture();
		this._updatePosition();
	}

	function _updateAffine()
	{
		if (this._owner != null && "updateAffine" in this._owner)
		{
			this._owner.updateAffine();
		}
	}

	function getImageResolution()
	{
		if (this._owner != null && "getImageResolution" in this._owner)
		{
			return this._owner.getImageResolution();
		}

		return 1.0;
	}

	function getResolution()
	{
		return this._resolution * this.getImageResolution();
	}

	function res_align( x )
	{
		local ratio = this.getResolution();

		if (ratio == 1.0)
		{
			return x;
		}

		if (typeof x == "array")
		{
			local ret = [];

			foreach( i, v in x )
			{
				if (v != null)
				{
					ret.append(this.round(v * ratio) / ratio);
				}
			}

			return ret;
		}
		else
		{
			return this.round(x * ratio) / ratio;
		}
	}

	function _calcParam( name )
	{
		local param = "calcParam" in this._owner ? this._owner.calcParam(name) : 1.0;

		if (this._motion != null)
		{
			return this._motion[name] * param;
		}

		return param;
	}

	function _updateImagePosition()
	{
		if (this._picture != null)
		{
			local z = this._imagezoom / this.getResolution();

			if (this._picture instanceof ::Motion)
			{
				this._picture.setCoord(-this._offx + this._imagex, -this._offy + this._imagey);
				this._picture.setZoom(this._scalex * z, this._scaley * z);
				this._picture.setAngleRad(-(this._imagerot + this._rot));
			}
			else if (this._picture instanceof ::Emote)
			{
				this._picture.setCoord(-this._offx + this._imagex, -this._offy + this._imagey);
				this._picture.setScale(this._scalex * z);
				this._picture.setRot(-(this._imagerot + this._rot));
				this._picture.setMeshDivisionRatio(this._calcParam("meshdivisionratio"));
				this._picture.setBustScale(this._calcParam("bustscale"));
				this._picture.setHairScale(this._calcParam("hairscale"));
				this._picture.setPartsScale(this._calcParam("partsscale"));
			}
			else if (this._picture instanceof ::Live2DPicture)
			{
				this._picture.setScale(this._scalex * z);
			}
			else
			{
				if ("setCoord" in this._picture)
				{
					this._picture.setCoord(-this._afxValue, -this._afyValue);
				}

				if ("setOffset" in this._picture)
				{
					this._picture.setOffset(this._offx - this._imagex, this._offy - this._imagey);
				}

				if ("setScale" in this._picture)
				{
					this._picture.setScale(this._scalex * z, this._scaley * z);
				}

				if ("setRot" in this._picture)
				{
					this._picture.setRot(-(this._imagerot + this._rot));
				}
			}
		}
	}

	function calcImageMatrix( x, y, zoom, rot )
	{
		this._imagex = x;
		this._imagey = y;
		this._imagezoom = zoom;
		this._imagerot = rot;
		this._updateImagePosition();
	}

	function _calcCenter( v, base )
	{
		switch(typeof v)
		{
		case "string":
			if (v == "" || v == "default" || v == "void")
			{
				return 0;
			}

			return ::eval(v, {
				center = ::toint(base / 2),
				left = 0,
				top = 0,
				right = base,
				bottom = base
			});

		case "null":
			return ::toint(base / 2);
		}

		return ::tonumber(v) * this.getImageResolution();
	}

	function _updatePosition()
	{
		this._afxValue = this._calcCenter(this._afx, this._imgWidth);
		this._afyValue = this._calcCenter(this._afy, this._imgHeight);
		this._updateAffine();
		this._updateImagePosition();
	}

	function _createPicture( origpicture = null )
	{
		if (this._owner == null)
		{
			return;
		}

		if (this._motion != null)
		{
			if (this._motion.type == "emote")
			{
				this._picture = ::EmotePicture(this._owner, origpicture, this._motion);
			}
			else
			{
				this._picture = ::MotionPicture(this._owner, origpicture);
			}
		}
		else if (this._live2d != null)
		{
			if (::Live2D)
			{
				this._picture = ::Live2DPicture(this._owner, origpicture, this._live2d);
			}
			else
			{
				this.printf("Live2D\x00e6\x009c\x00aa\x00e5\x00af\x00be\x00e5\x00bf\x009c\x00e3\x0081\x00a7\x00e3\x0081\x0099\n");
			}
		}
		else if (this._image != null)
		{
			local rasterTime = (this._picture instanceof ::DoubleLayerRaster) ? this._picture.getRasterTime() : null;

			if (this._imageinfo != null)
			{
				if (this._raster > 0)
				{
					this._picture = ::DoubleLayerRaster(this._owner, this._image);
					this._picture.raster = this._raster;
					this._picture.rasterLines = this._rasterLines;
					this._picture.rasterCycle = this._rasterCycle;

					if (rasterTime != null)
					{
						this._picture.setRasterTime(rasterTime);
					}
				}
				else
				{
					this._picture = ::DoubleLayerPicture(this._owner, this._image);
				}
			}
			else if (this._raster > 0)
			{
				this._picture = ::DoubleLayerRaster(this._owner, this._image, -this._imageLeft, -this._imageTop, this._imgWidth, this._imgHeight);
				this._picture.raster = this._raster;
				this._picture.rasterLines = this._rasterLines;
				this._picture.rasterCycle = this._rasterCycle;

				if (rasterTime != null)
				{
					this._picture.setRasterTime(rasterTime);
				}
			}
			else
			{
				this._picture = ::DoubleLayerPicture(this._owner, this._image, -this._imageLeft, -this._imageTop, this._imgWidth, this._imgHeight);
			}
		}
		else if (this._color != null)
		{
			this._picture = ::FillRect(this._owner);
			this._picture.setSize(this._color.width, this._color.height);
			this._picture.setColor(this.ARGB2RGBA(this._color.color));
		}
		else if (this._roll != null)
		{
			this._picture = ::RollPicture(this._owner, this._roll);

			if (origpicture instanceof ::RollPicture)
			{
				this._picture.rollvalue = origpicture.rollvalue;
			}
		}
		else if (this._tile != null)
		{
			this._picture = ::TilePicture(this._owner, this._tile);

			if (origpicture instanceof ::TilePicture)
			{
				this._picture.tilex = origpicture._tilex;
				this._picture.tiley = origpicture._tiley;
			}
		}
		else if (this._noise != null)
		{
			this._picture = ::NoisePicture(this._owner, this._noise);
		}
		else if (this._text != null)
		{
			this._picture = ::TextPicture(this._owner, this._text);
		}
		else if (this._movie != null)
		{
			if (this._movie instanceof ::DrawMovie)
			{
				this._picture = ::LayerDraw(this._owner, this._movie);
				this._picture.visible = true;
				this.printf("movie\x00e5\x008f\x0082\x00e7\x0085\x00a7\x00e7\x0094\x009f\x00e6\x0088\x0090\n");
			}
			else if (this._movie instanceof ::ShortMovie)
			{
				this._picture = ::LayerDraw(this._owner, this._movie);
				this._picture.visible = true;
				this.printf("movie\x00e5\x008f\x0082\x00e7\x0085\x00a7\x00e7\x0094\x009f\x00e6\x0088\x0090\n");
			}
			else if (::LayerMovie != null)
			{
				this._picture = this._createMovie(::LayerMovie(this._owner), this._movie.storage, this._movie.alpha, this._movie.loop);
				this._picture.visible = true;
			}
		}
		else if (this._rawimage != null)
		{
			this._picture = ::LayerRawTex(this._owner, this._rawimage.width, this._rawimage.height);
			this._picture.restore((this._rawimage instanceof this.RawImage) ? this._rawimage : this._rawimage.data);
		}

		if (this._picture != null)
		{
			this._picture.setVisible(this._visible);
		}

		this._updatePicture();
	}

	function _updatePicture()
	{
		if (this._image != null && this._imageinfo != null && this._picture != null)
		{
			local _face = this._faceover != null ? this._faceover : ::getval(this._options, "face", null);

			if ("crop" in this._imageinfo.root || "eyemap" in this._imageinfo.root || "lipmap" in this._imageinfo.root)
			{
				this._picture.clearImageRange();
				local crop = "crop" in this._imageinfo.root ? this._imageinfo.root.crop : {
					x = 0,
					y = 0,
					w = this._imageinfo.root.w,
					h = this._imageinfo.root.h
				};

				if ("eyemap" in this._imageinfo.root || "lipmap" in this._imageinfo.root)
				{
					local eyemap = "eyemap" in this._imageinfo.root ? this._imageinfo.root.eyemap : null;
					local lipmap = "lipmap" in this._imageinfo.root ? this._imageinfo.root.lipmap : null;
					local lipno;
					local eyeno;

					if (_face != null)
					{
						local f = _face.split(":");

						foreach( v in f )
						{
							local e = this._eye > 0 ? v + this._eye : v;
							local l = this._lip > 0 ? v + this._lip : v;

							if (e in eyemap)
							{
								eyeno = eyemap[e];
							}
							else if (l in lipmap)
							{
								lipno = lipmap[l];
							}
						}

						if (eyeno == null)
						{
							local e = this._eye > 0 ? _face + this._eye : _face;

							if (e in eyemap)
							{
								eyeno = eyemap[e];
							}
						}

						if (lipno == null)
						{
							local l = this._lip > 0 ? _face + this._lip : _face;

							if (l in lipmap)
							{
								lipno = lipmap[l];
							}
						}
					}

					if (eyeno == null && lipno == null)
					{
						this._picture.assignImageRange(0, 0, crop.w, crop.h, crop.x, crop.y);
					}
					else if (eyeno == null)
					{
						local ldiff = this._imageinfo.root.lipdiff;
						local lx = ldiff.x - crop.x;
						local ly = ldiff.y - crop.y;
						local lx2 = lx + ldiff.w;
						local ly2 = ly + ldiff.h;
						local ldh = ldiff.h + 2;
						local ldw = ldiff.w + 2;
						local lhc = ::toint(this._image.height / ldh);
						local lfx = ::toint(lipno / lhc);
						local lfy = lipno % lhc;
						local ldx = this._imageinfo.root.lipdiffbase + ldw * lfx + 1;
						local ldy = ldh * lfy + 1;
						this._picture.assignImageRange(0, 0, crop.w, ly, crop.x, crop.y);
						this._picture.assignImageRange(0, ly, lx, ly2, crop.x, ldiff.y);
						this._picture.assignImageRange(ldx, ldy, ldx + ldiff.w, ldy + ldiff.h, ldiff.x, ldiff.y);
						this._picture.assignImageRange(lx2, ly, crop.w, ly2, ldiff.x + ldiff.w, ldiff.y);
						this._picture.assignImageRange(0, ly2, crop.w, crop.h, crop.x, ldiff.y + ldiff.h);
					}
					else if (lipno == null)
					{
						local ediff = this._imageinfo.root.eyediff;
						local ex = ediff.x - crop.x;
						local ey = ediff.y - crop.y;
						local ex2 = ex + ediff.w;
						local ey2 = ey + ediff.h;
						local dh = ediff.h + 2;
						local dw = ediff.w + 2;
						local hc = ::toint(this._image.height / dh);
						local fx = ::toint(eyeno / hc);
						local fy = eyeno % hc;
						local edx = this._imageinfo.root.eyediffbase + dw * fx + 1;
						local edy = dh * fy + 1;
						this._picture.assignImageRange(0, 0, crop.w, ey, crop.x, crop.y);
						this._picture.assignImageRange(0, ey, ex, ey2, crop.x, ediff.y);
						this._picture.assignImageRange(edx, edy, edx + ediff.w, edy + ediff.h, ediff.x, ediff.y);
						this._picture.assignImageRange(ex2, ey, crop.w, ey2, ediff.x + ediff.w, ediff.y);
						this._picture.assignImageRange(0, ey2, crop.w, crop.h, crop.x, ediff.y + ediff.h);
					}
					else if (true)
					{
						local ediff = this._imageinfo.root.eyediff;
						local ex = ediff.x - crop.x;
						local ey = ediff.y - crop.y;
						local ex2 = ex + ediff.w;
						local ey2 = ey + ediff.h;
						local dh = ediff.h + 2;
						local dw = ediff.w + 2;
						local hc = ::toint(this._image.height / dh);
						local fx = ::toint(eyeno / hc);
						local fy = eyeno % hc;
						local edx = this._imageinfo.root.eyediffbase + dw * fx + 1;
						local edy = dh * fy + 1;
						local ldiff = this._imageinfo.root.lipdiff;
						local lx = ldiff.x - crop.x;
						local ly = ldiff.y - crop.y;
						local lx2 = lx + ldiff.w;
						local ly2 = ly + ldiff.h;
						local ldh = ldiff.h + 2;
						local ldw = ldiff.w + 2;
						local lhc = ::toint(this._image.height / ldh);
						local lfx = ::toint(lipno / lhc);
						local lfy = lipno % lhc;
						local ldx = this._imageinfo.root.lipdiffbase + ldw * lfx + 1;
						local ldy = ldh * lfy + 1;

						if (ly > ey2)
						{
							this._picture.assignImageRange(0, 0, crop.w, ey, crop.x, crop.y);
							this._picture.assignImageRange(0, ey, ex, ey2, crop.x, ediff.y);
							this._picture.assignImageRange(edx, edy, edx + ediff.w, edy + ediff.h, ediff.x, ediff.y);
							this._picture.assignImageRange(ex2, ey, crop.w, ey2, ediff.x + ediff.w, ediff.y);
							this._picture.assignImageRange(0, ey2, crop.w, ly, crop.x, ediff.y + ediff.h);
							this._picture.assignImageRange(0, ly, lx, ly2, crop.x, ldiff.y);
							this._picture.assignImageRange(ldx, ldy, ldx + ldiff.w, ldy + ldiff.h, ldiff.x, ldiff.y);
							this._picture.assignImageRange(lx2, ly, crop.w, ly2, ldiff.x + ldiff.w, ldiff.y);
							this._picture.assignImageRange(0, ly2, crop.w, crop.h, crop.x, ldiff.y + ldiff.h);
						}
						else
						{
							local yd = ey2 - ly;
							local yo = ediff.h - yd;
							local ey2x = ey2 - yd;
							local ediffy2 = ediff.y + yo;
							local elxd = ldiff.x - ediff.x;
							this._picture.assignImageRange(0, 0, crop.w, ey, crop.x, crop.y);
							this._picture.assignImageRange(0, ey, ex, ey2x, crop.x, ediff.y);
							this._picture.assignImageRange(edx, edy, edx + ediff.w, edy + ediff.h - yd, ediff.x, ediff.y);
							this._picture.assignImageRange(ex2, ey, crop.w, ey2x, ediff.x + ediff.w, ediff.y);
							this._picture.assignImageRange(0, ey2x, ex, ey2, crop.x, ediffy2);
							this._picture.assignImageRange(edx, edy + yo, edx + elxd, edy + ediff.h, ediff.x, ediffy2);
							this._picture.assignImageRange(ldx, ldy, ldx + ldiff.w, ldy + yd, ldiff.x, ldiff.y);
							this._picture.assignImageRange(edx + elxd + ldiff.w, edy + yo, edx + ediff.w, edy + ediff.h, ediff.x + elxd + ldiff.w, ediffy2);
							this._picture.assignImageRange(ex2, ey2x, crop.w, ey2, ediff.x + ediff.w, ediffy2);
							this._picture.assignImageRange(0, ly + yd, lx, ly2, crop.x, ldiff.y + yd);
							this._picture.assignImageRange(ldx, ldy + yd, ldx + ldiff.w, ldy + ldiff.h, ldiff.x, ldiff.y + yd);
							this._picture.assignImageRange(lx2, ly + yd, crop.w, ly2, ldiff.x + ldiff.w, ldiff.y + yd);
							this._picture.assignImageRange(0, ly2, crop.w, crop.h, crop.x, ldiff.y + ldiff.h);
						}
					}
					else
					{
						local all = ::Region();
						all.set(0, 0, crop.w, crop.h);
						local ediff;
						local eyereg;
						local ex;
						local ey;
						local edx;
						local edy;

						if (eyeno != null)
						{
							ediff = this._imageinfo.root.eyediff;
							ex = ediff.x - crop.x;
							ey = ediff.y - crop.y;
							all.exclude(ex, ey, ediff.w, ediff.h);
							local dh = ediff.h + 2;
							local dw = ediff.w + 2;
							local hc = ::toint(this._image.height / dh);
							local fx = ::toint(eyeno / hc);
							local fy = eyeno % hc;
							edx = this._imageinfo.root.eyediffbase + dw * fx + 1;
							edy = dh * fy + 1;

							if (lipno == null)
							{
								this._picture.assignImageRange(edx, edy, edx + ediff.w, edy + ediff.h, ediff.x, ediff.y);
							}
							else
							{
								eyereg = ::Region();
								eyereg.set(ex, ey, ediff.w, ediff.h);
							}
						}

						if (lipno != null)
						{
							local ldiff = this._imageinfo.root.lipdiff;
							local lx = ldiff.x - crop.x;
							local ly = ldiff.y - crop.y;
							all.exclude(lx, ly, ldiff.w, ldiff.h);

							if (eyereg != null)
							{
								eyereg.exclude(lx, ly, ldiff.w, ldiff.h);
							}

							local ldh = ldiff.h + 2;
							local ldw = ldiff.w + 2;
							local lhc = ::toint(this._image.height / ldh);
							local lfx = ::toint(lipno / lhc);
							local lfy = lipno % lhc;
							local ldx = this._imageinfo.root.lipdiffbase + ldw * lfx + 1;
							local ldy = ldh * lfy + 1;
							this._picture.assignImageRange(ldx, ldy, ldx + ldiff.w, ldy + ldiff.h, ldiff.x, ldiff.y);
						}

						if (eyereg != null)
						{
							eyereg.offset(-ex, -ey);
							local c = eyereg.getCount();

							for( local i = 0; i < c; i++ )
							{
								local rect = eyereg.getRect(i);
								this._picture.assignImageRange(edx + rect.l, edy + rect.t, edx + rect.r, edy + rect.b, ediff.x + rect.l, ediff.y + rect.t);
							}
						}

						local c = all.getCount();

						for( local i = 0; i < c; i++ )
						{
							local rect = all.getRect(i);
							this._picture.assignImageRange(rect.l, rect.t, rect.r, rect.b, crop.x + rect.l, crop.y + rect.t);
						}
					}
				}
				else if (("facemap" in this._imageinfo.root) && "diff" in this._imageinfo.root)
				{
					local faceno = _face != null ? ::getval(this._imageinfo.root.facemap, _face) : null;

					if (faceno == null)
					{
						this._picture.assignImageRange(0, 0, crop.w, crop.h, crop.x, crop.y);
					}
					else
					{
						local diff = this._imageinfo.root.diff;
						local x = diff.x - crop.x;
						local y = diff.y - crop.y;
						local x2 = x + diff.w;
						local y2 = y + diff.h;
						local dh = diff.h + 2;
						local dw = diff.w + 2;
						local hc = ::toint(this._image.height / dh);
						local fx = ::toint(faceno / hc);
						local fy = faceno % hc;
						local dx = ("diffbase" in this._imageinfo.root ? this._imageinfo.root.diffbase : crop.w) + dw * fx + 1;
						local dy = dh * fy + 1;
						local dx2 = dx + diff.w;
						local dy2 = dy + diff.h;
						this._picture.assignImageRange(0, 0, crop.w, y, crop.x, crop.y);
						this._picture.assignImageRange(0, y, x, y2, crop.x, diff.y);
						this._picture.assignImageRange(dx, dy, dx2, dy2, diff.x, diff.y);
						this._picture.assignImageRange(x2, y, crop.w, y2, diff.x + diff.w, diff.y);
						this._picture.assignImageRange(0, y2, crop.w, crop.h, crop.x, diff.y + diff.h);
					}
				}
				else if ("diff" in this._imageinfo.root)
				{
					local diff = this._imageinfo.root.diff;
					local x = diff.x - crop.x;
					local y = diff.y - crop.y;
					local x2 = x + diff.w;
					local y2 = y + diff.h;
					local dx = ("diffbase" in this._imageinfo.root ? this._imageinfo.root.diffbase : crop.w) + 1;
					local dy = this._lip * (diff.h + 2) + 1;
					local dx2 = dx + diff.w;
					local dy2 = dy + diff.h;
					this._picture.assignImageRange(0, 0, crop.w, y, crop.x, crop.y);
					this._picture.assignImageRange(0, y, x, y2, crop.x, diff.y);
					this._picture.assignImageRange(dx, dy, dx2, dy2, diff.x, diff.y);
					this._picture.assignImageRange(x2, y, crop.w, y2, diff.x + diff.w, diff.y);
					this._picture.assignImageRange(0, y2, crop.w, crop.h, crop.x, diff.y + diff.h);
				}
				else
				{
					this._picture.assignImageRange(0, 0, crop.w, crop.h, crop.x, crop.y);
				}
			}
		}
	}

	function _initOptions()
	{
		if (("resolution" in this._options) && this._options.resolution != "")
		{
			this._resolution = ::getfloat(this._options, "resolution") / 100.0;
		}

		this._afx = "afx" in this._options ? this._options.afx : this._defaultAfx;
		this._afy = "afy" in this._options ? this._options.afy : this._defaultAfy;
		local rr = 1.0 / this.getResolution();
		this._width = this._imgWidth * rr;
		this._height = this._imgHeight * rr;

		if (this._picture != null && this._options != null)
		{
			if ("setOptions" in this._picture)
			{
				this._picture.setOptions(this._options);
			}
		}
	}

	function _loadImage( data )
	{
		local info;

		if (data instanceof "table")
		{
			info = ::getval(data, "info");
			data = ::getval(data, "data");
		}

		if (data != null)
		{
			this.clear();

			if ("rollinfo" in data.root)
			{
				this._roll = {
					data = data
				};
			}
			else
			{
				if (info != null)
				{
					this._imageinfo = info;
				}
				else if ("crop" in data.root || "eyemap" in data.root || "lipmap" in data.root)
				{
					this._imageinfo = data;
				}
				else
				{
					this._imageinfo = null;
				}

				this._image = ::DoubleImage(data);
				this._lip = 0;
				this._eye = 2;

				if (this._imageinfo != null)
				{
					this._imgWidth = this._imageinfo.root.w;
					this._imgHeight = this._imageinfo.root.h;
				}
				else
				{
					this._imgWidth = this._image.width;
					this._imgHeight = this._image.height;
				}
			}
		}
	}

	function _createMovie( movie, storage, alpha, loop = false )
	{
		movie.volume = this.getMovieVolume();
		movie.useAlpha = alpha;

		if (::System.getSpec() == "nx" && alpha)
		{
			movie.specialAlpha = alpha;
		}

		movie.loop = loop;

		if (::SYSTEM_LANGUAGE == 1 && (storage == "ac_prologue01" || storage == "ac_prologue02" || storage == "ac_0112"))
		{
			if (this._owner != null && this._owner.player != null)
			{
				if (this._owner.player.getConfig("voiceLang"))
				{
					storage = storage + "_en";
				}
			}
		}

		if (1)
		{
			if ((movie instanceof this.DrawMovie) || (movie instanceof this.ShortMovie))
			{
				local param = this._owner.player.getMovieParam(storage + ::movieExt);

				if (param)
				{
					movie.setCryptKey(param.val);
				}
			}
		}

		movie.play("movie/" + storage + ::movieExt);

		while (!movie.playStart)
		{
			this.suspend();
		}

		if (::System.getSpec() == "ps4")
		{
			movie.loop = loop;
		}

		return movie;
	}

	function _initMovie( storage, alpha, loop = false )
	{
		this.clear();

		if (this.DrawMovie != null)
		{
			if (::System.getSpec() == "win" && ::ShortMovie != null && this._owner.player.isShortMovie(storage))
			{
				this._movie = this._createMovie(this.ShortMovie(), storage, alpha, loop);
			}
			else
			{
				this._movie = this._createMovie(this.DrawMovie(), storage, alpha, loop);
			}
		}
		else
		{
			this._movie = {
				storage = storage,
				alpha = alpha,
				loop = loop
			};
		}
	}

}

