package vault.behavior;

import haxe.macro.Type.TypedExpr;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.MetadataEntry;

using StringTools;
using haxe.macro.ExprTools;
using haxe.macro.TypedExprTools;
using haxe.macro.TypeTools;

typedef Step = {
	label:String,
	expr:Expr,
	isolatedExpr:Expr,
	capturedVariables:Array<CapturedVariable>,
	branch:Int,
	depth:Int,
	index:Int
};

typedef CapturedVariable = {
	name:String,
	mangledName:String,
	expr:Expr,
	?resetExpr:Expr,
	?scope:{branch:Int, depth:Int, index:Int}
};

class Coroutine {
	static final RESET_VARIABLES_INSTRUCTION = 7777;

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

	public inline function resetVariables():Bool {
		if (coordinator != null) {
			var oldInstruction = currentInstruction;
			currentInstruction = RESET_VARIABLES_INSTRUCTION;
			coordinator();
			currentInstruction = oldInstruction;
			return true;
		}
		return false;
	}

	public macro function set(_this:Expr, body:Expr):Expr {
		var steps:Array<Step> = [];
		var capturedVariables:Array<CapturedVariable> = [];
		var preSwitchExprs:Array<Expr> = [];
		var postSwitchExprs:Array<Expr> = [];
		var coordinatorExpr:Expr = macro {};
		var coordinatorCases:Array<Case> = [];
		coordinatorExpr.expr = ESwitch(macro $_this.currentInstruction, coordinatorCases, null);

		function unrollMeta(expr:Expr) {
			return switch (expr.expr) {
				case EMeta(s, e):
					unrollMeta(e);
				default:
					expr;
			}
		}

		function isVariableLoaded(expr:Expr, name:String):Bool {
			var found = false;
			function checkLoad(e:Expr) {
				switch (e.expr) {
					case EMeta(s, subExpr) if (s.name == ":load"):
						switch (unrollMeta(subExpr).expr) {
							case EVars(vars):
								for (v in vars) {
									if (v.name == name) {
										found = true;
									}
								}
							default:
						}
					default:
				}
				if (!found) {
					e.iter(checkLoad);
				}
			}
			expr.iter(checkLoad);
			return found;
		}

		function isolateExpr(expr:Expr) {
			return switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":step"):
					macro {};
				default:
					expr.map(isolateExpr);
			}
		}

		function load(expr:Expr, step:Step) {
			switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":load"):
					switch (e.map(unrollMeta).expr) {
						case EVars(vars):
							for (i in 0...vars.length) {
								var v = vars[i];
								var cvc:CapturedVariable = null;
								for (cv in step.capturedVariables) {
									if (cv.name == v.name && step.depth >= cv.scope.depth) {
										if (cvc == null || cv.scope.depth >= cvc.scope.depth) {
											cvc = cv;
										}
									}
								}
								if (cvc == null) {
									for (cv in capturedVariables) {
										if (cv.name == v.name) {
											cvc = cv;
										}
									}
								}
								if (cvc != null) {
									var cv = cvc;
									var name = v.name;
									if (cv.mangledName != null) {
										if (!capturedVariables.contains(cv)) {
											if (Context.getDisplayMode() == None) {
												capturedVariables.push(cv);
											} else {
												var retE:Expr = {pos: expr.pos, expr: cv.expr.expr};
												switch (retE.expr) {
													case EVars(vars2):
														vars2[i].name = vars[i].name;
													default:
												}
												return retE;
											}
											for (ss in steps) {
												if (ss.depth == cv.scope.depth && ss.index == cv.scope.index && ss.branch == cv.scope.branch) {
													switch (unrollMeta(ss.isolatedExpr).expr) {
														case EBlock(exprs):
															exprs.push(macro $i{cv.mangledName} = $i{name});
														default:
													}
													break;
												}
											}
										}
										switch (unrollMeta(step.isolatedExpr).expr) {
											case EBlock(exprs):
												exprs.push(macro $i{cv.mangledName} = $i{name});
											default:
										}
										return macro var $name = $i{cv.mangledName};
									} else {
										return macro {};
									}
								}
								Context.error("Couldn't load the variable: " + v.name, expr.pos);
							}
						default:
					}
				default:
			}
			return expr.map(load.bind(_, step));
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
					var label:String = null;
					if (s.params != null) {
						if (s.params.length > 0) {
							label = s.params[0].getValue();
						}
					}
					var step = {
						label: label,
						expr: expr,
						isolatedExpr: null,
						capturedVariables: [],
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

		var overwriteExpr:Expr;
		var resetExpr:Expr;
		var resetMethodExpr:Expr;
		function captureVariable(expr:Expr, step:Step, nestLevel:Int) {
			switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":overwrite"):
					overwriteExpr = s.params[0];
					captureVariable(e, step, nestLevel);
					overwriteExpr = null;
				case EMeta(s, e) if (s.name == ":reset"):
					resetExpr = s.params[0];
					captureVariable(e, step, nestLevel);
					resetExpr = null;
				case EMeta(s, e) if (s.name == ":resetMethod"):
					resetMethodExpr = s.params[0];
					captureVariable(e, step, nestLevel);
					resetMethodExpr = null;
				case EVars(vars):
					for (i in 0...vars.length) {
						if (step != null) {
							var loded = false;
							for (j in (steps.indexOf(step) + 1)...steps.length) {
								if (isVariableLoaded(steps[j].expr, vars[i].name)) {
									loded = true;
									break;
								}
							}
							if (loded) {
								var initExpr = vars[i].expr;
								var mangledName = '${vars[i].name}_${step.branch}_${step.depth}_${step.index}';
								var type = null;
								if (initExpr != null) {
									type = Context.typeof(initExpr).toComplexType();
								}
								if (type == null && vars[i].type != null) {
									type = vars[i].type;
								}
								if (type != null) {
									vars[i].type = type;
								}
								var resetFunctionName:String;
								var resetFunctionArguments:Array<Expr>;
								if (resetMethodExpr != null) {
									switch (resetMethodExpr.expr) {
										case ECall(e, params):
											resetFunctionName = e.toString();
											resetFunctionArguments = params;
										default:
									}
								}
								var capturedVariable = {
									name: vars[i].name,
									mangledName: mangledName,
									expr: initExpr != null ? (macro var $mangledName = $initExpr) : (macro var $mangledName:$type),
									resetExpr: resetExpr != null ? macro $i{mangledName} = $resetExpr : resetMethodExpr != null ? macro $p{[mangledName, resetFunctionName]}($a{resetFunctionArguments}) : macro $i{mangledName} = ${vars[i].expr},
									scope: {
										branch: step.branch,
										depth: step.depth,
										index: step.index
									}
								};
								step.capturedVariables.push(capturedVariable);
								if (overwriteExpr == null) {
									vars[i].expr = macro $i{mangledName};
								} else {
									vars[i].expr = overwriteExpr;
								}
							}
						} else {
							var resetFunctionName:String;
							var resetFunctionArguments:Array<Expr>;
							if (resetMethodExpr != null) {
								switch (resetMethodExpr.expr) {
									case ECall(e, params):
										resetFunctionName = e.toString();
										resetFunctionArguments = params;
									default:
								}
							}
							capturedVariables.push({
								name: vars[i].name,
								mangledName: null,
								expr: expr,
								resetExpr: resetExpr != null ? macro $i{vars[i].name} = $resetExpr : resetMethodExpr != null ? macro $p{[vars[i].name, resetFunctionName]}($a{resetFunctionArguments}) : macro $i{vars[i].name} = ${vars[i].expr},
							});
						}
					}
				default:
			}
			if (nestLevel > 0) {
				expr.iter(captureVariable.bind(_, step, nestLevel - 1));
			}
		}
		body.iter(captureVariable.bind(_, null, 0));
		body.iter((expr) -> {
			submitStep(expr, 0);
			switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":step"):
					nextBranch++;
				default:
			}
		});

		for (i in 0...steps.length) {
			steps[i].expr.iter(captureVariable.bind(_, steps[i], 1));
		}

		for (i in 0...steps.length) {
			if (i > 0) {
				for (j in 1...(i + 1)) {
					for (cv in steps[i - j].capturedVariables) {
						var alreadyHasIt = false;
						for (pcv in steps[i].capturedVariables) {
							if (pcv.name == cv.name)
								alreadyHasIt = true;
						}
						if (!alreadyHasIt) {
							steps[i].capturedVariables.push(cv);
						}
					}
				}
			}
		}
		for (i in 0...steps.length) {
			steps[i].isolatedExpr = steps[i].expr.map(isolateExpr);
			steps[i].isolatedExpr = steps[i].isolatedExpr.map(load.bind(_, steps[i]));
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
		coordinatorCases.push({
			values: [macro $v{RESET_VARIABLES_INSTRUCTION}],
			expr: macro $b{[for (cv in capturedVariables) if (cv.resetExpr != null) cv.resetExpr]}
		});
		return macro @:privateAccess $b{[for (v in capturedVariables) if (v.expr != null) v.expr].concat(preSwitchExprs).concat(postSwitchExprs)};
	}
}
