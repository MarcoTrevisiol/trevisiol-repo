PACKAGES := trevisiol-base trevisiol-dwm
ARCHES := all amd64 i386
REPO_DIR := repo
REPO_POOL := $(REPO_DIR)/pool/main
REPO_DIST := $(REPO_DIR)/dists/stable
DIST_DIR := $(REPO_DIST)/main
REPO_BUNDLE := repo.tar.gz

DEBUILD_FLAGS = -uc -us

PACKAGES_DIRS := $(foreach pkg,$(PACKAGES),packages/$(pkg))
BUILT_FILES := $(foreach pkg,$(PACKAGES),_build/$(pkg)/_built)
USCAN_FILES := $(foreach pkg,$(PACKAGES),_build/$(pkg)/_uscan)
PKG_UNCOMPRESSED := $(foreach arch,$(ARCHES),$(DIST_DIR)/binary-$(arch)/Packages)
PKG_GZ := $(addsuffix .gz,$(PKG_UNCOMPRESSED))
PKG_XZ := $(addsuffix .xz,$(PKG_UNCOMPRESSED))
CONTENTS := $(foreach arch,$(ARCHES),$(REPO_DIST)/Contents-$(arch).xz)

all: $(REPO_PACKAGES) $(REPO_BUNDLE)

init: $(PACKAGES_DIRS)

packages/%:
	git clone https://github.com/MarcoTrevisiol/$$(basename $@).git $@

# run as super user
build-dep: init
	apt install devscripts debhelper lintian
	cd packages/trevisiol-dwm && apt build-dep .

_build/%/_commit:
	@echo target_commit $@
	mkdir -p $$(dirname $@)
	git -C $$(dirname $(@:_build/%=packages/%)) pull --force
	git -C $$(dirname $(@:_build/%=packages/%)) rev-parse HEAD >$@

_build/%/_uscan: _build/%/_commit
	@echo target_uscan $@
	cd $$(dirname $(@:_build/%=packages/%)) && uscan -dd
	touch $@

_build/trevisiol-dwm/_built: DEBUILD_FLAGS= --no-tgz-check -uc -us
_build/trevisiol-dwm/_built: _build/trevisiol-dwm/_uscan

_build/%/_built: _build/%/_commit
	@echo target_built $@
	cd $$(dirname $(@:_build/%=packages/%)) && debuild $(DEBUILD_FLAGS)
	touch $@

_build/override: $(REPO_POOL)
	cat /dev/null >$@
	for i in $^/*.deb; do dpkg-deb -f "$$i" Package Priority Section | sed 's/^.*: //' | paste - - - >>$@; done

_build/Packages: $(REPO_POOL) _build/override
	mkdir -p $$(dirname $@)
	cd $(REPO_DIR) && dpkg-scanpackages pool ../_build/override >../$@

$(REPO_POOL): $(BUILT_FILES)
	mkdir -p $@
	find packages -maxdepth 1 -name '*dbgsym*' -prune -o -name '*.deb' -exec cp {} $@ \;
	touch $@

$(DIST_DIR)/binary-%/Packages: _build/Packages
	mkdir -p "$$(dirname '$@')"
	awk 'BEGIN{RS=""; ORS="\n\n"} \
		$$0 ~ ("(^|\\n)Architecture: $*(\\n|$$)") {print}' $< > $@

$(REPO_DIST)/Contents-%.xz:
	mkdir -p $$(dirname $@)
	echo -n "" | xz -9 --stdout >$@

$(REPO_BUNDLE): $(PKG_GZ) $(PKG_XZ) $(CONTENTS)
	tar -czf $@ repo

%.gz: %
	gzip -9 --stdout $< >$@

%.xz: %
	xz -9 --stdout $< >$@

.PHONY: clean
clean:
	cd packages && rm -f *deb *dsc *build *buildinfo *changes *tar.xz *tar.gz
	rm -f $(BUILT_FILES) $(USCAN_FILES)
	rm -rf repo _build
