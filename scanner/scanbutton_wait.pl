#!/usr/bin/perl -w
#
# scanbutton_wait.pl
# Copyright 2014 Max Christian Pohle [max AT coderonline.de]
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use Sane qw(SANE_STATUS_GOOD SANE_TYPE_BUTTON);
use POSIX qw(pause);
use Time::HiRes qw(setitimer ITIMER_REAL);

# check command line options...
my %args;
if(defined($ARGV[0]) and $ARGV[0] eq '-v')
{ $args{verbose} = 1; }

print q[started] if defined $args{verbose};

# enumerate sane devices...
my @devices = Sane->get_devices();
if($#devices == -1)
{ die qq[no sane devices found! check power connector, usb cable or network connection\n]; }
elsif ($Sane::STATUS != SANE_STATUS_GOOD) 
{ die qq[unable to enumerate all sane devices\n]; }

if(defined($args{verbose}))
{
  foreach my $dev (@devices)
  {    
    foreach(keys($dev))
    { print qq[$_:\t$dev->{$_}\n]; }
  }
}

# decide whether to use the first device or what is found in the environment variable...
my $device_name = $devices[0]->{name};
if(defined($ENV{'SANE_DEFAULT_DEVICE'}))
{ $device_name = $ENV{'SANE_DEFAULT_DEVICE'}; }

# open that device...
my $device = Sane::Device->open($device_name); 
if ($Sane::STATUS != SANE_STATUS_GOOD)
{ die qq[Scanner $device_name could not be opened!\n]; }

# check all options and find buttons (those are displayed by scanimage -A as well)
my %buttons;
for($i=0; $i<$device->get_option(0); $i++)
{
  my $option = $device->get_option_descriptor($i);
  if ($Sane::STATUS == SANE_STATUS_GOOD) 
  {
    #if($option->{type} == SANE_TYPE_BUTTON) # it should, but does not work
    if(defined($option->{name}) and $option->{desc} =~ /button/) # work around
    {
      if(defined($args{verbose}))
      { print "- monitoring button '".$option->{name}."'\n"; } 
      $buttons{$i} = $option->{name}; 
    }
    else
    { 
      if(defined($args{debug}))
      {
        foreach(keys $option)
        { print qq[\t$_ = $option->{$_}\n]; }
      }
    }
  }
}

# we use a pull method to check the buttons status. it is derived by the
# low level API for event timers, because that is easier to port to C
$SIG{ALRM} = sub 
{ 
  foreach(keys(%buttons))
  {
    #print qq[$_ .. $buttons{$_}\n];
    $button = $device->get_option($_); # check the buttons status
    if($button) # if it got pressed...
    { 
      # print the buttons name to STDOUT
      my $btn_name = $buttons{$_};
         $btn_name =~ s/[^a-z]//gi;
      print qq[$btn_name\n];
      # print qq[$buttons{$_}\n];
      # cleanly destroy the device object so that the 
      # scanner can be used by another person...
      $device->cancel();
      undef $device;       
      exit(0); # EXIT_SUCCESS
    }

  }
};

# this will initialize the timer, which will trigger an ALARM Signal every .1 seconds...
setitimer(ITIMER_REAL, .1, .1);

# endless loop / hit CTRL+C to quit. 
while(1)
{
#  my $input = <STDIN>;
#  if($input =~ /[0-9].*/)
#  {
#    print $buttons{$_};
#    exit(0)
#  }
  pause; 
}

