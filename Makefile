all: repo/dists/stable/main/binary-amd64/Packages.gz

build-dep:
	apt install devscripts debhelper lintian
	cd trevisiol-dwm && apt build-dep .

repo.tar.gz: repo/dists/stable/main/binary-amd64/Packages.gz
	tar -czf repo.tar.gz repo

repo/dists/stable/main/binary-amd64/Packages.gz: repo/pool/main
	mkdir -p repo/dists/stable/main/binary-amd64
	cd repo && dpkg-scanpackages pool /dev/null | gzip -9c >dists/stable/main/binary-amd64/Packages.gz

repo/pool/main: trevisiol-base_1_all.deb trevisiol-dwm_1-1_amd64.deb
	mkdir -p repo/pool/main/
	cp *.deb repo/pool/main/

trevisiol-base_1_all.deb: .submodule_base
	cd trevisiol-base && debuild -uc -us

trevisiol-dwm_1-1_amd64.deb: trevisiol-dwm_1.orig-dwm.tar.gz .submodule_dwm
	cd trevisiol-dwm && debuild --no-tgz-check -uc -us

trevisiol-dwm_1.orig-dwm.tar.gz: .submodule_dwm
	cd trevisiol-dwm && uscan -dd

SUBMODULE_COMMIT_BASE := $(shell git -C trevisiol-base rev-parse HEAD)
SUBMODULE_COMMIT_DWM  := $(shell git -C trevisiol-dwm  rev-parse HEAD)
.submodule_base:
	@echo "$(SUBMODULE_COMMIT_BASE)" > $@
.submodule_dwm:
	@echo "$(SUBMODULE_COMMIT_DWM)"  > $@

.PHONY: clean
clean:
	rm -f *deb *dsc *build *buildinfo *changes *tar.xz *tar.gz
	rm -rf repo
