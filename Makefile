EMSCRIPTEN_PREFIX = `dirname \`command -v emcc\``

PHON_FILES = phontab phonindex phondata intonations
DICT_FILES = en_dict ja_dict
DATA_FILES = $(PHON_FILES) $(DICT_FILES)
DATA_FILES_TARGET = $(addprefix espeak-japanese/espeak-data/,$(DATA_FILES))

all: src/speakGenerator.debug.js src/speakGenerator.js

$(DATA_FILES_TARGET):
	( cd espeak-japanese/; make )

src/data.js: $(DATA_FILES_TARGET)
	if [ ! -d src/data/ ]; then mkdir -p src/data/; fi
	$(foreach f,$(DATA_FILES),\
	    python "$(EMSCRIPTEN_PREFIX)/tools/file2json.py" "espeak-japanese/espeak-data/$(f)" "$(f)" > "src/data/$(f).js"; \
	)
	python "$(EMSCRIPTEN_PREFIX)/tools/file2json.py" espeak-japanese/espeak/espeak-data/voices/en/en-us en_us > src/data/en-us.js
	python "$(EMSCRIPTEN_PREFIX)/tools/file2json.py" espeak-japanese/espeak-data/voices/ja ja > src/data/ja.js
	python "$(EMSCRIPTEN_PREFIX)/tools/file2json.py" speak.js/espeak-data/config config > src/data/config.js
	cat $(patsubst %,src/data/%.js,$(DATA_FILES)) src/data/en-us.js src/data/ja.js src/data/config.js > src/data.js

src/speak.bc:
	if [ ! -d src/ ]; then mkdir -p src/; fi
	cd speak.js/src/; \
	    make distclean; make clean; \
	    rm -f libspeak.* speak speak.o; \
	    CXXFLAGS="-DNEED_WCHAR_FUNCTIONS" $(EMSCRIPTEN_PREFIX)/emmake make -j 2 speak; \
        mv speak ../../src/speak.bc

src/pre.js: src/data.js src/_pre.js
	cat src/_pre.js src/data.js > src/pre.js

src/post.js: src/data.js src/_post.js
	cat src/_post.js > src/post.js

src/speak.debug.js: src/speak.bc src/pre.js src/post.js
	cd $(EMSCRIPTEN_PREFIX)/src/; \
	    mv preamble.js preamble.js.bak; \
	    cat preamble.js.bak | sed -r 's/function intArrayFromString.*$$/\0\nstringy=unescape(encodeURIComponent(stringy));/' > preamble.js
	$(EMSCRIPTEN_PREFIX)/emcc -O0 src/speak.bc --pre-js src/pre.js --post-js src/post.js -o src/speak.debug.js
	cd $(EMSCRIPTEN_PREFIX)/src/; \
	    rm preamble.js; \
	    mv preamble.js.bak preamble.js

src/speak.js: src/speak.bc src/pre.js src/post.js
	cd $(EMSCRIPTEN_PREFIX)/src/; \
	    mv preamble.js preamble.js.bak; \
	    cat preamble.js.bak | sed -r 's/function intArrayFromString.*$$/\0\nstringy=unescape(encodeURIComponent(stringy));/' > preamble.js
	$(EMSCRIPTEN_PREFIX)/emcc -O2 src/speak.bc --pre-js src/pre.js --post-js src/post.js -o src/speak.js
	cd $(EMSCRIPTEN_PREFIX)/src/; \
	    rm preamble.js; \
	    mv preamble.js.bak preamble.js

src/speakGenerator.debug.js: src/speak.debug.js
	cat speak.js/src/shell_pre.js src/speak.debug.js speak.js/src/shell_post.js > src/speakGenerator.debug.js

src/speakGenerator.js: src/speak.js
	cat speak.js/src/shell_pre.js src/speak.js speak.js/src/shell_post.js > src/speakGenerator.js

clean:
	rm src/data.js src/pre.js src/post.js src/speak.bc src/speak.js src/speakGenerator.js src/speak.debug.js src/speakGenerator.debug.js

