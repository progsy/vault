package vault.behavior;

// TODO: Create a dedicated macro builder instead.
#if !macro
@:genericBuild(vault.macro.TypeDispatcher.build("Signal"))
#end
class Signal<Rest> {}

class Signal0 {
	var handles:Array<() -> Void> = [];
	var signals:Array<Signal0> = [];

	public function new() {}

	public extern inline overload function connect(func:() -> Void):Bool {
		if (!handles.contains(func)) {
			handles.push(func);
			return true;
		}
		return false;
	}

	public extern inline overload function connect(signal:Signal0):Bool {
		if (!signals.contains(signal)) {
			signals.push(signal);
			return true;
		}
		return false;
	}

	public extern inline overload function disconnect(func:() -> Void):Bool {
		return handles.remove(func);
	}

	public extern inline overload function disconnect(signal:Signal0):Bool {
		return signals.remove(signal);
	}

	public extern inline overload function hasConnection(func:() -> Void):Bool {
		return handles.contains(func);
	}

	public extern inline overload function hasConnection(signal:Signal0):Bool {
		return signals.contains(signal);
	}

	public inline function clear(deep:Bool = true):Void {
		handles.resize(0);
		if (deep) {
			signals.resize(0);
		}
	}

	public inline function emit(deep:Bool = true):Void {
		for (handle in handles) {
			handle();
		}
		if (deep) {
			for (signal in signals) {
				signal.emit(deep);
			}
		}
	}
}

class Signal1<T> {
	var handles:Array<(T) -> Void> = [];
	var signals:Array<Signal1<T>> = [];

	public function new() {}

	public extern inline overload function connect(func:(T) -> Void):Bool {
		if (!handles.contains(func)) {
			handles.push(func);
			return true;
		}
		return false;
	}

	public extern inline overload function connect(signal:Signal1<T>):Bool {
		if (!signals.contains(signal)) {
			signals.push(signal);
			return true;
		}
		return false;
	}

	public extern inline overload function disconnect(func:(T) -> Void):Bool {
		return handles.remove(func);
	}

	public extern inline overload function disconnect(signal:Signal1<T>):Bool {
		return signals.remove(signal);
	}

	public extern inline overload function hasConnection(func:(T) -> Void):Bool {
		return handles.contains(func);
	}

	public extern inline overload function hasConnection(signal:Signal1<T>):Bool {
		return signals.contains(signal);
	}

	public inline function clear(deep:Bool = true):Void {
		handles.resize(0);
		if (deep) {
			signals.resize(0);
		}
	}

	public inline function emit(arg1:T, deep:Bool = true):Void {
		for (handle in handles) {
			handle(arg1);
		}
		if (deep) {
			for (signal in signals) {
				signal.emit(arg1, deep);
			}
		}
	}
}

class Signal2<T1, T2> {
	var handles:Array<(T1, T2) -> Void> = [];
	var signals:Array<Signal2<T1, T2>> = [];

	public function new() {}

	public extern inline overload function connect(func:(T1, T2) -> Void):Bool {
		if (!handles.contains(func)) {
			handles.push(func);
			return true;
		}
		return false;
	}

	public extern inline overload function connect(signal:Signal2<T1, T2>):Bool {
		if (!signals.contains(signal)) {
			signals.push(signal);
			return true;
		}
		return false;
	}

	public extern inline overload function disconnect(func:(T1, T2) -> Void):Bool {
		return handles.remove(func);
	}

	public extern inline overload function disconnect(signal:Signal2<T1, T2>):Bool {
		return signals.remove(signal);
	}

	public extern inline overload function hasConnection(func:(T1, T2) -> Void):Bool {
		return handles.contains(func);
	}

	public extern inline overload function hasConnection(signal:Signal2<T1, T2>):Bool {
		return signals.contains(signal);
	}

	public inline function clear(deep:Bool = true):Void {
		handles.resize(0);
		if (deep) {
			signals.resize(0);
		}
	}

	public inline function emit(arg1:T1, arg2:T2, deep:Bool = true):Void {
		for (handle in handles) {
			handle(arg1, arg2);
		}
		if (deep) {
			for (signal in signals) {
				signal.emit(arg1, arg2, deep);
			}
		}
	}
}

class Signal3<T1, T2, T3> {
	var handles:Array<(T1, T2, T3) -> Void> = [];
	var signals:Array<Signal3<T1, T2, T3>> = [];

	public function new() {}

	public extern inline overload function connect(func:(T1, T2, T3) -> Void):Bool {
		if (!handles.contains(func)) {
			handles.push(func);
			return true;
		}
		return false;
	}

	public extern inline overload function connect(signal:Signal3<T1, T2, T3>):Bool {
		if (!signals.contains(signal)) {
			signals.push(signal);
			return true;
		}
		return false;
	}

	public extern inline overload function disconnect(func:(T1, T2, T3) -> Void):Bool {
		return handles.remove(func);
	}

	public extern inline overload function disconnect(signal:Signal3<T1, T2, T3>):Bool {
		return signals.remove(signal);
	}

	public extern inline overload function hasConnection(func:(T1, T2, T3) -> Void):Bool {
		return handles.contains(func);
	}

	public extern inline overload function hasConnection(signal:Signal3<T1, T2, T3>):Bool {
		return signals.contains(signal);
	}

	public inline function clear(deep:Bool = true):Void {
		handles.resize(0);
		if (deep) {
			signals.resize(0);
		}
	}

	public inline function emit(arg1:T1, arg2:T2, arg3:T3, deep:Bool = true):Void {
		for (handle in handles) {
			handle(arg1, arg2, arg3);
		}
		if (deep) {
			for (signal in signals) {
				signal.emit(arg1, arg2, arg3, deep);
			}
		}
	}
}
