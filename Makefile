TOPDIR		= $(CURDIR)
SUBDIRS		= src
TARGETS		= hwinfo hwinfo.pc changelog
CLEANFILES	= hwinfo hwinfo.pc hwinfo.static hwscan hwscan.static hwscand hwscanqueue doc/libhd doc/*~
LIBS		= -lhd
SLIBS		= -lhd -luuid
TLIBS		= -lhd_tiny
SO_LIBS		= -luuid
TSO_LIBS	=

export SO_LIBS

GIT2LOG := $(shell if [ -x ./git2log ] ; then echo ./git2log --update ; else echo true ; fi)
GITDEPS := $(shell [ -d .git ] && echo .git/HEAD .git/refs/heads .git/refs/tags)
BRANCH  := $(shell [ -d .git ] && git branch | perl -ne 'print $$_ if s/^\*\s*//')
ifdef HWINFO_VERSION
VERSION := $(shell echo ${HWINFO_VERSION} > VERSION; cat VERSION)
else
VERSION := $(shell $(GIT2LOG) --version VERSION ; cat VERSION)
endif
PREFIX  := hwinfo-$(VERSION)

include Makefile.common

INSTALL_PREFIX = /usr

ifeq "$(ARCH)" "x86_64"
LIBDIR		?= $(INSTALL_PREFIX)/lib64
else ifeq "$(ARCH)" "loongarch64"
LIBDIR		?= $(INSTALL_PREFIX)/lib64
else
LIBDIR		?= $(INSTALL_PREFIX)/lib
endif
ULIBDIR		= $(LIBDIR)

# ia64
ifneq ($(filter i%86 x86_64, $(ARCH)),)
SLIBS		+= -lx86emu
TLIBS		+= -lx86emu
SO_LIBS		+= -lx86emu
TSO_LIBS	+= -lx86emu
endif

SHARED_FLAGS	=
OBJS_NO_TINY	= names.o parallel.o modem.o

.PHONY:	fullstatic static shared tiny doc diet tinydiet uc tinyuc

ifdef HWINFO_VERSION
changelog:
	@true
else
changelog: $(GITDEPS)
	$(GIT2LOG) --changelog changelog
endif

hwscan: hwscan.o $(LIBHD)
	$(CC) hwscan.o $(LDFLAGS) $(CFLAGS) $(LIBS) -o $@

hwinfo: hwinfo.o $(LIBHD)
	$(CC) hwinfo.o $(LDFLAGS) $(CFLAGS) $(LIBS) -o $@

hwscand: hwscand.o
	$(CC) $< $(LDFLAGS) $(CFLAGS) -o $@

hwscanqueue: hwscanqueue.o
	$(CC) $< $(LDFLAGS) $(CFLAGS) -o $@

hwinfo.pc: hwinfo.pc.in VERSION
	VERSION=`cat VERSION`; \
	sed -e "s,@VERSION@,$${VERSION},g" -e 's,@LIBDIR@,$(ULIBDIR),g;s,@LIBS@,$(LIBS),g' $< > $@.tmp && mv $@.tmp $@

# kept for compatibility
shared:
	@make

tiny:
	@make EXTRA_FLAGS=-DLIBHD_TINY LIBHD_BASE=libhd_tiny LIBS="$(TLIBS)" SO_LIBS="$(TSO_LIBS)"

tinyinstall:
	@make EXTRA_FLAGS=-DLIBHD_TINY LIBHD_BASE=libhd_tiny LIBS="$(TLIBS)" SO_LIBS="$(TSO_LIBS)" install

tinystatic:
	@make EXTRA_FLAGS=-DLIBHD_TINY LIBHD_BASE=libhd_tiny SHARED_FLAGS= LIBS="$(TLIBS)" SO_LIBS="$(TSO_LIBS)"

diet:
	@make CC="diet gcc" EXTRA_FLAGS="-fno-pic -DDIET" SHARED_FLAGS= LIBS="$(SLIBS)"

tinydiet:
	@make CC="diet gcc" EXTRA_FLAGS="-fno-pic -DLIBHD_TINY -DDIET" SHARED_FLAGS= LIBS="$(SLIBS)"

uc:
	@make CC="/opt/i386-linux-uclibc/bin/i386-uclibc-gcc" EXTRA_FLAGS="-fno-pic -DUCLIBC" SHARED_FLAGS= LIBS="$(SLIBS)"

tinyuc:
	@make CC="/opt/i386-linux-uclibc/usr/bin/gcc" EXTRA_FLAGS="-fno-pic -DLIBHD_TINY -DUCLIBC" SHARED_FLAGS= LIBS="$(SLIBS)"

static:
	make SHARED_FLAGS= LIBS="$(SLIBS)"

fullstatic: static
	$(CC) -static hwinfo.o $(LDFLAGS) $(SLIBS) -o hwinfo.static
	strip -R .note -R .comment hwinfo.static

doc:
	@cd doc ; doxygen libhd.doxy

install:
	install -d -m 755 $(DESTDIR)$(INSTALL_PREFIX)/sbin $(DESTDIR)$(ULIBDIR) \
		$(DESTDIR)$(ULIBDIR)/pkgconfig $(DESTDIR)$(INSTALL_PREFIX)/include
	install -m 755 hwinfo $(DESTDIR)$(INSTALL_PREFIX)/sbin
	install -m 755 src/ids/check_hd $(DESTDIR)$(INSTALL_PREFIX)/sbin
	install -m 755 src/ids/convert_hd $(DESTDIR)$(INSTALL_PREFIX)/sbin
	if [ -f $(LIBHD_SO) ] ; then \
		install $(LIBHD_SO) $(DESTDIR)$(ULIBDIR) ; \
		ln -snf $(LIBHD_NAME) $(DESTDIR)$(ULIBDIR)/$(LIBHD_SONAME) ; \
		ln -snf $(LIBHD_SONAME) $(DESTDIR)$(ULIBDIR)/$(LIBHD_BASE).so ; \
	else \
		install -m 644 $(LIBHD) $(DESTDIR)$(ULIBDIR) ; \
	fi
	install -m 644 hwinfo.pc $(DESTDIR)$(ULIBDIR)/pkgconfig
	install -m 644 src/hd/hd.h $(DESTDIR)$(INSTALL_PREFIX)/include
	perl -pi -e "s/define\s+HD_VERSION\b.*/define HD_VERSION\t\t$(LIBHD_MAJOR_VERSION)/" $(DESTDIR)$(INSTALL_PREFIX)/include/hd.h
	perl -pi -e "s/define\s+HD_MINOR_VERSION\b.*/define HD_MINOR_VERSION\t$(LIBHD_MINOR_VERSION)/" $(DESTDIR)$(INSTALL_PREFIX)/include/hd.h
	install -m 755 getsysinfo $(DESTDIR)$(INSTALL_PREFIX)/sbin
	install -m 755 src/isdn/cdb/mk_isdnhwdb $(DESTDIR)$(INSTALL_PREFIX)/sbin
	install -d -m 755 $(DESTDIR)$(INSTALL_PREFIX)/share/hwinfo
	install -d -m 755 $(DESTDIR)/var/lib/hardware/udi
	install -m 644 src/isdn/cdb/ISDN.CDB.txt $(DESTDIR)$(INSTALL_PREFIX)/share/hwinfo
	install -m 644 src/isdn/cdb/ISDN.CDB.hwdb $(DESTDIR)$(INSTALL_PREFIX)/share/hwinfo

archive: changelog
	@if [ ! -d .git ] ; then echo no git repo ; false ; fi
	mkdir -p package
	git archive --prefix=$(PREFIX)/ $(BRANCH) > package/$(PREFIX).tar
	tar -r -f package/$(PREFIX).tar --mode=0664 --owner=root --group=root --mtime="`git show -s --format=%ci`" --transform='s:^:$(PREFIX)/:' VERSION changelog src/hd/hd.h
	xz -f package/$(PREFIX).tar
