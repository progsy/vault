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
	var steppedManually:Bool;

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
			steppedManually = false;
			coordinator();
			return true;
		}
		return false;
	}

	public inline function jump(step:String):Bool {
		var index = names.get(step);
		if (index != null) {
			currentIndex = index;
			steppedManually = true;
			return true;
		}
		return false;
	}

	public inline function stepBack():Void {
		currentIndex -= 1;
		steppedManually = true;
	}

	public inline function stick():Void {
		steppedManually = true;
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
		var variableExprs:Array<Expr> = [];
		var stepBlockExprs:Array<Expr> = [];
		var stepBlockNames:Array<String> = [];
		var essentialGeneralExprs:Array<Expr> = [];
		var generalExprs:Array<Expr> = [];
		var coordinatorExpr:Expr = macro {};
		var coordinatorCases:Array<Case> = [];
		coordinatorExpr.expr = ESwitch(macro $_this.currentIndex, coordinatorCases, null);

		function addStep(s:MetadataEntry, e:Expr) {
			var name:String;
			if (s.params != null) {
				if (s.params.length > 0) {
					name = s.params[0].getValue();
				}
			}
			stepBlockExprs.push(e);
			stepBlockNames.push(name);
		}

		switch (body.expr) {
			case EBlock(exprs):
				for (expr in exprs) {
					switch (expr.expr) {
						case EMeta(s, e) if (s.name == ":step"):
							addStep(s, e);
						case EVars(vars):
							variableExprs.push(expr);
						default:
					}
				}
			default:
		}

		essentialGeneralExprs.push(macro $_this.names.clear());
		for (i in 0...stepBlockExprs.length) {
			if (i == stepBlockExprs.length - 1) {
				coordinatorCases.push({
					values: [macro $v{i}],
					expr: macro {
						@:noPrivateAccess ${stepBlockExprs[i]};
						$_this.stop();
					}
				});
			} else {
				coordinatorCases.push({
					values: [macro $v{i}],
					expr: macro {
						@:noPrivateAccess ${stepBlockExprs[i]};
						if (!$_this.steppedManually) {
							$_this.currentIndex++;
						}
					}
				});
			}
			if (stepBlockNames[i] != null) {
				generalExprs.push(macro $_this.names.set($v{stepBlockNames[i]}, $v{i}));
			}
		}
		generalExprs.push(macro $_this.coordinator = () -> $coordinatorExpr);
		generalExprs.push(macro $_this.maxStep = $v{coordinatorCases.length});

		return macro @:privateAccess {
			$b{variableExprs.concat(essentialGeneralExprs).concat(generalExprs)};
		};
	}
}
