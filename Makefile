PKG_CONFIG ?= pkg-config
CFLAGS ?= -O2 -g
override CFLAGS += $(shell ${PKG_CONFIG} --cflags gtk+-3.0) $(shell ${PKG_CONFIG} --cflags gobject-introspection-1.0) -pthread -Wall
# LDLIBS = -ldl
CFLAGS_LIB = $(filter-out -fPIE -fpie -pie,$(CFLAGS)) -fPIC
LDFLAGS_LIB = $(filter-out -fPIE -fpie -pie,$(LDFLAGS)) -fPIC

prefix            ?= /usr/local
libdir            ?= $(prefix)/lib
bindir            ?= $(prefix)/bin
datadir           ?= ${prefix}/share
mandir            ?= $(datadir)/man
bashcompletiondir ?= ${datadir}/bash-completion/completions

all: libgtk3-nocsd.so gtk3-nocsd

clean:
	rm -f libgtk3-nocsd.so *.o gtk3-nocsd test-static-tls test-now *~
	[ ! -d testlibs ] || rm -r testlibs

libgtk3-nocsd.so: gtk3-nocsd.o
	$(CC) -shared $(CFLAGS_LIB) $(LDFLAGS_LIB) -Wl,-soname,libgtk3-nocsd.so -o $@ $^ $(LDLIBS)

gtk3-nocsd.o: gtk3-nocsd.c
	$(CC) $(CPPFLAGS) $(CFLAGS_LIB) -o $@ -c $<

gtk3-nocsd: gtk3-nocsd.in
	sed -e 's|@@libdir@@|$(libdir)|g' -e 's|@@prefix@@|$(prefix)|g' < $< > $@
	chmod +x $@

install:
	install -D -m 0644 libgtk3-nocsd.so $(DESTDIR)$(libdir)/libgtk3-nocsd.so
	install -D -m 0755 gtk3-nocsd $(DESTDIR)$(bindir)/gtk3-nocsd
	install -D -m 0644 gtk3-nocsd.1 $(DESTDIR)$(mandir)/man1/gtk3-nocsd.1
	install -D -m 0644 gtk3-nocsd.bash-completion $(DESTDIR)$(bashcompletiondir)/gtk3-nocsd

check: libgtk3-nocsd.so testlibs/stamp test-static-tls test-now
	@echo "RUNNING: test-symbols"
	@# Force LD_BIND_NOW to make sure we don't accidentally import
	@# any symbols from glib/gdk/gtk directly. (This ensures
	@# compatibility with software that is linked with -Wl,-z,now.)
	@LD_PRELOAD=./libgtk3-nocsd.so LD_BIND_NOW=1 ./test-now
	@echo "RUNNING: test-static-tls"
	@[ "$$(LD_PRELOAD= ./test-static-tls none)" = "$$(LD_PRELOAD=./libgtk3-nocsd.so ./test-static-tls gtk3-nocsd)" ] || \
		{ echo "   Without any library preloaded: can dlopen() up to the following number of libraries with static TLS:" ; \
		  echo -n "   " ; LD_PRELOAD= ./test-static-tls none ; \
		  echo "   With libgtk3-nocsd preloaded, can dlopen() up to the following number of libraries with static TLS:"; \
		  echo -n "   " ; LD_PRELOAD=./libgtk3-nocsd.so ./test-static-tls gtk3-nocsd ; \
		  echo "   These should match, but they don't." ; \
		  exit 1; \
		}

testlibs/stamp: test-dummylib.c
	@# Build a lot of dummy libraries. test-static-tls tries to load all
	@# of these libraries with dlopen(), which will fail at some point
	@# (because the DTV overflow entries are used up). Build a lot of
	@# them so even if the current default changes the cutoff point can
	@# be determined.
	mkdir -p testlibs
	for i in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
	         a b c d e f g h i j k l m n o p q r s t u v w x y z \
	         0 1 2 3 4 5 6 7 8 9 ; do \
	  $(CC) $(CPPFLAGS) $(CFLAGS_LIB) -ftls-model=initial-exec -DTESTLIB_NAME=$$i -c -o testlibs/libdummy-$$i.o test-dummylib.c ; \
	  $(CC) -shared $(CFLAGS_LIB) $(LDFLAGS_LIB) -Wl,-soname,libdummy-$$i.so -o testlibs/libdummy-$$i.so testlibs/libdummy-$$i.o $(LDLIBS) ; \
	done
	touch testlibs/stamp

test-static-tls: test-static-tls.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o test-static-tls test-static-tls.o $(LDLIBS)

test-now: test-now.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o test-now test-now.o $(LDLIBS)
