package fgl.gametracker;

import flash.events.Event;

class GameTrackerErrorEvent extends Event {
	public var msg(get, never) : String;

	public var _msg : String;
	public function new(type : String, msg : String) {
		_msg = msg;
		super(type, false, false);
	}

	public function get_msg() : String {
		return _msg;
	}

}

