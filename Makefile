CC = clang
CFLAGS += -Werror \
		  -Wpedantic \
		  -framework Foundation \
		  -framework AppKit \
		  -framework QuartzCore \
		  -fobjc-arc \
			-g

APP_TARGET = RemoteRendered.app
RENDERER_TARGET = $(APP_TARGET)/Contents/XPCServices/Renderer.xpc

define bundle_template
$(eval info_plist:=$(1)/Contents/Info.plist)
$(eval executable := $(1)/Contents/MacOS/$(basename $(notdir $(1))))
$(1): $(info_plist) $(executable) $(3)
	touch "$(1)"
$(info_plist): src/$(2)/Info.plist
	mkdir -p "$$(dir $$@)"
	cp "$$<" "$$@"
$(executable): src/$(2)/main.m
	mkdir -p "$$(dir $$@)"
	$(CC) $(CFLAGS) -o "$$@" "$$<"
endef

$(eval $(call bundle_template,$(APP_TARGET),app,$(RENDERER_TARGET)))
$(eval $(call bundle_template,$(RENDERER_TARGET),renderer))
