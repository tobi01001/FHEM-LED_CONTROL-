=head1
        98_LEDStripe2.pm

# $Id: $

        Version 0.1

=head1 SYNOPSIS
        FHEM Module and firmware for controlling WS2812b LED stripes
        contributed by Stefan Willmeroth 2016
		- adopted and changed by Toby 2018

=head1 DESCRIPTION
        98_LEDStripe2.pm is a perl module controlling a configurable LED Stripe incl WS2812FX library and should be copied into the FHEM directory.

=head1 AUTHOR - Stefan Willmeroth / Toby
        swi@willmeroth.com / tobi931@googlemail.com (forum.fhem.de)
=cut

##############################################
package main;

use strict;
use warnings;
use HTTP::Request;
use LWP::UserAgent;
use Switch;
use Color;
use JSON;
use HttpUtils;
#require 'HttpUtils.pm';

my %Commands = (
	"on:noArg" => "on",
	"off:noArg" => "off"
	);

my @gets = sort keys(%Commands); ## just the basic. gets updated dynamically during define (with non blocking http call)
my $defaultVerbose = 4; ###(can set the omplete verbose level of the module (for debugging).
my $callDelay = 1; ### number of seconds a call is delayed using an internal Timer....


##############################################
sub LEDStripe2_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "LEDStripe2_Set";
  $hash->{DefFn}     = "LEDStripe2_Define";
  $hash->{GetFn}     = "LEDStripe2_Get";
  $hash->{NotifyFn}  = "LEDStripe2_Notify";
  $hash->{ReadFn}	 = "LEDStripe2_Read";
  $hash->{ReadyFn}	 = "LEDStripe2_Ready";
  $hash->{AttrList}  = "interval power_switch disable:0,1 backwardCompatibility:0,1 timeout ".$readingFnAttributes;
  $hash->{cmds}      = ();
  $hash->{backwardCompatibility} = 0;
  $hash->{firstInit} = 1;
  Log(2, "LEDStripe2_Initialize called");
}

###################################
sub LEDStripe2_Read
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name, $defaultVerbose, "LEDStripe2 $name LEDStripe2_Read called!");
}

###################################
sub LEDStripe2_Ready
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name, $defaultVerbose, "LEDStripe2 $name LEDStripe2_Ready called!");
}

###################################
sub LEDStripe2_SetParameters
{
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	
	@gets = ();
	@gets = sort keys(%Commands); 
	Log3($name, $defaultVerbose, "LEDStripe2 $name LEDStripe2_SetParameters called!");
	foreach (%{$hash->{cmds}} )
	{
		if ( ref eq 'HASH' and exists $_->{type} ) 
		{
			if($_->{type} eq "num")
			{
				my $inc = $_->{inc};
				if($_->{max} >= 100)
				{	
					if($_->{max} <= 1000) 
					{
						$inc = 1;
					}
					Log3($name, $defaultVerbose, "LEDStripe2 $name $_->{name}:knob,min:$_->{min},max:$_->{max},step:$inc,width:70,height:70,angleOffset:-65,angleArc:130,displayPrevious:true,thickness:.5,cursor:3");
					push(@gets, "$_->{name}:knob,min:$_->{min},max:$_->{max},step:$inc,width:70,height:70,angleOffset:-65,angleArc:130,displayPrevious:true,thickness:.5,cursor:3");
				}
				elsif($_->{max} <50)
				{
					Log3($name, $defaultVerbose, "LEDStripe2 $name $_->{name}:selectnumbers,$_->{min},$inc,$_->{max},0,lin");
					push(@gets, "$_->{name}:selectnumbers,$_->{min},$inc,$_->{max},0,lin");
				}
				else
				{	
					Log3($name, $defaultVerbose, "LEDStripe2 $name $_->{name}:slider,$_->{min},$inc,$_->{max}");
					push(@gets, "$_->{name}:slider,$_->{min},$inc,$_->{max}");
				}
			}
			elsif($_->{type} eq "bool")
			{
				Log3($name, $defaultVerbose, "LEDStripe2 $name $_->{name}:uzsuToggle,on,off"); 
				push(@gets, "$_->{name}:uzsuToggle,on,off");
			}		
			elsif($_->{type} eq "list")
			{
				my @pList = sort { $_->{options}{$a} <=> $_->{options}{$b} } keys(%{$_->{options}});
				my $pNames = join(",",@pList);
				if(scalar(@pList) <= 4)
				{
					Log3($name, $defaultVerbose, "LEDStripe2 $name $_->{name}:select,$pNames");
					push(@gets, "$_->{name}:select,$pNames");
				}
				else
				{
					Log3($name, $defaultVerbose, "LEDStripe2 $name $_->{name}:$pNames");
					push(@gets, "$_->{name}:$pNames");
				}
			}
			elsif($_->{type} eq "rgbColor")
			{
				Log3($name, $defaultVerbose, "LEDStripe2 $name $_->{name}:colorpicker");
				push(@gets, "$_->{name}:colorpicker");
			}		
		}
		else
		{
			Log3($name, $defaultVerbose+1, "LEDStripe2 $name Nothing to do for $_ as it is no hash and/or does not contain type");
		}
	} 
	my $bwComp = AttrVal($name, "backwardCompatibility", 0);
	if($bwComp)
	{
		my @addgets = split(" ","fire:noArg rainbow:noArg sparks:noArg white_sparks:noArg sunrise sunset range solid_rgb pixel ");
		push(@gets, @addgets);
	}
}


####
sub LEDStripe2_delayedCall
{
  my ($command) = @_;
  fhem ("set $command");
}

###################################
sub LEDStripe2_Set($@)
{
  my ($hash, @a) = @_;
  my $rc = undef;
  my $reDOUBLE = '^(\\d+\\.?\\d{0,2})$';
  my $remote_ip = $hash->{remote_ip};
  my $remote_port = $hash->{remote_port};
  my $name = $hash->{NAME};
  my $URL = "http://" . $remote_ip . (defined $remote_port?":".$remote_port:"");
  
  return "" if(IsDisabled($name));
  
  return "Unknown argument $a[0] choose one of ".join(' ', @gets) unless(defined($a[1]) && $a[1] ne "?"); 
  ##return "unknown argument $a[0] chose one of ".join(' ', @gets) if($a[1] eq "?");
  return "disabled" if(AttrVal($hash->{NAME}, "disable", "0") == "1");
  shift @a;
  my $command = shift @a;
  Log3($name, $defaultVerbose, "LEDStripe2 $name command: $command");
  if($command =~ /^(\b([Oo]n)\b|\b([Oo]ff)\b)/)
  {
	Log3($name, $defaultVerbose, "LEDStripe2 $name ommand is on/off: $command");  
	push(@a, $command);
	$command = "power";
  }
  else
  {
	Log3($name, $defaultVerbose, "LEDStripe2 $name command is something else: $command");  
  }
  
  if(AttrVal($name, "backwardCompatibility", 0) == 1) { ### backward compatibility (not shown on setlist)
	  if($command eq "fire")
	  {
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name effect Fire_2012_-_Specific_Colors");
		return undef;
	  }
	  if($command eq "rainbow")
	  {
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name effect Rainbow_Cycle");
		return undef;
	  }
	  if($command eq "knightrider")
	  {
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name effect Scan");
		return undef;
	  }
	  if($command eq "sparks")
	  {
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name effect Twinkle_Fox");
		return undef;
	  }
	  if($command eq "white_sparks")
	  {
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name effect Twinkle_Fox");
		InternalTimer(gettimeofday()+2*$callDelay, "LEDStripe2_delayedCall", "$name solidColor ffffff");
		return undef;
	  }
	  if($command eq "sunrise")
	  {
		return "Set sunrise needs one parameter: <duration in minutes>" if ( @a != 1);
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name sunriseset $a[0]");
		InternalTimer(gettimeofday()+2*$callDelay, "LEDStripe2_delayedCall", "$name effect Sunrise");
		return undef;
	  }
	  if($command eq "sunset")
	  {
		return "Set sunset needs one parameter: <duration in minutes>" if ( @a != 1);
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name sunriseset $a[0]");
		InternalTimer(gettimeofday()+2*$callDelay, "LEDStripe2_delayedCall", "$name effect Sunset");
		return undef;
	  }
	  ## pixel will (may?) not work right now...
	  if($command eq "pixel")
	  {
		return "Set pixel needs four or one parameters: <desired_led> <red> <green> <blue>" if ( @a != 4 && @a != 2);
		my $desired_led=$a[0];
		$desired_led=($desired_led=~ m/$reDOUBLE/) ? $1:undef;
		return "desired_led value ".$a[0]." is not a valid number" if (!defined($desired_led));
		if(@a == 4)
		{
			my $red=$a[1];
			$red=($red=~ m/$reDOUBLE/) ? $1:undef;
			return "red value ".$a[1]." is not a valid number" if (!defined($red));

			my $green=$a[2];
			$green=($green=~ m/$reDOUBLE/) ? $1:undef;
			return "green value ".$a[2]." is not a valid number" if (!defined($green));

			my $blue=$a[3];
			$blue=($blue=~ m/$reDOUBLE/) ? $1:undef;
			return "blue value ".$a[3]." is not a valid number" if (!defined($blue));
			$URL .= "/set?pi=" . $desired_led . "&solidColor=".sprintf("%02x%02x%02x",$red,$green,$blue); #re=" . $red . "&gr=" . $green . "&bl=" . $blue;
		}
		else
		{
			$URL .= "/set?pi=" . $desired_led . "&solidColor=" . $a[1];
		}

		Log3($name, $defaultVerbose, "LEDStripe2 $name set command: " . $command ." desired:". $desired_led);
		
		$hash->{mode} = $command;
		LEDStripe2_request_nonBlocking($hash,$URL, "LEDStripe2_ParseHttpResponse");
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name power on");
		return undef;
	  }
	  if($command eq "range")
	  {
		return "Set range needs five or three parameters: <first_led> <last_led> <red> <green> <blue> or <RGB>" if ( @a != 5 && @a !=3 );
		my $first_led=$a[0];
		$first_led=($first_led=~ m/$reDOUBLE/) ? $1:undef;
		return "first_led value ".$a[0]." is not a valid number" if (!defined($first_led));

		my $last_led=$a[1];
		$last_led=($last_led=~ m/$reDOUBLE/) ? $1:undef;
		return "last_led value ".$a[1]." is not a valid number" if (!defined($last_led));

		if(@a == 5)
		{
			my $red=$a[2];
			$red=($red=~ m/$reDOUBLE/) ? $1:undef;
			return "red value ".$a[2]." is not a valid number" if (!defined($red));

			my $green=$a[3];
			$green=($green=~ m/$reDOUBLE/) ? $1:undef;
			return "green value ".$a[3]." is not a valid number" if (!defined($green));

			my $blue=$a[4];
			$blue=($blue=~ m/$reDOUBLE/) ? $1:undef;
			return "blue value ".$a[4]." is not a valid number" if (!defined($blue));
		
			$URL .= "/set?rnS=" . $first_led . "&rnE=" . $last_led . "&solidColor=".sprintf("%02x%02x%02x",$red,$green,$blue); ##"&re=" . $red . "&gr=" . $green . "&bl=" . $blue;
		}
		else
		{
			$URL .= "/set?rnS=" . $first_led . "&rnE=" . $last_led . "&solidColor=" . $a[2];
		}

		Log3($name, $defaultVerbose, "LEDStripe2 $name set command: " . $command ." desired:". $first_led . " to " . $last_led);
		
		#$hash->{mode} = $command;
		LEDStripe2_request_nonBlocking($hash,$URL, "LEDStripe2_ParseHttpResponse");
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name power on");
		return undef;
	  }
	  if($command eq "solid_rgb")
	  {
		my $rgbval;
		#$rgbval = $hash->{READINGS}{rgb}{VAL} if defined($hash->{READINGS}{rgb}{VAL});
		$rgbval = $a[0] if ( @a == 1 && length($a[0]) == 6);
		return "Set rgb needs a color parameter: <red><green><blue> e.g. ffaa00" if !defined($rgbval);

		$URL .= "/set?rgb=1&solidColor=$rgbval";
		#$hash->{mode} = $command;
		LEDStripe2_request_nonBlocking($hash,$URL, "LEDStripe2_ParseHttpResponse");
		InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name power on");
		return undef;
	  }
    }### end backward compatibility
  
  
  my $reftype = ref ($hash->{cmds}->{$command});
  if ($reftype && $reftype eq 'HASH') {
	  Log3($name, $defaultVerbose, "LEDStripe2 $name: We found ".$hash->{cmds}->{$command}->{name}." of type ".$hash->{cmds}->{$command}->{type});
	  Log3($name, $defaultVerbose, "LEDStripe2 $name: The value to be set for ".$hash->{cmds}->{$command}->{name}." is ".$a[0]);
	  
	  if($hash->{cmds}->{$command}->{type} eq "bool")
	  {
		if($a[0] eq "on")
		{
			$URL .= "/set?".$command."=1";
		}
		elsif($a[0] eq "off")
		{
			$URL .= "/set?".$command."=0";
		}
		else
		{
			return "Wrong Parameter $a[0]. $command needs one parameter: <on> or <off>";
		}
	  }
	  elsif($hash->{cmds}->{$command}->{type} eq "list")
	  {
		if(exists($hash->{cmds}->{$command}->{options}->{$a[0]}))
		{
			$URL .= "/set?".$command."=".$hash->{cmds}->{$command}->{options}->{$a[0]};
			InternalTimer(gettimeofday()+$callDelay, "LEDStripe2_delayedCall", "$name power on") if($command eq "effect");
		}	
		else
		{
			return "Wrong Parameter \"$a[0]\" for \"$command\" Please use one of :\n\t".join("\n\t", sort { $hash->{cmds}->{$command}->{options}{$a} <=> $hash->{cmds}->{$command}->{options}{$b} } keys(%{$hash->{cmds}->{$command}->{options}}));
			Log3($name, $defaultVerbose, "LEDStripe2 $name No Entry for $a[0]");
		}
	  }
	  elsif($hash->{cmds}->{$command}->{type} eq "num")
	  {
		if(($a[0] =~ /^[+-]?\d+$/) and ($a[0] <= $hash->{cmds}->{$command}->{max}) and ($a[0] >= $hash->{cmds}->{$command}->{min}))
		{
			
			Log3($name, $defaultVerbose, , "LEDStripe2 $name: valid number found in $a[0] for $command");
			$URL .= "/set?".$command."=".$a[0];
		}
		else
		{
			return "Wrong Parameter $a[0] for $command Please use a numerical (integer) value between ".$hash->{cmds}->{$command}->{min}." and ".$hash->{cmds}->{$command}->{max};
		}
	  }
	  elsif($hash->{cmds}->{$command}->{type} eq "rgbColor")
	  {
		my $rgbval;
		$rgbval = $a[0] if ( @a == 1 && length($a[0]) == 6);
		return "Wrong Parameter \"$a[0]\" for \"$command\" Please use a hexadecimal color value: <red><green><blue> e.g. ffaa00" if !defined($rgbval);
		$URL .= "/set?".$command."=".$rgbval;
	  }
	  Log3($name, $defaultVerbose, , "LEDStripe2 $name: will now call $URL");
	  LEDStripe2_request_nonBlocking($hash,$URL, "LEDStripe2_ParseHttpResponse");
  }
  else
  {
	  Log3($name, $defaultVerbose, , "LEDStripe2 $name: The command $command with value $a[0] is not in the list of commands");
	  return "Unknown argument $command with parameter $a[0]: choose one of ".join(' ', @gets)
  }
  return undef;
}

#####################################
sub LEDStripe2_Define($$)
{
  my ($hash, $def) = @_;
  my($a, $h) = parseParams($def);
  my $name = $hash->{NAME};
  return "wrong syntax. need at least ip: define <name> LEDStripe2 ip=<ip-address> optional: port=<port> interval=<interval>" if(!defined($h->{ip}));
  if(!goodDeviceName($hash->{NAME}))
  {
	return "This is not a good device name. You can however try this one: ".makeDeviceName($hash->{NAME});
  }
  $hash->{remote_ip} = $h->{ip};
  $hash->{remote_port} = $h->{port} if(defined($h->{port}));
  $hash->{interval} = $h->{interval} if(defined($h->{interval}));
  $hash->{interval} = 120 if(!defined($hash->{interval}) || $hash->{interval} < 5);
  
  
  $attr{$name}{"devStateIcon"} = "{\"on:light_led_stripe_rgb\\\@#\".(ReadingsVal(\$name,\"rgb\",\"000000\")).\" off:light_led_stripe_rgb\\\@black\"}";
  $attr{$name}{"webCmd"} = "power:autoPalette:autoPlay:speed:colorPalette:effect:autoPalInterval:autoPlayInterval:brightness:solidColor";
  $attr{$name}{"webCmdLabel"} = "Power:Autopalette:Automode:Speed:Colorpalette\n:Effect:Autopal Interval:Automode Interval:Brightness:Solid Color";
	
  my $URL = "http://" . $hash->{remote_ip} . (defined $hash->{remote_port}?":".$hash->{remote_port}:"") . "/status";

  Log3($name, $defaultVerbose, "LEDStripe2 $name defined LEDStripe2 at $hash->{remote_ip}:$hash->{remote_port} with interval $hash->{interval}") if(defined($h->{port}));
  Log3($name, $defaultVerbose, "LEDStripe2 $name defined LEDStripe2 at $hash->{remote_ip} with interval $hash->{interval}") if(!defined($h->{port}));
  
  LEDStripe2_UpdateCommands($hash);
  
  return undef;
}
#####################################
sub LEDStripe2_Notify($$)
{
	my ($own_hash, $dev_hash) = @_;
	my $ownName = $own_hash->{NAME}; # own name / hash
 
	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
 
	my $devName = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	
	if($devName eq $ownName)
	{
		Log3($ownName, $defaultVerbose, "LEDStripe2 $ownName notified itself with @{$events}");
		my $bwComp = AttrVal($ownName, "backwardCompatibility", 0);
		if($own_hash->{backwardCompatibility} != $bwComp)
		{
			Log3($ownName, $defaultVerbose, "LEDStripe2 $ownName Attr BackwardCompatibility changed from $own_hash->{backwardCompatibility} to $bwComp");
			$own_hash->{backwardCompatibility} = $bwComp;
			LEDStripe2_UpdateCommands($own_hash);
		}
		if($own_hash->{firstInit})
		{
			Log3($ownName, $defaultVerbose, "LEDStripe2 $ownName Module firstInit triggerd!");
			$own_hash->{firstInit} = 0;
			LEDStripe2_UpdateCommands($own_hash);
		}
	}
	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		Log3($ownName, $defaultVerbose, "LEDStripe2 $ownName notified by global with @{$events}");
		my $bwComp = AttrVal($ownName, "backwardCompatibility", 0);
		if($own_hash->{backwardCompatibility} != $bwComp)
		{
			Log3($ownName, $defaultVerbose, "LEDStripe2 $ownName Attr BackwardCompatibility changed from $own_hash->{backwardCompatibility} to $bwComp");
			$own_hash->{backwardCompatibility} = $bwComp;
			LEDStripe2_UpdateCommands($own_hash);
		}
		if($own_hash->{firstInit})
		{
			Log3($ownName, $defaultVerbose, "LEDStripe2 $ownName Module firstInit triggerd!");
			$own_hash->{firstInit} = 0;
			LEDStripe2_UpdateCommands($own_hash);
		}
	}
}

#####################################
sub LEDStripe2_Undef($$)
{
   my ( $hash, $arg ) = @_;
   my $name = $hash->{NAME};
   RemoveInternalTimer($hash); 
   Log3($name, $defaultVerbose, "LEDStripe2 ".$hash->{name}. " removed ---");
   return undef;
}


#####################################
sub LEDStripe2_UpdateCommands($@)
{
	my ($hash, @args) = @_;
	my $name   = $hash->{NAME};
	return "" if(IsDisabled($name));
	if(!$init_done)
	{
		Log3($name, $defaultVerbose, "LEDStripe2 $name: Not yet initialized. Waiting another 5 seconds...");
		InternalTimer(gettimeofday()+2, "LEDStripe2_UpdateCommands", $hash);
		return undef;
	}
	my $URL = "http://" . $hash->{remote_ip} . (defined $hash->{remote_port}?":".$hash->{remote_port}:"") . "/all";
	Log3($name, $defaultVerbose, "LEDStripe2 $name going to update the command list now by calling $URL");
	LEDStripe2_request_nonBlocking($hash,$URL, "LEDStripe2_ParseUpdateResponse");
	return undef;
}

#####################################
sub LEDStripe2_ParseUpdateResponse
{
	my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
	return undef unless($init_done); #should not happen but who knows...
	return "" if(IsDisabled($name));
    if($err ne "") # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
		Log3($name, $defaultVerbose, "LEDStripe2 $name error while requesting $param->{url}. - $err");
		return undef;
    }
    elsif($data ne "")                                                                                                     
    {
		Log3($name, $defaultVerbose, "LEDStripe2 $name LEDStripe2_ParseUpdateResponse  $param->{url} returned quite some data as follows:");
		eval {decode_json($data) };
		if($@) { 
			Log3($name, $defaultVerbose, "LEDStripe2 $name will quit becasue of: $@"); 
			return undef;
		}
		my $json = undef;
		$json = decode_json($data);
		Log3($name, $defaultVerbose, "LEDStripe2 $name  -> goint to extract Keys in JSON $data");
		for my $item( @{$json} )
		{
			if($item->{type} == 0)
			{
				my $iInc = 1;
				if( $item->{max} > 255) 
				{
					$iInc = int( $item->{max}/100);
				}
				$hash->{cmds}->{$item->{name}}->{"name"} = $item->{name};
				$hash->{cmds}->{$item->{name}}->{"type"} = "num";
				$hash->{cmds}->{$item->{name}}->{"min"}  = $item->{min};
				$hash->{cmds}->{$item->{name}}->{"inc"}  = $iInc;
				$hash->{cmds}->{$item->{name}}->{"max"}  = $item->{max};
				Log3($name, $defaultVerbose, "LEDStripe2 $name  ->\t ".sprintf ("%-20s :\t %-27s :\t %s", $item->{name}, "Type", "num"));
			}
			elsif($item->{type} == 1)
			{
				$hash->{cmds}->{$item->{name}}->{"name"} = $item->{name};
				$hash->{cmds}->{$item->{name}}->{"type"} = "bool";
				$hash->{cmds}->{$item->{name}}->{"on"}   = 0;
				$hash->{cmds}->{$item->{name}}->{"off"}  = 1;
				Log3($name, $defaultVerbose, "LEDStripe2 $name  ->\t ".sprintf ("%-20s :\t %-27s :\t %s", $item->{name}, "Type", "bool"));
			}
			elsif($item->{type} == 2)
			{	
				my $id = 0;
				$hash->{cmds}->{$item->{name}}->{"type"} = "list";
				$hash->{cmds}->{$item->{name}}->{"name"} = $item->{name};
				foreach my $arrVal (@{$item->{options}})
				{
					$hash->{cmds}->{$item->{name}}->{"options"}->{makeReadingName($arrVal)} = $id;
					$id++;
				}
				while ( (my $mOption, my $mValue) = each %{$hash->{cmds}->{$item->{name}}->{options}} ) 
				{ 
					Log3($name, $defaultVerbose, "LEDStripe2 $name  ->\t ".sprintf ("%-20s :\t %-27s :\t %s", $item->{name}, $mOption, $mValue));
				} 
			}
			elsif($item->{type} == 3)
			{
				$hash->{cmds}->{$item->{name}}->{"name"} = $item->{name};
				$hash->{cmds}->{$item->{name}}->{"type"} = "rgbColor";
				Log3($name, $defaultVerbose, "LEDStripe2 $name  ->\t ".sprintf ("%-20s :\t %-27s :\t %s", $item->{name}, "Type", "rgbColor"));
			}
			elsif($item->{type} == 4)
			{
				Log3($name, $defaultVerbose, "LEDStripe2 $name  ->\t ".sprintf ("%-20s :\t %-27s :\t %s", $item->{name}, "Type", "OverallLabel"));
			}
			elsif($item->{type} == 5)
			{
				Log3($name, $defaultVerbose, "LEDStripe2 $name  ->\t ".sprintf ("%-20s :\t %-27s :\t %s", $item->{name}, "Type", "Sectionlabel"));
			}
		}
	}
	else
	{
		Log3($name, $defaultVerbose, "LEDStripe2 $name error while requesting $param->{url} - no data received in answer!");
		return undef;
	}
	## We have updated the hash with the fileds. So we update the commandlist
	LEDStripe2_SetParameters($hash);
	# if we get this far, the command was successfull and we can start polling
	LEDStripe2_Get($hash);
}

#####################################
sub LEDStripe2_Get($@)
{
	my ($hash, @args) = @_;
	my $name   = $hash->{NAME};
	return undef unless($init_done);
	return "" if(IsDisabled($name));
	
	my $bwComp = AttrVal($name, "backwardCompatibility", 0);
	if($hash->{backwardCompatibility} != $bwComp)
	{
		Log3($name, $defaultVerbose, "LEDStripe2 $name Attr BackwardCompatibility changed from $hash->{backwardCompatibility} to $bwComp");
		$hash->{backwardCompatibility} = $bwComp;
		LEDStripe2_UpdateCommands($hash);
	}
	if($hash->{firstInit})
	{
		Log3($name, $defaultVerbose, "LEDStripe2 $name Module firstInit triggerd!");
		$hash->{firstInit} = 0;
		LEDStripe2_UpdateCommands($hash);
	}
	my $URL = "http://" . $hash->{remote_ip} . (defined $hash->{remote_port}?":".$hash->{remote_port}:"") . "/status";
	RemoveInternalTimer($hash);    # is this required?
	InternalTimer(gettimeofday()+$hash->{interval}, "LEDStripe2_Get", $hash);
	$hash->{NEXTUPDATE}=localtime(gettimeofday()+$hash->{interval});
	Log3($name, $defaultVerbose, "LEDStripe2 $name Get: Timer Restarted, Calling Noblocking Request with LEDStripe2_ParseHttpResponse");
	## maybe we start the next time from the callback to ensure we actually received data?
	LEDStripe2_request_nonBlocking($hash,$URL, "LEDStripe2_ParseHttpResponse");
	
	return undef;
}


######################################
sub LEDStripe2_power
{
  my ($hash, $command) = @_;
  my $name   = $hash->{NAME};
  my $switch = AttrVal($name, "power_switch", undef);
  Log3($name, $defaultVerbose, "LEDStripe2 $name Power Switch called with $command");
  if (defined $switch) {
	my $currentpower = Value($switch);
	if($command ne $currentpower) {
	  fhem "set $switch $command";
	  if ($command eq "on") {
		select(undef, undef, undef, 1.5);
	  }
	}
  }
}


#####################################
sub LEDStripe2_ParseHttpResponse
{
	my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
	return undef unless($init_done);
	return "" if(IsDisabled($name));
	Log3($name, $defaultVerbose, "LEDStripe2 $name   url  $param->{url} returned: $data");
    if($err ne "") # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
		Log3($name, $defaultVerbose, "LEDStripe2 $name error while requesting $param->{url}. - $err");
        readingsSingleUpdate($hash, "_ERROR_STATE", "ERROR: $err", 1);
		return;
    }
    elsif($data ne "")                                                                                                     
    {
		Log3($name, $defaultVerbose, "LEDStripe2 $name going to extract json data...");
		eval {decode_json($data) };
		if($@) { 
			Log3($name, $defaultVerbose, "LEDStripe2 $name will quit becasue of: $@"); 
			return;
		}
		my $json = undef;
		$json = decode_json($data);
		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "_ERROR_STATE", "No Error"); 
		## ToDo: Simplyfy: loop through all and only make difference to RGB
		foreach my $skey (sort keys %{$json})
		{
			foreach my $key (sort keys %{$json->{$skey}}) 
			{
				if(($key eq "rgb") or (exists($hash->{cmds}->{$key}->{type}) and ($hash->{cmds}->{$key}->{type} eq "rgbColor")))
				#if($key eq "rgb")
				{
					Log3($name, $defaultVerbose, "LEDStripe2 $name updating ".sprintf ("%-25s :\t %06x", "rgb", $json->{$skey}->{$key}));
					##rgb with:\t ".sprintf("%06x", $json->{$skey}->{$key}));
					readingsBulkUpdateIfChanged($hash, $key, sprintf("%06x", $json->{$skey}->{$key}));
				}
				elsif(exists($hash->{cmds}->{$key}->{type}))
				{
					Log3($name, $defaultVerbose, "LEDStripe2 $name updating ".sprintf ("%-25s :\t %s", $key, makeReadingName($json->{$skey}->{$key})));
					readingsBulkUpdateIfChanged($hash, $key, makeReadingName($json->{$skey}->{$key}));
				}
				else
				{
					Log3($name, $defaultVerbose, "LEDStripe2 $name updating ".sprintf ("%-25s :\t %s", $key, $json->{$skey}->{$key}));
					readingsBulkUpdateIfChanged($hash, $key, $json->{$skey}->{$key});
				}
			}
		}
		readingsEndUpdate($hash, 1);	
		## we got this far, everything was OK. Why not updating the STATE?
		$hash->{STATE} = $hash->{READINGS}{power}{VAL};
		readingsSingleUpdate($hash, "state", $hash->{READINGS}{power}{VAL}, 1);
		LEDStripe2_power($hash,$hash->{STATE});
	}
	else
	{
		Log3($name, $defaultVerbose, "LEDStripe2 $name error while requesting $param->{url} - no data received in answer!");
        readingsSingleUpdate($hash, "_ERROR_STATE", "Did not receive any data!", 1);     
	}
}

#####################################
sub LEDStripe2_request_nonBlocking
{
	my ($hash, $URL, $callBack) = @_;
	my $name = $hash->{NAME};
	return "disabled" if(AttrVal($name, "disable", "0") == "1");
    my $param = {
                    url                => $URL,
                    timeout            => 15,
					incrementalTimout  => 1,
					keepalive          => 1,
                    hash               => $hash,                             # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    method             => "GET",                             # Lesen von Inhalten
                    header             => HTTP::Request->new( GET => $URL ), # Den Header gemäss abzufragender Daten ändern
                    callback           =>  \&$callBack				#LEDStripe2_ParseHttpResponse    # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                };
	Log3($name, $defaultVerbose, "LEDStripe2 $name request: $param->{url} $callBack");
    HttpUtils_NonblockingGet($param);   
}

1;

=pod
=begin html

<html>
<a name="LEDStripe2"></a>
<h3>LEDStripe2</h3>
<ul>
  <a name="LEDStripe2_define"></a>
  <h4>Define</h4>
  <ul>
    <code>define &lt;name&gt; LEDStripe2 &lt;ip_address&gt;</code>
    <br/>
    <br/>
    Defines a module for controlling WS2812b LED stripes connected to an Arduino with Ethernet shield or an ESP8266 <br/><br/>
    Example:
    <ul>
      <code>define LED_Wohnzimmer LEDStripe2 192.168.1.21</code><br>
      <code>attr LED_Wohnzimmer playfile /opt/fhem/ledwall.txt</code><br>
      <code>attr LED_Wohnzimmer webCmd rgb:off:rgb 5a2000:rgb 654D8A</code><br>
      <code>attr LED_Wohnzimmer power_switch RL23_LED_WZ</code><br>
    </ul>

  </ul>

  <a name="LEDStripe2_Attr"></a>
  <h4>Attributes</h4>
  <ul>
    <li><a name="playfile"><code>attr &lt;name&gt; playfile &lt;string&gt;</code></a>
                <br />Points to a file with LED color information containing several lines in the pixels format described below</li>
    <li><a name="playtimer"><code>attr &lt;name&gt; playtimer &lt;integer&gt;</code></a>
                <br />Delay in seconds when playing a LED color file</li>
    <li><a name="webCmd"><code>attr &lt;name&gt; webCmd rgb:off:rgb 5a2000:rgb 654D8A</code></a>
                <br />Show a color picker and color buttons (the colors are just examples, any combinations are possible)./li>
    <li><a name="power_switch"><code>attr &lt;name&gt; power_switch &lt;integer&gt;</code></a>
                <br />Control LED power on/off using s switch channel</li>
  </ul>

  <a name="LEDStripe2_set"></a>
  <b>Set</b>
  <ul>
    <li><a name="on"><code>set &lt;name&gt; on</code></a>
                <br />Resume last LED setting or effect/li>
    <li><a name="off"><code>set &lt;name&gt; off</code></a>
                <br />Switch all LEDs off and stop any effects</li>
    <li><a name="play"><code>set &lt;name&gt; play</code></a>
                <br />Start 'playing' the file with LED color information</li>
    <li><a name="pixel"><code>set &lt;name&gt; pixel &lt;led id&gt; &lt;red&gt; &lt;green&gt; &lt;blue&gt;</code></a>
                <br />Set the color of a single LED, index starts at 0, color values are from 0-255</li>
    <li><a name="range"><code>set &lt;name&gt; range &lt;start id&gt; &lt;end id&gt; &lt;red&gt; &lt;green&gt; &lt;blue&gt;</code></a>
                <br />Set the color of a range of LEDs, start and end are inclusive beginning with 0</li>
    <li><a name="pixels"><code>set &lt;name&gt; pixels &lt;color data&gt;</code></a>
                <br />Define the color of all LEDs, the color data consists of three hex digits per LED containing the three colors,
                e.g. 000 would be off, F00 would be all red, 080 would be 50% green, 001 a faint blue</li>
    <li><a name="fire"><code>set &lt;name&gt; fire</code></a>
                <br />Start a 'fire' light effect on all LEDs</li>
    <li><a name="rainbow"><code>set &lt;name&gt; rainbow &lt;string&gt;</code></a>
                <br />Start a 'rainbow color chase' light effect on all LEDs</li>
    <li><a name="sparks"><code>set &lt;name&gt; sparks &lt;string&gt;</code></a>
                <br />Start sparkling dots (random color) light effect on all LEDs</li>
    <li><a name="white_sparks"><code>set &lt;name&gt; white_sparks &lt;string&gt;</code></a>
                <br />Start sparkling dots (white) light effect on all LEDs</li>
    <li><a name="knightrider"><code>set &lt;name&gt; knightrider &lt;string&gt;</code></a>
                <br />Start knightrider light effect on all LEDs</li>
  </ul>

</ul>

=end html
=cut
