SRC    := openid-federation-well-known-binding-1_0.md
XML    := openid-federation-well-known-binding-1_0.xml
HTML   := openid-federation-well-known-binding-1_0.html

.PHONY: all html xml clean

all: html

html: $(HTML)

xml: $(XML)

$(HTML): $(XML)
	xml2rfc --html $(XML) --out $(HTML)

$(XML): $(SRC)
	mmark $(SRC) > $(XML)

clean:
	rm -f $(XML) $(HTML)
