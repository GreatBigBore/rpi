PROGRAMS = SansIf

ifneq ($(MAKECMDGOALS),)
PROGRAMS = $(MAKECMDGOALS)
endif

all: $(PROGRAMS)

$(PROGRAMS): % : %.o
	ld -o $@ $<
	
clean:
	rm -f *.o $(PROGRAMS)
	
