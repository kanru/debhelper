# This generates a list of synopses of debhelper commands, and substitutes
# it in to the #LIST# line on the man page fed to it on stdin. Must be passed
# parameters of all the executables or pod files to get the synopses from.
# For correct conversion of pod tags (like S< >) #LIST# must be substituted in
# the pod file and not in the troff file.
MAKEMANLIST=perl -e ' \
		undef $$/; \
		foreach (@ARGV) { \
		        open (IN, $$_) or die "$$_: $$!"; \
		        $$file=<IN>; \
		        close IN; \
		        if ($$file=~m/=head1 .*?\n\n(.*?) - (.*?)\n\n/s) { \
		                $$collect.="=item $$1(1)\n\n$$2\n\n"; \
		        } \
		} \
		END { \
			while (<STDIN>) { \
		        	s/\#LIST\#/$$collect/; \
				print; \
			}; \
		}'

PREFIX=/usr/local

# Figure out the `current debhelper version.
VERSION=$(shell expr "`dpkg-parsechangelog |grep Version:`" : '.*Version: \(.*\)')

PERLLIBDIR=$(shell echo $(shell perl -MConfig -e 'print $$Config{vendorlib}')/Debian/Debhelper \
 | sed 's|/usr|$(PREFIX)|g')

POD2MAN=pod2man -c Debhelper -r "$(VERSION)"

# l10n to be built is determined from .po files
LANGS=$(notdir $(basename $(wildcard man/po4a/po/*.po)))

build: version
	find . -maxdepth 1 -type f -perm +100 -name "dh*" \
		-exec $(POD2MAN) {} {}.1 \;
	cat debhelper.pod | \
		$(MAKEMANLIST) `find . -maxdepth 1 -type f -perm +100 -name "dh_*" | sort` | \
		$(POD2MAN) --name="debhelper" --section=7  > debhelper.7
	po4a man/po4a/po4a.cfg
	set -e; \
	for lang in $(LANGS); do \
		dir=man/$$lang; \
		for file in $$dir/dh*.pod; do \
			prog=`basename $$file | sed 's/.pod//'`; \
			$(POD2MAN) $$file $$prog.$$lang.1; \
		done; \
		cat $$dir/debhelper.pod | \
			$(MAKEMANLIST) `find $$dir -type f -maxdepth 1 -name "dh_*.pod" | sort` | \
			$(POD2MAN) --name="debhelper" --section=7 > debhelper.$$lang.7; \
	done

version:
	printf "package Debian::Debhelper::Dh_Version;\n\$$version='$(VERSION)';\n1" > \
		Debian/Debhelper/Dh_Version.pm

clean:
	rm -f *.1 *.7 Debian/Debhelper/Dh_Version.pm
	po4a --rm-translations --rm-backups man/po4a/po4a.cfg
	for lang in $(LANGS); do \
		if [ -e man/$$lang ]; then rmdir man/$$lang; fi; \
	done;

install:
	install -d $(DESTDIR)$(PREFIX)/bin \
		$(DESTDIR)$(PREFIX)/share/debhelper/autoscripts \
		$(DESTDIR)$(PERLLIBDIR)/Sequence
	install $(shell find -maxdepth 1 -mindepth 1 -name dh\* |grep -v \.1\$$) $(DESTDIR)$(PREFIX)/bin
	install -m 0644 autoscripts/* $(DESTDIR)$(PREFIX)/share/debhelper/autoscripts
	install -m 0644 Debian/Debhelper/*.pm $(DESTDIR)$(PERLLIBDIR)
	install -m 0644 Debian/Debhelper/Sequence/*.pm $(DESTDIR)$(PERLLIBDIR)/Sequence

test: version
	./run perl -MTest::Harness -e 'runtests grep { ! /CVS/ && ! /\.svn/ } @ARGV' t/*
# clean up log etc
	./run dh_clean
