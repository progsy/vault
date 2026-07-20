# Vault
Vault is a game-oriented library which contains a set of essential modules for game development. Some of the notable modules are:
- vault.behavior.**Coroutine**: Macro-powered coroutines with support for labels and jumping.
- vault.behavior.**Signal**: General-purpose event dispatcher that supports variadic type parameters and nesting.
- vault.behavior.**Schedule**: Sequential executor for tasks/jobs.
- vault.data.**StructOfArrays** & vault.data.**StructOfVectors**: Alternative cache-friendly containers.
- vault.macro.**JsonClass**: Allows you to inject class fields from a json file at compile time with optional runtime reloading support.

## Installation
``haxelib git vault https://github.com/progsy/vault.git``

## Example
### Coroutine
```haxe
var coro = new vault.behavior.Coroutine();

inline function isEven(num:Int):Bool {
    return num % 2 == 0;
}

coro.set({
    // This variable will be available throughout the lifetime of this coroutine.
    var number:Null<Int> = null;

    @:step {
        // Remember the last result.
        if (number != null) {
            trace('Last number ($number) was ${isEven(number) ? 'even' : 'odd'}.');
            coro.stop();
        } else {
            trace('We will be generating a random number and check if it is even or odd.');
        }
    };

    @:step {
        number = Std.random(0x4FFFFFFF);
        trace('We generated the number $number.');
        if (isEven(number)) {
            coro.jump("Even");
        }
    };

    @:step {
        trace('The number is odd.');
        // We have to explictly stop the coroutine otherwise it will execute the next step.
        coro.stop();
    }

    // We can label the step to enable jumping
    @:step("Even") {
        trace('The number is even.');
    }
});
trace('(Tick 1)');
coro.run();
trace('(Tick 2)');
coro.resume();
trace('(Tick 3)');
coro.resume();
trace('(Tick 4)');
coro.restart();
```
This should output something like:
```
(Tick 1)
We will be generating a random number and check if it is even or odd.
(Tick 2)
We generated the number 923949475.
(Tick 3)
The number is odd.
(Tick 4)
Last number (923949475) was odd.
```

## Experimental
Experimental features are available in the experimental package. Those features HAVE NOT been polished yet and MIGHT NOT work as expected. Please don't use them in production. 