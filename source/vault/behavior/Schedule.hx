package vault.behavior;

class Task<C> {
	public var func:(C, Float) -> Bool;
	public var delay:Float = 0.0;
	public var runtime:Float = -1.0;
	public var repeat:Int = 1;
	@:optional public var name:String = "";
	@:optional public var startSignal:Signal = null;
	@:optional public var finishSignal:Signal = null;
}

class Schedule<C> {
	public var context:C;
	public var finished(get, never):Bool;
	public var tasks(default, null):StructOfVectors<Task<C>>;
	public var taskStartSignal(default, null):Signal<Schedule<C>> = new Signal<Schedule<C>>();
	public var taskFinishSignal(default, null):Signal<Schedule<C>> = new Signal<Schedule<C>>();

	var index:Int;
	var currentElapsedTime:Float;

	inline function get_finished() {
		return index == -1;
	}

	public inline function new(context:C, capacity:Int = 16) {
		this.context = context;
		tasks = new StructOfVectors<Task<C>>(capacity);
	}

	public inline function restart():Void {
		index = 0;
	}

	public function update(dt:Float):Void {
		if (tasks.length > index) {
			if (tasks.func[index] != null) {
				if (currentElapsedTime <= 0.0) {
					taskStartSignal.emit(this);
				}
				currentElapsedTime += dt;
				if (currentElapsedTime >= tasks.delay[index]) {
					if (tasks.func[index](context, dt) || (currentElapsedTime >= tasks.runtime[index] && tasks.runtime[index] > 0.0)) {
						taskFinishSignal.emit(this);
						currentElapsedTime = 0.0;
						tasks.repeat[index]--;
						if (tasks.repeat[index] < 0) {
							index++;
							if (index == tasks.length) {
								index = -1;
							}
						}
					}
				}
			}
		}
	}
}
