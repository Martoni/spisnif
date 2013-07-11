spisnif component
========================


FPGA component
--------------

### registers table ###

spisnif is composed of 8 16 bits register :

|   offset 8bits  | Offset 16bits  | name            | R/W | description               |
|:---------------:|:--------------:|:---------------:|:---:|:-------------------------:|
|    0x00         | 0x00           | CONTROL         | R/W | Control register          |
|    0x02         | 0x01           | FIFO_MOSI       | R   | Bits access for MOSI      |
|    0x04         | 0x02           | FIFO_MISO       | R   | Bits access for MISO      |
|    0x06         | 0x03           | FIFO_PACKET     | R   | Packets descriptions      |
|    0x08         | 0x04           | STATUS          | R   | Status reg                |
|    0x0A         | 0x05           | CONFIG          | R/W | SPI protocol config       |
|    0x0C         | 0x06           |                 | R   |                           |
|    0x0E         | 0x07           | ID              | R   | Component ID              |

### registers descriptions ###

#### CONTROL ####

| 15    | 14      | 13 | 12 | 11 |  10 downto  0   |
|:-----:|:-------:|:--:|:--:|:--:|:---------------:|
| reset | irq_ack |    |    |    | irq_pnum_trig   |
|   W   |   R/W   |  0 | 0  | 0  |      R/W        |

- **reset**: reset all fifos by writing '1'.
- **irq_ack**: acknowledge interrupt.
- **irq_pnum_trig**: Packets number to trigger interrution. 0 value disable interrupt

#### FIFO_PACKET ####

| 15  downto  0 |
|:-------------:|
| packet_desc   |
|      R        |

- **packet_desc**: bits number under the packet.

#### FIFO_MOSI ####

| 15  downto  0 |
|:-------------:|
|  mosi_value   |
|      R        |

- **mosi_value**: bit vector of mosi packet.

#### FIFO_MISO ####

| 15  downto  0 |
|:-------------:|
|  miso_value   |
|      R        |

- **miso_value**: bit vector of miso packet.

#### STATUS ####

| 15         |     14    |        13      | 12 | 11 |  10 downto  0   |
|:----------:|:---------:|:--------------:|:--:|:--:|:---------------:|
| fifo_empty | fifo_full | fifo_mxsx_full |    |    |   packet_num    |
|    R       |     R     |       R        |  0 | 0  |       R         |

- **fifo_empty**: fifo_packet empty flag
- **fifo_full**: fifo_packet full flag
- **fifo_mxsx_full**: fifo_mxsx full flax
- **packet_num**: packets number under fifo.

#### CONFIG ####

| 15  dowto 3 |   2   |   1  |   0  |
|:-----------:|:-----:|:----:|:----:|
|             | CSPOL | CPHA | CPOL |
|      0      |  R/W  |  R/W |  R/W |

- **CPOL**: sck polarity (cf linux kernel documentation Documentation/spi/spi-summary)
- **CPHA**: sck phase (cf linux kernel documentation Documentation/spi/spi-summary)
- **CSPOL**: chip select polarity:
	- '0': chip select active low
	- '1': chip select active high

#### ID ####

| 15  downto  0 |
|:-------------:|
|      id       |
|      R        |

- **id**: component identifiant number.

ARMadeus linux driver
---------------------

