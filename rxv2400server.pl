#! perl -w

# version 1.1 of linxServer.pl #####################################
####################################################################
############### hacked by jörg dießl, fall 99 (joreg@testphase.at) #
####################################################################
# based on the original version talkrcx.txt,v 1.3 ##################
# written by Paul Haas (http://www.hamjudo.com/rcx/talkrcx.txt) ####
####################################################################
# besides a perl version (>5) this script requires two modules #####
# installed on your system: ########################################
# Win32::API available under http://www.divinf.it/dada/perl/Win32API-0.011.zip
# Win32::SerialPort available under http://members.aol.com/Bbirthisel/Win32-SerialPort-0.18.tar.gz
####################################################################
####################################################################
# this server listens to port 9000 for the following commands:	   #
# "vor", "stop", "zruck" and "view" 							   #
# corresponding to the command a string is sent to the serial-port #
# (to which a cybermaster should be connected) that starts one	   #
# of the four tasks that may be stored in a cybermaster 		   #
####################################################################
# before the server starts listening...							   #
# ...the serial-port is opened									   #
# ...the firmware is unlocked									   #
# ...variables 0 and 1 are set to 1 (starting values for viewchange [required in loop.nqc])
# ...the power down delay is set to 0 (infinite)				   #
####################################################################
####################################################################
# linx for more info on rcx-programming: ###########################
# http://graphics.stanford.edu/~kekoa/rcx/ #########################
# http://home.concepts.nl/~bvandam/ ################################
# http://www.crynwr.com/lego-robotics/ #############################
####################################################################

use Win32::SerialPort 0.15;
use IO::Socket;
use Net::hostent;
use Sys::Hostname;

my $PortName = "COM1";
my $PortObj = new Win32::SerialPort ($PortName)
       || die "Can't open $PortName: $^E\n";

$PortObj->databits(8);
$PortObj->baudrate(2400);
$PortObj->parity("odd");
$PortObj->parity_enable(1);
$PortObj->stopbits(1);
$PortObj->buffers(4096, 4096);
$PortObj->dtr_active(1);
$PortObj->rts_active(1);            

if ($PortObj->write_settings != 1) 
{
	print "sorry, couldn't setup serial port";
}

print "unlocking firmware...\n";
# "Do you byte, when I knock?"
$unlockMSG = "FE	00	00	FF	A5	5A	44	BB	6F	90	20	DF	79	86	6F	90	75	8A	20	DF	62	9D	79	86	74	8B	65	9A	2C	D3	20	DF	77	88	68	97	65	9A	6E	91	20	DF	49	B6	20	DF	6B	94	6E	91	6F	 90	63	9C	6B	94	3F	C0	85	7A";
$unlockMSG = hex2str($unlockMSG);
$response = str2hex (getMsg($unlockMSG));

sleep(1);

print "setting variables 0 and 1 to 1...\n";
$varMSG = "FE	00	00	FF	1C E3 00 FF 02 FD 01 FE 00 FF 1F E0";
$varMSG = hex2str($varMSG);
$response = str2hex (getMsg($varMSG));

sleep(1);

$varMSG = "FE	00	00	FF	14 EB 01 FE 02 FD 01 FE 00 FF 18 E7";
$varMSG = hex2str($varMSG);
$response = str2hex (getMsg($varMSG));

sleep(1);

print "setting power down delay to 0 (infinite)...\n";
$powerMSG = "FE	00	00	FF	B9 46 00 FF B9 46";
$powerMSG = hex2str($powerMSG);
$response = str2hex (getMsg($powerMSG));


$PORT = 9000;
$message = "1234"; #anystring
$messageHeader = hex2str("FE 0 0 FF");

$server = IO::Socket::INET->new( Proto     => 'tcp',
                                 LocalPort => $PORT,
                                 Listen    => SOMAXCONN,
                                 Reuse     => 1);

die "sorry, couldn't setup server" unless $server;
print "[LINX-Server waiting for commands on port $PORT]\n";

while ($client = $server->accept()) 
{
	$client->autoflush(1);
    while (<$client>) 
    {
    	next unless /\S/;       # blank line
     	if    (/view/i)    
     	{ 
			$y = hex2str("71 03");
    		$message = toMsg($y,$message);
    		$response = str2hex (getMsg($message));
    		print "viewchange\n";
   		}
     	elsif (/vor/i)    
     	{ 
     		$y = hex2str("71 02");
			$message = toMsg($y,$message);
			$response = str2hex (getMsg($message));
			print "vor\n";
   		}
     	elsif (/stop/i)         
     	{ 
     		$y = hex2str("71 00");
			$message = toMsg($y,$message);
    		$response = str2hex (getMsg($message));
    		print "stop\n";
     	}
     	elsif (/zruck/i)      
     	{ 
     		$y = hex2str("71 01");
			$message = toMsg($y,$message);
    		$response = str2hex (getMsg($message));
    		print "zruck\n";
    		
     	}
     	print $client "\015\012";
     	last;
    }
    close $client;
} 

#close the port - when the server is shut down
undef $PortObj;


sub getMsg 
{
    local($outmsg) = @_;
	# Send the message to the RCX.
	sendMsg($outmsg);
}

sub sendMsg 
{
    local($msg) = @_;
    $PortObj->write($msg);
}

# Convert a string into hex for easier viewing by people.
sub str2hex 
{
    local ($line) = @_;
    $line =~ s/(.)/sprintf("%02x ",ord($1))/eg;
    return $line;
}

# $string = hex2str ( $hexstring );
# Where string is of the form "xx xx xx xx" where x is 0-9a-f
# hex numbers are limited to 8 bits.
sub hex2str 
{
    local ($l) = @_;
    $l =~ s/([0-9a-f]{1,2})\s*/sprintf("%c",hex($1))/egi;
    return $l;
}

sub toMsg 
{
    local ($str,$lastMsg) = @_;
    local ($msg) = "";
    local ($sum, $c, $invC,$seqno);
    $sum = 0;  # Checksum;
    $msg = $messageHeader;
    $seqno = 0x08 != (0x08 & ord(substr($lastMsg,4,1)));
    if ( $seqno ) {
        substr($str,0,1) = chr(ord($str) | 0x08);
    } else {
        substr($str,0,1) = chr(ord($str) & 0xf7);
    }
    foreach $c ( split(//,$str) ) {
        $invC = chr(0xff ^ ord($c));
        $msg .= $c . $invC;
        $sum += ord($c);
    }
    $sum &= 0xff;
    $msg .= chr($sum) . chr(0xff ^ $sum);
    return $msg
}