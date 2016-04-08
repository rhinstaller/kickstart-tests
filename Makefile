# This Makefile generates some .ks.in files which are similar in many ways
# from templates and include files found in lib/ . It is not intended to be
# configurable and exists entirely for the purpose of reducing duplication
# between .ks.in files.
#
# This is a regular Makefile without any automake weirdness, so just keep it
# friendly.

PROXY     = proxy=http://127.0.0.1:8080
AUTHPROXY = proxy=http://anaconda:qweqwe@127.0.0.1:8080

.PHONY: all clean
all: proxy-cmdline.ks.in proxy-kickstart.ks.in proxy-auth.ks.in

clean:
	-rm proxy-cmdline.ks.in proxy-kickstart.ks.in proxy-auth.ks.in

# The more complex sed lines here are basically saying 'when you see
# this text, read in some text from one or more files, then delete
# the matched text'. You can chain multiple 'r' expressions within
# the curly braces, closing with the 'd}' expression does the delete.

# cmdline: no repo test, so no REPO_LINE and no proxy-repo.inc, also no
# PROXY_TEXT as that's only in proxy-repo.inc. Proxy has no password,
# so no PROXY_PASSWORD_LINE.
proxy-cmdline.ks.in: lib/proxy.template lib/proxy.py lib/proxy-common.inc
	sed -e 's,URL_LINE,url @KSTEST_URL@,' $< > $@
	sed -i -e '/REPO_LINE/d' $@
	sed -i -e '/PROXY_PASSWORD_LINE/d' $@
	sed -i -e '/PROXY_PYTHON/{r lib/proxy.py' -e 'd}' $@
	sed -i -e '/PROXY_TESTS/{r lib/proxy-common.inc' -e 'r lib/proxy-common-end.inc' -e 'd}' $@

# kickstart: repo tests, no proxy password. We set REPO_LINE and
# PROXY_TEXT accordingly, there is no PROXY_PASSWORD_LINE, we include
# the repo tests.
proxy-kickstart.ks.in: lib/proxy.template lib/proxy.py lib/proxy-common.inc lib/proxy-repo.inc
	sed -e 's,URL_LINE,url @KSTEST_URL@ --$(PROXY),' $< > $@
	sed -i -e 's,REPO_LINE,repo --name=kstest-http --baseurl=HTTP-ADDON-REPO --$(PROXY) --install,' $@
	sed -i -e '/PROXY_PASSWORD_LINE/d' $@
	sed -i -e '/PROXY_PYTHON/{r lib/proxy.py' -e 'd}' $@
	sed -i -e '/PROXY_TESTS/{r lib/proxy-common.inc' -e 'r lib/proxy-repo.inc' -e 'r lib/proxy-common-end.inc' -e 'd}' $@
	sed -i -e 's,PROXY_TEXT,$(PROXY),' $@

# auth: repo tests and passworded proxy. We set REPO_LINE,
# PROXY_PASSWORD_LINE and PROXY_TEXT, use AUTHPROXY which includes the
# password, and include the repo tests.
proxy-auth.ks.in: lib/proxy.template lib/proxy.py lib/proxy-common.inc lib/proxy-repo.inc
	sed -e 's,URL_LINE,url @KSTEST_URL@ --$(AUTHPROXY),' $< > $@
	sed -i -e 's,REPO_LINE,repo --name=kstest-http --baseurl=HTTP-ADDON-REPO --$(AUTHPROXY) --install,' $@
	sed -i -e 's,PROXY_PASSWORD_LINE,echo 'anaconda:qweqwe' > /tmp/proxy.password,' $@
	sed -i -e '/PROXY_PYTHON/{r lib/proxy.py' -e 'd}' $@
	sed -i -e '/PROXY_TESTS/{r lib/proxy-common.inc' -e 'r lib/proxy-repo.inc' -e 'r lib/proxy-common-end.inc' -e 'd}' $@
	sed -i -e 's,PROXY_TEXT,$(AUTHPROXY),' $@
