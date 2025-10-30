PACKAGES := $(patsubst packages/%/,%,$(wildcard packages/*/))
REPO_DIR := repo
BUILT_FILES := $(foreach pkg,$(PACKAGES),_build/$(pkg)/_built)
USCAN_FILES := $(foreach pkg,$(PACKAGES),_build/$(pkg)/_uscan)
DEBUILD_FLAGS = -uc -us
REPO_POOL := repo/pool/main
REPO_PACKAGES := repo/dists/stable/main/binary-amd64/Packages.gz
REPO_BUNDLE := repo.tar.gz

all: $(REPO_PACKAGES) $(REPO_BUNDLE)

# run as super user
build-dep:
	apt install devscripts debhelper lintian
	cd packages/trevisiol-dwm && apt build-dep .

_build/%/_commit:
	echo target_commit $@
	mkdir -p $$(dirname $@)
	git submodule update --remote $$(dirname $(@:_build/%=packages/%))
	git -C $$(dirname $(@:_build/%=packages/%)) rev-parse HEAD >$@

_build/trevisiol-dwm/_built: DEBUILD_FLAGS= --no-tgz-check -uc -us
_build/trevisiol-dwm/_built: _build/trevisiol-dwm/_uscan

_build/%/_built: _build/%/_commit
	echo target_built $@
	cd $$(dirname $(@:_build/%=packages/%)) && debuild $(DEBUILD_FLAGS)
	touch $@

_build/%/_uscan: _build/%/_commit
	echo target_uscan $@
	cd $$(dirname $(@:_build/%=packages/%)) && uscan -dd
	touch $@

$(REPO_PACKAGES): $(REPO_POOL)
	mkdir -p $$(dirname $@)
	cd repo && dpkg-scanpackages pool /dev/null | gzip -9c >$(@:repo/%=%)

$(REPO_POOL): $(BUILT_FILES)
	mkdir -p $@
	find packages -maxdepth 1 -name '*dbgsym*' -prune -o -name '*.deb' -exec cp {} $@ \;

$(REPO_BUNDLE): $(REPO_PACKAGES)
	tar -czf $@ repo

.PHONY: clean
clean:
	cd packages && rm -f *deb *dsc *build *buildinfo *changes *tar.xz *tar.gz
	rm -f $(BUILT_FILES) $(USCAN_FILES)
	rm -rf repo _build
