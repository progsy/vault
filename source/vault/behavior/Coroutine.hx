package vault.behavior;

import haxe.macro.Type.TypedExpr;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Expr.ExprOf;
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

enum abstract QueueVariableSignature(Int) from Int to Int {
	var Int = 1;
	var Float;
	var Bool;
	var Object;
}

@:using(vault.behavior.Coroutine.CoroutineMacro)
class Coroutine {
	var coordinator:() -> Void;
	var labelledInstructions:Map<String, Int> = [];
	var primitvieQueue:haxe.io.Bytes = haxe.io.Bytes.alloc(CoroutineMacro.MAX_QUEUE_PRIMITIVES * CoroutineMacro.SIGNATURE_ALIGNMENT);
	var objectQueue:haxe.ds.Vector<Any> = new haxe.ds.Vector<Any>(CoroutineMacro.MAX_QUEUE_OBJECTS);
	var incomingPrimitives:Int;
	var incomingObjects:Int;
	var queueSignature:Int;

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
			coordinator();
			return true;
		}
		return false;
	}

	public inline function jump(step:String):Bool {
		var index = labelledInstructions.get(step);
		if (index != null) {
			currentInstruction = index;
			return true;
		}
		return false;
	}

	public inline function step(steps:Int = 1):Void {
		currentInstruction += steps;
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
			currentInstruction = CoroutineMacro.RESET_VARIABLES_INSTRUCTION;
			coordinator();
			currentInstruction = oldInstruction;
			return true;
		}
		return false;
	}

	public inline function incoming():Int {
		return incomingPrimitives + incomingObjects;
	}

	public inline function cancelIncoming():Void {
		if (incomingPrimitives > 0) {
			primitvieQueue.fill(0, incomingPrimitives * CoroutineMacro.SIGNATURE_ALIGNMENT, 0);
		}
		for (i in 0...incomingObjects) {
			objectQueue[i] = null;
		}
		incomingPrimitives = 0;
		incomingObjects = 0;
	}
}

private class CoroutineMacro {
	public static final RESET_VARIABLES_INSTRUCTION = 7777;
	public static final MAX_QUEUE_PRIMITIVES = 10;
	public static final MAX_QUEUE_OBJECTS = 10;
	public static final SIGNATURE_ALIGNMENT = 8;

	public static macro function validate(coroutine:ExprOf<Coroutine>, ...args:Expr):Expr {
		var primitiveIndex = 0;
		var objectIndex = 0;
		var signature = 0;
		for (arg in args) {
			switch (Context.typeof(arg)) {
				case TType(_.get() => t, params) if (t.name == "Abstract<Int>"):
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Int << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TType(_.get() => t, params) if (t.name == "Abstract<Float>"):
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Float << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TType(_.get() => t, params) if (t.name == "Abstract<Bool>"):
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Bool << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TType(_.get() => t, _) if (t.name.startsWith("Class") || t.name.startsWith("Enum")):
					signature = (signature & ~(SIGNATURE_ALIGNMENT << objectIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Object << objectIndex * SIGNATURE_ALIGNMENT);
					objectIndex++;
				case TAnonymous(_):
					signature = (signature & ~(SIGNATURE_ALIGNMENT << objectIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Object << objectIndex * SIGNATURE_ALIGNMENT);
					objectIndex++;
				default:
					Context.error("This type is not supported", arg.pos);
			}
		}
		return macro $v{signature} == @:privateAccess $coroutine.queueSignature;
	}

	public static macro function accept(coroutine:ExprOf<Coroutine>, ...args:Expr) {
		if (args.length > 10) {
			Context.error("Can't accept more than 10 arguments", Context.currentPos());
		}
		var primitiveIndex = 0;
		var objectIndex = 0;
		var signature = 0;
		var objectCount = 0;
		var exprs:Array<Expr> = [];
		for (arg in args) {
			var type = switch (arg.expr) {
				case EConst(c):
					switch (c) {
						case CIdent(s):
							Context.typeof(arg);
						default:
							Context.error("Argument must be a variable identifier", arg.pos);
							return macro {};
					}
				default:
					Context.typeof(arg);
			}
			switch (type.followWithAbstracts()) {
				case TAbstract(_.get() => t, params) if (t.name == "Int"):
					exprs.push(macro $arg = $coroutine.primitvieQueue.getInt32($v{primitiveIndex * SIGNATURE_ALIGNMENT}));
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Int << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TAbstract(_.get() => t, params) if (t.name == "Float"):
					exprs.push(macro $arg = $coroutine.primitvieQueue.getDouble($v{primitiveIndex * SIGNATURE_ALIGNMENT}));
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Float << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TAbstract(_.get() => t, params) if (t.name == "Bool"):
					exprs.push(macro $arg = $coroutine.primitvieQueue.get($v{primitiveIndex * SIGNATURE_ALIGNMENT}) > 0);
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Bool << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TInst(_, _), TEnum(_, _), TAnonymous(_):
					exprs.push(macro $arg = $coroutine.objectQueue[$v{objectIndex}]);
					exprs.push(macro $coroutine.objectQueue[$v{objectIndex}] = null);
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Object << primitiveIndex * SIGNATURE_ALIGNMENT);
					objectIndex++;
				default:
					Context.error("This type is not supported", arg.pos);
			}
		}
		exprs.push(macro @:privateAccess $coroutine.incomingPrimitives = 0);
		exprs.push(macro @:privateAccess $coroutine.incomingObjects = 0);
		exprs.push(macro @:privateAccess $coroutine.queueSignature = 0);
		return macro @:privateAccess $b{exprs};
	}

	public static macro function send(coroutine:ExprOf<Coroutine>, ...args:Expr) {
		if (args.length > 10) {
			Context.error("Can't accept more than 10 arguments", Context.currentPos());
		}
		var primitiveIndex = 0;
		var objectIndex = 0;
		var signature = 0;
		var exprs:Array<Expr> = [];
		for (arg in args) {
			switch (Context.typeof(arg).followWithAbstracts()) {
				case TAbstract(_.get() => t, params) if (t.name == "Int"):
					exprs.push(macro $coroutine.primitvieQueue.setInt32($v{primitiveIndex * SIGNATURE_ALIGNMENT}, $arg));
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Int << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TAbstract(_.get() => t, params) if (t.name == "Float"):
					exprs.push(macro $coroutine.primitvieQueue.setDouble($v{primitiveIndex * SIGNATURE_ALIGNMENT}, $arg));
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Float << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TAbstract(_.get() => t, params) if (t.name == "Bool"):
					exprs.push(macro $coroutine.primitvieQueue.set($v{primitiveIndex * SIGNATURE_ALIGNMENT}, $arg ? 1 : 0));
					signature = (signature & ~(SIGNATURE_ALIGNMENT << primitiveIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Bool << primitiveIndex * SIGNATURE_ALIGNMENT);
					primitiveIndex++;
				case TInst(_, _), TEnum(_, _), TAnonymous(_):
					exprs.push(macro $coroutine.objectQueue[$v{objectIndex}] = $arg);
					signature = (signature & ~(SIGNATURE_ALIGNMENT << objectIndex * SIGNATURE_ALIGNMENT)) | (QueueVariableSignature.Object << objectIndex * SIGNATURE_ALIGNMENT);
					objectIndex++;
				default:
					Context.error("This type is not supported", arg.pos);
			}
		}
		exprs.push(macro @:privateAccess $coroutine.incomingPrimitives = $v{primitiveIndex});
		exprs.push(macro @:privateAccess $coroutine.incomingObjects = $v{objectIndex});
		exprs.push(macro @:privateAccess $coroutine.queueSignature = $v{signature});
		return macro @:privateAccess $b{exprs};
	}

	public static macro function set(coroutine:ExprOf<Coroutine>, body:Expr):Expr {
		var steps:Array<Step> = [];
		var capturedVariables:Array<CapturedVariable> = [];
		var preSwitchExprs:Array<Expr> = [];
		var postSwitchExprs:Array<Expr> = [];
		var coordinatorExpr:Expr = macro {};
		var coordinatorCases:Array<Case> = [];
		var labels:Map<String, Step> = [];
		coordinatorExpr.expr = ESwitch(macro $coroutine.currentInstruction, coordinatorCases, null);

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

		function handleReturn(expr:Expr) {
			return switch (expr.expr) {
				case EFunction(kind, f):
					expr;
				case EReturn(e):
					if (e == null) {
						macro {
							$coroutine.stop();
							return;
						};
					} else {
						var type = Context.typeof(e).followWithAbstracts();
						switch (type) {
							case TAbstract(_.get() => t, params) if (t.name == "Int"):
								macro {
									$coroutine.step($e);
									return;
								};
							case TInst(_.get() => t, params) if (t.name == "String"):
								var label:String = e.getValue();
								if (!labels.exists(label)) {
									Context.error("Label " + label + " does not exist", e.pos);
									return expr;
								}
								macro {
									$coroutine.jump($e);
									return;
								};
							default:
								Context.error("Returned value must be an increment or a step label", e.pos);
						}
					}
				default:
					expr.map(handleReturn);
			}
		}

		function load(expr:Expr, step:Step) {
			switch (expr.expr) {
				case EMeta(s, e) if (s.name == ":load"):
					switch (unrollMeta(e).expr) {
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
								Context.error("Couldn't load the variable " + v.name, expr.pos);
								return expr;
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
							if (labels.exists(label)) {
								Context.error("Label " + label + " is already taken", s.params[0].pos);
								return;
							}
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
					if (label != null) {
						labels.set(label, step);
					}
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
					Context.typeExpr(expr);
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
								var mangledName = '${vars[i].name}_${step.branch}_${step.depth}_${step.index}';
								var type = null;
								if (vars[i].expr != null) {
									type = Context.typeof(vars[i].expr).toComplexType();
								} else {
									Context.error("Variable " + vars[i].name + " initial expression must be set", expr.pos);
									return;
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
									expr: vars[i].expr != null ? (macro var $mangledName = ${vars[i].expr}) : (macro var $mangledName:$type),
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
							if (vars[i].expr == null) {
								Context.error("Variable " + vars[i].name + " initial expression must be set", expr.pos);
								return;
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
			steps[i].isolatedExpr = steps[i].isolatedExpr.map(handleReturn);
			steps[i].isolatedExpr = steps[i].isolatedExpr.map(load.bind(_, steps[i]));
		}

		preSwitchExprs.push(macro $coroutine.labelledInstructions.clear());
		for (i in 0...steps.length) {
			if (i == steps.length - 1) {
				coordinatorCases.push({
					values: [macro $v{i}],
					expr: macro {
						@:noPrivateAccess ${steps[i].isolatedExpr};
						$coroutine.stop();
					}
				});
			} else {
				coordinatorCases.push({
					values: [macro $v{i}],
					expr: macro {
						@:noPrivateAccess ${steps[i].isolatedExpr};
						$coroutine.step(1);
					}
				});
			}
			if (steps[i].label != null) {
				postSwitchExprs.push(macro $coroutine.labelledInstructions.set($v{steps[i].label}, $v{i}));
			}
		}
		postSwitchExprs.push(macro $coroutine.coordinator = () -> $coordinatorExpr);
		postSwitchExprs.push(macro $coroutine.instructionCount = $v{coordinatorCases.length});
		coordinatorCases.push({
			values: [macro $v{RESET_VARIABLES_INSTRUCTION}],
			expr: macro $b{[for (cv in capturedVariables) if (cv.resetExpr != null) cv.resetExpr]}
		});
		return macro @:privateAccess $b{[for (v in capturedVariables) if (v.expr != null) v.expr].concat(preSwitchExprs).concat(postSwitchExprs)};
	}
}
