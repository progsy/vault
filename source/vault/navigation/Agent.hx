package vault.navigation;

enum abstract UpdateResult(Int) {
	var OnGoing = 1;
	var NodePassed;
	var ReachedDestination;
	var Blocked;
}

class Agent {
	public var x(default, null):Float;
	public var y(default, null):Float;
	public var z(default, null):Float;
	public var headingX(default, null):Float;
	public var headingY(default, null):Float;
	public var headingZ(default, null):Float;
	public var path(default, set):Path;
	public var followFlags:Int;
	public var avoidFlags:Int;

	var nodeOffset:Int;
	var version:Int;

	public function new(path:Path, followFlags:Int = 0xFFFFFFFF, avoidFlags:Int = 0) {
		this.path = path;
		this.followFlags = followFlags;
		this.avoidFlags = avoidFlags;
	}

	inline function set_path(v) {
		path = v;
		if (path != null) {
			reset();
		}
		return path;
	}

	public inline function reset() {
		var node = path.getNode();
		headingX = node.x;
		headingY = node.y;
		headingZ = node.z;
		nodeOffset = 0;
		version = path.version;
	}

	public function update(x:Float, y:Float, z:Float, passDistance:Float = 0.15):UpdateResult {
		this.x = x;
		this.y = y;
		this.z = z;

		if (version != path.version) {
			reset();
		}
		if (nodeOffset >= path.length) {
			return ReachedDestination;
		}

		var node = path.getNode(nodeOffset);
		if (node.flags & avoidFlags != 0 || node.flags & followFlags == 0) {
			return Blocked;
		}

		var dx = node.x - x;
		var dy = node.y - y;
		var dz = node.z - z;
		var distance = dx * dx + dy * dy + dz * dz;
		if (distance <= passDistance * passDistance) {
			if (++nodeOffset >= path.length) {
				return ReachedDestination;
			}
			var nextNode = path.getNode(nodeOffset);
			headingX = nextNode.x;
			headingY = nextNode.y;
			headingZ = nextNode.z;
			return NodePassed;
		}
		return OnGoing;
	}
}
