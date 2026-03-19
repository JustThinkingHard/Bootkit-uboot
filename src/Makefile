PWNED := pwned.bin

.PHONY: all clean help POC

AS := aarch64-linux-gnu-as
OBJCOPY := aarch64-linux-gnu-objcopy

all: POC

POC: $(PWNED)

$(PWNED): pwned.o
	$(OBJCOPY) -O binary $< $@

pwned.o: pwned.S
	$(AS) -o $@ $<

clean:
	rm -rf $(PWNED) pwned.o

help:
	@echo "Available targets:"
	@echo "  all     - Build the project"
	@echo "  pwned   - Build the pwned binary"
	@echo "  clean   - Remove build artifacts"
	@echo "  help    - Show this help message"