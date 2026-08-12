package vault.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

class System {
	static function build():Array<Field> {
		var fields:Array<Field> = [];
		var buildFields = Context.getBuildFields();
		var type = Context.getLocalType();
		var complexType = type.toComplexType();
		var componentArrays:Array<{
			name:String,
			type:ComplexType,
			typePath:TypePath,
			componentType:Type
		}> = [];

		function addComponentArray(name:String, componentType:Type) {
			var componentArray:{
				name:String,
				type:ComplexType,
				typePath:TypePath,
				componentType:Type
			} = {
				name: name,
				type: null,
				typePath: null,
				componentType: componentType
			};

			switch (componentType.followWithAbstracts()) {
				case TAbstract(_.get() => t, params):
					componentArray.type = macro :haxe.ds.Vector;
				default:
					componentArray.type = macro :vault.data.StructOfVectors;
			}
			switch (componentArray.type) {
				case TPath(p):
					p.params = [TPType(componentType.toComplexType())];
					componentArray.typePath = p;
				default:
					Context.error('Something wrong happened', Context.currentPos());
			}

			var suffixIndex = componentArray.name.indexOf('Component');
			suffixIndex = suffixIndex == -1 ? componentArray.name.indexOf('Comp') : suffixIndex;
			if (suffixIndex != -1) {
				componentArray.name = componentArray.name.substring(0, suffixIndex);
			}
			componentArray.name = componentArray.name.substring(0, 1).toLowerCase() + componentArray.name.substring(1);
			componentArrays.push(componentArray);
		}

		addComponentArray('InternalStatusComponent', Context.getType('vault.behavior.System.InternalStatusComponent'));
		switch (type.followWithAbstracts()) {
			case TInst(_.get() => t, params):
				for (m in t.meta.get()) {
					if (m.name == ":component" || m.name == ":c" || m.name == ":comp") {
						var componentType:Type = null;
						var componentTypeName:String = '';
						if (m.params == null) {
							Context.error('You must specify component type', m.pos);
						}
						if (m.params.length != 1) {
							Context.error('You must specify exactly one component type', m.pos);
						}

						var ps = m.params[0].toString();
						if (ps.indexOf('<') != -1) {
							Context.error('Component types must not contain type parameters', m.params[0].pos);
						}
						try {
							componentType = Context.getType(ps);
						} catch (e) {
							Context.error('Could not find type ($ps)', m.params[0].pos);
						}

						switch (componentType) {
							case TInst(_.get() => ct, _):
								componentTypeName = ct.name;
							case TAbstract(_.get() => ct, _):
								componentTypeName = ct.name;
							case TType(_.get() => ct, _):
								componentTypeName = ct.name;
							default:
						}

						addComponentArray(componentTypeName, componentType);
					}
				}
			default:
				Context.error('The system must be a class', Context.currentPos());
		}

		fields.push({
			name: "capacity",
			kind: FProp("default", "null", macro :Int),
			access: [APublic],
			pos: Context.currentPos()
		});

		fields.push({
			name: "count",
			kind: FProp("default", "null", macro :Int),
			access: [APublic],
			pos: Context.currentPos()
		});

		fields.push({
			name: "activeIndices",
			kind: FVar(macro :Array<Int>),
			access: [APrivate],
			pos: Context.currentPos()
		});

		fields.push({
			name: "freeIndices",
			kind: FVar(macro :Array<Int>),
			access: [APrivate],
			pos: Context.currentPos()
		});

		fields.push({
			name: "nextFreeIndexIndex",
			kind: FVar(macro :Int),
			access: [APrivate],
			pos: Context.currentPos()
		});

		fields.push({
			name: "ticks",
			kind: FVar(macro :Int),
			access: [APrivate],
			pos: Context.currentPos()
		});

		var setupExprs:Array<Expr> = [];
		for (componentArray in componentArrays) {
			var tp = componentArray.typePath;
			fields.push({
				name: componentArray.name,
				kind: FProp("default", "null", componentArray.type),
				access: [APublic],
				pos: Context.currentPos()
			});
			setupExprs.push(macro $i{componentArray.name} = new $tp(capacity));
		}

		fields.push({
			name: "setup",
			kind: FFun({
				args: [{name: "capacity", type: macro :Int}],
				ret: macro :Void,
				expr: macro {
					if (capacity < 1) {
						throw 'Capacity must be higher than zero';
					}
					$b{setupExprs};
					activeIndices = [];
					freeIndices = [for (i in 0...capacity) i];
					nextFreeIndexIndex = 0;
					ticks = 0;
					this.capacity = capacity;
				},
			}),
			pos: Context.currentPos(),
			access: [APrivate]
		});

		fields.push({
			name: "createUnit",
			kind: FFun({
				args: [],
				ret: macro :vault.behavior.Unit<$complexType>,
				expr: macro {
					if (count < capacity) {
						var lastIndex = freeIndices.pop();
						var index = freeIndices[nextFreeIndexIndex];
						freeIndices[nextFreeIndexIndex] = lastIndex;
						nextFreeIndexIndex = (nextFreeIndexIndex + 1) % freeIndices.length;
						internalStatus.activeArrayIndex[index] = activeIndices.length;
						internalStatus.active[index] = true;
						activeIndices.push(index);
						count++;
						return new vault.behavior.Unit(index, ++internalStatus.generation[index]);
					}
					return vault.behavior.Unit.getInvalid();
				},
			}),
			pos: Context.currentPos(),
			access: [APublic]
		});

		fields.push({
			name: "destoryUnit",
			kind: FFun({
				args: [{name: "unit", type: macro :vault.behavior.Unit<$complexType>}],
				ret: macro :Bool,
				expr: macro {
					if (isUnitValid(unit)) {
						var lastIndex = activeIndices.pop();
						activeIndices[internalStatus.activeArrayIndex[unit.index]] = lastIndex;
						freeIndices.push(unit.index);
						internalStatus.active[unit.index] = false;
						count--;
						return true;
					}
					return false;
				},
			}),
			pos: Context.currentPos(),
			access: [APublic]
		});

		fields.push({
			name: "isUnitValid",
			kind: FFun({
				args: [{name: "unit", type: macro :vault.behavior.Unit<$complexType>}],
				ret: macro :Bool,
				expr: macro {
					return unit.index < capacity ? (internalStatus.active[unit.index]
						&& unit.generation == internalStatus.generation[unit.index]) : false;
				},
			}),
			pos: Context.currentPos(),
			access: [APublic, AInline]
		});

		var hasUpdate:Bool;
		var updateFunctionExpr:Expr;
		for (bf in buildFields) {
			if (bf.name == "update") {
				hasUpdate = true;
				switch (bf.kind) {
					case FFun(f):
						updateFunctionExpr = f.expr;
					default:
				}
			}
		}

		var subUpdates:Array<{name:String, frequency:Int}> = [];
		for (bf in buildFields) {
			if (bf.meta != null) {
				switch (bf.kind) {
					case FFun(f):
						for (m in bf.meta) {
							if (m.name == ":update" || m.name == ":up" || m.name == ":u") {
								if (f.args.length != 1) {
									Context.warning('Update functions must have 1 argument (dt:Float)', bf.pos);
									continue;
								}
								if (f.args[0].name != 'dt') {
									Context.warning('Argument name must be dt', bf.pos);
									continue;
								}
								if (f.args[0].type.toString() != 'Float') {
									Context.warning('Argument type must be Float', bf.pos);
									continue;
								}
								var frequency:Int = 1;
								if (m.params != null) {
									if (m.params.length > 0) {
										try {
											frequency = m.params[0].getValue();
										} catch (e) {
											Context.error(e.message, m.params[0].pos);
										}
									}
								}
								subUpdates.push({name: bf.name, frequency: frequency});
								bf.access.push(AInline);

								if (frequency > 1) {
									fields.push({
										name: '__${bf.name}Dt',
										kind: FVar(macro :Float),
										access: [APrivate],
										pos: Context.currentPos()
									});
								}
							}
						}
					default:
				}
			}
		}

		var updateExpr = macro {
			${
				for (su in subUpdates) {
					if (su.frequency > 1) {
						macro {
							$i{'__${su.name}Dt'} += dt;
							if (ticks % $v{su.frequency} == 0 && ticks >= $v{su.frequency}) {
								$i{su.name}($i{'__${su.name}Dt'});
								$i{'__${su.name}Dt'} = 0.0;
							}
						}
					} else {
						macro $i{su.name}(dt);
					}
				}
			}
		};
		if (!hasUpdate) {
			fields.push({
				name: "update",
				kind: FFun({
					args: [{name: "dt", type: macro :Float}],
					ret: macro :Void,
					expr: macro {
						ticks++;
						$updateExpr;
					},
				}),
				pos: Context.currentPos(),
				access: [APublic]
			});
		} else {
			updateFunctionExpr = macro {
				ticks++;
				$updateFunctionExpr;
				$updateExpr;
			}
		}

		return buildFields.concat(fields);
	}
}
#end
