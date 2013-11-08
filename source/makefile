ifeq ($(MAKECMDGOALS),)
$(error Specify a source file)
endif

$(MAKECMDGOALS) : $(MAKECMDGOALS).o
	ld -o ~/bin/$@ /tmp/$<

$(MAKECMDGOALS).o : $(MAKECMDGOALS).s
	as -o /tmp/$@ $<

