all: src/ppx_trace_log.ml
	make -C src $@
	mkdir -p bin
	cp -f src/_build/ppx_trace_log.native bin/ppx_trace_log.native

test: all
	ocamlfind ppx_tools/rewriter bin/ppx_trace_log.native tests/test_ppx_trace_log.ml 
