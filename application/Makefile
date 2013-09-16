HOST_DIR = ../../../buildroot/output/host/
STAGING_DIR = ../../../buildroot/output/staging/
TARGET_DIR = ../../../buildroot/output/target/

CC = $(HOST_DIR)/usr/bin/arm-linux-gcc
CFLAGS = -Wall
INCLUDE = -I$(STAGING_DIR)/usr/include/as_devices/
INSTALL_DIR = $(TARGET_DIR)/usr/bin/


spisnif: spisnif.c
	$(CC) $(CFLAGS) spisnif.c -o spisnif -las_devices $(INCLUDE)

clean:
	rm -f *.o $(EXEC)

.PHONY: install clean
