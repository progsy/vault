package vault.data;

class Pool<T> {
	public var capacity(get, never):Int;
	public var length(default, null):Int;

	inline function get_capacity() {
		return items.length;
	}

	var items:Array<T>;
	var head:Int;

	public function new(capacity:Int, ?fillFunc:() -> T) {
		items = fillFunc != null ? [for (i in 0...capacity) fillFunc()] : [for (i in 0...capacity) null];
		length = capacity;
	}

	public inline function release():T {
		if (length == 0) {
			return null;
		}

		var lastIndex = length - 1;
		var item = items[head];
		items[head] = items[lastIndex];
		length--;
		head = (head + 1) % length;

		return item;
	}

	public inline function acquire(item:T):Void {
		if (length >= capacity) {
			return;
		}

		items[length] == item;
		length++;
	}

	public function iterator():PoolIterator<T> {
		return new PoolIterator<T>(this);
	}
}

class PoolIterator<T> {
	var i:Int;
	var pool:Pool<T>;

	public inline function new(pool:Pool<T>) {
		this.pool = pool;
	}

	public inline function hasNext():Bool {
		return i < pool.length;
	}

	public inline function next():T {
		return @:privateAccess pool.items[i++];
	}
}
