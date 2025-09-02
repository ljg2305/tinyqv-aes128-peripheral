# AES-128 Encrypt/Decrypt 

Author: Lawrence Gray 

Peripheral index: 23 

## What it does

This peripheral is used for acceleration of encryption and decryption using the AES-128 algorithm.
The execution time of cryptography algorithms on a basic RISC-V instruction set can be very high, especially when considering the number of load stores to handle the quantity of data to both store and manipulate the encryption data state. Having this as a peripheral allows the processor to offload the task of encryption and spend time instead on its primary task. 
This project does not include the generation of the AES-128 key, this key should either be randomly generated and sent to the receiver or be precomputed by some other means. 
Specifically this implements the most basic version of AES-128, ECB (Electronic Codebook). In this mode, each plain text block is encrypted independently using the same key.

## Register map

| Address |  Name   | Access  | Description                                                       |
|---------|---------|---------|-------------------------------------------------------------------|
| 0x00    | CTRL    | R/W     | Bit 0; Start (flappy) Bit 1-2; Operation (Encrypt,Decrypt),Bit 3; Interrupt Enable,Bit 7; Interrupt Clear      |
| 0x04    | KEY0    | R/W     | AES Key [31:0]                                                    |
| 0x08    | KEY1    | R/W     | AES Key [63:32]                                                   |
| 0x0C    | KEY2    | R/W     | AES Key [95:64]                                                   |
| 0x10    | KEY3    | R/W     | AES Key [127:96]                                                  |
| 0x14    | DATA0   | R/W     | Input block [31:0]                                                |
| 0x18    | DATA1   | R/W     | Input block [63:32]                                               |
| 0x1C    | DATA2   | R/W     | Input block [95:64]                                               |
| 0x20    | DATA3   | R/W     | Input block [127:96]                                              |
| 0x24    | STATUS  | R       | Bit 0; Ready, Bit 1; Done (read only)                             |
| 0x28    | RESULT0 | R       | Output block [31:0]    (read only)                                |
| 0x2C    | RESULT1 | R       | Output block [63:32]   (read only)                                |
| 0x30    | RESULT2 | R       | Output block [95:64]   (read only)                                |
| 0x34    | RESULT3 | R       | Output block [127:96]  (read only)                                |

## How to test
The basics of using this peripheral are as follows
  * Write the (precomputed) Key to addresses 0x04-0x10
  * Write the input data to addresses 0x14-0x20 
    * for data shorter than 128 bits then the remaining data should be padded with 0's
    * for data longer than 128 bits then it should be split into 128bit chunks and calculated separately.
    * for encrypt then write the raw data to be sent to receiver.
    * for decrypt then write the encrypted data received from the sender. 
  * Read address 0x24, check if bit 0 is high to see if peripheral is ready for new data. 
  * Write to the CTRL reg
    * write 1 to bit 0 when ready to execute the encrypt/decrypt. If only writing to this bit then you must do a read modify write.
      * The start bit is self clearing, this will only stay high for one cycle. 
    * write to bit 1: 0 for encrypt, 1 for decrypt. (bit 2 is reserved for extended modes of operation) 
    * write a 1 to bit 3 to enable the interrupt signal when the encrypt/decrypt is complete. 
    * If interrupt is enabled and has fire clear the interrupt with a read modify write to this bit. 
  * await done/interrupt
    * Once start bit has gone high it takes a significant number of cycles to get the result.
    * Either poll address 0x24 and check for bit 1 to see if the computation is 'done'. 
    * Or if the interrupt is enabled, await the interrupt.
  * read result. 
    * When the computation is complete the result can be read from addresses 0x28-0x34

