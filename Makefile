GSC		=	gsc
GSI		=	gsi
MAKE		=	make
INSTALL		= 	cp
COPY		=	cp
REMOVE		=	rm
CC		=	gcc
MAKEDIR		=	mkdir

CC_OPTIONS	=	-D___DYNAMIC -O3

LIBNAME		= 	persistent
SRCDIR		= 	src
BUILDDIR	= 	build
TESTDIR		= 	test
DIR		=	ls

SOURCES		=	$(shell ls ${SRCDIR}/*[a-zA-Z0-9].scm)
INCLUDES	=	$(shell ls ${SRCDIR}/*\#.scm)
CFILES		= 	$(SOURCES:.scm=.c)
OFILES		=	$(CFILES:.c=.o)

LINKFILE	=	$(SRCDIR)/$(LIBNAME).o1
CLINKFILE	=	$(LINKFILE:.o1=.o1.c)
OLINKFILE	=	$(CLINKFILE:.c=.o)

INSTALLDIR	= 	$(shell ${GSI} -e "(display (path-expand \"~~${LIBNAME}\"))")

TEST_FILES	= 	$(shell ls ${TESTDIR}/*test.scm)

all: builddir

clean: 
	-$(REMOVE) $(SRCDIR)/*~
	-$(REMOVE) $(CFILES)
	-$(REMOVE) $(OFILES)
	-$(REMOVE) $(CLINKFILE)
	-$(REMOVE) $(OLINKFILE)
	-$(REMOVE) $(LINKFILE)
	-$(REMOVE) $(INC_LINKFILE)
	-$(REMOVE) -r $(BUILDDIR)

builddir: $(LINKFILE) $(BUILDDIR)
	$(COPY) $(LINKFILE) $(BUILDDIR)
	$(COPY) -r $(INCLUDES) $(BUILDDIR)

%.o: %.c
	$(GSC) -cc-options "${CC_OPTIONS}" -obj -o $@ $<

%.c: %.scm
	$(GSC) -c -o $@ $<

$(LINKFILE): $(OLINKFILE) $(OFILES)
	@echo "Doing $(LINKFILE)"
	$(CC) -shared $(OFILES) $(OLINKFILE) -o $(LINKFILE)

$(OLINKFILE): $(CLINKFILE)
	$(GSC) -cc-options "${CC_OPTIONS}" -obj -o $(OLINKFILE) $(CLINKFILE)

$(CLINKFILE): 
	$(GSC) -link -flat -o $(CLINKFILE) $(SOURCES)

$(BUILDDIR):
	$(MAKEDIR) $(BUILDDIR)

$(INSTALLDIR):
	-$(MAKEDIR) $(INSTALLDIR)

install: builddir $(INSTALLDIR)
	-@echo "installing '${LIBNAME}' in:"
	-@echo $(INSTALLDIR)

test: builddir
	$(GSI) -:~~$(LIBNAME)=$(BUILDDIR) ~~$(LIBNAME)/$(LIBNAME) $(TEST_FILES)
