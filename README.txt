* We have not written our own makefile, instead used the already given one.
* So, the following should work fine
	> make deps
  	> make

  So the out file will be named 'flcli' in the directory 
  	<PROJECT_ROOTDIR>/makestuff/apps/flcli/lin.x64/rel/


We implemented read module, encryption module, decryption module similar to previous assignments which reads 8 bytes of data, one byte at a time. 
In timer, we gave two outputs, one having T interval(depending upon N) and other output D(2T). 
io_interface module creates the channels for reading and writing. The channels are created as per the specifiations mentioned in the problem statement. Each channel is implemented as an 8-bit register.
Sequencer module defines the states such as ready, loading cash, dispensing cash, read, communication with backend, and check_status as provided in the PS.

In the top module, we have defined a signal state, which is mapped to the `state` output of sequencer and connected as input to the display module, so that display can do it's work according to the state. 


HONOR CODE 
-----------

The entire work submitted by the following group memebers "The entire work submitted by the following group members have been done by them, and no part has been copied, or copied-and-modified-to-obfuscate, except the code fragments given by the instructors.  All work that has been referenced has been properly cited, and no cited work has been copied, or copied-and-modified-to-obfuscate."

	 - Vinayak K (150050098)
	 - Mohit Patil (150050017)
	 - Rajat Kapoor (150050037)
	 - Fenil Vanvi (150050003)