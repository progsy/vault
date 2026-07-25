# Vault
Vault is a game-oriented library which contains a set of essential modules for game development. Some of the notable modules are:
- vault.behavior.**Coroutine**: Macro-powered coroutines with advanced features and low overhead.
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
    // Those variables will be available throughout the lifetime of the coroutine for all steps.
    // The reset metadata allows the variable to be reset to its initial value when coro.resetVariables is called.
    @:reset var number:Int = -1;
    @:reset var cancelledBefore:Bool = false;

    @:step {
        // Remember the last result.
        if (number != -1) {
            trace('Last number ($number) was ${isEven(number) ? 'even' : 'odd'}.');
            // Stop the coroutine. We have to run it again with coro.run
            return;
        } else if (cancelledBefore) {
            trace('You refused to proceed.');
            return;
        }
        trace('We will be generating a number and check if it is even or odd. Send true to proceed or false to cancel.');

        // This variable is initially set to 0.0, but whenever we execute this line we set it to 3.14. If we never reach this line pi might remain 0.0
        @:overwrite(3.14) var pi = 0.0;

        @:step {
            // Check if anything was sent via coro.send
            if (coro.incoming() == 0) {
                trace('Please send something.');
                // Stick to this step.
                return 0;
            }
            // Validate the incoming data types.
            if (!coro.validate(Bool)) {
                trace('Send a boolean, please.');
                return 0;
            }

            var shallProceed:Bool;
            // Read the data that was previously sent via coro.send. Variables must be in the same order in which they were sent.
            coro.accept(shallProceed);
            if (!shallProceed) {
                trace('We shall not proceed.');
                cancelledBefore = true;
                return;
            }

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
            // We skip "Odd" and jump directly to "Even". This is a safe equivalent to coro.jump("Even")
            return "Even";
        }
    };

    // We can label the step to enable jumping
    @:step("Odd") {
        trace('The number is odd.');
        return;
    }

    @:step("Even") {
        trace('The number is even.');
    }
});

var ticks = 1;
trace('(Start)(Tick $ticks)');
coro.run();
coro.send(true);
for (i in 1...coro.instructionCount - 1) {
    if (!coro.running) {
        break;
    }
    trace('(Tick ${++ticks})');
    coro.resume();
}
trace('(Restart)(Tick ${++ticks})');
coro.restart();
```
This should output something like:
```
(Start)(Tick 1)
We will be generating a number and check if it is even or odd. Send true to proceed or false to cancel.
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
Alternatively if we sent false:
```
(Start)(Tick 1)
We will be generating a number and check if it is even or odd. Send true to proceed or false to cancel.
(Tick 2)
We shall not proceed.
(Restart)(Tick 3)
You refused to proceed.
```

## Experimental
Experimental features are available in the experimental package. Those features HAVE NOT been polished yet and MIGHT NOT work as expected. Please don't use them in production. 