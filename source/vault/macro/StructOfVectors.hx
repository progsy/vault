package vault.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Context.makeExpr;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypedExprTools;
using StringTools;

class StructOfVectors {
	static function build():ComplexType {
		var type = Context.getLocalType();

		switch (type) {
			case TInst(_.get() => cl, params):
				var structTypes:Array<Type> = [];
				var optionalStructTypes:Array<Type> = [];
				var fields = Context.getBuildFields();
				var typeFields:Array<{
					name:String,
					sourceName:String,
					type:ComplexType,
					optional:Bool,
					ignore:Bool,
					expr:Expr
				}> = [];
				var typeParamComplexTypes = [for (p in params) p.toComplexType()];
				var uniqueName = "StructOfVectors";
				var fullPack = ["vault", "data"];

				if (params.length == 0) {
					Context.error('No type paramaters were found', Context.currentPos());
				}

				var classTypeParameterDecls:Array<TypeParamDecl> = [];
				var classTypeParameters:Array<TypeParam> = [];

				var nextOptional = false;
				var lastExpr = null;

				function checkTypeMeta(expr:Expr) {
					switch (expr.expr) {
						case EMeta(s, e):
							if (s.name == ':optional') {
								nextOptional = true;
							}
							lastExpr = e;
							e.iter(checkTypeMeta);
						default:
					}
				}

				for (i in 0...params.length) {
					var param = params[i].followWithAbstracts();
					switch (param) {
						case TInst(_.get() => structDefType, structTypeParams):
							switch (structDefType.kind) {
								case KExpr(expr):
									checkTypeMeta(expr);
									if (lastExpr != null) {
										Context.typeExpr(lastExpr);
										var typeName = lastExpr.toString();
										var structType = Context.getType(typeName).followWithAbstracts();
										uniqueName += "_" + typeName.replace('.', '');
										for (i in 0...structDefType.params.length) {
											classTypeParameterDecls.push({name: structDefType.params[i].name});
											classTypeParameters.push(TPType(structDefType.params[i].t.toComplexType()));
										}
										if (nextOptional) {
											optionalStructTypes.push(structType);
										} else {
											structTypes.push(structType);
										}
										nextOptional = false;
									}
									lastExpr = null;
									params[i] = null;
								default:
									var structType = param;
									structTypes.push(structType);
									uniqueName += "_" + structDefType.pack.join('') + structDefType.name;
									for (i in 0...structDefType.params.length) {
										classTypeParameterDecls.push({name: structDefType.params[i].name});
										classTypeParameters.push(TPType(structDefType.params[i].t.toComplexType()));
									}
							}
						default:
					}
				}

				var complexType = TPath({
					pack: fullPack,
					name: uniqueName,
					params: classTypeParameters.length > 0 ? classTypeParameters : null
				});

				try {
					var existingPath = fullPack.join(".") + "." + uniqueName;
					Context.getType(existingPath);
					return complexType;
				} catch (e) {}

				var allStructTypes:Array<Type> = structTypes.concat(optionalStructTypes);

				for (i in 0...allStructTypes.length) {
					var structType = allStructTypes[i];
					var structComplexType = structType.toComplexType();

					switch (structType) {
						case TInst(_.get() => t, tps):
							for (f in t.fields.get()) {
								var capitalizeInitialLetter = f.name.charAt(0).toUpperCase();
								var nameRest = f.name.substring(1);
								var fieldName = f.name;
								var typedExpr = f.expr();

								switch (f.kind) {
									case FMethod(_):
										continue;
									case FVar(read, write) if ((read == AccCall && write == AccCall)
										|| (read == AccCall && write == AccNever)):
										continue;
									default:
								}

								typeFields.push({
									name: fieldName,
									sourceName: f.name,
									optional: f.meta.has(":optional") || optionalStructTypes.contains(structType),
									ignore: f.meta.has(":ignore"),
									type: f.type.toComplexType(),
									expr: typedExpr != null ? Context.getTypedExpr(typedExpr) : null
								});
							}
						default:
							Context.error('Unsupported type: $structType', Context.currentPos());
					}
				}

				var constructorExprs:Array<Expr> = [];
				var clearExprs:Array<Expr> = [];
				var removeAtExprs:Array<Expr> = [];
				var popExprs:Array<Expr> = [];
				var shiftExprs:Array<Expr> = [];
				var pushExprs:Array<Expr> = [];
				var insertExprs:Array<Expr> = [];
				var shiftArrayExprs:Array<Expr> = [];
				var pushArrayExprs:Array<Expr> = [];
				var pushArrayExprs:Array<Expr> = [];
				var insertArrayExprs:Array<Expr> = [];
				var pushArgs:Array<FunctionArg> = [];
				var insertArgs:Array<FunctionArg> = [{name: "index", type: macro :Int}];

				for (f in typeFields) {
					var fieldName = f.name;
					var fieldSourceName = f.sourceName;
					var fieldType = f.type;
					var fieldExpr = f.expr;
					var typePath:TypePath = {
						pack: ["haxe", "ds"],
						name: "Vector",
						params: [TPType(f.type)]
					};

					fields.push({
						name: f.name,
						kind: FieldType.FProp("default", "null", TPath(typePath)),
						pos: Context.currentPos(),
						access: [APublic]
					});

					if (["Int", "Float", "Bool"].contains(fieldType.toType().toString()) && fieldExpr != null) {
						constructorExprs.push(macro this.$fieldName = new $typePath(this.capacity = capacity, $fieldExpr));
					} else {
						constructorExprs.push(macro this.$fieldName = new $typePath(this.capacity = capacity));
					}

					shiftArrayExprs.push(macro this.$fieldName[i - 1] = this.$fieldName[i]);
					removeAtExprs.push(macro {
						var lastIndex = this.length - 1;
						if (lastIndex >= 0) {
							this.$fieldName[index] = this.$fieldName[lastIndex];
						}
					});
					if (!f.ignore) {
						pushArgs.push({name: fieldSourceName, type: fieldType, opt: f.optional});
						insertArgs.push({name: fieldSourceName, type: fieldType, opt: f.optional});

						pushArrayExprs.push(macro this.$fieldName[index] = $i{fieldSourceName});
						insertArrayExprs.push(macro {
							var old = this.$fieldName[index];
							this.$fieldName[index] = $i{fieldSourceName};
							this.$fieldName[length] = old;
						});
					}
				}

				clearExprs.push(macro length = 0);
				popExprs.push(macro var index = length - 1);
				popExprs.push(macro if (index >= 0) {
					length--;
				});
				popExprs.push(macro return index);
				shiftExprs.push(macro if (length > 0) {
					for (i in 1...length) {
						$b{shiftArrayExprs};
					}
					length--;
				});
				pushExprs.push(macro var index = length);
				pushExprs.push(macro if (index < capacity) {
					$b{pushArrayExprs};
					length++;
				});
				pushExprs.push(macro return index);
				insertExprs.push(macro if (index < length && length + 1 < capacity) {
					$b{insertArrayExprs};
					length++;
				});

				fields.push({
					name: "new",
					pos: Context.currentPos(),
					kind: FFun({
						args: [{name: "capacity", type: macro :Int}],
						expr: macro {
							$b{constructorExprs};
						}
					}),
					access: [APublic]
				});

				fields.push({
					name: "capacity",
					kind: FieldType.FProp("default", "null", macro :Int),
					pos: Context.currentPos(),
					access: [APublic]
				});

				fields.push({
					name: "length",
					kind: FieldType.FProp("default", "null", macro :Int),
					pos: Context.currentPos(),
					access: [APublic]
				});

				fields.push({
					name: "clear",
					kind: FieldType.FFun({
						args: [],
						ret: macro :Void,
						expr: macro $b{clearExprs}
					}),
					pos: Context.currentPos(),
					access: [APublic, AInline]
				});

				fields.push({
					name: "removeAt",
					kind: FieldType.FFun({
						args: [{name: "index", type: macro :Int}],
						ret: macro :Void,
						expr: macro $b{removeAtExprs}
					}),
					pos: Context.currentPos(),
					access: [APublic, AInline]
				});

				fields.push({
					name: "push",
					kind: FieldType.FFun({
						args: pushArgs,
						ret: macro :Int,
						expr: macro $b{pushExprs}
					}),
					pos: Context.currentPos(),
					access: [APublic, AInline]
				});

				fields.push({
					name: "insert",
					kind: FieldType.FFun({
						args: insertArgs,
						ret: macro :Void,
						expr: macro $b{insertExprs}
					}),
					pos: Context.currentPos(),
					access: [APublic, AInline]
				});

				fields.push({
					name: "pop",
					kind: FieldType.FFun({
						args: [],
						ret: macro :Int,
						expr: macro $b{popExprs}
					}),
					pos: Context.currentPos(),
					access: [APublic, AInline]
				});

				fields.push({
					name: "shift",
					kind: FieldType.FFun({
						args: [],
						ret: macro :Void,
						expr: macro $b{shiftExprs}
					}),
					pos: Context.currentPos(),
					access: [APublic, AInline]
				});

				var typeDef:TypeDefinition = {
					pack: fullPack,
					name: uniqueName,
					pos: Context.currentPos(),
					kind: TDClass(),
					fields: fields
				};

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
				return Context.error("Invalid usage of StructOfVectors", Context.currentPos());
		}
	}
}
#end
