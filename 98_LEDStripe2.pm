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

## to be adopted
my @gets = split(" ", "on off pixel range fire:noArg rainbow:noArg knightrider:noArg sparks:noArg white_sparks:noArg speed:slider,0,100,10000 brightness:slider,0,1,255 rgb:colorpicker volume:slider,0,1,100 wsfxmode_Num:slider,0,1,45 palette_num:slider,0,1,21 next prev sunrise:slider,1,1,60 sunset:slider,1,1,60 AutoPlayMode:Off,Up,Down,Random AutoPalMode:Off,Up,Down,Random");

##############################################
sub LEDStripe2_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "LEDStripe2_Set";
  $hash->{DefFn}     = "LEDStripe2_Define";
  $hash->{GetFn}     = "LEDStripe2_Get";
  $hash->{AttrList}  = "interval power_switch disable:0,1 timeout";
}

###################################
sub LEDStripe2_Set($@)
{
  my ($hash, @a) = @_;
  my $rc = undef;
  my $reDOUBLE = '^(\\d+\\.?\\d{0,2})$';
  my $remote_ip = $hash->{remote_ip};
  my $remote_port = $hash->{remote_port};
  my $URL = "http://" . $remote_ip . (defined $remote_port?":".$remote_port:"");

  ## rework: get modes dynamically during define if possible?
   
  return "Unknown argument $a[0] choose one of ".join(' ', @gets) unless(defined($a[1]) && $a[1] ne "?"); 
  ##return "unknown argument $a[0] chose one of ".join(' ', @gets) if($a[1] eq "?");
  return "disabled" if(AttrVal($hash->{NAME}, "disable", "0") == "1");
  shift @a;
  my $command = shift @a;

  Log 4, "LEDStripe2 command: $command";

  if($command eq "on")
  {
	if (defined($hash->{mode}))
	{
		$command = $hash->{mode};
		if($command eq "wsfxmode_Num") 
		{
		  $a[0] = $hash->{READINGS}{wsfxmode_Num}{VAL};
		}
		else
		{	
			$command = "wsfxmode_Num";
			$a[0] = 20;  ## equals pride currently
		}
	}
	else
	{
		$command = "wsfxmode_Num";
		$a[0] = 20;  ## equals pride currently
	}
  }
  elsif($command eq "off")
  {
    $URL .= "/set?mo=o";
    LEDStripe2_request_nonBlocking($hash,$URL);
    LEDStripe2_power($hash,$command);
  }

  
  if($command eq "fire")
  {
    LEDStripe2_power($hash,"on");
    $URL .= "/set?mo=f";
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "rainbow")
  {
    LEDStripe2_power($hash,"on");
    $URL .= "/set?mo=r";
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "knightrider")
  {

    LEDStripe2_power($hash,"on");
    $URL .= "/set?mo=k";
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "sparks")
  {

    LEDStripe2_power($hash,"on");
    $URL .= "/set?mo=s";
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "white_sparks")
  {

    LEDStripe2_power($hash,"on");
    $URL .= "/set?mo=w";
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "sunrise")
  {
    return "Set sunrise needs one parameter: <duration in minutes>" if ( @a != 1);
    $URL .= "/set?mo=Sunrise&min=".$a[0];
    ##$hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "sunset")
  {
    return "Set sunset needs one parameter: <duration in minutes>" if ( @a != 1);
    $URL .= "/set?mo=Sunset&min=".$a[0];
    ##$hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "pixel")
  {
    return "Set pixel needs four or two parameters: <desired_led> <red> <green> <blue>" if ( @a != 4 && @a != 2);
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
		$URL .= "/set?pi=" . $desired_led . "&re=" . $red . "&gr=" . $green . "&bl=" . $blue;
	}
	else
	{
		$URL .= "/set?pi=" . $desired_led . "&co=" . $a[1];;
	}

    LEDStripe2_power($hash,"on");

    Log 4, "set command: " . $command ." desired:". $desired_led;
    
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
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
	
		$URL .= "/set?rnS=" . $first_led . "&rnE=" . $last_led . "&re=" . $red . "&gr=" . $green . "&bl=" . $blue;
	}
	else
	{
		$URL .= "/set?rnS=" . $first_led . "&rnE=" . $last_led . "&co=" . $a[2];
	}
    LEDStripe2_power($hash,"on");

    Log 4, "set command: " . $command ." desired:". $first_led . " to " . $last_led;
    
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "rgb")
  {
    my $rgbval;
    $rgbval = $hash->{READINGS}{rgb}{VAL} if defined($hash->{READINGS}{rgb}{VAL});
    $rgbval = $a[0] if ( @a == 1 && length($a[0]) == 6);
    return "Set rgb needs a color parameter: <red><green><blue> e.g. ffaa00" if !defined($rgbval);

    LEDStripe2_power($hash,"on");
    $URL .= "/set?rgb=1&co=$rgbval";
    $hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "speed")
  {
    my $delayval;
    $delayval = $hash->{READINGS}{speed}{VAL} if defined($hash->{READINGS}{delay}{VAL});
    $delayval = $a[0] if ( @a == 1 );
    return "Set speed needs a beat88 parameter: beat88 = beat88/256 = beats per minute e.g. 1024" if !defined($delayval);
    $URL .= "/set?sp=$delayval";
    ##$hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "brightness")
  {
    my $brightnessval;
    $brightnessval = $hash->{READINGS}{brightness}{VAL} if defined($hash->{READINGS}{brightness}{VAL});
    $brightnessval = $a[0] if ( @a == 1 );
    return "Set brightness needs a value (0-255) parameter: <Brightness> e.g. 128" if !defined($brightnessval);
    $URL .= "/set?br=$brightnessval";
    ##$hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "volume")
  {
	my $brightnessval;
    $brightnessval = $hash->{READINGS}{brightness}{VAL} if defined($hash->{READINGS}{brightness}{VAL});
    $brightnessval = int($a[0]*2.55) if ( @a == 1 );
    return "Set brightness needs a value (0-255) parameter: <Brightness> e.g. 128" if !defined($brightnessval);
    $URL .= "/set?br=$brightnessval";
    ##$hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "palette_num")
  {
    my $paletteval;
    $paletteval = $hash->{READINGS}{palette}{VAL} if defined($hash->{READINGS}{palette}{VAL});
    $paletteval = $a[0] if ( @a == 1 );
    return "Set palette needs a value (0-pal_count) parameter: <palette> e.g. 7" if !defined($paletteval);
    $URL .= "/set?pa=$paletteval";
    ##$hash->{mode} = $command;
    LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "ws2812np")
  {
    return "ws2812np needs at least one or 4 parameters. <fx [next or prev]> OR <fx [next or prev]> and <red> <green> <blue>" if ( @a != 1 && @a != 4 );
    my $ws_mode = $a[0];
	if($ws_mode =~ m/prev/)
	{
		$ws_mode = "d";
	}
	elsif($ws_mode =~ m/next/)
	{
		$ws_mode = "u";
	}
	if(@a == 4)
	{
		my $red=$a[1];
		$red=($red=~ m/$reDOUBLE/) ? $1:undef;
		return "red value ".$a[2]." is not a valid number" if (!defined($red));

		my $green=$a[2];
		$green=($green=~ m/$reDOUBLE/) ? $1:undef;
		return "green value ".$a[3]." is not a valid number" if (!defined($green));

		my $blue=$a[3];
		$blue=($blue=~ m/$reDOUBLE/) ? $1:undef;
		return "blue value ".$a[4]." is not a valid number" if (!defined($blue));
		
		LEDStripe2_power($hash,"on");

		Log 4, "set command: " . $command ." desired:". $ws_mode;
		$URL .= "/set?mo=$ws_mode&re=$red&gr=$green&bl=$blue";
		$hash->{mode} = "ws2812fx"; ##$command;
		LEDStripe2_request_nonBlocking($hash,$URL);
	}
	else
	{
		LEDStripe2_power($hash,"on");
		Log 4, "set command: " . $command ." desired:". $ws_mode;
		$URL .= "/set?mo=$ws_mode";
		$hash->{mode} = "ws2812fx"; ##$command;
		LEDStripe2_request_nonBlocking($hash,$URL);
	}
  }
  if($command eq "next")
  {
	my $ws_mode = "u";
	LEDStripe2_power($hash,"on");
	Log 4, "set command: " . $command ." desired:". $ws_mode;
	$URL .= "/set?mo=$ws_mode";
	$hash->{mode} = "ws2812fx"; ## $hash->{mode} = $command;
	LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if($command eq "prev")
  {
	my $ws_mode = "d";
	LEDStripe2_power($hash,"on");
	Log 4, "set command: " . $command ." desired:". $ws_mode;
	$URL .= "/set?mo=$ws_mode";
	$hash->{mode} = "ws2812fx"; ## $hash->{mode} = $command;
	LEDStripe2_request_nonBlocking($hash,$URL);
  }
  if(($command eq "wsfxmode_Num") or ($command eq "ws2812fx"))
  {
    return "wsfxmode_Num needs at least one or 4 parameters. <fx [number]> OR <fx [number]> and <red> <green> <blue>" if ( @a != 1 && @a != 4 );
    my $ws_mode = $a[0];
	$ws_mode=($ws_mode=~ m/$reDOUBLE/) ? $1:undef;
    return "Mode value ".$a[0]." is not a valid number" if (!defined($ws_mode));
	
	if(@a == 4)
	{
		my $red=$a[1];
		$red=($red=~ m/$reDOUBLE/) ? $1:undef;
		return "red value ".$a[2]." is not a valid number" if (!defined($red));

		my $green=$a[2];
		$green=($green=~ m/$reDOUBLE/) ? $1:undef;
		return "green value ".$a[3]." is not a valid number" if (!defined($green));

		my $blue=$a[3];
		$blue=($blue=~ m/$reDOUBLE/) ? $1:undef;
		return "blue value ".$a[4]." is not a valid number" if (!defined($blue));
		
		LEDStripe2_power($hash,"on");

		Log 4, "set command: " . $command ." desired:". $ws_mode;
		$URL .= "/set?mo=$ws_mode&re=$red&gr=$green&bl=$blue";
		$hash->{mode} = $command;
		LEDStripe2_request_nonBlocking($hash,$URL);
	}
	else
	{
		LEDStripe2_power($hash,"on");
		Log 4, "set command: " . $command ." desired:". $ws_mode;
		$URL .= "/set?mo=$ws_mode";
		$hash->{mode} = $command;
		LEDStripe2_request_nonBlocking($hash,$URL);
	}
  }
  return undef;
}

#####################################
sub LEDStripe2_Define($$)
{
  my ($hash, $def) = @_;
  my($a, $h) = parseParams($def);
  return "wrong syntax. need at least ip: define <name> LEDStripe2 ip=<ip-address> optional: port=<port> interval=<interval>" if(!defined($h->{ip}));
  $hash->{remote_ip} = $h->{ip};
  $hash->{remote_port} = $h->{port} if(defined($h->{port}));
  $hash->{interval} = $h->{interval} if(defined($h->{interval}));
  $hash->{interval} = 10 if(!defined($hash->{interval}) || $hash->{interval} < 3);
  my$name = $hash->{NAME};
  
  $attr{$name}{"icon"} = "light_led_stripe_rgb";
  $attr{$name}{"devStateIcon"} = "{\"on:light_led_stripe_rgb\\\@#\".(ReadingsVal(\$name,\"rgb\",\"000000\")).\" off:light_led_stripe_rgb\\\@black\"}";
	
  my $URL = "http://" . $hash->{remote_ip} . (defined $hash->{remote_port}?":".$hash->{remote_port}:"") . "/status";

  
  #LEDStripe2_request_nonBlocking($hash,$URL);

  Log 1, "$hash->{NAME} defined LEDStripe2 at $hash->{remote_ip}:$hash->{remote_port} ";

  
  
  InternalTimer(gettimeofday()+5, "LEDStripe2_Get", $hash);
  
  return undef;
}

#####################################
sub LEDStripe2_Undef($$)
{
   my ( $hash, $arg ) = @_;
   RemoveInternalTimer($hash); 
   Log 3, $hash->{name}. " removed ---";
   return undef;
}

#####################################
sub LEDStripe2_Get($@)
{
	my ($hash, @args) = @_;
	my $name   = $hash->{NAME};
	return undef unless($init_done);
	return "disabled" if(AttrVal($name, "disable", "0") == "1");
	my $URL = "http://" . $hash->{remote_ip} . (defined $hash->{remote_port}?":".$hash->{remote_port}:"") . "/status";
	RemoveInternalTimer($hash);    
	InternalTimer(gettimeofday()+$hash->{interval}, "LEDStripe2_Get", $hash);
	$hash->{NEXTUPDATE}=localtime(gettimeofday()+$hash->{interval});
	
	LEDStripe2_request_nonBlocking($hash,$URL);
	
	return undef;
}


######################################
sub LEDStripe2_power
{
  my ($hash, $command) = @_;
  my $name   = $hash->{NAME};
  my $switch = AttrVal($name, "power_switch", undef);
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
#	sub LEDStripe2_closeplayfile
#	{
#	  my ($hash) = @_;
#	  RemoveInternalTimer($hash);
#	  if (defined($hash->{filehash})) {
#		close ($hash->{filehash});
#		undef ($hash->{filehash});
#	  }
#	}
#####################################
sub LEDStripe2_ParseHttpResponse
{
	my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
	return undef unless($init_done);
	return "disabled" if(AttrVal($name, "disable", "0") == "1");
    if($err ne "") # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        Log3 $name, 3, "error while requesting ".$param->{url}." - $err";                                                  # Eintrag fürs Log
        readingsSingleUpdate($hash, "_ERROR_STATE", "ERROR: $err", 1);                                                              # Readings erzeugen
    }

    elsif($data ne "")                                                                                                     
    {
        Log3 $name, 3, "url ".$param->{url}." returned: $data";                                                            # Eintrag fürs Log
		eval {decode_json($data) };
		if($@) { 
			 Log3 $name, 3, "I will quit becasue of: $@";  
			return;
		}
		my $json = decode_json($data);
		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "_ERROR_STATE", "No Error"); 
		foreach my $key (sort keys %{$json->{'currentState'}}) {
			if($key eq "rgb")
			{
				readingsBulkUpdateIfChanged($hash, $key, sprintf("%x", $json->{'currentState'}->{$key}));
			}
			else
			{
				readingsBulkUpdateIfChanged($hash, $key, $json->{'currentState'}->{$key});
				if($key eq "brightness")
				{
					readingsBulkUpdateIfChanged($hash, "volume", int($json->{'currentState'}->{$key}/2.55));
				}
			}
		}
		my $regex = qr/Color/mp;
		foreach my $key (sort keys %{$json->{'sunRiseState'}}) {
			if($key =~ /$regex/g)
			{
				
				readingsBulkUpdateIfChanged($hash, $key, sprintf("%x", $json->{'sunRiseState'}->{$key}));
			}
			else
			{
				
				readingsBulkUpdateIfChanged($hash, $key, $json->{'sunRiseState'}->{$key});
			}
		}
		foreach my $key (sort keys %{$json->{'ESP_Data'}}) {
			readingsBulkUpdateIfChanged($hash, $key, $json->{'ESP_Data'}->{$key});
		}
		foreach my $key (sort keys %{$json->{'Server_Args'}}) {
			readingsBulkUpdateIfChanged($hash, $key, $json->{'Server_Args'}->{$key});
		}
		foreach my $key (sort keys %{$json->{'Stats'}}) {
			readingsBulkUpdateIfChanged($hash, $key, $json->{'Stats'}->{$key});
		}
		readingsEndUpdate($hash, 1);		
	}
	else
	{
		Log3 $name, 3, "error while requesting ".$param->{url}." - no data received in answer!";                                                  # Eintrag fürs Log
        readingsSingleUpdate($hash, "_ERROR_STATE", "Did not receive any data!", 1);     
	}
	
}

#####################################
sub LEDStripe2_request_nonBlocking
{
	my ($hash, $URL) = @_;
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
                    callback           =>  \&LEDStripe2_ParseHttpResponse    # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                };
	Log 3, "LEDStripe request: $param->{header}";
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
