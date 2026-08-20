package vault.navigation;

private class Vector {
	public var x:Float;
	public var y:Float;
	public var z:Float;

	public inline function new(x:Float = 0.0, y:Float = 0.0, z:Float = 0.0) {
		this.x = x;
		this.y = y;
		this.z = z;
	}
}

@:access(vault.navigation)
class Path {
	public var length(default, null):Int;
	public var pathfinder(default, null):Pathfinder;
	public var version(default, null):Int;
	public var smoothed(default, null):Bool;

	var smoothPositions:StructOfVectors<Vector>;
	var nodes:haxe.ds.Vector<NodeHandle>;

	public function new(capacity:Int) {
		if (capacity < 1) {
			throw 'Capacity must not be less than 1';
		}
		nodes = new haxe.ds.Vector(capacity);
		smoothPositions = new StructOfVectors<Vector>(capacity);
	}

	public function smooth(smoothFactor:Float = 0.5):Bool {
		if (length < 1 || smoothed) {
			return false;
		}
		inline function lerp(a:Float, b:Float, k:Float):Float {
			return a + k * (b - a);
		}
		var firstNode = nodes[0];
		var firstNodeIndex = firstNode.index;
		var lastNode = nodes[length - 1];
		var lastNodeIndex = lastNode.index;
		smoothPositions.x[0] = pathfinder.nodes.x[firstNodeIndex];
		smoothPositions.y[0] = pathfinder.nodes.y[firstNodeIndex];
		smoothPositions.z[0] = pathfinder.nodes.z[firstNodeIndex];
		smoothPositions.x[length - 1] = pathfinder.nodes.x[lastNodeIndex];
		smoothPositions.y[length - 1] = pathfinder.nodes.y[lastNodeIndex];
		smoothPositions.z[length - 1] = pathfinder.nodes.z[lastNodeIndex];
		for (i in 1...length - 1) {
			var currentNode = nodes[i];
			var currentNodeIndex = currentNode.index;
			var nextNode = nodes[i + 1];
			var nextNodeIndex = nextNode.index;
			var previousNode = nodes[i - 1];
			var previousNodeIndex = previousNode.index;
			var point = new Vector(pathfinder.nodes.x[currentNodeIndex], pathfinder.nodes.y[currentNodeIndex], pathfinder.nodes.z[currentNodeIndex]);
			var nextPoint = new Vector(pathfinder.nodes.x[nextNodeIndex], pathfinder.nodes.y[nextNodeIndex], pathfinder.nodes.z[nextNodeIndex]);
			var previousPoint = new Vector(pathfinder.nodes.x[previousNodeIndex], pathfinder.nodes.y[previousNodeIndex], pathfinder.nodes.z[previousNodeIndex]);
			smoothPositions.x[i] = point.x = lerp(point.x, lerp(previousPoint.x, nextPoint.x, 0.5), smoothFactor);
			smoothPositions.y[i] = point.y = lerp(point.y, lerp(previousPoint.y, nextPoint.y, 0.5), smoothFactor);
			smoothPositions.z[i] = point.z = lerp(point.z, lerp(previousPoint.z, nextPoint.z, 0.5), smoothFactor);
		}
		return smoothed = true;
	}

	public inline function getNode(offset:Int = 0):Node {
		var node = new Node();
		if (length >= 1) {
			var localIndex = (length - 1) - offset;
			var nodeHandle = nodes[localIndex];
			var nodeIndex = nodeHandle.index;
			var nodeGeneration = nodeHandle.generation;
			if (!pathfinder.nodes.freed[nodeIndex] && pathfinder.nodes.generation[nodeIndex] == nodeGeneration) {
				if (smoothed) {
					node.x = smoothPositions.x[localIndex];
					node.y = smoothPositions.y[localIndex];
					node.z = smoothPositions.z[localIndex];
				} else {
					node.x = pathfinder.nodes.x[nodeIndex];
					node.y = pathfinder.nodes.y[nodeIndex];
					node.z = pathfinder.nodes.z[nodeIndex];
				}
				node.flags = pathfinder.nodes.flags[nodeIndex];
				node.weight = pathfinder.nodes.weight[nodeIndex];
				node.connectionCount = pathfinder.nodes.connectionCount[nodeIndex];
			}
		}
		return node;
	}

	public inline function clear() {
		length = 0;
	}

	public inline function calculateTotalDistance():Float {
		if (nodes.length <= 1) {
			return 0.0;
		}

		var d = 0.0;
		for (i in 0...nodes.length - 1) {
			var currentNode = nodes[i];
			var currentNodeIndex = currentNode.index;
			var nextNode = nodes[i + 1];
			var nextNodeIndex = nextNode.index;
			var dx = pathfinder.nodes.x[currentNodeIndex] - pathfinder.nodes.x[nextNodeIndex];
			var dy = pathfinder.nodes.y[currentNodeIndex] - pathfinder.nodes.y[nextNodeIndex];
			var dz = pathfinder.nodes.z[currentNodeIndex] - pathfinder.nodes.z[nextNodeIndex];
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
			var currentNode = nodes[i];
			var currentNodeIndex = currentNode.index;
			var nextNode = nodes[i + 1];
			var nextNodeIndex = nextNode.index;
			var dx = pathfinder.nodes.x[currentNodeIndex] - pathfinder.nodes.x[nextNodeIndex];
			var dy = pathfinder.nodes.y[currentNodeIndex] - pathfinder.nodes.y[nextNodeIndex];
			var dz = pathfinder.nodes.z[currentNodeIndex] - pathfinder.nodes.z[nextNodeIndex];
			d += dx * dx + dy * dy + dz * dz;
		}

		return d;
	}
}
