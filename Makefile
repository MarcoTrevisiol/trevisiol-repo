PACKAGES := trevisiol-base trevisiol-dwm
PACKAGES_DIRS := $(foreach pkg,$(PACKAGES),packages/$(pkg))
REPO_DIR := repo
BUILT_FILES := $(foreach pkg,$(PACKAGES),_build/$(pkg)/_built)
USCAN_FILES := $(foreach pkg,$(PACKAGES),_build/$(pkg)/_uscan)
DEBUILD_FLAGS = -uc -us
REPO_POOL := repo/pool/main
REPO_PACKAGES_GZ := repo/dists/stable/main/binary-amd64/Packages.gz
REPO_PACKAGES_XZ := repo/dists/stable/main/binary-amd64/Packages.xz
REPO_PACKAGES_ALL_XZ := repo/dists/stable/main/binary-all/Packages.xz
REPO_CONTENT_ALL := repo/dists/stable/Contents-all.xz
REPO_CONTENT_64 := repo/dists/stable/Contents-amd64.xz
REPO_BUNDLE := repo.tar.gz

all: $(REPO_PACKAGES) $(REPO_BUNDLE)

init: $(PACKAGES_DIRS)

packages/%:
	git clone https://github.com/MarcoTrevisiol/$$(basename $@).git $@

# run as super user
build-dep:
	apt install devscripts debhelper lintian
	cd packages/trevisiol-dwm && apt build-dep .

_build/%/_commit:
	@echo target_commit $@
	mkdir -p $$(dirname $@)
	git -C $$(dirname $(@:_build/%=packages/%)) pull --force
	git -C $$(dirname $(@:_build/%=packages/%)) rev-parse HEAD >$@

_build/trevisiol-dwm/_built: DEBUILD_FLAGS= --no-tgz-check -uc -us
_build/trevisiol-dwm/_built: _build/trevisiol-dwm/_uscan

_build/%/_built: _build/%/_commit
	@echo target_built $@
	cd $$(dirname $(@:_build/%=packages/%)) && debuild $(DEBUILD_FLAGS)
	touch $@

_build/%/_uscan: _build/%/_commit
	@echo target_uscan $@
	cd $$(dirname $(@:_build/%=packages/%)) && uscan -dd
	touch $@

$(REPO_PACKAGES_GZ): $(REPO_POOL) repo/override
	mkdir -p $$(dirname $@)
	cd repo && dpkg-scanpackages pool override | gzip -9c >$(@:repo/%=%)

$(REPO_PACKAGES_XZ): $(REPO_POOL) repo/override
	mkdir -p $$(dirname $@)
	cd repo && dpkg-scanpackages pool override | xz -9e --stdout >$(@:repo/%=%)

$(REPO_PACKAGES_ALL_XZ): $(REPO_POOL)
	mkdir -p $$(dirname $@)
	echo -n "" | xz -9e --stdout >$@

$(REPO_CONTENT_ALL): $(REPO_POOL)
	mkdir -p $$(dirname $@)
	echo -n "" | xz -9e --stdout >$@

$(REPO_CONTENT_64): $(REPO_POOL)
	mkdir -p $$(dirname $@)
	echo -n "" | xz -9e --stdout >$@

$(REPO_POOL): $(BUILT_FILES)
	mkdir -p $@
	find packages -maxdepth 1 -name '*dbgsym*' -prune -o -name '*.deb' -exec cp {} $@ \;
	touch $@

$(REPO_BUNDLE): $(REPO_PACKAGES_GZ) $(REPO_PACKAGES_XZ) $(REPO_PACKAGES_ALL_XZ) $(REPO_CONTENT_ALL) $(REPO_CONTENT_64)
	tar -czf $@ repo

repo/override: $(REPO_POOL)
	cat /dev/null >$@
	for i in $^/*.deb; do dpkg-deb -f "$$i" Package Priority Section | sed 's/^.*: //' | paste - - - >>$@; done

.PHONY: clean
clean:
	cd packages && rm -f *deb *dsc *build *buildinfo *changes *tar.xz *tar.gz
	rm -f $(BUILT_FILES) $(USCAN_FILES)
	rm -rf repo _build
