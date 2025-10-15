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

trevisiol-base_1_all.deb:
	cd trevisiol-base && debuild -uc -us

trevisiol-dwm_1-1_amd64.deb: trevisiol-dwm_1.orig-dwm.tar.gz
	cd trevisiol-dwm && debuild --no-tgz-check -uc -us

trevisiol-dwm_1.orig-dwm.tar.gz:
	cd trevisiol-dwm && uscan -dd

.PHONY: clean
clean:
	rm -f *deb *dsc *build *buildinfo *changes *tar.xz *tar.gz
	rm -rf repo
