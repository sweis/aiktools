CC=gcc

.PHONY: all
all: getcert aikpublish aikrespond aikchallenge aikquote aikqverify

getcert: getcert.c
	$(CC) $< -ltspi -o $@
aikpublish: aikpublish.c
	$(CC) $< -ltspi -o $@
aikrespond: aikrespond.c
	$(CC) $< -ltspi -o $@
aikchallenge: aikchallenge.c
	$(CC) $< -lcrypto -o $@
aikquote: aikquote.c
	$(CC) $< -ltspi -o $@
aikqverify: aikqverify.c
	$(CC) $< -lcrypto -o $@

.PHONY: clean
clean:
	rm -f getcert aikpublish aikrespond aikchallenge aikquote aikverify
