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
	var labelledInstructions:Map<String, Int> = [];
	var stepped:Bool;

	public var running(default, null):Bool;
	public var currentInstruction(default, null):Int;
	public var instructionCount(default, null):Int;

	public function new() {}

	public inline function run() {
		if (coordinator != null && !running) {
			currentInstruction = 0;
			running = true;
			if (!resume()) {
				running = false;
			}
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
		var index = labelledInstructions.get(step);
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
		running = false;
	}

	public inline function restart():Void {
		stop();
		run();
	}

	public macro function set(_this:Expr, body:Expr):Expr {
		var capturedVariables:Array<{
			name:String,
			expr:Expr,
			scope:Array<String>,
			// stackScoop:{branch:Int, depth:Int, index:Int}
		}> = [];
		var stackInfo:Map<Int, Map<Int, Int>> = []; // branch -> depth -> step
		var steps:Array<{
			label:String,
			expr:Expr,
			isolatedExpr:Expr,
			branch:Int,
			depth:Int,
			index:Int
		}> = [];
		var preSwitchExprs:Array<Expr> = [];
		var postSwitchExprs:Array<Expr> = [];
		var coordinatorExpr:Expr = macro {};
		var coordinatorCases:Array<Case> = [];
		// var depthSteps:Map<Int, Int> = [];
		coordinatorExpr.expr = ESwitch(macro $_this.currentInstruction, coordinatorCases, null);

		function isolateExpr(expr:Expr) {
			return switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":step"):
					expr = macro {};
				default:
					expr.map(isolateExpr);
			}
		}
		function scopeOut(label:String, expr:Expr) {
			switch (expr.expr) {
				case EConst(c):
					switch (c) {
						case CIdent(s):
							var variables = Context.getLocalVars();
							for (gv in capturedVariables) {
								if (gv.name == s && gv.scope.length > 0) {
									if (!gv.scope.contains(label)) {
										variables.remove(gv.name);
										Context.typeExpr(expr);
									}
								}
							}
						default:
					}
				default:
			}
			expr.iter(scopeOut.bind(label, _));
		}

		var stackIndex:Map<Int, Map<Int, Int>> = [];
		var nextBranch = 0;
		function submitStep(expr:Expr, depth:Int) {
			var actualDepth = Std.int(depth / 2);
			if (!stackIndex.exists(nextBranch)) {
				stackIndex.set(nextBranch, []);
			}
			var index = stackIndex.get(nextBranch).get(actualDepth) ?? 0;
			switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":step"):
					var label:String;
					if (s.params != null) {
						if (s.params.length > 0) {
							label = s.params[0].getValue();
						}
					}
					expr.iter(scopeOut.bind(label, _));
					var step = {
						label: label,
						expr: expr,
						isolatedExpr: expr.map(isolateExpr),
						branch: nextBranch,
						depth: actualDepth,
						index: index
					};
					stackIndex.get(nextBranch).set(actualDepth, index + 1);
					steps.push(step);
				default:
			}
			expr.iter(submitStep.bind(_, ++depth));
		}
		function captureVariable(expr:Expr) {
			switch (expr.expr) {
				case EVars(vars):
					for (i in 0...vars.length) {
						capturedVariables.push({
							name: vars[i].name,
							expr: i == 0 ? expr : null,
							scope: []
						});
					}
				case EMeta(s, e) if (s.name == ":scope"):
					switch (e.expr) {
						case EVars(vars):
							for (i in 0...vars.length) {
								capturedVariables.push({
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
		body.iter(captureVariable);
		body.iter((expr) -> {
			submitStep(expr, 0);
			switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":step"):
					nextBranch++;
				default:
			}
		});
		for (step in steps) {
			trace('${step.branch}:${step.depth}:${step.index} ${step.expr.toString()}');
		}

		preSwitchExprs.push(macro $_this.labelledInstructions.clear());
		for (i in 0...steps.length) {
			var step = steps[i];
			if (i == steps.length - 1) {
				coordinatorCases.push({
					values: [macro $v{i}],
					expr: macro {
						@:noPrivateAccess ${step.isolatedExpr};
						$_this.stop();
					}
				});
			} else {
				coordinatorCases.push({
					values: [macro $v{i}],
					expr: macro {
						@:noPrivateAccess ${step.isolatedExpr};
						if (!$_this.stepped) {
							$_this.step(1);
						}
					}
				});
			}
			if (step.label != null) {
				postSwitchExprs.push(macro $_this.labelledInstructions.set($v{step.label}, $v{i}));
			}
		}
		postSwitchExprs.push(macro $_this.coordinator = () -> $coordinatorExpr);
		postSwitchExprs.push(macro $_this.instructionCount = $v{coordinatorCases.length});

		return macro @:privateAccess $b{[for (v in capturedVariables) if (v.expr != null) v.expr].concat(preSwitchExprs).concat(postSwitchExprs)};
	}
}
