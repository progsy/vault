package vault.experimental.navigation;

enum abstract PathMode(Int) {
	var Normal = 1;
	var ClosestPossible;
}

private class ConnectionData {
	public var target:NodeHandle;
	public var distance:Float;
}

private class ValidationData {
	@:ignore public var freed:Bool = false;
	@:ignore public var generation:Int = 0;
}

private class SearchData {
	@:ignore public var gScore:Float;
	@:ignore public var fScore:Float;
	@:ignore public var parent:NodeHandle;
	@:ignore public var searchId:Int = -1;
	@:ignore public var closedId:Int = -1;
	@:ignore public var heapIndex:Int = -1;
}

@:access(vault.experimental.navigation)
class Pathfinder {
	public static var spatialMapCellInvSize:Float = 1 / 2.5;

	public var connectionsPerNode(default, null):Int;

	var nodes:vault.data.StructOfVectors<Node, ValidationData, SearchData>;
	var connections:vault.data.StructOfVectors<ConnectionData>;
	var currentId:Int;
	var heap:Array<NodeHandle> = [];
	var heapSize:Int;
	var spatialMap:Map<Int, Array<NodeHandle>> = [];

	static inline function hash(x:Float, y:Float, z:Float) {
		var ix = Std.int(x * spatialMapCellInvSize);
		var iy = Std.int(y * spatialMapCellInvSize);
		var iz = Std.int(z * spatialMapCellInvSize);
		return (ix << 20) | (iy << 8) | (iz);
	}

	public inline function new(maxNodes:Int, connectionsPerNode:Int = 12) {
		nodes = new vault.data.StructOfVectors<Node, ValidationData, SearchData>(maxNodes);
		connections = new vault.data.StructOfVectors<ConnectionData>(maxNodes * connectionsPerNode);
		this.connectionsPerNode = connectionsPerNode;
	}

	public inline function getNodeHandle(index:Int):NodeHandle {
		return new NodeHandle(index, nodes.generation[index]);
	}

	public function createNode(x:Float, y:Float, z:Float, flags:Int, weight:Float):NodeHandle {
		var node:NodeHandle = NodeHandle.INVALID;
		if (nodes.length + 1 < node.index) {
			var index = nodes.push(x, y, z, flags, weight);
			node.index = index;
			node.generation = ++nodes.generation[index];
			nodes.freed[index] = false;

			var key = hash(x, y, z);
			var cell = spatialMap.get(key);
			if (cell == null) {
				cell = [];
				spatialMap.set(key, cell);
			}
			cell.push(node);
		}
		return node;
	}

	public function destroyNode(node:NodeHandle):Bool {
		var nodeIndex = node.index;
		if (node == NodeHandle.INVALID) {
			return false;
		}
		if (node.generation != nodes.generation[nodeIndex]) {
			return false;
		}

		nodes.removeAt(nodeIndex);
		nodes.freed[nodeIndex] = true;

		var key = hash(nodes.x[nodeIndex], nodes.x[nodeIndex], nodes.x[nodeIndex]);
		var cell = spatialMap.get(key);
		if (cell != null) {
			var targetIndex = cell.indexOf(node);
			if (cell.length > 0 && targetIndex != -1) {
				cell[targetIndex] = cell.pop();
			}
		}
		return true;
	}

	public function connectNodes(nodeA:NodeHandle, nodeB:NodeHandle):Void {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		if (nodeA == NodeHandle.INVALID || nodeB == NodeHandle.INVALID) {
			return;
		}
		if (nodes.freed[nodeAIndex]
			|| nodes.freed[nodeBIndex]
			|| nodeA.generation != nodes.generation[nodeAIndex]
			|| nodeB.generation != nodes.generation[nodeBIndex]) {
			return;
		}

		if (nodes.connectionCount[nodeAIndex] < connectionsPerNode) {
			var connectionStartIndex = (nodeAIndex * connectionsPerNode);
			var lastConnectionIndex = connectionStartIndex + nodes.connectionCount[nodeAIndex];
			connections.target[lastConnectionIndex] = nodeB;
			connections.distance[lastConnectionIndex] = estimate(nodeA, nodeB);
			nodes.connectionCount[nodeAIndex]++;
		}
	}

	public function disconnectNodes(nodeA:NodeHandle, nodeB:NodeHandle):Void {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		if (nodeA == NodeHandle.INVALID || nodeB == NodeHandle.INVALID) {
			return;
		}
		if (nodes.freed[nodeAIndex]
			|| nodes.freed[nodeBIndex]
			|| nodeA.generation != nodes.generation[nodeAIndex]
			|| nodeB.generation != nodes.generation[nodeBIndex]) {
			return;
		}

		var connectionStartIndex = (nodeAIndex * connectionsPerNode);
		var count = nodes.connectionCount[nodeAIndex];
		for (i in connectionStartIndex...connectionStartIndex + count) {
			if (connections.target[i] == nodeB) {
				var lastIndex = connectionStartIndex + count - 1;
				connections.target[i] = connections.target[lastIndex];
				connections.distance[i] = connections.distance[lastIndex];
				connections.target[lastIndex] = NodeHandle.INVALID;
				nodes.connectionCount[nodeAIndex]--;
			}
		}
	}

	public function hasConnection(nodeA:NodeHandle, nodeB:NodeHandle):Bool {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		if (nodeA == NodeHandle.INVALID || nodeB == NodeHandle.INVALID) {
			return false;
		}
		if (nodes.freed[nodeAIndex]
			|| nodes.freed[nodeBIndex]
			|| nodeA.generation != nodes.generation[nodeAIndex]
			|| nodeB.generation != nodes.generation[nodeBIndex]) {
			return false;
		}

		var connectionStartIndex = (nodeAIndex * connectionsPerNode);
		var count = nodes.connectionCount[nodeAIndex];
		for (i in connectionStartIndex...connectionStartIndex + count) {
			if (connections.target[i] == nodeB) {
				return true;
			}
		}
		return false;
	}

	public inline function setNodeFlags(node:NodeHandle, flags:Int):Void {
		if (node != NodeHandle.INVALID) {
			var nodeIndex = node.index;
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				nodes.flags[nodeIndex] = flags;
			}
		}
	}

	public inline function getNodeFlags(node:NodeHandle):Int {
		var nodeIndex = node.index;
		var flags = 0;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				flags = nodes.flags[nodeIndex];
			}
		}
		return flags;
	}

	public inline function setNodeWeight(node:NodeHandle, weight:Float):Void {
		var nodeIndex = node.index;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				nodes.weight[nodeIndex] = weight;
			}
		}
	}

	public inline function getNodeWeight(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var weight = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				weight = nodes.weight[nodeIndex];
			}
		}
		return weight;
	}

	public inline function getNodeX(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var x = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				x = nodes.x[nodeIndex];
			}
		}
		return x;
	}

	public inline function getNodeY(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var y = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				y = nodes.y[nodeIndex];
			}
		}
		return y;
	}

	public inline function getNodeZ(node:NodeHandle):Float {
		var nodeIndex = node.index;
		var z = Math.NaN;
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				z = nodes.z[nodeIndex];
			}
		}
		return z;
	}

	#if heaps
	public inline function getNodePosition(node:NodeHandle):h3d.Vector {
		var nodeIndex = node.index;
		var position = new h3d.Vector(Math.NaN, Math.NaN, Math.NaN);
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				position.set(nodes.x[nodeIndex], nodes.y[nodeIndex], nodes.z[nodeIndex]);
			}
		}
		return position;
	}
	#elseif hxmath
	public inline function getNodePosition(node:NodeHandle):hxmath.math.Vector3 {
		var nodeIndex = node.index;
		var position = new hxmath.math.Vector3(Math.NaN, Math.NaN, Math.NaN);
		if (node != NodeHandle.INVALID) {
			if (!nodes.freed[nodeIndex] && node.generation == nodes.generation[nodeIndex]) {
				position.set(nodes.x[nodeIndex], nodes.y[nodeIndex], nodes.z[nodeIndex]);
			}
		}
		return position;
	}
	#end

	public function clear() {
		for (i in 0...nodes.length) {
			nodes.freed[i] = false;
			nodes.connectionCount[i] = 0;
			nodes.searchId[i] = -1;
			nodes.closedId[i] = -1;
			nodes.heapIndex[i] = -1;
		}
		for (cell in spatialMap) {
			cell.resize(0);
		}
		currentId = 0;
		heapSize = 0;
	}

	function track(path:Path, mode:PathMode, flags:Int, start:NodeHandle, end:NodeHandle):Void {
		var startIndex = start.index;
		var endIndex = end.index;
		if (start == NodeHandle.INVALID || end == NodeHandle.INVALID) {
			return;
		}
		if (nodes.freed[startIndex]
			|| nodes.freed[endIndex]
			|| start.generation != nodes.generation[startIndex]
			|| end.generation != nodes.generation[endIndex]) {
			return;
		}

		path.clear();
		path.pathfinder = this;
		path.smoothed = false;

		if (start == end) {
			path.nodes[path.length++] = start;
			return;
		}

		currentId++;
		heapSize = 0;
		var bestClosest = start;
		var bestClosestScore = estimate(start, end);
		nodes.gScore[startIndex] = 0;
		nodes.fScore[startIndex] = bestClosestScore;
		nodes.searchId[startIndex] = currentId;
		nodes.closedId[startIndex] = -1;
		nodes.parent[startIndex] = NodeHandle.INVALID;
		pushHeap(start);

		while (heapSize > 0) {
			var current = popHeap();
			var currentIndex = current.index;
			var currentGeneration = current.generation;
			if (currentGeneration != nodes.generation[currentIndex]) {
				continue;
			}

			var h = estimate(current, end);
			if (mode == ClosestPossible && h < bestClosestScore) {
				bestClosestScore = h;
				bestClosest = current;
			}

			if (current == end) {
				backtrack(path, end);
				return;
			}

			nodes.closedId[currentIndex] = currentId;
			var connectionStart = (currentIndex * connectionsPerNode);
			for (i in 0...nodes.connectionCount[currentIndex]) {
				var connectionIndex = connectionStart + i;
				var neighbor = connections.target[connectionIndex];
				var neighborDistance = connections.distance[connectionIndex];
				var neighborIndex = neighbor.index;
				var neighborGeneration = neighbor.generation;

				if (neighbor == NodeHandle.INVALID
					|| nodes.closedId[neighborIndex] == currentId
					|| nodes.freed[neighborIndex]
					|| neighborGeneration != nodes.generation[neighborIndex]
					|| nodes.flags[neighborIndex] & flags == 0) {
					continue;
				}

				var ng = nodes.gScore[currentIndex] + connections.distance[connectionIndex] * nodes.weight[neighborIndex];
				if (nodes.searchId[neighborIndex] != currentId || ng < nodes.gScore[neighborIndex]) {
					nodes.parent[neighborIndex] = current;
					nodes.gScore[neighborIndex] = ng;
					nodes.fScore[neighborIndex] = ng + neighborDistance;

					if (nodes.searchId[neighborIndex] != currentId) {
						nodes.searchId[neighborIndex] = currentId;
						pushHeap(neighbor);
					} else {
						if (nodes.heapIndex[neighborIndex] != -1) {
							fetchUpper(nodes.heapIndex[neighborIndex]);
						}
					}
				}
			}
		}

		if (mode == ClosestPossible && bestClosest != NodeHandle.INVALID) {
			backtrack(path, bestClosest);
		}
	}

	inline function estimate(nodeA:NodeHandle, nodeB:NodeHandle):Float {
		var nodeAIndex = nodeA.index;
		var nodeBIndex = nodeB.index;
		var dx = nodes.x[nodeAIndex] - nodes.x[nodeBIndex];
		var dy = nodes.y[nodeAIndex] - nodes.y[nodeBIndex];
		var dz = nodes.z[nodeAIndex] - nodes.z[nodeBIndex];
		return Math.sqrt(dx * dx + dy * dy + dz * dz);
	}

	inline function backtrack(path:Path, end:NodeHandle):Void {
		var current = end;
		while (current != NodeHandle.INVALID && path.length < path.nodes.length) {
			var currentIndex = current.index;
			// if (current.generation != nodes.generation[currentIndex]) {
			// 	break;
			// }

			path.nodes[path.length++] = current;
			current = nodes.parent[currentIndex];
		}
		path.version++;
	}

	inline function pushHeap(node:NodeHandle):Void {
		var heapIndex = heapSize++;
		heap[heapIndex] = node;
		nodes.heapIndex[node.index] = heapIndex;
		fetchUpper(heapIndex);
	}

	inline function popHeap():NodeHandle {
		var top = heap[0];
		nodes.heapIndex[top.index] = -1;
		heapSize--;
		if (heapSize > 0) {
			heap[0] = heap[heapSize];
			nodes.heapIndex[heap[0].index] = 0;
			fetchBottom(0);
		}
		return top;
	}

	inline function fetchUpper(heapIndex:Int):Void {
		var node = heap[heapIndex];
		var nodeIndex = node.index;
		while (heapIndex > 0) {
			var parentNodeHeapIndex = (heapIndex - 1) >> 1;
			var parentNode = heap[parentNodeHeapIndex];
			var parentNodeIndex = parentNode.index;
			if (nodes.fScore[nodeIndex] < nodes.fScore[parentNodeIndex]) {
				heap[heapIndex] = parentNode;
				nodes.heapIndex[parentNodeIndex] = heapIndex;
				heapIndex = parentNodeHeapIndex;
			} else {
				break;
			}
		}

		heap[heapIndex] = node;
		nodes.heapIndex[nodeIndex] = heapIndex;
	}

	inline function fetchBottom(heapIndex:Int):Void {
		var node = heap[heapIndex];
		var nodeIndex = node.index;
		var f = nodes.fScore[nodeIndex];
		while (true) {
			var left = (heapIndex << 1) + 1;
			if (left >= heapSize) {
				break;
			}

			var right = left + 1;
			var smallest = left;
			if (right < heapSize && nodes.fScore[heap[right].index] < nodes.fScore[heap[left].index]) {
				smallest = right;
			}

			var childNode = heap[smallest];
			var childNodeIndex = childNode.index;
			if (nodes.fScore[childNodeIndex] < f) {
				heap[heapIndex] = childNode;
				nodes.heapIndex[childNodeIndex] = heapIndex;
				heapIndex = smallest;
			} else {
				break;
			}
		}
		heap[heapIndex] = node;
		nodes.heapIndex[nodeIndex] = heapIndex;
	}

	public function queryNearestNode(x:Float, y:Float, z:Float, flags:Int, maxRadius:Float = 1e38):NodeHandle {
		var best = NodeHandle.INVALID;
		var bestDistance = maxRadius * maxRadius;
		var key = hash(x, y, z);
		var cell = spatialMap.get(key);

		inline function process(index:Int) {
			if (nodes.flags[index] & flags != 0) {
				var dx = nodes.x[index] - x;
				var dy = nodes.y[index] - y;
				var dz = nodes.z[index] - z;
				var distance = dx * dx + dy * dy + dz * dz;
				if (distance < bestDistance) {
					bestDistance = distance;
					best.index = index;
					best.generation = nodes.generation[index];
				}
			}
		}

		if (cell != null) {
			for (node in cell) {
				process(node.index);
			}
		}
		if (best == NodeHandle.INVALID) {
			for (i in 0...nodes.length) {
				process(i);
			}
		}
		return best;
	}

	public inline function findPath(path:Path, mode:PathMode, flags:Int, sx:Float, sy:Float, sz:Float, dx:Float, dy:Float, dz:Float):Void {
		var start = queryNearestNode(sx, sy, sz, flags);
		var end = queryNearestNode(dx, dy, dz, flags);
		if (start == NodeHandle.INVALID || end == NodeHandle.INVALID) {
			return;
		}
		track(path, mode, flags, start, end);
	}
}
