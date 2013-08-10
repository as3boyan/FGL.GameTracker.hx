package fgl.gametracker;

import flash.events.Event;

class GameTrackerErrorEvent extends Event {
	public var msg(getMsg, never) : String;

	public var _msg : String;
	public function new(type : String, msg : String) {
		_msg = msg;
		super(type, false, false);
	}

	public function getMsg() : String {
		return _msg;
	}

}

