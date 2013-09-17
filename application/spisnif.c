/* spisnif.c
 *
 * simple polling program for testing spisnif
 *
 * (c) Copyright 2013 The Armadeus Project - ARMadeus Systems
 * Fabien Marteau <fabien.marteau@armadeus.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 ***********************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>	/* file management */
#include <fcntl.h>
#include <signal.h>
#include <unistd.h>	/* sleep, write(), read() */
#include <string.h>	/* converting string */
#include <sys/mman.h>	/* memory management */

/* for IMX27 */
#define PLATFORM "APF27"
#define FPGA_ADDRESS 0xD6000000
#define FPGA_MAP_SIZE	0x2000
/* for IMX51 */
//# define PLATFORM "APF51"
//# define FPGA_ADDRESS 0xB8000000
//# define FPGA_MAP_SIZE	0x10000
/* for  MXC9328 */
//# define PLATFORM "APF9328"
//# define FPGA_ADDRESS 0x12000000
//# define FPGA_MAP_SIZE	0x2000

#define WORD_ACCESS (2)
#define LONG_ACCESS (4)

#define SPISNIF_BASE            0x10
#define SPISNIF_CONTROL_REG     (SPISNIF_BASE + 0x00)
#define SPISNIF_FIFO_MOSI_REG   (SPISNIF_BASE + 0x02)
#define SPISNIF_FIFO_MISO_REG   (SPISNIF_BASE + 0x04)
#define SPISNIF_FIFO_PACKET_REG (SPISNIF_BASE + 0x06)
#define SPISNIF_STATUS_REG      (SPISNIF_BASE + 0x08)
#define SPISNIF_CONFIG_REG      (SPISNIF_BASE + 0x0a)
#define SPISNIF_ID_REG          (SPISNIF_BASE + 0x0c)

#define SPISNIF_RESET_FLG   (0x8000)

#define SPISNIF_CONFIG_CSPOL (0x0004)
#define SPISNIF_CONFIG_CPHA  (0x0002)
#define SPISNIF_CONFIG_CPOL  (0x0001)

void print_usage()
{
        printf("command:\n");
        printf("Reseting component with configuration\n");
        printf("$ spisnif (-)cspol (-)cpha (-)cpol\n");
        printf("        cspol    active\n");
        printf("       -cspol    inactive\n");
        printf("        cpha     active\n");
        printf("       -cpha     inactive\n");
        printf("        cpol     active\n");
        printf("       -cpol     inactive\n");
        printf("Read frames :\n");
        printf("$ spisnif\n");
}

unsigned short spisnif_read(void* ptr_fpga, int addr)
{
	return *(unsigned short*)(ptr_fpga+(addr));
}

void spisnif_write(void* ptr_fpga, int addr,
                             unsigned short value) {

	*(unsigned short*)(ptr_fpga+(addr)) = value;

}

unsigned short petit_indien(unsigned short value) {
//    return value;
    unsigned short walign_value = ((value << 8)&0xFF00) | ((value >> 8)&0x00FF);
    unsigned short balign_value;

    balign_value = (walign_value << 4)&0xF0F0;
    balign_value |= (walign_value >> 4)&0x0F0F;

    return  ((balign_value<<3)&0x8888)|
            ((balign_value<<1)&0x4444)|
            ((balign_value>>1)&0x2222)|
            ((balign_value>>3)&0x1111);
}

char *bit_vector(unsigned short value, int lenght) {
    char *vector = malloc(17*sizeof(char));
    unsigned short tmp_value = value;
    int i;

    if ((lenght > 16) || (lenght < 0)) {
        printf("bit_vector error lenght %d\n", lenght);
        return NULL;
    }

    for (i = 0; i < lenght; i++) {
        if (tmp_value&0x8000)
            vector[i] = '1';
        else
            vector[i] = '0';
        tmp_value = tmp_value << 1;
    }
    vector[16] = '\0';

    return vector;
}

void print_map(void* ptr_fpga) {
    printf("SPISNIF_CONTROL_REG     (%02X) -> %04X\n",
           SPISNIF_CONTROL_REG     ,spisnif_read(ptr_fpga,SPISNIF_CONTROL_REG));
    printf("SPISNIF_FIFO_MOSI_REG   (%02X) -> %04X\n",
           SPISNIF_FIFO_MOSI_REG   ,spisnif_read(ptr_fpga,SPISNIF_FIFO_MOSI_REG));
    printf("SPISNIF_FIFO_MISO_REG   (%02X) -> %04X\n",
           SPISNIF_FIFO_MISO_REG   ,spisnif_read(ptr_fpga,SPISNIF_FIFO_MISO_REG));
    printf("SPISNIF_FIFO_PACKET_REG (%02X) -> %04X\n",
           SPISNIF_FIFO_PACKET_REG ,spisnif_read(ptr_fpga,SPISNIF_FIFO_PACKET_REG));
    printf("SPISNIF_STATUS_REG      (%02X) -> %04X\n",
           SPISNIF_STATUS_REG      ,spisnif_read(ptr_fpga,SPISNIF_STATUS_REG));
    printf("SPISNIF_CONFIG_REG      (%02X) -> %04X\n",
           SPISNIF_CONFIG_REG      ,spisnif_read(ptr_fpga,SPISNIF_CONFIG_REG));
    printf("SPISNIF_ID_REG          (%02X) -> %04X\n",
           SPISNIF_ID_REG          ,spisnif_read(ptr_fpga,SPISNIF_ID_REG));
}

int main(int argc, char *argv[])
{
	int ffpga;
	void* ptr_fpga;
    int frame_num;
    int bit_num;
    int i, j;
    unsigned short config = 0;


    /* open fpga memory zone */
	ffpga = open("/dev/mem", O_RDWR|O_SYNC);
	if (ffpga < 0) {
		printf("can't open file /dev/mem\n");
		return -1;
	}

	ptr_fpga = mmap(0, FPGA_MAP_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, ffpga, FPGA_ADDRESS);
	if (ptr_fpga == MAP_FAILED) {
		printf("mmap failed\n");
		return -1;
	}

    /* reset component with config given */
    if (argc == 4) {

        if (strcmp(argv[1], "cspol") == 0)
            config |= SPISNIF_CONFIG_CSPOL;
        if (strcmp(argv[2], "cpha") == 0)
            config |= SPISNIF_CONFIG_CPHA;
        if (strcmp(argv[3], "cpol") == 0)
            config |= SPISNIF_CONFIG_CPOL;

        printf("reseting ...\n");
        spisnif_write(ptr_fpga, SPISNIF_CONTROL_REG, SPISNIF_RESET_FLG);
        spisnif_write(ptr_fpga, SPISNIF_CONTROL_REG, 0);

        printf("write config %04X\n", config);
        spisnif_write(ptr_fpga, SPISNIF_CONFIG_REG, config);

   /* print usages */
    } else if (argc==1){

        frame_num = spisnif_read(ptr_fpga, SPISNIF_STATUS_REG);
        if (frame_num == 0x8000) {
            printf("No frame captured\n");
            frame_num = 0;
        } else if(frame_num < (1<<11)) {
            printf("%d frame captured\n", frame_num);
        } else {
            printf("Error status : %04X\n", frame_num);
        }

        for(i=0; i < frame_num; i++) {
            bit_num = spisnif_read(ptr_fpga, SPISNIF_FIFO_PACKET_REG);
            printf("\npacket %d, %d bits ->\n", i, bit_num);
            printf(" MOSI:");
            for(j=0; j < ((bit_num-1)/16) + 1; j++) {
                if (j == (bit_num-1)/16)
                    printf(" %s", bit_vector(petit_indien(spisnif_read(ptr_fpga, SPISNIF_FIFO_MOSI_REG)), bit_num%16));
                else
                    printf(" %s", bit_vector(petit_indien(spisnif_read(ptr_fpga, SPISNIF_FIFO_MOSI_REG)), 16));
            }
            printf("\n MISO:");
            for(j=0; j < ((bit_num-1)/16) + 1; j++) {
                if (j == (bit_num-1)/16)
                    printf(" %s", bit_vector(petit_indien(spisnif_read(ptr_fpga, SPISNIF_FIFO_MISO_REG)), bit_num%16));
                else
                    printf(" %s", bit_vector(petit_indien(spisnif_read(ptr_fpga, SPISNIF_FIFO_MISO_REG)), 16));
            }
            printf("\n");
        }

    } else {
        print_usage();
    }

    munmap(ptr_fpga, FPGA_MAP_SIZE);
    close(ffpga);

    return EXIT_SUCCESS;
}
