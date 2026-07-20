package vault.behavior;

class Process {
	public var startSignal(default, null):Signal<Process> = new Signal<Process>();
	public var endSignal(default, null):Signal<Process> = new Signal<Process>();
	public var started(default, null):Bool = false;
	public var subProcesses(default, null):Array<Process> = [];

	public function new() {}

	public function start():Void {
		if (started) {
			return;
		}

		for (process in subProcesses) {
			process.start();
		}
		startSignal.emit(this);
	}

	public function end():Void {
		if (!started) {
			return;
		}

		for (process in subProcesses) {
			process.end();
		}
		endSignal.emit(this);
	}
}
