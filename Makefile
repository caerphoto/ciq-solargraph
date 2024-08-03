APP_NAME = Solargraph
DEVICE = fr165

VPATH = ./source
SOURCES = $(wildcard *.mc)
SDK_DIR = ~/dev/garmin/sdk
COMPILER = $(SDK_DIR)/monkeyc
PRG_FILE = bin/$(APP_NAME).prg
COMMON_FLAGS = -f monkey.jungle -o $(PRG_FILE) -y developer_key -d $(DEVICE) -w -l2

.PHONY: build-debug
build-debug : $(SOURCES)
	$(COMPILER) $(COMMON_FLAGS) -g

.PHONY: build-release
build-release : $(SOURCES)
	$(COMPILER) $(COMMON_FLAGS) -O2 -r

.PHONY: sim
sim :
	open $(SDK_DIR)/ConnectIQ.app

.PHONY: run
run :
	open $(SDK_DIR)/ConnectIQ.app
	$(SDK_DIR)/monkeydo $(PRG_FILE) $(DEVICE)
