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
#include <time.h>
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


static int keepRunning = 1;

struct spi_frame {
    int bit_num;
    unsigned short *mosi;
    unsigned short *miso;
};

struct spi_frame_list {
    int frame_num;
    struct spi_frame **frames;
};

void intHandler(int dummy) {
    printf("Crl-C captured\n");
    keepRunning = 0;
}

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

struct spi_frame_list *read_frames(void *ptr_fpga) {
    struct spi_frame_list *flist;
    unsigned short read_value;
    int i, j;

    read_value = spisnif_read(ptr_fpga, SPISNIF_STATUS_REG);
    if ((read_value == 0x8000)||(read_value >= (1<<11))||(read_value == 0))
        return NULL;

    flist = (struct spi_frame_list *)malloc(sizeof(struct spi_frame_list));
    if (flist == NULL) {
        printf("can't allocate memory for struct flist\n");
        return NULL;
    }

    flist->frame_num = (int)read_value;

    /* allocate memory for frames */
    flist->frames = (struct spi_frame **)
                    malloc(flist->frame_num*sizeof(struct spi_frame *));
    if (flist->frames == NULL) {
        printf("can't allocate memory for struct flist->frames\n");
        goto free_list;
    }
    for (i = 0; i < flist->frame_num; i++) {
        flist->frames[i] = (struct spi_frame *)malloc(sizeof(struct spi_frame));
        if (flist->frames[i] == NULL) {
            printf("Error allocating memory for spi_frames[%d]\n", i);
            return NULL;
        }
        read_value = spisnif_read(ptr_fpga, SPISNIF_FIFO_PACKET_REG);
        if (read_value == 0) {
            flist->frames[i]->bit_num = 0;
            //flist->frames[i]->mosi == NULL;
            //flist->frames[i]->miso == NULL;
        } else {
            flist->frames[i]->bit_num = read_value;
            flist->frames[i]->mosi = (unsigned short *)malloc(((read_value-1)/16+1)*sizeof(unsigned short));
            if (flist->frames[i]->mosi == NULL) {
                printf("Error allocating memory for  flist->frames[%d]->mosi\n", i);
                return NULL;
            }
            flist->frames[i]->miso = (unsigned short *)malloc(((read_value-1)/16+1)*sizeof(unsigned short));
            if (flist->frames[i]->miso == NULL) {
                printf("Error allocating memory for  flist->frames[%d]->miso\n", i);
                return NULL;
            }

            /* read all values */
            for (j = 0; j < ((flist->frames[i]->bit_num - 1)/16 + 1); j++) {
                flist->frames[i]->mosi[j] = spisnif_read(ptr_fpga, SPISNIF_FIFO_MOSI_REG);
                flist->frames[i]->miso[j] = spisnif_read(ptr_fpga, SPISNIF_FIFO_MISO_REG);
            }
        }
    }

    return flist;

free_list:
    free(flist);
    return NULL;
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
    vector[i] = '\0';

    return vector;
}

void print_frame_list(struct spi_frame_list *flist) {
    int i;
    int j;
    int bit_num_tmp;

    for (i=0; i < flist->frame_num; i++) {
        bit_num_tmp = flist->frames[i]->bit_num;
        if(bit_num_tmp != 0) {
            printf("(%03d)MOSI: ", flist->frames[i]->bit_num);
            for(j=0; j < ((flist->frames[i]->bit_num-1)/16)+1; j++) {
                    printf("(%04x)%s",
                           flist->frames[i]->mosi[j],
                           bit_vector(
                                      petit_indien(flist->frames[i]->mosi[j]),
                                      (bit_num_tmp>15)?16:bit_num_tmp)
                           );
                    bit_num_tmp = bit_num_tmp - 16;
            }
            printf("\n");
            bit_num_tmp = flist->frames[i]->bit_num;
            printf("(%03d)MOSI: ", flist->frames[i]->bit_num);
            for(j=0; j < ((flist->frames[i]->bit_num-1)/16)+1; j++) {
                    printf("(%04x)%s",
                           flist->frames[i]->miso[j],
                           bit_vector(
                                      petit_indien(flist->frames[i]->miso[j]),
                                      (bit_num_tmp>15)?16:bit_num_tmp)
                           );
                    bit_num_tmp = bit_num_tmp - 16;
            }
            printf("\n\n");
        } else
            printf("Void CS\n\n");
    }
}

void free_frame_list(struct spi_frame_list *flist) {
    int i;

    if (flist != NULL) {
        for (i=0; i < flist->frame_num; i++) {
            if (flist->frames[i]->bit_num != 0) {
                free(flist->frames[i]->mosi);
                free(flist->frames[i]->miso);
            }
            free(flist->frames[i]);
        }
        free(flist->frames);
        free(flist);
    }
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

void reset_spisnif(void * ptr_fpga) {
    unsigned short value;
    value = spisnif_read(ptr_fpga, SPISNIF_CONTROL_REG);
    spisnif_write(ptr_fpga,
                  SPISNIF_CONTROL_REG,
                  value | SPISNIF_RESET_FLG);
    spisnif_write(ptr_fpga,
                  SPISNIF_CONTROL_REG,
                  value);
}

int main(int argc, char *argv[])
{
	int ffpga;
	void* ptr_fpga;
    unsigned short config = 0;
    struct spi_frame_list *flist;

    signal(SIGINT, intHandler);

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
        spisnif_write(ptr_fpga, SPISNIF_CONFIG_REG, config);
        reset_spisnif(ptr_fpga);

    /* print usages */
    } else if (argc==1){

        printf("Launching spi sniffing ...\n");
        while(keepRunning) {
            flist = read_frames(ptr_fpga);
            if (flist != NULL) {
                printf("%d frames read\n", flist->frame_num);
                print_frame_list(flist);
                free_frame_list(flist);
            } else
                reset_spisnif(ptr_fpga);
            sleep(1); //XXX
        }

    } else {
        print_usage();
    }

    munmap(ptr_fpga, FPGA_MAP_SIZE);
    close(ffpga);

    printf("Spisnif end...\n");
    return EXIT_SUCCESS;
}
