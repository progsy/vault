package vault.experimental.navigation;

enum PathMode {
	Normal;
	ClosestPossible;
}

private class Edge {
	public var to:Int;
	public var next:Int;
	public var prev:Int;
	public var distance:Float;
}

private class Searcher {
	public var gScore:Float;
	public var fScore:Float;
	public var parent:Int;
	public var searchId:Int = -1;
	public var closedId:Int = -1;
	public var heapIdx:Int = -1;
	public var nextHeapIdx:Int;
}

@:access(vault.experimental.navigation)
class Pathfinder {
	public static inline var INVALID_NODE:Int = -1;

	public var nodes(default, null):vault.data.StructOfVectors<Node>;

	var searchers(default, null):vault.data.StructOfVectors<Searcher>;
	var edges(default, null):vault.data.StructOfVectors<Edge>;

	var currentId:Int = 0;
	var heapSize:Int = 0;

	public inline function new(maxNodes:Int, maxEdges:Int) {
		nodes = new vault.data.StructOfVectors<Node>(maxNodes);
		searchers = new vault.data.StructOfVectors<Searcher>(maxNodes);
		edges = new vault.data.StructOfVectors<Edge>(maxEdges);
	}

	inline function unlinkEdge(nodeIndex:Int, edgeIndex:Int):Void {
		var p = edges.prev[edgeIndex];
		var n = edges.next[edgeIndex];

		if (p != -1) {
			edges.next[p] = n;
		} else {
			nodes.firstEdge[nodeIndex] = n;
		}

		if (n != -1) {
			edges.prev[n] = p;
		}
	}

	public function connect(a:Int, b:Int, dist:Float):Void {
		var edgeIndex = edges.push(b, nodes.firstEdge[a], -1, dist);
		if (edgeIndex == -1) {
			return;
		}

		if (nodes.firstEdge[a] != -1) {
			edges.prev[nodes.firstEdge[a]] = edgeIndex;
		}
		nodes.firstEdge[a] = edgeIndex;
	}

	public function disconnect(a:Int, b:Int):Void {
		var edgeIndex = nodes.firstEdge[a];
		while (edgeIndex != -1) {
			if (edges.to[edgeIndex] == b) {
				unlinkEdge(a, edgeIndex);
				edges.removeAt(edgeIndex);
				break;
			}
			edgeIndex = edges.next[edgeIndex];
		}
	}

	public function clear() {
		for (i in 0...nodes.length) {
			nodes.firstEdge[i] = -1;
			searchers.searchId[i] = -1;
			searchers.closedId[i] = -1;
			searchers.heapIdx[i] = -1;
		}
		currentId = 0;
		heapSize = 0;
	}

	function track(path:Path, mode:PathMode, flags:Int, start:Int, end:Int):Void {
		if (start == -1 || end == -1) {
			return;
		}

		path.clear();

		if (start == end) {
			path.push(nodes.x[start], nodes.y[start], nodes.z[start], nodes.flags[start], nodes.weight[start]);
			return;
		}

		currentId++;
		heapSize = 0;

		var bestClosest = start;
		var bestClosestScore = estimate(start, end);

		searchers.gScore[start] = 0;
		searchers.fScore[start] = bestClosestScore;
		searchers.searchId[start] = currentId;
		searchers.closedId[start] = -1;
		searchers.parent[start] = INVALID_NODE;

		bubblePush(start);

		while (heapSize > 0) {
			var curr = bubblePop();

			var h = estimate(curr, end);

			if (mode == ClosestPossible && h < bestClosestScore) {
				bestClosestScore = h;
				bestClosest = curr;
			}

			if (curr == end) {
				backtrack(path, end);
				return;
			}

			searchers.closedId[curr] = currentId;

			var e = nodes.firstEdge[curr];
			var g = searchers.gScore[curr];

			while (e != -1) {
				var n = edges.to[e];

				if (n >= 0 && searchers.closedId[n] != currentId && (nodes.flags[n] & flags) != 0) {
					var ng = g + edges.distance[e] * nodes.weight[n];
					var inOpen = searchers.searchId[n] == currentId;

					if (!inOpen || ng < searchers.gScore[n]) {
						searchers.parent[n] = curr;
						searchers.gScore[n] = ng;
						searchers.fScore[n] = ng + estimate(n, end);

						if (!inOpen) {
							searchers.searchId[n] = currentId;
							bubblePush(n);
						} else {
							updateKey(n);
						}
					}
				}

				e = edges.next[e];
			}
		}

		if (mode == ClosestPossible && bestClosest != INVALID_NODE) {
			backtrack(path, bestClosest);
		}
	}

	inline function estimate(a:Int, b:Int):Float {
		var dx = nodes.x[a] - nodes.x[b];
		var dy = nodes.y[a] - nodes.y[b];
		var dz = nodes.z[a] - nodes.z[b];
		return Math.sqrt(dx * dx + dy * dy + dz * dz);
	}

	inline function backtrack(path:Path, end:Int):Void {
		var connection = end;
		while (connection != INVALID_NODE) {
			if (path.push(nodes.x[connection], nodes.y[connection], nodes.z[connection], nodes.flags[connection], nodes.weight[connection]) == -1) {
				break;
			}
			connection = searchers.parent[connection];
		}
	}

	inline function bubblePush(id:Int)
		bubbleUp(heapSize++, id);

	inline function updateKey(id:Int) {
		var i = searchers.heapIdx[id];
		bubbleUp(i, id);
		bubbleDown(i, id);
	}

	inline function bubbleUp(i:Int, id:Int) {
		var f = searchers.fScore[id];
		while (i > 0) {
			var p = (i - 1) >> 1;
			var pId = searchers.nextHeapIdx[p];
			if (f < searchers.fScore[pId]) {
				searchers.nextHeapIdx[i] = pId;
				searchers.heapIdx[pId] = i;
				i = p;
			} else {
				break;
			}
		}
		searchers.nextHeapIdx[i] = id;
		searchers.heapIdx[id] = i;
	}

	inline function bubblePop():Int {
		var r = searchers.nextHeapIdx[0];
		searchers.heapIdx[r] = -1;
		var last = searchers.nextHeapIdx[--heapSize];
		if (heapSize > 0) {
			bubbleDown(0, last);
		}
		return r;
	}

	inline function bubbleDown(i:Int, id:Int) {
		var f = searchers.fScore[id];
		while (true) {
			var l = (i << 1) + 1;
			if (l >= heapSize) {
				break;
			}
			var r = l + 1;
			var c = (r < heapSize && searchers.fScore[searchers.nextHeapIdx[r]] < searchers.fScore[searchers.nextHeapIdx[l]]) ? r : l;
			var cid = searchers.nextHeapIdx[c];
			if (searchers.fScore[cid] < f) {
				searchers.nextHeapIdx[i] = cid;
				searchers.heapIdx[cid] = i;
				i = c;
			} else {
				break;
			}
		}
		searchers.nextHeapIdx[i] = id;
		searchers.heapIdx[id] = i;
	}

	public function queryNearestNode(x:Float, y:Float, z:Float, flags:Int, maxRadius:Float = 1e38):Int {
		var best = INVALID_NODE;
		var bestD = maxRadius * maxRadius;
		for (i in 0...nodes.length) {
			if ((nodes.flags[i] & flags) == 0) {
				continue;
			}
			var dx = nodes.x[i] - x;
			var dy = nodes.y[i] - y;
			var dz = nodes.z[i] - z;
			var d = dx * dx + dy * dy + dz * dz;
			if (d < bestD) {
				bestD = d;
				best = i;
			}
		}
		return best;
	}

	public inline function findPath(path:Path, mode:PathMode, flags:Int, sx:Float, sy:Float, sz:Float, dx:Float, dy:Float, dz:Float):Void {
		var start = queryNearestNode(sx, sy, sz, flags);
		var end = queryNearestNode(dx, dy, dz, flags);
		if (start == INVALID_NODE || end == INVALID_NODE) {
			return;
		}
		track(path, mode, flags, start, end);
	}
}
