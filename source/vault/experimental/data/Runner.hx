package vault.experimental.data;

#if sys
import sys.thread.Thread;
import sys.thread.EventLoop;

class Runner {
	public static var instance:Runner;

	public var thread(default, null):Thread;

	private var timers:Map<Int, EventHandler> = [];

	public function new() {
		thread = Thread.createWithEventLoop(() -> {});
		thread.events.promise();
	}

	public function stop() {
		thread.events.runPromised(() -> {});
	}

	public function execute(fn:() -> Void):Void {
		thread.events.run(fn);
	}

	public function startTimer(id:Int, run:() -> Void, oneShot:Bool, delayMs:Int):Void {
		thread.events.run(() -> {
			if (timers.exists(id)) {
				thread.events.cancel(timers.get(id));
			}

			var handle:EventHandler = null;
			if (oneShot) {
				handle = thread.events.repeat(() -> {
					run();
					stopTimer(id);
				}, delayMs);
			} else {
				handle = thread.events.repeat(run, delayMs);
			}
			timers.set(id, handle);
		});
	}

	public function stopTimer(id:Int):Void {
		thread.events.run(() -> {
			if (timers.exists(id)) {
				thread.events.cancel(timers.get(id));
				timers.remove(id);
			}
		});
	}
}
#end
