# ppx_trace_log
Syntax extension to insert or ignore logging statements

This syntax extension is modeled after Camlp4DebugParser. More
documentation to follow, this just in brief.

When in use, turn ```@trace``` attributes of expressions into 
logging statements. Replace each attributed expression 
```
expr [@trace sect fmt args]
```
with
```OCaml
let __ppx_trace_log_res = expr in
	Trace.log sect fmt args; 
__ppx_trace_log_res
```

Multiple ```@trace``` attributes for the same expression are
supported, other attributes of the expression are preserved.

The ```sect``` parameter is a lowercase identifier for a tracing
section, and is passed to the ```Trace.log``` function to enable and
disable traces at runtime.

The ```fmt``` parameter is a format string, and ```args``` are the
parameters to the format string.

The ```Trace.log``` function is intended to wrap around a
```Format.printf``` with ```fmt``` and ```args``` as
parameters. Before that, it should consult the ```sect``` parameter
whether to ignore the output. See [examples/trace.ml].

Individual tracing sections can be enabled or disabled at compile
time. No calls to ```Trace.log``` will be generated for disabled
sections.

Since ```@trace``` is an attribute, compiling without the
pre-processor will simply ignore the attribute, and it will not be
visible in the compiled code.
