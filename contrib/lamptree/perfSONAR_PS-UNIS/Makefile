PACKAGE=perfSONAR_PS-UNIS
ROOTPATH=/opt/perfsonar_ps/unis_service
VERSION=3.1

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	mkdir /tmp/$(PACKAGE)
	tar ch -T MANIFEST | tar x -C /tmp/$(PACKAGE)
	tar czf $(PACKAGE)-$(VERSION).tar.gz -C /tmp $(PACKAGE)
	rm -rf /tmp/$(PACKAGE)

upgrade:
	mkdir /tmp/$(PACKAGE)
	tar ch --exclude=etc/* -T MANIFEST | tar x -C /tmp/$(PACKAGE)
	tar czf $(PACKAGE)-$(VERSION)-upgrade.tar.gz -C /tmp $(PACKAGE)
	rm -rf /tmp/$(PACKAGE)

install:
	mkdir -p ${ROOTPATH}
	tar ch --exclude=etc/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	for i in `cat MANIFEST | grep ^etc`; do  mkdir -p `dirname $(ROOTPATH)/$${i}`; if [ -e $(ROOTPATH)/$${i} ]; then install -m 640 -c $${i} $(ROOTPATH)/$${i}.new; else install -m 640 -c $${i} $(ROOTPATH)/$${i}; fi; done
	mkdir -p /usr/local/etc; cp -R etc/protogeni /usr/local/etc/
