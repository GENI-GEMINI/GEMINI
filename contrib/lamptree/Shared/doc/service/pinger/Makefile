FILE=pinger
VERSION=1.0
HTMLSHEET=/usr/share/xml/docbook/stylesheet/nwalsh/xhtml/docbook.xsl
#HTMLSHEET=/opt/local/var/macports/software/docbook-xsl/1.72.0_0/opt/local/share/xsl/docbook-xsl/xhtml/docbook.xsl

all: clean html

html: clean
	xsltproc -o $(FILE).html --stringparam appendix.autolabel A --stringparam chapter.autolabel 1 --stringparam part.autolabel I --stringparam reference.autolabel I --stringparam section.autolabel 1 --stringparam toc.section.depth 5 --stringparam section.autolabel.max.depth 5 $(HTMLSHEET) $(FILE).xml

clean:
	rm -frd *.html *.fo *pdf
