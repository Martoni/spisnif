/*
 * Platform data for spisnif IP driver
 *
 * (c) Copyright 2013    The Armadeus Project - ARMadeus Systems
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
 */

#include <linux/version.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/platform_device.h>

#include <mach/hardware.h>
#include <mach/fpga.h>

/*$foreach:instance$*/
#define /*$instance_name$*/_BASE /*$registers_base_address:swb16$*/
/*$foreach:instance:end$*/

/*$foreach:instance$*/
static struct resource /*$instance_name$*/_resources[] = {
	[0] = {
		.start = ARMADEUS_FPGA_BASE_ADDR + /*$instance_name$*/_BASE,
		.end = ARMADEUS_FPGA_BASE_ADDR + /*$instance_name$*/_BASE + 0x1F,
		.flags	= IORESOURCE_MEM,
	},
	[1] = {
		.start	= IRQ_FPGA(/*$interrupt_number$*/),
		.end	= IRQ_FPGA(/*$interrupt_number$*/),
		.flags	= IORESOURCE_IRQ,
	}
};

void /*$instance_name$*/_release(struct device *dev)
{
	dev_dbg(dev, "released\n");
}

static struct platform_device /*$instance_name$*/_device = {
	.name		= "spisnif",
	.id		= /*$instance_num$*/,
	.dev		= {
		.release	= /*$instance_name$*/_release,
	},
	.num_resources	= ARRAY_SIZE(/*$instance_name$*/_resources),
	.resource	= /*$instance_name$*/_resources,
};
/*$foreach:instance:end$*/

static int __init board_spisniftest_init(void)
{
    int ret;

/*$foreach:instance$*/
	ret = platform_device_register(&/*$instance_name$*/_device);
    if (ret < 0)
        printk(KERN_ERR "Error: con't init device /*$instance_name$*/\n");
/*$foreach:instance:end$*/
    return ret;
}

static void __exit board_spisniftest_exit(void)
{
/*$foreach:instance$*/
	platform_device_unregister(&/*$instance_name$*/_device);
/*$foreach:instance:end$*/
}

module_init(board_spisniftest_init);
module_exit(board_spisniftest_exit);

MODULE_AUTHOR("Fabien Marteau <fabien.marteau@armadeus.com> & Kevin Joly <joly.kevin25@gmail.com>");
MODULE_DESCRIPTION("Board specific spisniftest driver");
MODULE_LICENSE("GPL");
