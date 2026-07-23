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
    // This variable will be available throughout the lifetime of the coroutine for all steps.
    var number:Null<Int> = null;

    @:step {
        // Remember the last result.
        if (number != null) {
            trace('Last number ($number) was ${isEven(number) ? 'even' : 'odd'}.');
            coro.stop();
        } else {
            trace('We will be generating a random number and check if it is even or odd.');
        }

        // This variable is initially set to 0.0, but whenever we execute this step we set it to 3.14.
        @:overwrite(3.14) var pi = 0.0;

        @:step {
            // Load the variable pi from the previous step.
            @:load var pi;
            trace('Before we start here is a fun fact: pi is equal to $pi');
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
        trace('The number is odd.');
        // We have to explictly stop the coroutine here otherwise it will execute the very next step.
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
Before we start here is a fun fact: pi is equal to 3.14
(Tick 3)
Generating...
(Tick 4)
We generated the number 559976683.
(Tick 5)
The number is odd.
(Restart)(Tick 6)
Last number (559976683) was odd.
```

## Experimental
Experimental features are available in the experimental package. Those features HAVE NOT been polished yet and MIGHT NOT work as expected. Please don't use them in production. 