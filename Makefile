EXTRAS = 
REMOTE_URL = svn://gcc.gnu.org/svn/gcc
VERBOSITY = "verbose 1"
REPOSURGEON = pypy `command -v reposurgeon`

# Configuration ends here

.PHONY: local-clobber remote-clobber gitk gc compare clean dist stubmap diff
# Tell make not to auto-remove tag directories, because it only tries rm and hence fails
.PRECIOUS: gcc-%-checkout gcc-%-git

default: gcc-git

# Build the converted repo from the second-stage fast-import stream
gcc-git: gcc.fi
	rm -fr gcc-git; $(REPOSURGEON) "read <gcc.fi" "prefer git" "rebuild gcc-git" "elapsed"
	cd gcc-git; ../filters

# Build the second-stage fast-import stream from the first-stage stream dump
gcc.fi: gcc.svn gcc.lift gcc.map $(EXTRAS)
	$(REPOSURGEON) $(VERBOSITY) "script gcc.opts" "read <gcc.svn" "authors read <gcc.map" "sourcetype svn" "prefer git" "script gcc.lift" "legacy write >gcc.fo" "write --legacy >gcc.fi" "elapsed"

# Build the first-stage stream dump from the local mirror
gcc.svn: gcc-mirror
	repotool mirror gcc-mirror
	(cd gcc-mirror/ >/dev/null; repotool export) >gcc.svn

# Build a local mirror of the remote repository
gcc-mirror:
	rsync --archive --delete --compress rsync://gcc.gnu.org/gcc-svn gcc-mirror

#  Get a list of tags from the project mirror
gcc-tags.txt: gcc-mirror
	cd gcc-mirror >/dev/null; repotool tags

# Make a local checkout of the source mirror for inspection
gcc-checkout: gcc-mirror
	cd gcc-mirror >/dev/null; repotool checkout ../gcc-checkout

# Make a local checkout of the source mirror for inspection at a specific tag
gcc-%-checkout: gcc-mirror
	cd gcc-mirror >/dev/null; repotool ../gcc-$*-checkout $*

# Force rebuild of first-stage stream from the local mirror on the next make
local-clobber: clean
	rm -fr gcc.fi gcc-git *~ .rs* gcc-conversion.tar.gz gcc-*-git

# Force full rebuild from the remote repo on the next make.
remote-clobber: local-clobber
	rm -fr gcc.svn gcc-mirror gcc-checkout gcc-*-checkout

# Get the (empty) state of the author mapping from the first-stage stream
stubmap: gcc.svn
	$(REPOSURGEON) "read <gcc.svn" "authors write >gcc.map"

# Compare the histories of the unconverted and converted repositories at head
# and all tags.
EXCLUDE = -x CVS -x .svn -x .git
EXCLUDE += -x .svnignore -x .gitignore -x .cvsignore
headcompare:
	repotool compare $(EXCLUDE) gcc-checkout gcc-git
tagscompare:
	repotool compare-tags $(EXCLUDE) gcc-checkout gcc-git

# General cleanup and utility
clean:
	rm -fr *~ .rs* gcc-conversion.tar.gz *.svn *.fi *.fo

# Bundle up the conversion metadata for shipping
SOURCES = Makefile gcc.lift gcc.map $(EXTRAS)
gcc-conversion.tar.gz: $(SOURCES)
	tar --dereference --transform 's:^:gcc-conversion/:' -czvf gcc-conversion.tar.gz $(SOURCES)

dist: gcc-conversion.tar.gz

#
# The following productions are git-specific
#

# Browse the generated git repository
gitk: gcc-git
	cd gcc-git; gitk --all

# Run a garbage-collect on the generated git repository.  Import doesn't.
# This repack call is the active part of gc --aggressive.  This call is
# tuned for very large repositories.
gc: gcc-git
	cd gcc-git; time git -c pack.threads=1 repack -AdF --window=1250 --depth=250


