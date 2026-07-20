package vault.experimental.data;

private class Cargo<T> {
	public var value:T;
	public var duration:Int;
	#if sys
	@:optional public var id:Int;
	#else
	@:optional public var timer:haxe.Timer;
	#end
}

class Train<T> {
	#if sys
	static var idStride:Int = 0xFFFFFF;
	static var nextID:Int = idStride;

	public var runner(default, null):Runner;
	#end
	public var current(default, null):T;
	public var running(default, null):Bool;
	public var cargos(default, null):StructOfVectors<Cargo<T>>;

	public function run() {
		if (cargos.length > 0) {
			var value = cargos.value[0];
			var duration = cargos.duration[0];
			running = true;
			cargos.shift();

			#if sys
			runner.startTimer(nextID, () -> {
				current = value;
				run();
			}, true, duration);
			nextID++;
			#else
			var timer = new haxe.Timer(duration);
			timer.run = () -> {
				current = value;
				run();
			};
			cargos.push(timer, duration);
			#end
		} else {
			running = false;
		}
	}

	public function stop() {
		for (i in 0...cargos.length) {
			#if sys
			runner.stopTimer(cargos.id[i]);
			#else
			cargos.timer[i].stop();
			#end
		}
		cargos.clear();
		running = false;
	}

	public function new(initialValue:T, stackCapacity:Int = 16 #if sys, ?runner:Runner #end) @:bypassAccessor {
		current = initialValue;
		cargos = new StructOfVectors<Cargo<T>>(stackCapacity);
		#if sys
		if (runner != null) {
			this.runner = runner;
		} else {
			if (Runner.instance == null) {
				Runner.instance = new Runner();
			}
			this.runner = Runner.instance;
		}
		#end
	}
}
