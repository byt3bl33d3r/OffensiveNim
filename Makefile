vpath %.exe bin/
vpath %.dll bin/
vpath %.nim src/

#NIMFLAGS = -d=danger -d=mingw -d=strip --passc=-flto --passl=-flto --opt=size
NIMFLAGS = -d=debug -d=mingw --embedsrc=on --hints=on

SRCS_BINS = $(notdir $(filter-out $(wildcard src/linux_*), $(wildcard src/*_bin.nim)))
SRCS_LIBS = $(notdir $(filter-out $(wildcard src/linux_*), $(wildcard src/*_lib.nim)))
BINS = $(patsubst %.nim,%.exe,$(SRCS_BINS))
DLLS = $(patsubst %.nim,%.dll,$(SRCS_LIBS))

.PHONY: clean

default: build

build: $(BINS) $(DLLS)

rebuild: clean build

clean:
	rm -rf bin/*.exe bin/*.dll

%.exe : %.nim
	echo $*

%.dll: %.nim
	echo $*