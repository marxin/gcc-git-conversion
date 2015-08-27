PROJECT = gcc
SOURCE_VCS = svn
TARGET_VCS = git
EXTRAS = 
REMOTE_URL = svn://gcc.gnu.org/svn/gcc
VERBOSITY = "verbose 1"
REPOSURGEON = cyreposurgeon

# Configuration ends here

.PHONY: local-clobber remote-clobber gitk gc compare clean dist stubmap diff
# Tell make not to auto-remove tag directories, because it only tries rm and hence fails
.PRECIOUS: $(PROJECT)-%-checkout $(PROJECT)-%-$(TARGET_VCS)

default: $(PROJECT)-$(TARGET_VCS)

# Build the converted repo from the second-stage fast-import stream
$(PROJECT)-$(TARGET_VCS): $(PROJECT).fi
	rm -fr $(PROJECT)-$(TARGET_VCS); $(REPOSURGEON) "read <$(PROJECT).fi" "prefer $(TARGET_VCS)" "rebuild $(PROJECT)-$(TARGET_VCS)"

# Build the second-stage fast-import stream from the first-stage stream dump
$(PROJECT).fi: $(PROJECT).$(SOURCE_VCS) $(PROJECT).lift $(PROJECT).map $(EXTRAS)
	$(REPOSURGEON) $(VERBOSITY) "read <$(PROJECT).$(SOURCE_VCS)" "authors read <$(PROJECT).map" "sourcetype $(SOURCE_VCS)" "prefer git" "script $(PROJECT).lift" "legacy write >$(PROJECT).fo" "write >$(PROJECT).fi"

# Build the first-stage stream dump from the local mirror
$(PROJECT).$(SOURCE_VCS): $(PROJECT)-mirror
	repotool mirror $(PROJECT)-mirror
	(cd $(PROJECT)-mirror/ >/dev/null; repotool export) >$(PROJECT).$(SOURCE_VCS)

# Build a local mirror of the remote repository
$(PROJECT)-mirror:
	repotool mirror $(REMOTE_URL) $(PROJECT)-mirror

#  Get a list of tags from the project mirror
$(PROJECT)-tags.txt: $(PROJECT)-mirror
	cd $(PROJECT)-mirror >/dev/null; repotool tags

# Make a local checkout of the source mirror for inspection
$(PROJECT)-checkout: $(PROJECT)-mirror
	cd $(PROJECT)-mirror >/dev/null; repotool checkout ../$(PROJECT)-checkout

# Make a local checkout of the source mirror for inspection at a specific tag
$(PROJECT)-%-checkout: $(PROJECT)-mirror
	cd $(PROJECT)-mirror >/dev/null; repotool ../$(PROJECT)-$*-checkout $*

# Force rebuild of first-stage stream from the local mirror on the next make
local-clobber: clean
	rm -fr $(PROJECT).fi $(PROJECT)-$(TARGET_VCS) *~ .rs* $(PROJECT)-conversion.tar.gz $(PROJECT)-*-$(TARGET_VCS)

# Force full rebuild from the remote repo on the next make.
remote-clobber: local-clobber
	rm -fr $(PROJECT).$(SOURCE_VCS) $(PROJECT)-mirror $(PROJECT)-checkout $(PROJECT)-*-checkout

# Get the (empty) state of the author mapping from the first-stage stream
stubmap: $(PROJECT).$(SOURCE_VCS)
	$(REPOSURGEON) "read <$(PROJECT).$(SOURCE_VCS)" "authors write >$(PROJECT).map"

# Compare the histories of the unconverted and converted repositories at head
# and all tags.
EXCLUDE = -x CVS -x .$(SOURCE_VCS) -x .$(TARGET_VCS)
EXCLUDE += -x .$(SOURCE_VCS)ignore -x .$(TARGET_VCS)ignore
headcompare:
	repotool compare $(EXCLUDE) $(PROJECT)-checkout $(PROJECT)-$(TARGET_VCS)
tagscompare:
	repotool compare-tags $(EXCLUDE) $(PROJECT)-checkout $(PROJECT)-$(TARGET_VCS)

# General cleanup and utility
clean:
	rm -fr *~ .rs* $(PROJECT)-conversion.tar.gz *.$(SOURCE_VCS) *.fi *.fo

# Bundle up the conversion metadata for shipping
SOURCES = Makefile $(PROJECT).lift $(PROJECT).map $(EXTRAS)
$(PROJECT)-conversion.tar.gz: $(SOURCES)
	tar --dereference --transform 's:^:$(PROJECT)-conversion/:' -czvf $(PROJECT)-conversion.tar.gz $(SOURCES)

dist: $(PROJECT)-conversion.tar.gz

#
# The following productions are git-specific
#

ifeq ($(TARGET_VCS),git)

# Browse the generated git repository
gitk: $(PROJECT)-git
	cd $(PROJECT)-git; gitk --all

# Run a garbage-collect on the generated git repository.  Import doesn't.
# This repack call is the active part of gc --aggressive.  This call is
# tuned for very large repositories.
gc: $(PROJECT)-git
	cd $(PROJECT)-git; time git -c pack.threads=1 repack -AdF --window=1250 --depth=250

endif

