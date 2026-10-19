CC ?= cc
CFLAGS ?= -O2
CPPFLAGS ?=
PREFIX ?= /opt/proot-sphal
DESTDIR ?=
HYBRIS_PREFIX ?= $(PREFIX)

WARNINGS := -Wall -Wextra -Werror

.PHONY: all check install clean

all: .build/libproot-sphal.so.0 .build/sphal-probe

.build/libproot-sphal.so.0: src/proot_sphal.c include/proot_sphal.h
	mkdir -p .build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARNINGS) -fPIC -shared \
		-Wl,-soname,libproot-sphal.so.0 -Iinclude $< \
		-L$(HYBRIS_PREFIX)/lib -lhybris-common -o $@

.build/sphal-probe: tools/sphal-probe.c .build/libproot-sphal.so.0
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARNINGS) -Iinclude $< \
		-L.build -L$(HYBRIS_PREFIX)/lib \
		-Wl,-rpath-link,$(HYBRIS_PREFIX)/lib \
		-l:libproot-sphal.so.0 -lhybris-common -o $@

check: .build/test-loader
	./.build/test-loader

.build/test-loader: tests/test_loader.c src/proot_sphal.c include/proot_sphal.h
	mkdir -p .build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARNINGS) -Iinclude \
		tests/test_loader.c src/proot_sphal.c -o $@

install: all
	install -d $(DESTDIR)$(PREFIX)/include $(DESTDIR)$(PREFIX)/lib \
		$(DESTDIR)$(PREFIX)/bin
	install -m 0644 include/proot_sphal.h $(DESTDIR)$(PREFIX)/include/
	install -m 0755 .build/libproot-sphal.so.0 $(DESTDIR)$(PREFIX)/lib/
	ln -sfn libproot-sphal.so.0 $(DESTDIR)$(PREFIX)/lib/libproot-sphal.so
	install -m 0755 .build/sphal-probe $(DESTDIR)$(PREFIX)/bin/

clean:
	rm -rf .build
