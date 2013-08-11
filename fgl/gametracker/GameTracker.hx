/* This code copyright 2010 by Lucrative Gaming, LLC.

   Author: Eric Heimburg

   Revised By: Aaron Ward

   Date: Jan 05, 2012

   Version: 1.2 - this is the second "BETA" version

   

   Change Log:

* Singleton support added: access via GameTracker.api

* _lastGameState and _lastScore added to reduce null data entries

* backupLastData() added to reuse the code inside : called at the start of each function that reports currentScore and currentGameState

* _currentScore and _currentGameState added to make backupLastData possible

*/
package fgl.gametracker;

import flash.events.EventDispatcher;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import flash.net.NetConnection;
import flash.net.Responder;
import flash.utils.Timer;

/**	

 * <p>An object to send gameplay information to FlashGameLicense's server

 * for later analysis.</p>

 * <p><strong>To use: </strong></p>

 * <ol>

 * <li> Copy the FGL directory into your game folder so that your code can acccess FGL.GameTracker.

 *    If you are using a multi-file development platform you'll need to add <code>import FGL.GameTracker;</code> 

 *    at the top of each file that calls GameTracker functions. </li>

 * <li> GameTracker is singleton, meaning there is only one GameTracker in your whole game. Access it via the variable <code>GameTracker.api</code></li>

 * <li> Add calls to GameTracker at various places in your game.

 * 		<ul>

     *      <li>Call <code>GameTracker.api.beginGame()</code> when a game begins, and <code>GameTracker.api.endGame()</code> when a game ends</li>

 * 		<li>Call <code>GameTracker.api.beginLevel()</code> when a level begins, and <code>GameTracker.api.endLevel()</code> when a level ends</li>

 * 		<li>Call <code>GameTracker.api.checkpoint()</code> if you want to note that a user has gotten to a checkpoint in the 

 * 			current level</li>

 * 		<li>Call <code>GameTracker.api.alert()</code> to report something important, such as "Player beat the game!" or 

 * 			"Player read the instructions!" These alerts are shown specially on the report page,

 *          so you can tell at a glance what the gamer accomplished.</li>

 * 		<li>Call <code>GameTracker.api.customMsg()</code> to report anything else that might be interesting. For instance, 

 *          you might use custom messages named "GUI" to report when the user clicks on GUI elements.

 *          (The name of your custom message can't be more than 20 characters long, but the actual

 *          message you send can be up to 255 characters long.)</li>

 *	    </ul></li>

 * <li> After you have implemented the API in your game, upload it to FGL. To test it, just view

 *		your game. After you've played for a little bit (at least 15 seconds!), go to your game's Views

 *  	listing. Click the checkbox that shows owner-views. (By default, it doesn't list the times

 *  	that you play your own game, but in this case you want to know that.) You'll see a link called

 *  	"view session". Click this to view the session report, examine the data, and download it for

 *  	offline viewing.</li>

 * </ol>

 * 

 *  <p><strong>Common Parameters</strong></p>

 * 

 *	<p>For each of these functions, you will want to pass in the score, the "game state", and a 

 *  custom message if desired. There may be additional parameters, too, but those three will 

 *  always show up.</p>

 * 

 *  <p>The <code>currentScore</code> is just what it sounds like: the game's current score. (Pass 0 for scoreless games.)</p>

 *  <p>The <code>currentGameState</code> is a string, up to 80 characters long, describing the overall state of the game.

 *  This is just for your use and is entirely optional. Suggested uses include: </p><ul>

 * 		<li> Brief description of the player's power-ups</li>

 * 		<li> What branches of the story the player chose</li>

 * 		<li> How much money (or other "alternate scores") the player has</li></ul>

 *  <p>The <code>customMsg</code> is a string up to 255 characters long. This can be anything you want.

 *  The custom message parameter is entirely optional. However, for <code>alert()</code> and <code>customMsg()</code> events,

 *  the custom message is the whole point, so passing null for those is kind of useless.

 *  (Note also that GameTracker sometimes has to generate events spontaneously (such as when the game abruptly ends); if it does so,

 *  it includes a custom message. Those messages always start with "AUTO:".)</p>

 * 

 *  <p><strong>Catching errors:</strong> you can call addEventListener to listen to GAMETRACKER_SERVER_ERROR and

 *  GAMETRACKER_CODING_ERROR events. This is especially useful during development and testing!</p>

 *

 * <p><strong>It's Auto-Disabled:</strong> GameTracker will automatically detect if it's on FGL's website, and if not,

 *  it will turn itself off. This way you never need to worry about whether it's on or off -- just call the functions. 

 *  If it's off, they won't do anything.</p>

 * 

 *  <p><strong>Timing and Batching</strong></p>

 *  <p>The game tracker's timer is only accurate to a single second. (Although if you have many

 *  events during the same second, they will be recorded in order.) Thus, it's not really designed to

 *  record things that happen very quickly, such as all mouse movement, or other very low-level detail. 

 *  It's intended for use at a slightly higher granularity. (Please don't generate more than about one event per second.)

 *  But even so, you can still send quite a lot of events -- for instance, you can record every time the user clicks any GUI button.</p>

 *

 *  <p>GameTracker batches up the events you log, and sends them to the server every 15 seconds. This saves our 

 *  server from exploding, but there's a down side: since Flash games don't reliably know when they're terminating, it's 

 *  possible to lose the last few seconds of the game messages.</p>

 *

 *  <p>To help alleviate this problem, the endGame() and alert() events are sent immediately. That way you will never lose an alert() due 

 *  to the game ending abruptly. However, that means that if you sent too many alerts you'd bog down our GameTracker server. Please 

 *  don't call alert() more than once every 5	seconds or so, max. If you just want to	record miscellaneous stuff, 

 *  don't use alert(), use customMsg().</p>

 * 

 *  <p>A final note: FGL counts a "session" as one user playing a game nonstop for several minutes.

 *  What this means is that if the user hits F5 to refresh the web page, or leaves and comes back

 *  a minute later, FGL is likely to consider the return as part of the SAME session. This is very   

 *  useful when analyzing how people are using your game. Just be aware of it when looking at the 

 *  results. (Each time the player reloads the webpage, it will be shown as a new game-load in the report.)</p>

 */class GameTracker extends EventDispatcher {
	static public var api(get, never) : GameTracker;

	// you can catch this to get information about errors. It sends a GameTrackerErrorEvent as its event type! That object's _msg param is an English error message
		// FIXME: should be exceptions?
		static public inline var GAMETRACKER_SERVER_ERROR : String = "gametracker_server_error";
	static public inline var GAMETRACKER_CODING_ERROR : String = "gametracker_coding_error";
	// Singleton pattern:
		static var _instance : GameTracker = null;
	static inline var TIMER_DELAY : Int = 15000;
	// please do not go faster than this, FGL's server will asplode
		// Internally used to make backupLastData() possible: updated before recorded
		var _currentScore : Float;
	var _currentGameState : String;
	// Internally used to reduce null data
		var _lastGameState : String;
	var _lastScore : Float;
	/**

	 * @private Creates a GameTracker(). 

	 * Uses JavaScript to initialize itself to FGL's current system parameters.

	 * If the game isn't running on FGL, GameTracker will automatically shut itself off.

	 * You can check to see if it's enabled by calling isEnabled(), but you don't

	 * normally need to care. You can just call the functions assuming it's enabled,

	 * and they'll just do nothing if it's disabled.

	 */	public function new() {
		 super();
		 
		_lastGameState = "";
		_lastScore = 0;
		_timer = null;
		_currentGame = 0;
		_currentLevel = 0;
		_inGame = false;
		_inLevel = false;
		_msg_queue = new Array<Dynamic>();
		_conn = null;
		_responder = null;
		_isEnabled = false;
		_serverVersionMajor = 0;
		_serverVersionMinor = 0;
		_hostUrl = "";
		_serviceName = "";
		_passphrase = "";
		if(_instance == null)  {
			_instance = this;
		}

		else  {
			trace("GameTracker: Instance Error: The GameTracker class is a singleton and should only be constructed once. Use GameTracker.api instead.");
			return;
		}

		setGlobalConfig();
		if(_isEnabled)  {
			_responder = new Responder(onSuccess, onNetworkingError);
			_conn = new NetConnection();
			//_conn.objectEncoding = ObjectEncoding.AMF0;
			_conn.connect(_hostUrl);
			_timer = new Timer(TIMER_DELAY);
			_timer.addEventListener("timer", onTimer);
			_timer.start();
			_sessionID = Math.floor((Date.now().getTime() / 1000));
			addToMsgQueue("begin_app", null, 0, null, null);
		}
	}

	/**

	 * Static reference to the current GameTracker instance

	 */	static public function get_api() : GameTracker {
		if(_instance == null)  {
			trace("GameTracker: Instance Error: Attempted to get instance before initial construction.");
			return null;
		}
		return _instance;
	}

	/**

	 * Indicates that the GameTracker is attempting to send messages to the server

	 * periodically. This does not connote success in actually doing so, however!

	 */	public function isEnabled() : Bool {
		return _isEnabled;
	}

	/**

	 * Returns the most recently-submitted score (for testing/debugging)

	 */	public function getScore() : Float {
		return _currentScore;
	}

	/**

	 * Returns the most recently-submitted score (for testing/debugging)

	 */	public function getGameState() : String {
		return _currentGameState;
	}

	/**

	 * Call at the beginning of the game.

	 */	public function beginGame(?currentScore : Float, ?currentGameState : String = null, ?customMsg : String = null) : Void {
		backupLastData(currentScore, currentGameState);
		if(_inGame)  {
			endGame(_currentScore, _currentGameState, "AUTO:(this game automatically ended when new game was started)");
		}
		_currentGame++;
		_inGame = true;
		addToMsgQueue("begin_game", null, _currentScore, _currentGameState, customMsg);
	}

	/**

	 * Call at the end of the game.

	 * If you fail to call endGame(), the GameTracker attempts to do so for you when you

	 * next call beginGame(), but this isn't as accurate as you doing it yourself.

	 */	public function endGame(currentScore : Float, currentGameState : String = null, customMsg : String = null) : Void {
		backupLastData(currentScore, currentGameState);
		if(!_inGame)  {
			dispatchEvent(new GameTrackerErrorEvent(GAMETRACKER_CODING_ERROR, "endGame() called before beginGame() was called!"));
		}

		else  {
			if(_inLevel)  {
				endLevel(_currentScore, _currentGameState, "AUTO:(this level automatically ended when game ended)");
			}
			addToMsgQueue("end_game", null, _currentScore, _currentGameState, customMsg);
			_inGame = false;
			submitMsgQueue();
		}

	}

	/**

	 * Call when a level begins. You must call this AFTER you'be called beginGame().

	 */	public function beginLevel(newLevel : Int, currentScore : Float, currentGameState : String = null, customMsg : String = null) : Void {
		backupLastData(currentScore, currentGameState);
		if(!_inGame)  {
			dispatchEvent(new GameTrackerErrorEvent(GAMETRACKER_CODING_ERROR, "beginLevel() called before beginGame() was called!"));
		}

		else  {
			if(_inLevel)  {
				endLevel(_currentScore, _currentGameState, "AUTO:(this level automatically ended when new level was started)");
			}
			_currentLevel = newLevel;
			_inLevel = true;
			addToMsgQueue("begin_level", null, _currentScore, _currentGameState, customMsg);
		}

	}

	/**

	 * Call when a level ends. You must call this AFTER you've called beginLevel().

	 * If you fail to call endLevel(), the GameTracker attempts to do so for you when you

	 * next call beginLevel(), but this isn't as accurate as you doing it yourself.

	 */	public function endLevel(currentScore : Float, currentGameState : String = null, customMsg : String = null) : Void {
		backupLastData(currentScore, currentGameState);
		if(!_inLevel)  {
			dispatchEvent(new GameTrackerErrorEvent(GAMETRACKER_CODING_ERROR, "endLevel() called before beginLevel() was called!"));
		}

		else  {
			_inLevel = false;
			addToMsgQueue("end_level", null, _currentScore, _currentGameState, customMsg);
		}

	}

	/**

	 * Call this to denote that the user has reached a checkpoint in the current level.

	 * The exact meaning of what a "checkpoint" is is up to you. Some games like to emit

	 * checkpoint messages every 5 seconds, just to keep track of the user's score. That's okay.

	 * Just don't emit them more than every few seconds! (For our server's sanity.)

	 * 

	 * You can only call checkpoint during a game (that is, after beginGame() has been called).

	 * It can be between levels, though, if you want. Although that's kinda weird.

	 */	public function checkpoint(currentScore : Float, currentGameState : String = null, customMsg : String = null) : Void {
		backupLastData(currentScore, currentGameState);
		if(!_inGame)  {
			dispatchEvent(new GameTrackerErrorEvent(GAMETRACKER_CODING_ERROR, "checkpoint() called before startGame() was called!"));
		}

		else  {
			addToMsgQueue("checkpoint", null, _currentScore, _currentGameState, customMsg);
		}

	}

	/**

        * Call this to point out that something important has happened. You pretty much always want to 

        * provide a customMsg when calling alert(), to indicate what happened. Good example alerts are:

        * 	"The user beat the game!"

        * 	"The user clicked on the instructions link"

        * 	"The game hit a fatal exception!"

        * 	"The user found the secret level!"

        * 

        * Alerts are often very important to your analysis, so they are sent immediately to the server.

        * For this reason, please don't overuse alerts. If you want to send notices every few seconds, use

        * checkpoint() or customMsg().

        */	public function alert(customMsg : String = null, currentScore : Float, currentGameState : String = null) : Void {
		backupLastData(currentScore, currentGameState);
		addToMsgQueue("alert", null, _currentScore, _currentGameState, customMsg);
		submitMsgQueue();
	}

	/**

        * Send a message meaning whatever you want it to mean. The "msgType" parameter must not be more than

        * 20 characters long. Please don't send these more than say once per second on average minute.

        * (For our server's sanity.)

        */	public function customMsg(customMsg : String = null, msgType : String = "custom", currentScore : Float, currentGameState : String = null) : Void {
		backupLastData(currentScore, currentGameState);
		addToMsgQueue("custom", msgType, _currentScore, _currentGameState, customMsg);
	}

	function addToMsgQueue(action : String, subaction : String, score : Float, gamestate : String, custom_msg : String) : Void {
		if(_isEnabled)  {
			var msg : Dynamic = {};
			Reflect.setField(msg, "action", action);
			Reflect.setField(msg, "custom_action", subaction);
			Reflect.setField(msg, "session_id", _sessionID);
			Reflect.setField(msg, "game_idx", _currentGame);
			Reflect.setField(msg, "level", _currentLevel);
			Reflect.setField(msg, "score", score);
			Reflect.setField(msg, "game_state", gamestate);
			Reflect.setField(msg, "time", Math.floor((Date.now().getTime() / 1000)));
			Reflect.setField(msg, "msg", custom_msg);
			_msg_queue.push(msg);
		}
	}

	function submitMsgQueue() : Void {
		if(_isEnabled && _msg_queue.length > 0)  {
			var obj : Dynamic = {};
			Reflect.setField(obj, "actions", _msg_queue);
			Reflect.setField(obj, "identifier", _passphrase);
			//_conn.call(_serviceName, _responder, _passphrase, obj);
			_conn.call(_serviceName, _responder, obj);
			_msg_queue = new Array<Dynamic>();
		}
	}

	/**

	 * Record the currentScore and currentGameState if the developer reported them

	 */	function backupLastData(currentScore : Float, currentGameState : String) : Void {
		// null is used here in place of null
		if(Math.isNaN(currentScore))  {
			currentScore = _lastScore;
		}

		else  {
			_lastScore = currentScore;
		}
;
		_currentScore = currentScore;
		if(currentGameState != null)  {
			_lastGameState = "lastState : " + currentGameState;
		}

		else  {
			currentGameState = _lastGameState;
		}

		_currentGameState = currentGameState;
	}

	// the timer that reminds us to submit the message queue
		var _timer : Timer;
	// the current "indices" for things like game number
		var _currentGame : Int;
	var _currentLevel : Int;
	var _inGame : Bool;
	var _inLevel : Bool;
	// the queue of pending events that have not been sent to the server yet
		var _msg_queue : Array<Dynamic>;
	// networking vars set up by constructor
		var _conn : NetConnection;
	var _responder : Responder;
	var _sessionID : UInt;
	// vars set by setGlobalConfig()
		var _isEnabled : Bool;
	var _serverVersionMajor : Int;
	var _serverVersionMinor : Int;
	var _hostUrl : String;
	var _serviceName : String;
	var _passphrase : String;
	function setGlobalConfig() : Void {
		// this function calls a JavaScript function on the hosting page
		// to retrieve a bunch of setting data.
		// If that function can't be called or doesn't exist, or if the
		// function indicates that the major version isn't what was expected,
		// then it disables itself.
		_isEnabled = false;
		_serverVersionMajor = 0;
		_serverVersionMinor = 0;
		_hostUrl = "";
		_serviceName = "";
		_passphrase = "";
		try {
			if(ExternalInterface.available)  {
				var ret : Array<Dynamic> = ExternalInterface.call("get_gametracker_info");
				_serverVersionMajor = ret[0];
				_serverVersionMinor = ret[1];
				_hostUrl = ret[2];
				_serviceName = ret[3];
				_passphrase = ret[4];
				_isEnabled = (_serverVersionMajor == 1);
			}
		}
		catch(e : Dynamic){ };
	}

	function onSuccess(evt : Dynamic) : Void {
		if(evt.toString() != "")  {
			dispatchEvent(new GameTrackerErrorEvent(GAMETRACKER_SERVER_ERROR, evt.toString()));
		}
	}

	function onNetworkingError(evt : Dynamic) : Void {
		dispatchEvent(new GameTrackerErrorEvent(GAMETRACKER_SERVER_ERROR, "Networking error"));
	}

	function onTimer(evt : TimerEvent) : Void {
		submitMsgQueue();
	}

}

