package vault.experimental.navigation;

@:access(vault.experimental.navigation)
class Path {
	public var length(default, null):Int;
	public var pathfinder(default, null):Pathfinder;
	public var version(default, null):Int;

	var nodes:haxe.ds.Vector<NodeHandle>;

	public function new(capacity:Int) {
		if (capacity < 1) {
			throw 'Capacity must not be less than 1';
		}
		nodes = new haxe.ds.Vector(capacity);
		#if heaps
		smoothPositions = new StructOfVectors<h3d.Vector>(capacity);
		#end
	}

	#if heaps
	public var smoothFactor:Float = 0.5;

	var smoothPositions(default, null):StructOfVectors<h3d.Vector>;

	public function smooth() {
		if (length < 1) {
			return;
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
			var point = new h3d.Vector(pathfinder.nodes.x[currentNodeIndex], pathfinder.nodes.y[currentNodeIndex], pathfinder.nodes.z[currentNodeIndex]);
			var nextPoint = new h3d.Vector(pathfinder.nodes.x[nextNodeIndex], pathfinder.nodes.y[nextNodeIndex], pathfinder.nodes.z[nextNodeIndex]);
			var previousPoint = new h3d.Vector(pathfinder.nodes.x[previousNodeIndex], pathfinder.nodes.y[previousNodeIndex],
				pathfinder.nodes.z[previousNodeIndex]);
			var midPoint = new h3d.Vector();
			midPoint.lerp(previousPoint, nextPoint, 0.5);
			point.lerp(point, midPoint, smoothFactor);
			smoothPositions.x[i] = point.x;
			smoothPositions.y[i] = point.y;
			smoothPositions.z[i] = point.z;
		}
	}
	#end

	public inline function getNode(offset:Int = 0):Node {
		var node = new Node();
		if (length >= 1) {
			var localIndex = (length - 1) - offset;
			var nodeHandle = nodes[localIndex];
			var nodeIndex = nodeHandle.index;
			var nodeGeneration = nodeHandle.generation;
			if (!pathfinder.nodes.freed[nodeIndex] && pathfinder.nodes.generation[nodeIndex] == nodeGeneration) {
				#if heaps
				node.x = smoothPositions.x[localIndex];
				node.y = smoothPositions.y[localIndex];
				node.z = smoothPositions.z[localIndex];
				#else
				node.x = pathfinder.nodes.x[nodeIndex];
				node.y = pathfinder.nodes.y[nodeIndex];
				node.z = pathfinder.nodes.z[nodeIndex];
				#end
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

	public inline function pop() {
		return --length;
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
