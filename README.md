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
    // This variable will be available throughout the lifetime of the coroutine.
    var number:Null<Int> = null;
    // This variable is only accessible form "Odd" step.
    @:scope("Odd") var onlyInOdd:Bool;

    @:step {
        // Remember the last result.
        if (number != null) {
            trace('Last number ($number) was ${isEven(number) ? 'even' : 'odd'}.');
            coro.stop();
        } else {
            trace('We will be generating a random number and check if it is even or odd.');
        }
        // We can have nested steps (with caveats).
        @:step {
            trace('Are you ready?');
            @:step {
                trace('Good.');
            }
        }
        @:step {
            trace('Generating...');
        }
    };

    @:step {
        number = Std.random(0x4FFFFFFF);
        trace('We generated the number $number.');
        if (isEven(number)) {
            // We skip "Odd" and jump directly to "Even".
            coro.jump("Even");
        }
    };

    // We can label the step to enable jumping
    @:step("Odd") {
        onlyInOdd = true;
        trace('The number is odd.');
         // We have to explictly stop the coroutine otherwise it will execute the very next step.
        coro.stop();
    }

    @:step("Even") {
        trace('The number is even.');
    }
});
trace('(Start)(Tick 1)');
coro.run();
for (i in 1...coro.instructionCount - 1) {
    trace('(Tick ${i + 1})');
    coro.resume();
}
trace('(Restart)(${coro.instructionCount})');
coro.restart();
```
This should output something like:
```
(Start)(Tick 1)
We will be generating a random number and check if it is even or odd.
(Tick 2)
Are you ready?
(Tick 3)
Good.
(Tick 4)
Generating...
(Tick 5)
We generated the number 559976683.
(Tick 6)
The number is odd.
(Restart)(Tick 7)
Last number (559976683) was odd.
```
Nesting is possible but nested variables will not be captured as they are considered local.

## Experimental
Experimental features are available in the experimental package. Those features HAVE NOT been polished yet and MIGHT NOT work as expected. Please don't use them in production. 