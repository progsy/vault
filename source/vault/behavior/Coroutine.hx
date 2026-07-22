package vault.behavior;

import haxe.macro.Type.TypedExpr;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.MetadataEntry;

using StringTools;
using haxe.macro.ExprTools;
using haxe.macro.TypedExprTools;
using haxe.macro.TypeTools;

class Coroutine {
	var coordinator:() -> Void;
	var names:Map<String, Int> = [];
	var stepped:Bool;

	public var running(default, null):Bool;
	public var currentInstruction(default, null):Int;
	public var instructionCount(default, null):Int;

	public function new() {}

	public inline function run() {
		if (coordinator != null && !running) {
			currentInstruction = 0;
			running = true;
			resume();
		}
	}

	public inline function resume():Bool {
		if (running && currentInstruction >= 0 && currentInstruction < instructionCount && coordinator != null) {
			stepped = false;
			coordinator();
			return true;
		}
		return false;
	}

	public inline function jump(step:String):Bool {
		var index = names.get(step);
		if (index != null) {
			currentInstruction = index;
			stepped = true;
			return true;
		}
		return false;
	}

	public inline function step(steps:Int = 1):Void {
		currentInstruction += steps;
		stepped = true;
	}

	public inline function stick():Void {
		stepped = true;
	}

	public inline function stop():Void {
		if (running) {
			running = false;
		}
	}

	public inline function restart():Void {
		stop();
		run();
	}

	public macro function set(_this:Expr, body:Expr):Expr {
		var globalVariables:Array<{
			name:String,
			expr:Expr,
			scope:Array<String>,
		}> = [];
		var preSwitchExprs:Array<Expr> = [];
		var postSwitchExprs:Array<Expr> = [];
		var steps:Array<{
			name:String,
			expr:Expr,
			isolatedExpr:Expr,
			depth:Int,
			index:Int
		}> = [];
		var coordinatorExpr:Expr = macro {};
		var coordinatorCases:Array<Case> = [];
		var depthSteps:Map<Int, Int> = [];
		coordinatorExpr.expr = ESwitch(macro $_this.currentInstruction, coordinatorCases, null);

		function addStep(expr:Expr) {
			function isolateExpr(expr:Expr) {
				return switch (expr.expr) {
					case EMeta(s, e) if (s.name == ":step"):
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
				case EVars(vars):
					for (i in 0...vars.length) {
						globalVariables.push({
							name: vars[i].name,
							expr: i == 0 ? expr : null,
							scope: []
						});
					}
				case EMeta(s, e) if (s.name == ":scope"):
					switch (e.expr) {
						case EVars(vars):
							for (i in 0...vars.length) {
								globalVariables.push({
									name: vars[i].name,
									expr: i == 0 ? expr : null,
									scope: [for (p in s.params) p.getValue()]
								});
							}
						default:
					}
				default:
			}
		}
		body.iter(addStep);
		for (i in 0...steps.length) {
			function scopeOut(expr:Expr) {
				switch (expr.expr) {
					case EConst(c):
						switch (c) {
							case CIdent(s):
								var variables = Context.getLocalVars();
								for (gv in globalVariables) {
									if (gv.name == s && gv.scope.length > 0) {
										if (!gv.scope.contains(steps[i].name)) {
											variables.remove(gv.name);
											Context.typeExpr(expr);
										}
									}
								}
							default:
						}
					default:
				}
				expr.iter(scopeOut);
			}
			steps[i].expr.iter(scopeOut);
			steps[i].expr.iter(addStep);
		}

		preSwitchExprs.push(macro $_this.names.clear());
		for (step in steps) {
			if (step.index == depthSteps.get(step.depth) - 1) {
				coordinatorCases.push({
					values: [macro $v{step.index}],
					expr: macro {
						@:noPrivateAccess ${step.expr};
						$_this.stop();
					}
				});
			} else {
				coordinatorCases.push({
					values: [macro $v{step.index}],
					expr: macro {
						@:noPrivateAccess ${step.expr};
						if (!$_this.stepped) {
							$_this.step(1);
						}
					}
				});
			}
			if (step.name != null) {
				postSwitchExprs.push(macro $_this.names.set($v{step.name}, $v{step.index}));
			}
		}
		postSwitchExprs.push(macro $_this.coordinator = () -> $coordinatorExpr);
		postSwitchExprs.push(macro $_this.instructionCount = $v{coordinatorCases.length});

		return macro @:privateAccess $b{[for (v in globalVariables) if (v.expr != null) v.expr].concat(preSwitchExprs).concat(postSwitchExprs)};
	}
}
