package vault.experimental.navigation;

class Path {
	public var length(default, null):Int;
	public var nodes(default, null):haxe.ds.Vector<Int>;
	public var pathfinder(default, null):Pathfinder;

	public function new(capacity:Int) {
		if (capacity < 1) {
			throw 'Capacity must not be less than 1';
		}
		nodes = new haxe.ds.Vector(capacity);
	}

	public inline function clear() {
		length = 0;
	}

	public inline function pop() {
		return --length;
	}

	public inline function calculateTotalDistance():Float {
		if (nodes.length <= 1) {
			return 0.0;
		}

		var d = 0.0;
		for (i in 0...nodes.length - 1) {
			var dx = pathfinder.nodes.x[nodes[i]] - pathfinder.nodes.x[nodes[i + 1]];
			var dy = pathfinder.nodes.y[nodes[i]] - pathfinder.nodes.y[nodes[i + 1]];
			var dz = pathfinder.nodes.z[nodes[i]] - pathfinder.nodes.z[nodes[i + 1]];
			d += Math.sqrt(dx * dx + dy * dy + dz * dz);
		}

		return d;
	}

	public inline function calculateTotalDistanceSq():Float {
		if (nodes.length <= 1) {
			return 0.0;
		}

		var d = 0.0;
		for (i in 0...nodes.length - 1) {
			var dx = pathfinder.nodes.x[nodes[i]] - pathfinder.nodes.x[nodes[i + 1]];
			var dy = pathfinder.nodes.y[nodes[i]] - pathfinder.nodes.y[nodes[i + 1]];
			var dz = pathfinder.nodes.z[nodes[i]] - pathfinder.nodes.z[nodes[i + 1]];
			d += dx * dx + dy * dy + dz * dz;
		}

		return d;
	}
}
