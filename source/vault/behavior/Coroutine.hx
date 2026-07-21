package vault.behavior;

import haxe.macro.Expr;
import haxe.macro.Expr.MetadataEntry;

using StringTools;
using haxe.macro.ExprTools;
using haxe.macro.TypedExprTools;
using haxe.macro.TypeTools;

class Coroutine {
	var coordinator:() -> Void;
	var names:Map<String, Int> = [];
	var currentIndex:Int = -1;
	var maxStep:Int;
	var stepped:Bool;

	public var running(default, null):Bool;

	public function new() {}

	public inline function run() {
		if (coordinator != null && !running) {
			currentIndex = 0;
			running = true;
			resume();
		}
	}

	public inline function resume():Bool {
		if (running && currentIndex >= 0 && currentIndex < maxStep && coordinator != null) {
			stepped = false;
			coordinator();
			return true;
		}
		return false;
	}

	public inline function jump(step:String):Bool {
		var index = names.get(step);
		if (index != null) {
			currentIndex = index;
			stepped = true;
			return true;
		}
		return false;
	}

	public inline function stepForward(steps:Int = 1):Void {
		currentIndex += 1;
		stepped = true;
	}

	public inline function stepBack(steps:Int = 1):Void {
		currentIndex -= steps;
		stepped = true;
	}

	public inline function stick():Void {
		stepped = true;
	}

	public inline function stop():Void {
		if (running) {
			currentIndex = -1;
			running = false;
		}
	}

	public inline function restart():Void {
		stop();
		run();
	}

	public macro function set(_this:Expr, body:Expr):Expr {
		var globalVariableExprs:Array<Expr> = [];
		var preSwitchExprs:Array<Expr> = [];
		var postSwitchExprs:Array<Expr> = [];
		var steps:Array<{
			name:String,
			expr:Expr,
			isolatedExpr:Expr,
			depth:Int,
			index:Int
		}> = [];
		var subSteps:Array<{
			name:String,
			expr:Expr,
			isolatedExpr:Expr,
			depth:Int,
			index:Int
		}> = [];
		var coordinatorExpr:Expr = macro {};
		var coordinatorCases:Array<Case> = [];
		var depthSteps:Map<Int, Int> = [];
		coordinatorExpr.expr = ESwitch(macro $_this.currentIndex, coordinatorCases, null);

		function checkStep(expr:Expr, sub:Bool) {
			function isolateExpr(expr:Expr) {
				return switch (expr.expr) {
					case EMeta(s, e) if (s.name == ":step"):
						if (sub) {
							checkStep(expr, true);
						}
						expr = macro {};
					default:
						expr.map(isolateExpr);
				}
			}
			switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":step"):
					var name:String;
					if (s.params != null) {
						if (s.params.length > 0) {
							name = s.params[0].getValue();
						}
					}
					var step = {
						name: name,
						expr: expr,
						isolatedExpr: expr.map(isolateExpr),
						depth: 0,
						index: steps.length
					};
					depthSteps.set(step.depth, (depthSteps.get(step.depth) ?? 0) + 1);
					steps.push(step);
				case EVars(vars) if (!sub):
					globalVariableExprs.push(expr);
				default:
			}
		}
		body.iter(checkStep.bind(_, false));
		for (i in 0...steps.length) {
			steps[i].expr.iter(checkStep.bind(_, false));
		}

		preSwitchExprs.push(macro $_this.names.clear());
		for (step in steps) {
			if (step.index == depthSteps.get(step.depth) - 1) {
				coordinatorCases.push({
					values: [macro $v{step.index}],
					expr: macro {
						${step.expr};
						$_this.stop();
					}
				});
			} else {
				coordinatorCases.push({
					values: [macro $v{step.index}],
					expr: macro {
						${step.expr};
						if (!$_this.stepped) {
							$_this.stepForward();
						}
					}
				});
			}
			if (step.name != null) {
				postSwitchExprs.push(macro $_this.names.set($v{step.name}, $v{step.index}));
			}
		}
		postSwitchExprs.push(macro $_this.coordinator = () -> $coordinatorExpr);
		postSwitchExprs.push(macro $_this.maxStep = $v{coordinatorCases.length});

		return macro @:privateAccess $b{globalVariableExprs.concat(preSwitchExprs).concat(postSwitchExprs)};
	}
}
