#! perl -w

#   RX-V2400 Server
#   Control software for certain Yamaha A/V receivers.
#   This is independently developed software with no relation to Yamaha.
#
#   Copyright 2006 Mark Jerde
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
#   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
#   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# version 0.1 of rxv2400server.pl ##################################
####################################################################
############## hacked by Mark Jerde, fall 05 (mjerde3@charter.net) #
####################################################################
# based on the original version linxServer.pl 1.1 ##################
# hacked by jörg dießl, fall 99 (joreg@testphase.at) ###############
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
# (to which a Yamaha RX-V 2400 should be connected) that performs  #
# the operations allowed by the Yamaha receiver         		   #
####################################################################
# before the server starts listening...							   #
# ...the serial-port is opened									   #
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

$app = $0;
print "app $app\n";

my %yamaha = ( "System" => "1", "Power" => "0" ); # Busy and Off

my $STX = hex2str("02");
my $ETX = hex2str("03");

my %Spec =
( "R0161" =>
  { "Configuration" =>
    { "System" => { "OK" => "0" , "Busy" => "1" },
      "Power" => { "OFF" => "0" , "ON" => "1" }
    },
    "Control" =>
    { "Prefix" => $STX,
      "Suffix" => $ETX,
      "Operation" =>
      { "Prefix" => "07",
        "Power" => { "Prefix" => "A1" , "ON" => "D" , "OFF" => "E" }
      },
      "System" =>
      { "Prefix" => "2"
      }
    }
  }
);

## DO NOT DELETE ##
# Hash recursion example:
#$source = \%Spec;
#print("source keys");
#for $key ( keys %{$source} ) { print " ".$key; }
#print "\n";
#$source = $source->{"R0161"};
#print("source keys");
#for $key ( keys %{$source} ) { print " ".$key; }
#print "\n";
#exit;
## END OF DO-NOT-DELETE ##

my $PortName = "COM1";
my $PortObj = new Win32::SerialPort ($PortName)
       || die "Can't open $PortName: $^E\n";

$PortObj->databits(8);
$PortObj->baudrate(9600);
$PortObj->parity("none");
$PortObj->handshake("none");
$PortObj->parity_enable(F);
$PortObj->stopbits(1);
$PortObj->buffers(4096, 4096);
$PortObj->dtr_active(1);
$PortObj->rts_active(1);            

if ($PortObj->write_settings != 1) 
{
	print "sorry, couldn't setup serial port";
}

sub sendInit
{
	print "Sending undocumented init...\n";
	$PortObj->write("0000020100");
	($count_in, $string_in) = $PortObj->read(275);
	print "Got $count_in bytes back.\n";
	$string_in = "";
	print "\n";
}

sub sendReady # getConfiguration
{
	print "Sending Ready command...\n";
	$PortObj->write("000");
	($count_in, $response) = $PortObj->read(512);
	print "Got $count_in bytes, reading Configuration...\n";

	# DCn
	$response =~ s/(.)//;
	$_ = str2hex($1);
	if ( m/11/ ) { print(" DC1\n"); }
	elsif ( m/12/ ) { print(" DC2\n"); }
	elsif ( m/13/ ) { print(" DC3\n"); }
	elsif ( m/14/ ) { print(" DC4\n"); }
	else { print "error: No DCn\n" and exit; }
	
	print " Received Configuration...\n";
	# 5B Model ID
	$yamaha{'ModelID'} = substr($response,0,5);
	print "  model ID: ".$yamaha{'ModelID'};
	if ( $yamaha{'ModelID'} eq "R0161" ) { print " (RX-V2400)"; }
	print "\n"; $response =~ s/.....//;
	# 1B Software Version
	print "  software version: ".substr($response,0,1)."\n";
	$response =~ s/.//;
	# 2B data length
	$dataLength = substr($response,0,2);
	$response =~ s/..//;
	print "  data length: 0x".$dataLength;
	$dataLength = atoi($dataLength);
	print " ($dataLength)\n";
	# up to 256B data
	if ( $dataLength < 9 ) { print "error: Data length less than minimum.\n" and exit; }
	$yamaha{'System'} = substr($response,7,1);
	$yamaha{'Power'} = substr($response,8,1);
	if ( $yamaha{'System'} eq "0" )
	{
		if ( $yamaha{'Power'} eq "0" ) {
			if ( $dataLength != 9 ) { print "error: Data length greater than expected.\n" and exit;
			}
		} else {
			if ( $dataLength != 138 ) { print "error: Data length not as expected.\n" and exit;
			}
		}
	}
	print "  data: ";
	while ( $dataLength > 0 )
	{
		print substr($response,0,1);
		$response =~ s/.//;
		$dataLength--;
	}
	print "\n";
	# 2B checksum
	$checksum = substr($response,0,2);
	print "  checksum: 0x".$checksum;
	$checksum = atoi($checksum);
	print " ($checksum)\n";
	$response =~ s/..//;
	# ETX
	$response =~ s/(.)//;
	$_ = str2hex($1);
	if ( m/03/ ) { print(" ETX\n"); }
	else { print "error: No ETX\n" and exit; }
	print "\n";
}

sub sendControl # getReport
{
	local($inStr) = @_;

	# Rules
	if ( $yamaha{'Power'} ne $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}{'ON'} )
	{
		#return "error: Only Power and System Control commands are valid when the power is off.\n";
	}
	if ( $yamaha{'System'} ne $Spec{$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'} )
	{
		return "error: No Control commands are allowed when the system status is not OK.\n";
	}

	$source = $Spec{$yamaha{'ModelID'}}{'Control'};
	$cdr = $inStr;
	$packet = "";
	$packetTail = "";
	$count = 0;
	while ( "" ne $cdr )
	{
		if ( $count > 100 ) { return "error: Internal search fault."; }
		$count++;
		if ( defined($source->{'Prefix'}) ) { $packet = $packet.$source->{'Prefix'}; }
		if ( defined($source->{'Suffix'}) ) { $packetTail = $source->{'Suffix'}.$packetTail; }
		print "cdr $cdr\n";
		$cdr =~ s/(\S+)\s*//;
		$car = $1;
		print "car $car cdr $cdr source source\n$packet $packetTail\n";
		if ( !defined($source->{$car}) )
		{
			return "error: Couldn't understand '$car' in '$inStr'";
		}
		if ( "" ne $cdr )
		{
			print("source $source\n");
			print("source keys");
			for $key ( keys %{$source} ) { print " ".$key; }
			print "\n";
			print("source->{$car} ".$source->{$car}."\n");
			$source = $source->{$car};
		} else {
			print("source->{$car} $source->{$car}\n");
			$packet = $packet.$source->{$car}.$packetTail;
		}
	}
	print "send $packet";

	print "Sending Control $inStr...\n";
	#$PortObj->write($STX."07EB".$inStr.$ETX);
	$PortObj->write($packet);
	($count_in, $string_in) = $PortObj->read(275);
	print "Got $count_in bytes back.\n";
	$string_in = "";
	print "\n";
	return "OK - Received $count_in byte response.";
}

sendInit();
sendReady();

$PORT = 9000;

$server = IO::Socket::INET->new( Proto     => 'tcp',
                                 LocalPort => $PORT,
                                 Listen    => SOMAXCONN,
                                 Reuse     => 1);

die "sorry, couldn't setup server" unless $server;
print "[LINX-Server waiting for commands on port $PORT]\n";

while ($client = $server->accept()) 
{
	$client->autoflush(1);

	# Welcome message
	print $client "rxv2400server connection open.\n";
	print $client "Accepting commands for $yamaha{'ModelID'}";
	if ( $yamaha{'ModelID'} eq "R0161" ) { print $client " (RX-V2400)"; }
	print $client " device.\n";
	print $client "(type 'help' for documentation)\n";
	
    while (<$client>) 
    {
    	next unless /\S/;       # blank line check

		s/\n//;
		s/\r//;
		s/^\s*//;

		if ( /^Control/ )
		{
			s/^Control\s*//;
			$command = $_;
			sendInit();
			sendReady();
			$status = sendControl($command);
			print $status."\n";
			print $client $status."\n";
		} elsif ( /^bye/i ) {
     		last;
		} elsif ( /^reload/i ) {
    		close $client;
			close $server;
			undef $PortObj;
			exec( "\"$app\"" );
		} elsif ( /^shutdown/i ) {
    		close $client;
			close $server;
			undef $PortObj;
			exit;
		} elsif ( /^help/i ) {
			s/help\s*//;
			$help = $_;

			$source = $Spec{$yamaha{'ModelID'}};
			$cdr = $_;
			$count = 0;
			if ( "" eq $cdr )
			{
				print $client "\nWelcome to help.\n";
				print $client "Basic commands are:\n";
				print $client "  Control\n";
				print $client "  bye\n";
				print $client "  reload\n";
				print $client "  shutdown\n";
				print $client "  help\n";
				print $client "\n";
				print $client " Additional documentation on capitalized basic commands is available by typing\n";
				print $client "help and that command name.  e.g. \"help Control\"\n";
				print $client " Command options with an asterisk (*) following their name are sub-commands\n";
				print $client "which have their own options which you can get help on too.  e.g. \"help Control Operation\"\n";
			} else {
				print $client "\nCommands that being with \"$_\" have the following options:\n";
			}
			while ( "" ne $cdr )
			{
				if ( $count > 100 ) { print $client "error: Internal search fault.\n"; $cdr = ""; next; }
				$count++;
				$cdr =~ s/(\S+)\s*//;
				$car = $1;
				if ( !defined($source->{$car}) )
				{
					print $client "error: Couldn't understand '$car' in '$help'\n";
					$cdr = "";
					next;
				}
				if ( "" ne $cdr )
				{
					$source = $source->{$car};
				} else {
					$options = 0;
					for $key ( keys %{$source->{$car}} )
					{
						if ( "Prefix" ne $key && "Suffix" ne $key )
						{
							$options++;
							print $client "  ".$key;
							if ( defined((keys %{$source->{$car}->{$key}})[0]) ) { print $client "*"; }
							print $client "\n";
						}
					}
					if ( 0 == $options ) { print $client "  <none>\n"; }
				}
			}
		}
		print $client "\n";
    }
    close $client;
} 

#close the port - when the server is shut down
undef $PortObj;


sub atoi
{
	local($inStr) = @_;
	$retVal = 0;
	while ( $inStr =~ s/(.)// )
	{
		$char = $1;
		$retVal <<= 4;
		$num = ord($char);
		if ( $num >= 0x30 && $num <= 0x39 ) { $retVal += ($num - 0x30); }
		elsif ( $num >= 0x41 && $num <= 0x46 ) { $retVal += (10 + $num - 0x41); }
		else { print "atoi error at $char ($num) $retVal $inStr\n" and exit; }
	}
	return $retVal;
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
