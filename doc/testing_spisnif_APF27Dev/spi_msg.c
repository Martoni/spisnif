#include <as_spi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SPI_SPEED 100000

#define DEVPATH argv[1]
#define SEQUENCE argv[2]
#define BITCOUNT argv[3]

void print_usage()
{
        printf("USAGE: spi_msg dev_path 0x[HEX sequence] [bit count]\n");
}

int ascii_hex_to_int(char c)
{
    if ((c >= '0') && (c <= '9')) {
        return c - '0';
    } else if ((c >= 'a') && (c <= 'f')) {
        return c - 'a' + 10;
    } else if ((c >= 'A') && (c <= 'F')) {
        return c - 'A' + 10;
    } else {
        return -1;
    }
}

unsigned long long ascii_to_hex(char *str)
{
    int i, val;
    unsigned long long res = 0;

    for (i = 0 ; i < strlen(str) ; i++) {
        val = ascii_hex_to_int(str[i]);

        if (val < 0) {
            printf("[Warning] Data may be invalid\n");
            return 0;
        }

        res = res << 4;
        res += val;
    }

    return res;
}

int main(int argc, char *argv[])
{
    int fd, ret, bit_count;
    unsigned long long msg;

    if (argc != 4) {
        print_usage();
        return EXIT_SUCCESS;
    }

    if ((SEQUENCE[0] != '0') && (SEQUENCE[1] != 'x')) {
        print_usage();
        return EXIT_SUCCESS;
    }

    msg = ascii_to_hex(SEQUENCE+2);
    bit_count = atoi(BITCOUNT);

    if (bit_count < 1) {
        printf("[ERROR] Bad bit number to send.\n");
        print_usage();
        return EXIT_FAILURE;
    }

    msg &= (1 << (bit_count+1)) - 1; //Mask unused bits

    fd = as_spi_open((unsigned char *)DEVPATH);

    if (fd < 0) {
        printf("Error: can't open spidev %s\n", DEVPATH);
        return EXIT_FAILURE;
    }

    printf("Sending 0x%llX (%d bits)\n", msg, bit_count);
    ret = as_spi_msg(fd, msg, bit_count, SPI_SPEED);

    printf("Response: %x\n", ret);
    as_spi_close(fd);

    return EXIT_SUCCESS;
}
