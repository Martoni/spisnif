/*
 * spisnif.c driver for virtual component spisnif (FPGA)
 *
 * (c) Copyright 2012	Armadeus Project - ARMadeus Systems
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
#include <linux/io.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/wait.h>
#include <linux/irq.h>

#include <mach/hardware.h>
#include <mach/fpga.h>

#define DRIVER_NAME	"spisnif"

#define SPISNIF_RAMSIZE	1024

/* masks */
#define SPISNIF_CONTROL_MASK_ACK_FIFO	(0x8000)
#define SPISNIF_CONTROL_MASK_OS		(0x01C0)
#define SPISNIF_CONTROL_MASK_EXT_TRIG_NUM	(0x003E)
#define SPISNIF_CONTROL_MASK_EXT_TRIG_INV	(0x0200)
#define SPISNIF_CONTROL_MASK_TRIGGER	(0x0001)

#define SPISNIF_STATUS_MASK_FEMPTY6	(1<<13)
#define SPISNIF_STATUS_MASK_FEMPTY5	(1<<12)
#define SPISNIF_STATUS_MASK_FEMPTY4	(1<<11)
#define SPISNIF_STATUS_MASK_FEMPTY3	(1<<10)
#define SPISNIF_STATUS_MASK_FEMPTY2	(1<<9)
#define SPISNIF_STATUS_MASK_FEMPTY1	(1<<8)
#define SPISNIF_STATUS_MASK_RUN		(0x2)
#define SPISNIF_STATUS_MASK_PFIFOFULL	(0x1)

/* registers addresses */
#define SPISNIF_REG_CONTROL	(2*0x00)
#define SPISNIF_REG_STATUS	(2*0x01)
#define SPISNIF_REG_PRESCALER	(2*0x02)

#define SPISNIF_REG_FIFO_V1	(2*0x04)
#define SPISNIF_REG_FIFO_V2	(2*0x05)
#define SPISNIF_REG_FIFO_V3	(2*0x06)
#define SPISNIF_REG_FIFO_V4	(2*0x07)
#define SPISNIF_REG_FIFO_V5	(2*0x08)
#define SPISNIF_REG_FIFO_V6	(2*0x09)

#define SPISNIF_REG_FIFO_SIZE_0	(2*0x0c)
#define SPISNIF_REG_FIFO_SIZE_1	(2*0x0d)
#define SPISNIF_REG_DEBUG		(2*0x0e)
#define SPISNIF_REG_ID		(2*0x0f)


struct spisnif_chip {
	struct resource		*resource_mem;
	struct resource		*resource_irq;
	struct platform_device	*pdev;
	void __iomem		*reg_base;
	/* cdev structures */
	struct cdev		cdev;
	dev_t			devt;
	int			cdev_open;
	/* interrupts */
	int			irq_occur;
	wait_queue_head_t	wait_queue;

};

/* wishbone16 accesses */
static u16 ad_read_reg(const struct spisnif_chip *ad_chip, int reg)
{
	return ioread16(ad_chip->reg_base + reg);
}

static void ad_write_reg(const struct spisnif_chip *ad_chip, int reg, u16 value)
{
	iowrite16(value, ad_chip->reg_base + reg);
}

/* file operations */
static ssize_t spisnif_open(struct inode *inode, struct file *file)
{
	struct spisnif_chip *ad_chip = container_of(inode->i_cdev, struct spisnif_chip, cdev);

	file->private_data = ad_chip;
	if (ad_chip->cdev_open)
		return -EBUSY;

	ad_chip->cdev_open = 1;
	return 0;
}

static ssize_t spisnif_release(struct inode *inode, struct file *filp) {
	struct spisnif_chip *ad_chip = filp->private_data; 

	ad_chip->cdev_open = 0;

	return 0;
}

static ssize_t spisnif_read(struct file *file, char __user *buf, size_t count, loff_t *f_pos) {
	struct spisnif_chip *ad_chip = file->private_data; 
	int reg_value;

	/* start sampling */
	reg_value = ad_read_reg(ad_chip, SPISNIF_REG_CONTROL);
	if (reg_value < 0)
		return -EFAULT ;

	ad_write_reg(ad_chip,
		     SPISNIF_REG_CONTROL,
		     reg_value|SPISNIF_CONTROL_MASK_TRIGGER);

	/* wait for interrupt */
	wait_event_interruptible(ad_chip->wait_queue, ad_chip->irq_occur);
	ad_chip->irq_occur = 0;

	return 0;
}

struct file_operations ad_fops = {
	.read	= spisnif_read,
	.open	= spisnif_open,
	.release= spisnif_release,
};

static irqreturn_t ad_interrupt(int irq, void *data) {
	struct spisnif_chip *ad_chip = data;
	int ret;

	/* acknowledge interrupt */
	ad_chip->irq_occur = 1;
	wake_up_interruptible(&ad_chip->wait_queue);
	/* acknowledge interrupt */
	ret = ad_read_reg(ad_chip, SPISNIF_REG_STATUS);

	return IRQ_HANDLED;
}

/* /sys/ operations */
static ssize_t show_fifo_base_addr(	struct device *dev,
					struct device_attribute *attr,
					char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);

	return sprintf(buf, "%d\n", ad_chip->resource_mem->start);
}

static ssize_t show_fifo_v1_size(	struct device *dev,
					struct device_attribute *attr,
					char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int fifo_size = 0;

	fifo_size = ad_read_reg(ad_chip, SPISNIF_REG_FIFO_SIZE_0)&0x001F;
	fifo_size = fifo_size*SPISNIF_RAMSIZE;

	return sprintf(buf, "%d\n", fifo_size);
}

static ssize_t show_fifo_v2_size(	struct device *dev,
					struct device_attribute *attr,
					char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int fifo_size = 0;

	fifo_size = (ad_read_reg(ad_chip, SPISNIF_REG_FIFO_SIZE_0)&0x03E0)>>5;
	fifo_size = fifo_size*SPISNIF_RAMSIZE;

	return sprintf(buf, "%d\n", fifo_size);
}

static ssize_t show_fifo_v3_size(	struct device *dev,
					struct device_attribute *attr,
					char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int fifo_size = 0;

	fifo_size = (ad_read_reg(ad_chip, SPISNIF_REG_FIFO_SIZE_0)&0x7C00)>>10;
	fifo_size = fifo_size*SPISNIF_RAMSIZE;

	return sprintf(buf, "%d\n", fifo_size);
}

static ssize_t show_fifo_v4_size(	struct device *dev,
					struct device_attribute *attr,
					char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int fifo_size = 0;

	fifo_size = ad_read_reg(ad_chip, SPISNIF_REG_FIFO_SIZE_1)&0x001F;
	fifo_size = fifo_size*SPISNIF_RAMSIZE;

	return sprintf(buf, "%d\n", fifo_size);
}

static ssize_t show_fifo_v5_size(	struct device *dev,
					struct device_attribute *attr,
					char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int fifo_size = 0;

	fifo_size = (ad_read_reg(ad_chip, SPISNIF_REG_FIFO_SIZE_1)&0x03E0)>>5;
	fifo_size = fifo_size*SPISNIF_RAMSIZE;

	return sprintf(buf, "%d\n", fifo_size);
}

static ssize_t show_fifo_v6_size(	struct device *dev,
					struct device_attribute *attr,
					char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int fifo_size = 0;

	fifo_size = (ad_read_reg(ad_chip, SPISNIF_REG_FIFO_SIZE_1)&0x7C00)>>10;
	fifo_size = fifo_size*SPISNIF_RAMSIZE;

	return sprintf(buf, "%d\n", fifo_size);
}

static ssize_t show_prescaler(struct device *dev,
			      struct device_attribute *attr,
			      char *buf)
{
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);

	return sprintf(buf, "%d\n", ad_read_reg(ad_chip, SPISNIF_REG_PRESCALER));
}

static ssize_t store_prescaler(struct device *dev,
			       struct device_attribute *attr,
			       const char *buf, size_t size)
{
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);

	ad_write_reg(ad_chip, SPISNIF_REG_PRESCALER, simple_strtoul(buf, NULL, 10));

	return size;
}

static ssize_t show_oversampling(struct device *dev,
				struct device_attribute *attr,
				char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);

	return sprintf(buf, "%d\n", (ad_read_reg(ad_chip, SPISNIF_REG_CONTROL)>>6)&0x7);
}

static ssize_t store_oversampling(struct device *dev,
				struct device_attribute *attr,
				const char *buf, size_t size) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int os;
	int reg_value;

	os = simple_strtoul(buf, NULL, 10);
	os = (os&0x07)<<6;

	reg_value = ad_read_reg(ad_chip, SPISNIF_REG_CONTROL);
	if (reg_value < 0)
		return size;

	ad_write_reg(ad_chip,
		     SPISNIF_REG_CONTROL,
		     (reg_value&(~SPISNIF_CONTROL_MASK_OS))|os);

	return size;
}

static ssize_t store_ack_fifo(struct device *dev,
				struct device_attribute *attr,
				const char *buf, size_t size) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int reg_value;

	reg_value = ad_read_reg(ad_chip, SPISNIF_REG_CONTROL);
	if (reg_value < 0)
		return size;

	ad_write_reg(ad_chip,
		     SPISNIF_REG_CONTROL,
		     reg_value|SPISNIF_CONTROL_MASK_ACK_FIFO);

	return size;
}

static ssize_t show_ext_trig(struct device *dev,
				struct device_attribute *attr,
				char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);

	return sprintf(buf, "%d\n",
		       (ad_read_reg(ad_chip, SPISNIF_REG_CONTROL)&SPISNIF_CONTROL_MASK_EXT_TRIG_NUM)
		       >>1);
}

static ssize_t store_ext_trig(struct device *dev,
				struct device_attribute *attr,
				const char *buf, size_t size) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int ext_trig, reg_value;

	ext_trig = simple_strtoul(buf, NULL, 10);
	if ((ext_trig < 0) || (ext_trig > 19))
		return size;

	reg_value = ad_read_reg(ad_chip, SPISNIF_REG_CONTROL);
	if (reg_value < 0)
		return size;

	reg_value = reg_value&(~SPISNIF_CONTROL_MASK_EXT_TRIG_NUM);

	ad_write_reg(ad_chip,
		     SPISNIF_REG_CONTROL,
		     reg_value | (ext_trig<<1));

	return size;
}

static ssize_t show_ext_trig_inv(struct device *dev,
				struct device_attribute *attr,
				char *buf) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);

	return sprintf(buf, "%d\n",
		       (ad_read_reg(ad_chip, SPISNIF_REG_CONTROL)&SPISNIF_CONTROL_MASK_EXT_TRIG_INV)
		       >>9);
}

static ssize_t store_ext_trig_inv(struct device *dev,
				struct device_attribute *attr,
				const char *buf, size_t size) {
	struct platform_device *pdev =
		container_of(dev, struct platform_device, dev);
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);
	int ext_trig_inv, reg_value;

	ext_trig_inv = simple_strtoul(buf, NULL, 10);
	if ((ext_trig_inv < 0) || (ext_trig_inv > 1))
		return size;

	reg_value = ad_read_reg(ad_chip, SPISNIF_REG_CONTROL);
	if (reg_value < 0)
		return size;

	reg_value = reg_value&(~SPISNIF_CONTROL_MASK_EXT_TRIG_INV);

	ad_write_reg(ad_chip,
		     SPISNIF_REG_CONTROL,
		     reg_value | (ext_trig_inv<<9));

	return size;
}


static DEVICE_ATTR(fifo_base_addr, S_IRUGO, show_fifo_base_addr, 0);
static DEVICE_ATTR(fifo_v1_size, S_IRUGO, show_fifo_v1_size, 0);
static DEVICE_ATTR(fifo_v2_size, S_IRUGO, show_fifo_v2_size, 0);
static DEVICE_ATTR(fifo_v3_size, S_IRUGO, show_fifo_v3_size, 0);
static DEVICE_ATTR(fifo_v4_size, S_IRUGO, show_fifo_v4_size, 0);
static DEVICE_ATTR(fifo_v5_size, S_IRUGO, show_fifo_v5_size, 0);
static DEVICE_ATTR(fifo_v6_size, S_IRUGO, show_fifo_v6_size, 0);

/* controls */
static DEVICE_ATTR(oversampling, S_IRUGO | S_IWUGO, show_oversampling, store_oversampling);
static DEVICE_ATTR(ack_fifo, S_IWUGO, 0, store_ack_fifo);
static DEVICE_ATTR(ext_trig, S_IRUGO | S_IWUGO, show_ext_trig, store_ext_trig);
static DEVICE_ATTR(ext_trig_inv, S_IRUGO | S_IWUGO, show_ext_trig_inv, store_ext_trig_inv);

static DEVICE_ATTR(prescaler, S_IRUGO | S_IWUGO, show_prescaler, store_prescaler);

static int spisnif_probe(struct platform_device *pdev)
{
	struct spisnif_chip *ad_chip;
	struct resource *resource_memory, *resource_irq;
	int ret = 0;

	resource_memory = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	resource_irq = platform_get_resource(pdev, IORESOURCE_IRQ, 0);
	if ((resource_irq == NULL) || (resource_memory == NULL)) {
		ret = -ENODEV;
		dev_err(&pdev->dev, "Device spisnif not found\n");
		goto error_exit;
	}

	if (!request_mem_region(resource_memory->start,
				resource_size(resource_memory), DRIVER_NAME)) {
		dev_err(&pdev->dev, "Can't request memory region %x to %x\n",
		resource_memory->start, resource_memory->start + resource_memory->end);
		ret = -ENOMEM;
		goto error_exit;
	}

	ad_chip = kzalloc(sizeof(struct spisnif_chip), GFP_KERNEL);
	if(!ad_chip) {
		ret = -ENOMEM;
		dev_err(&pdev->dev,
			"Can't allocate memory for spisnif_chip\n");
		goto release_region;
	}

	ad_chip->resource_mem = resource_memory;
	ad_chip->resource_irq = resource_irq;

	dev_set_drvdata(&pdev->dev, ad_chip);

	ad_chip->reg_base = ioremap_nocache(resource_memory->start,
					    resource_size(resource_memory));
	if (!ad_chip->reg_base) {
		ret = -EIO;
		goto free_chip;
	}

	/* Create sysfs */
	ret = device_create_file(&pdev->dev, &dev_attr_fifo_base_addr);
	if (ret < 0) {
		pr_err("Can't create /sys/../fifo_base_addr\n");
		goto exit_iounmap;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_fifo_v1_size);
	if (ret < 0) {
		pr_err("Can't create /sys/../fifo_v1_size\n");
		goto error_remove_file_fifo_base_addr;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_fifo_v2_size);
	if (ret < 0) {
		pr_err("Can't create /sys/../fifo_v2_size\n");
		goto error_remove_file_fifo_v1_size;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_fifo_v3_size);
	if (ret < 0) {
		pr_err("Can't create /sys/../fifo_v3_size\n");
		goto error_remove_file_fifo_v2_size;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_fifo_v4_size);
	if (ret < 0) {
		pr_err("Can't create /sys/../fifo_v4_size\n");
		goto error_remove_file_fifo_v3_size;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_fifo_v5_size);
	if (ret < 0) {
		pr_err("Can't create /sys/../fifo_v5_size\n");
		goto error_remove_file_fifo_v4_size;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_fifo_v6_size);
	if (ret < 0) {
		pr_err("Can't create /sys/../fifo_v6_size\n");
		goto error_remove_file_fifo_v5_size;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_prescaler);
	if (ret < 0) {
		pr_err("Can't create /sys/../prescaler\n");
		goto error_remove_file_fifo_v6_size;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_oversampling);
	if (ret < 0) {
		pr_err("Can't create /sys/../oversampling\n");
		goto error_remove_file_prescaler;
	}

	ret = device_create_file(&pdev->dev, &dev_attr_ack_fifo);
	if (ret < 0) {
		pr_err("Can't create /sys/../ack_fifo\n");
		goto error_remove_file_oversampling;
	}
	ret = device_create_file(&pdev->dev, &dev_attr_ext_trig);
	if (ret < 0) {
		pr_err("Can't create /sys/../ext_trig\n");
		goto error_remove_file_ack_fifo;
	}
	ret = device_create_file(&pdev->dev, &dev_attr_ext_trig_inv);
	if (ret < 0) {
		pr_err("Can't create /sys/../ext_trig_inv\n");
		goto error_remove_file_ext_trig;
	}

	init_waitqueue_head(&ad_chip->wait_queue);
	/* TODO: check return */

	/* register file */
	cdev_init(&ad_chip->cdev, &ad_fops);
	ad_chip->cdev.owner = THIS_MODULE;
	ret = alloc_chrdev_region(&ad_chip->devt, 0, 5, DRIVER_NAME);
	if (ret < 0) {
		pr_err("Can't allocating major/minor number\n");
		goto error_remove_file_ext_trig_inv;
	}

	ret = cdev_add(&ad_chip->cdev, ad_chip->devt, 1);
	if (ret < 0) {
		pr_err("Registering char device failed\n");
		goto error_unregister_chrdev_region;
	}
	ad_chip->cdev_open = 0;
	dev_info(&pdev->dev, "Registering char driver major:%d minor:%d\n",
		 MAJOR(ad_chip->devt), MINOR(ad_chip->devt));

	/* TODO: check ID */

	ret = request_irq(resource_irq->start, ad_interrupt,
			  0, "spisnif", ad_chip);
	if (ret) {
		dev_err(&pdev->dev, "Can't request irq %d\n",
			resource_irq->start);
		goto error_unregister_chrdev;
	}

	/* end probe */
	return 0;

/*error_free_irq:*/
	free_irq(resource_irq->start, ad_chip);
error_unregister_chrdev:
	unregister_chrdev(ad_chip->devt, DRIVER_NAME);
error_unregister_chrdev_region:
	unregister_chrdev_region(ad_chip->devt, 5);
	cdev_del(&ad_chip->cdev);
error_remove_file_ext_trig_inv:
	device_remove_file(&pdev->dev, &dev_attr_ext_trig_inv);
error_remove_file_ext_trig:
	device_remove_file(&pdev->dev, &dev_attr_ext_trig);
error_remove_file_ack_fifo:
	device_remove_file(&pdev->dev, &dev_attr_ack_fifo);
error_remove_file_oversampling:
	device_remove_file(&pdev->dev, &dev_attr_oversampling);
error_remove_file_prescaler:
	device_remove_file(&pdev->dev, &dev_attr_prescaler);
error_remove_file_fifo_v6_size:
	device_remove_file(&pdev->dev, &dev_attr_fifo_v6_size);
error_remove_file_fifo_v5_size:
	device_remove_file(&pdev->dev, &dev_attr_fifo_v5_size);
error_remove_file_fifo_base_addr:
	device_remove_file(&pdev->dev, &dev_attr_fifo_base_addr);
exit_iounmap:
	iounmap(ad_chip->reg_base);
free_chip:
	kfree(ad_chip);
release_region:
	release_mem_region(resource_memory->start,
			   resource_size(resource_memory));
error_exit:
	return ret;
}

static int spisnif_remove(struct platform_device *pdev)
{
	struct spisnif_chip *ad_chip = dev_get_drvdata(&pdev->dev);

	free_irq(ad_chip->resource_irq->start, ad_chip);
	unregister_chrdev(ad_chip->devt, DRIVER_NAME);
	unregister_chrdev_region(ad_chip->devt, 5);
	cdev_del(&ad_chip->cdev);
	device_remove_file(&pdev->dev, &dev_attr_ext_trig_inv);
	device_remove_file(&pdev->dev, &dev_attr_ext_trig);
	device_remove_file(&pdev->dev, &dev_attr_ack_fifo);
	device_remove_file(&pdev->dev, &dev_attr_prescaler);
	device_remove_file(&pdev->dev, &dev_attr_fifo_v2_size);
	device_remove_file(&pdev->dev, &dev_attr_fifo_v1_size);
	device_remove_file(&pdev->dev, &dev_attr_fifo_base_addr);
	free_irq(ad_chip->resource_irq->start, ad_chip);
	iounmap(ad_chip->reg_base);
	release_mem_region(ad_chip->resource_mem->start,
		   resource_size(ad_chip->resource_mem));
	kfree(ad_chip);
	return 0;
}

static struct platform_driver spisnif_drv = {
	.driver = {
		.name = DRIVER_NAME,
		.owner = THIS_MODULE,
	},
	.probe = spisnif_probe,
	.remove = spisnif_remove,
};

static int __init spisnif_init(void)
{
	return platform_driver_register(&spisnif_drv);
}
module_init(spisnif_init);

static void __exit spisnif_exit(void)
{
	platform_driver_unregister(&spisnif_drv);
}
module_exit(spisnif_exit);

MODULE_AUTHOR("Fabien Marteau <fabien.marteau@armadeus.com> & Kevin Joly <joly.kevin25@gmail.com>");
MODULE_DESCRIPTION("spisnif driver");
MODULE_LICENSE("GPL");
