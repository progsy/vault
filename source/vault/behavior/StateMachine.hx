package vault.behavior;

class StateMachine<E:EnumValue> {
	public var currentState(default, null):E;
	public var stateChangeSignal(default, null) = new Signal<E, E>();

	var transitions:Array<haxe.EnumFlags<E>> = [for (i in 0...32) new haxe.EnumFlags(0)];

	public inline function new() {}

	public inline function toggleTransition(from:E, to:E, toggle:Bool, symmetric:Bool = false):Void {
		var index = Type.enumIndex(from);
		if (toggle) {
			transitions[index].set(to);
		} else {
			transitions[index].unset(to);
		}
		if (symmetric) {
			toggleTransition(to, from, toggle, false);
		}
	}

	public inline function hasTransition(from:E, to:E):Bool {
		var index = Type.enumIndex(from);
		return transitions[index].has(to);
	}

	public function dispatch(state:E):Bool {
		if (currentState != null) {
			var index = Type.enumIndex(currentState);
			if (transitions[index].has(state)) {
				stateChangeSignal.emit(currentState, state);
				currentState = state;
				return true;
			}
		} else {
			stateChangeSignal.emit(currentState, state);
			currentState = state;
			return true;
		}
		return false;
	}
}
