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

+ **CONTROL** : Control register

| 15 downto 4 |  3   |        2     |           1       |   0   |
|:-----------:|:----:|:------------:|:-----------------:|:-----:|
|    void     | busy | start/stop_n | RAM pointer reset | Reset |


ARMadeus linux driver
---------------------

