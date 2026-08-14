package vault.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using StringTools;

class Signal {
	static function build():ComplexType {
		var type = Context.getLocalType();

		switch (type) {
			case TInst(_.get() => cl, params):
				var fields = Context.getBuildFields();
				var uniqueName = 'Signal_${params.length}';
				var fullPack = ["vault", "behavior"];
				var classTypeParameterDecls:Array<TypeParamDecl> = [];
				var classTypeParameters:Array<TypeParam> = [];
				var classSelfTypeParameters:Array<TypeParam> = [];

				for (i in 0...params.length) {
					var param = params[i];
					var paramName = 'T${i + 1}';
					classTypeParameterDecls.push({name: paramName});
					classTypeParameters.push(TPType(param.toComplexType()));
					classSelfTypeParameters.push(TPType(TPath({pack: [], name: paramName})));
				}

				var complexType = TPath({
					pack: fullPack,
					name: uniqueName,
					params: classTypeParameters.length > 0 ? classTypeParameters : null
				});

				var selfType = TPath({
					pack: fullPack,
					name: uniqueName,
					params: classSelfTypeParameters.length > 0 ? classSelfTypeParameters : null
				});

				try {
					var existingPath = fullPack.concat([uniqueName]).join(".");
					Context.getType(existingPath);
					return complexType;
				} catch (e) {}

				var tfunArgs:Array<{name:String, opt:Bool, t:Type}> = [];
				var handleArgs:Array<FunctionArg> = [];
				var complexArgs:Array<ComplexType> = [];
				for (i in 0...params.length) {
					var paramName = 'T${i + 1}';
					var typePath = TPath({pack: [], name: paramName});
					tfunArgs.push({name: '_${i + 1}', opt: false, t: params[i]});
					handleArgs.push({name: '_${i + 1}', opt: false, type: typePath});
					complexArgs.push(typePath);
				}
				var handleType:Type = TFun(tfunArgs, (macro :Void).toType());
				var handleComplexType:ComplexType = TFunction(complexArgs, macro :Void);
				var handleArrayType = macro :Array<$handleComplexType>;
				var handleArgExprs = [for (i in 0...handleArgs.length) macro $i{'_${i + 1}'}];
				var handleCallExpr = macro handle($a{handleArgExprs});
				var signalEmitExpr = macro signal.emit($a{handleArgExprs});

				fields.push({
					name: 'handles',
					pos: Context.currentPos(),
					kind: FVar(handleArrayType, macro []),
					access: [APrivate]
				});

				fields.push({
					name: 'signals',
					pos: Context.currentPos(),
					kind: FVar(macro :Array<$selfType>, macro []),
					access: [APrivate]
				});

				fields.push({
					name: 'new',
					pos: Context.currentPos(),
					kind: FFun({args: [], expr: macro {}}),
					access: [APublic]
				});

				fields.push({
					name: 'connect',
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: 'handle', type: handleComplexType}],
						expr: macro {
							if (!handles.contains(handle)) {
								handles.push(handle);
								return true;
							}
							return false;
						},
						ret: macro :Bool
					}),
					access: [APublic, AInline, AExtern, AOverload]
				});

				fields.push({
					name: 'connect',
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: 'signal', type: selfType}],
						expr: macro {
							if (!signals.contains(signal)) {
								signals.push(signal);
								return true;
							}
							return false;
						},
						ret: macro :Bool
					}),
					access: [APublic, AInline, AExtern, AOverload]
				});

				fields.push({
					name: 'disconnect',
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: 'handle', type: handleComplexType}],
						expr: macro {
							return handles.remove(handle);
						},
						ret: macro :Bool
					}),
					access: [APublic, AInline, AExtern, AOverload]
				});

				fields.push({
					name: 'disconnect',
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: 'signal', type: selfType}],
						expr: macro {
							return signals.remove(signal);
						},
						ret: macro :Bool
					}),
					access: [APublic, AInline, AExtern, AOverload]
				});

				fields.push({
					name: 'has',
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: 'handle', type: handleComplexType}],
						expr: macro {
							return handles.contains(handle);
						},
						ret: macro :Bool
					}),
					access: [APublic, AInline, AExtern, AOverload]
				});

				fields.push({
					name: 'has',
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: 'signal', type: selfType}],
						expr: macro {
							return signals.contains(signal);
						},
						ret: macro :Bool
					}),
					access: [APublic, AInline, AExtern, AOverload]
				});

				fields.push({
					name: 'clear',
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: 'deep', value: macro true, type: macro :Bool}],
						expr: macro {
							handles.resize(0);
							if (deep) {
								signals.resize(0);
							}
						},
						ret: macro :Void
					}),
					access: [APublic, AInline]
				});

				fields.push({
					name: 'emit',
					pos: Context.currentPos(),
					kind: FFun({
						args: handleArgs,
						expr: macro {
							for (handle in handles) {
								$handleCallExpr;
							}
							for (signal in signals) {
								$signalEmitExpr;
							}
						},
						ret: macro :Void
					}),
					access: [APublic, AInline]
				});

				Context.defineType({
					pack: fullPack,
					name: uniqueName,
					pos: Context.currentPos(),
					kind: TDClass(),
					params: classTypeParameterDecls.length > 0 ? classTypeParameterDecls : null,
					fields: fields
				});
				return complexType;
			default:
				return Context.error("Invalid usage of Signal", Context.currentPos());
		}
	}
}
#end
