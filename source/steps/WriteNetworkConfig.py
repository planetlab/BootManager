#!/usr/bin/python2

# Copyright (c) 2003 Intel Corporation
# All rights reserved.
#
# Copyright (c) 2004-2006 The Trustees of Princeton University
# All rights reserved.
# expected /proc/partitions format

import os, string

from Exceptions import *
import utils
import BootAPI
import ModelOptions

def Run( vars, log ):
    """
    Write out the network configuration for this machine:
    /etc/hosts
    /etc/sysconfig/network-scripts/ifcfg-eth0
    /etc/resolv.conf (if applicable)
    /etc/sysconfig/network

    It is assumed the caller mounted the root partition and the vserver partition
    starting on SYSIMG_PATH - it is not checked here.

    The values to be used for the network settings are to be set in vars
    in the variable 'NETWORK_SETTINGS', which is a dictionary
    with keys:

     Key               Used by this function
     -----------------------------------------------
     node_id
     node_key
     method            x
     ip                x
     mac               x (optional)
     gateway           x
     network           x
     broadcast         x
     netmask           x
     dns1              x
     dns2              x (optional)
     hostname          x
     domainname        x

    Expect the following variables from the store:
    SYSIMG_PATH             the path where the system image will be mounted
                            (always starts with TEMP_PATH)
    NETWORK_SETTINGS  A dictionary of the values from the network
                                configuration file
    Sets the following variables:
    None
    """

    log.write( "\n\nStep: Install: Writing Network Configuration files.\n" )

    try:
        SYSIMG_PATH= vars["SYSIMG_PATH"]
        if SYSIMG_PATH == "":
            raise ValueError, "SYSIMG_PATH"

    except KeyError, var:
        raise BootManagerException, "Missing variable in vars: %s\n" % var
    except ValueError, var:
        raise BootManagerException, "Variable in vars, shouldn't be: %s\n" % var


    try:
        network_settings= vars['NETWORK_SETTINGS']
    except KeyError, e:
        raise BootManagerException, "No network settings found in vars."

    try:
        hostname= network_settings['hostname']
        domainname= network_settings['domainname']
        method= network_settings['method']
        ip= network_settings['ip']
        gateway= network_settings['gateway']
        network= network_settings['network']
        netmask= network_settings['netmask']
        dns1= network_settings['dns1']
        mac= network_settings['mac']
    except KeyError, e:
        raise BootManagerException, "Missing value %s in network settings." % str(e)

    try:
        dns2= ''
        dns2= network_settings['dns2']
    except KeyError, e:
        pass

        
    log.write( "Writing /etc/hosts\n" )
    hosts_file= file("%s/etc/hosts" % SYSIMG_PATH, "w" )    
    hosts_file.write( "127.0.0.1       localhost\n" )
    if method == "static":
        hosts_file.write( "%s %s.%s\n" % (ip, hostname, domainname) )
    hosts_file.close()
    hosts_file= None
    

    log.write( "Writing /etc/sysconfig/network-scripts/ifcfg-eth0\n" )
    eth0_file= file("%s/etc/sysconfig/network-scripts/ifcfg-eth0" %
                    SYSIMG_PATH, "w" )
    eth0_file.write( "DEVICE=eth0\n" )
    if method == "static":
        eth0_file.write( "BOOTPROTO=static\n" )
        eth0_file.write( "IPADDR=%s\n" % ip )
        eth0_file.write( "NETMASK=%s\n" % netmask )
        eth0_file.write( "GATEWAY=%s\n" % gateway )
    else:
        eth0_file.write( "BOOTPROTO=dhcp\n" )
        eth0_file.write( "DHCP_HOSTNAME=%s\n" % hostname )
    if mac != "":
        eth0_file.write( "HWADDR=%s\n" % mac )
    eth0_file.write( "ONBOOT=yes\n" )
    eth0_file.write( "USERCTL=no\n" )
    eth0_file.close()
    eth0_file= None

    if method == "static":
        log.write( "Writing /etc/resolv.conf\n" )
        resolv_file= file("%s/etc/resolv.conf" % SYSIMG_PATH, "w" )
        if dns1 != "":
            resolv_file.write( "nameserver %s\n" % dns1 )
        if dns2 != "":
            resolv_file.write( "nameserver %s\n" % dns2 )
        resolv_file.write( "search %s\n" % domainname )
        resolv_file.close()
        resolv_file= None

    log.write( "Writing /etc/sysconfig/network\n" )
    network_file= file("%s/etc/sysconfig/network" % SYSIMG_PATH, "w" )
    network_file.write( "NETWORKING=yes\n" )
    network_file.write( "HOSTNAME=%s.%s\n" % (hostname, domainname) )
    if method == "static":
        network_file.write( "GATEWAY=%s\n" % gateway )
    network_file.close()
    network_file= None
