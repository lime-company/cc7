/*
 * Building OpenSSL for the different Android architectures requires 
 * different settings. In order to be able to use assembly code on all
 * devices, we keep optimal settings for all devices and use this 
 * intermediate header file to use the proper opensslconf.h file 
 * for each architecture.
 */
