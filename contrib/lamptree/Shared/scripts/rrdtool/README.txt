Purpose:
	RRDp.pm seems to have strange behavior when it comes to
	error handling.  This patch will make it behave has it 
	should, instead of hanging in a loop when an error is
	detected.

Instructions:
	Find your copy of RRDp.pm:
		find /usr | grep RRDp.pm			

	Copy the patchfile to that location:
		cp patchfile /PATH/TO/FILE && cd /PATH/TO/FILE 

	Patch:
		patch -p0 -u < patchfile

	Remove the patchfile:
		rm -f patchfile

-jason
04/16/2007

