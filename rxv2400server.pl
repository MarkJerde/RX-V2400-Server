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
# pmm Win32-SerialPort
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
      "Power" => { "OFF" => "0" , "ON" => "1" },
	  "Input" => [ "PHONO" , "CD" , "TUNER" , "CD-R" , "MD/TAPE" , "DVD" , "D-TV/LD" , "CABLE/SAT" , "SAT" , "VCR1" , "VCR2/DVR" , "VCR3" , "V-AUX" ],
      "OffOn" => [ "OFF" , "ON" ],
      "ABCDE" => [ "A" , "B" , "C" , "D" , "E" ],
      "InputMode" => [ "AUTO" , "DD/RF" , "DTS" , "DIGITAL" , "ANALOG" , "AAC" ],
    },
	"macro" =>
    {
    },
    "Control" =>
    { "Prefix" => $STX,
      "Suffix" => $ETX,
      "Operation" =>
      { "Prefix" => "07",
        "Zone1Volume" => { "Prefix" => "A1" , "Up" => "A" , "Down" => "B" },
        "Zone1Mute" => { "Prefix" => "EA" , "ON" => "2" , "OFF" => "3" },
        "Zone1Input" => { "Prefix" => "A" ,
                          "PHONO" => "14" ,
                          "CD" => "15" ,
                          "TUNER" => "16" ,
                          "CD-R" => "19" ,
                          "MD/TAPE" => "C9" ,
                          "DVD" => "C1" ,
                          "D-TV/LD" => "54" ,
                          "CABLE/SAT" => "C0" ,
                          "SAT" => "CA" ,
                          "VCR1" => "0F" ,
                          "VCR2/DVR" => "13" ,
                          "VCR3" => "C8" ,
                          "V-AUX" => "55" },
        "6chInput" => { "Prefix" => "EA" , "ON" => "4" , "OFF" => "5" },
        "InputMode" => { "Prefix" => "EA" ,
                         "AUTO" => "6" ,
                         "DD/RF" => "7" ,
                         "DTS" => "8" ,
                         "DIGITAL" => "9" ,
                         "ANALOG" => "A" ,
                         "AAC" => "B" },
        "Zone2Volume" => { "Prefix" => "AD" , "Up" => "A" , "Down" => "B" },
        "Zone2Mute" => { "Prefix" => "EA" , "ON" => "0" , "OFF" => "1" },
        "Zone2Input" => { "Prefix" => "A" ,
                          "PHONO" => "D0" ,
                          "CD" => "D1" ,
                          "TUNER" => "D2" ,
                          "CD-R" => "D4" ,
                          "MD/TAPE" => "CF" ,
                          "DVD" => "CD" ,
                          "D-TV/LD" => "D9" ,
                          "CABLE/SAT" => "CC" ,
                          "SAT" => "CB" ,
                          "VCR1" => "D6" ,
                          "VCR2/DVR" => "D7" ,
                          "VCR3" => "CE" ,
                          "V-AUX" => "D8" },
        "Power" => { "Prefix" => "A1" , "ON" => "D" , "OFF" => "E" },
        "Zone1Power" => { "Prefix" => "E7" , "ON" => "E" , "OFF" => "F" },
        "Zone2Power" => { "Prefix" => "EB" , "ON" => "A" , "OFF" => "B" },
        "Zone3Power" => { "Prefix" => "AE" , "ON" => "D" , "OFF" => "E" },
        "Zone3Mute" => { "Prefix" => "E" , "ON" => "2" , "OFF" => "6" , "Suffix" => "6" },
        "Zone3Volume" => { "Prefix" => "AF" , "Up" => "D" , "Down" => "E" },
        "Zone3Input" => { "Prefix" => "AF" ,
                          "PHONO" => "1" ,
                          "CD" => "2" ,
                          "TUNER" => "3" ,
                          "CD-R" => "5" ,
                          "MD/TAPE" => "4" ,
                          "DVD" => "C" ,
                          "D-TV/LD" => "6" ,
                          "CABLE/SAT" => "7" ,
                          "SAT" => "8" ,
                          "VCR1" => "9" ,
                          "VCR2/DVR" => "A" ,
                          "VCR3" => "B" ,
                          "V-AUX" => "0" },
        #...,
        "TunerPreset" => { "Prefix" => "AE" ,
                           "Page" => { "A" => "0" , "B" => "1" , "C" => "2" , "D" => "3" , "E" => "4" } ,
                           "Num" => { "1" => "5" , "2" => "6" , "3" => "7" , "4" => "8" , "5" => "9" , "6" => "A" , "7" => "B" , "8" => "C" } },
        #...,
        "SpeakerRelay" => { "Prefix" => "EA" ,
                            "A" => { "ON" => "B" , "OFF" => "C" } ,
                            "B" => { "ON" => "D" , "OFF" => "E" } }
      },
      "System" =>
      { "Prefix" => "2",
        "Zone1Volume" => { "Prefix" => "30" ,
                           "Eval" => "val" ,
                           "Up" => "\$yamaha{'Zone1Volume'}++;
                                    itoa(\$yamaha{'Zone1Volume'});" ,
                           "Down" => "\$yamaha{'Zone1Volume'}++;
                                      itoa(\$yamaha{'Zone1Volume'});",
                           "Adjust" => { "Eval" => "\$yamaha{'Zone1Volume'}+=(\$car*2);
                                                    itoa(\$yamaha{'Zone1Volume'});"},
                           "Set" => { "Eval" => "\$yamaha{'Zone1Volume'}=(\$car*2+199);
                                                 itoa(\$yamaha{'Zone1Volume'});"}
        },
        "Zone2Volume" => { "Prefix" => "31" ,
                           "Eval" => "val" ,
                           "Up" => "\$yamaha{'Zone2Volume'}++;
                                    itoa(\$yamaha{'Zone2Volume'});" ,
                           "Down" => "\$yamaha{'Zone2Volume'}++;
                                      itoa(\$yamaha{'Zone2Volume'});",
                           "Adjust" => { "Eval" => "\$yamaha{'Zone2Volume'}+=(\$car*2);
                                                    itoa(\$yamaha{'Zone2Volume'});"},
                           "Set" => { "Eval" => "\$yamaha{'Zone2Volume'}=(\$car*2+199);
                                                 itoa(\$yamaha{'Zone2Volume'});"}
        },
        "Zone3Volume" => { "Prefix" => "34" ,
                           "Eval" => "val" ,
                           "Up" => "\$yamaha{'Zone3Volume'}++;
                                    itoa(\$yamaha{'Zone3Volume'});" ,
                           "Down" => "\$yamaha{'Zone3Volume'}++;
                                      itoa(\$yamaha{'Zone3Volume'});",
                           "Adjust" => { "Eval" => "\$yamaha{'Zone3Volume'}+=(\$car*2);
                                                    itoa(\$yamaha{'Zone3Volume'});"},
                           "Set" => { "Eval" => "\$yamaha{'Zone3Volume'}=(\$car*2+199);
                                                 itoa(\$yamaha{'Zone3Volume'});"}
        },
      }
    },
    "Report" =>
    { "ControlType" => [ "serial" , "IR" , "panel" , "system" , "encoder" ],
      "GuardStatus" => ["No" , "System" , "Setting" ],
	  "00" => { "00" => "\$yamaha{'System'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'};",
                "01" => "\$yamaha{'System'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'System'}{'Busy'};",
                "02" => "\$yamaha{'System'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'};\$yamaha{'Power'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Power'}{'OFF'};"
      },
      "01" => "\$error .= \"ERROR: SYSTEM WARNING \$rdat.\n\";",
      "10" => "assert(14>atoi(\$rdat));\$yamaha{'Playback'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Playback'}[\$rdat];\$info .= \"Playback = \$yamaha{'Playback'}\n\";",
      "11" => "assert(12>atoi(\$rdat));\$yamaha{'Fs'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Fs'}[\$rdat];\$info .= \"Fs = \$yamaha{'Fs'}\n\";",
      "12" => "assert(3>atoi(\$rdat));\$yamaha{'EX/ES'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'EX/ES'}[\$rdat];\$info .= \"EX/ES = \$yamaha{'EX/ES'}\n\";",
      "13" => "assert(2>atoi(\$rdat));\$yamaha{'Thr/Bypass'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[\$rdat];\$info .= \"Thr/Bypass = \$yamaha{'Thr/Bypass'}\n\";",
      "14" => "assert(2>atoi(\$rdat));\$yamaha{'REDdts'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'REDdts'}[\$rdat];\$info .= \"REDdts = \$yamaha{'REDdts'}\n\";",
      "15" => "assert(2>atoi(\$rdat));\$yamaha{'TunerTuned'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[\$rdat];\$info .= \"TunerTuned = \$yamaha{'TunerTuned'}\n\";",
      "16" => "assert(2>atoi(\$rdat));\$yamaha{'Dts96/24'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[\$rdat];\$info .= \"Dts96/24 = \$yamaha{'Dts96/24'}\n\";",
      "20" => "\$rdat=atoi(\$rdat);assert(8>\$rdat);\$info .= setZ1Power((((\$rdat%7)%3)+1)>>1); \$info .= setZ2Power((\$rdat>>2)^(\$rdat&1)); \$info .= setZ3Power(\$rdat&1);"
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
my $PortObj;

my $info = "";
my $warning = "";
my $error = "";

sub setupSerialPort
{
	$PortObj = new Win32::SerialPort ($PortName)
	       || die "Can't open $PortName: $^E\n";
	
	$PortObj->user_msg(ON);
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

$dcnfail = 0;
sub sendReady # getConfiguration
{
	print "Sending Ready command...\n";
	$PortObj->write("000");
	($count_in, $response) = $PortObj->read(512);
	print "Got $count_in bytes, reading Configuration...\n";
	if ( 0 == $count_in )
	{
		$response = "N";
	}

	# DCn
	$response =~ s/(.)//;
	$_ = str2hex($1);
	if ( m/11/ ) { print(" DC1\n"); }
	elsif ( m/12/ ) { print(" DC2\n"); }
	elsif ( m/13/ ) { print(" DC3\n"); }
	elsif ( m/14/ ) { print(" DC4\n"); }
	else
	{
		print "error: No DCn... ";
		if ( 0 == $dcnfail )
		{
			$dcnfail++;
			print "reloading serial interface.\n";
			undef $PortObj;
			setupSerialPort();
			return sendReady();
		} elsif ( 1 == $dcnfail ) {
			$dcnfail++;
			print "sleeping... ";
			sleep 30;
			print "reloading serial interface.\n";
			undef $PortObj;
			setupSerialPort();
			return sendReady();
		} else {
			print "failing.\n" and exit;
		}
	}
	
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
	if ( $dataLength < 9 )
	{
		print "error: Data length less than minimum.\n";
		print "reloading serial interface.\n";
		$dcnfail++;
		return sendReady();
	} else {
		while ( $dataLength > ($count_in - 12) )
		{
			print "warning: Ready response missing ".($dataLength - ($count_in - 12))." bytes.\n";
			($ncount_in, $nresponse) = $PortObj->read(512);
			$count_in += $ncount_in;
			$response .= $nresponse;
			if ( $ncount_in == 0 )
			{
				print "error: Couldn't read ready data.\n";
				print "reloading serial interface.\n";
				$dcnfail++;
				return sendReady();
			}
		}
	}
	$yamaha{'System'} = substr($response,7,1);
	$yamaha{'Power'} = substr($response,8,1);
	if ( $yamaha{'System'} eq "0" )
	{
		if ( $yamaha{'Power'} eq "0" ) {
			if ( $dataLength != 9 ) { print "error: Data length greater than expected.\n" and exit; }
		} else {
			if ( $dataLength != 138 ) { print "error: Data length not as expected.\n" and exit; }

			$yamaha{'Zone1Input'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Input'}[substr($response,9,1)];
			$yamaha{'6chInput'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,10,1)];
			$yamaha{'InputMode'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'InputMode'}[substr($response,11,1)];
			$yamaha{'Zone1Mute'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,12,1)];
			$yamaha{'Zone2Input'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Input'}[substr($response,13,1)];
			$yamaha{'Zone2Mute'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,14,1)];
			# Volume is numeric.  Higher = Louder.  0.5db increment.
			$yamaha{'Zone1Volume'} = atoi(substr($response,15,2));
			$yamaha{'Zone2Volume'} = atoi(substr($response,17,2));
			# 19..20 "Program"
			$yamaha{'Effect'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,21,1)];
			# 22 "6.1/ES"
			# 23 "OSD"
			# 24 "Sleep"
			$yamaha{'TunerPage'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'ABCDE'}[substr($response,25,1)];
			$yamaha{'TunerNum'} = substr($response,26,1);
			$yamaha{'NightMode'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,27,1)];
			# 28 "Don't Care"
			$yamaha{'SpeakerA'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,29,1)];
			$yamaha{'SpeakerB'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,30,1)];

			print "== === Yamaha ";
			if ( $yamaha{'ModelID'} eq "R0161" ) { print "RX-V2400"; }
			else { print $yamaha{'ModelID'}; }
			print " Settings === ==\n";
			print "          Zone 1    Zone 2    Zone 3\n";
			print "Input     $yamaha{'Zone1Input'}    $yamaha{'Zone2Input'}    \$yamaha{'Zone3Input'}\n";
			print "Volume    $yamaha{'Zone1Volume'}    $yamaha{'Zone2Volume'}    \$yamaha{'Zone3Volume'}\n";
			print "Mute      $yamaha{'Zone1Mute'}    $yamaha{'Zone2Mute'}    \$yamaha{'Zone3Mute'}\n";
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
	else
	{
		print "error: No ETX\n";
		print "reloading serial interface.\n";
		$dcnfail++;
		return sendReady();
	}
	print "\n";
	$dcnfail = 0;
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
#		print "car $car cdr $cdr source source\n$packet $packetTail\n";
		if ( !defined($source->{$car}) &&
			( "" ne $cdr
			|| !defined($source->{'Eval'})
			|| "val" eq $source->{'Eval'} ) )
		{
			if ( "" ne $cdr ) { print "necdr\n"; }
			else { print "cdr |$cdr|\n"; }
			if ( !defined($source->{'Eval'}) ) { print "nedef\n"; }
			elsif ( "val" ne $source->{'Eval'} ) { print "seval $source->{'Eval'}\n"; }
			return "error: Couldn't understand '$car' in '$inStr'";
		}
		if ( "" ne $cdr )
		{
#			print("source $source\n");
#			print("source keys");
#			for $key ( keys %{$source} ) { print " ".$key; }
#			print "\n";
#			print("source->{$car} ".$source->{$car}."\n");
			$source = $source->{$car};
		} else {
#			print("source->{$car} $source->{$car}\n");
			if ( defined($source->{'Eval'}) )
			{
				if ( "val" eq $source->{'Eval'} )
				{
					$packet = $packet.eval($source->{$car}).$packetTail;
				} else {
					$packet = $packet.eval($source->{'Eval'}).$packetTail;
				}
			} else {
				$packet = $packet.$source->{$car}.$packetTail;
			}
		}
	}
	print "send $packet";

	print "Sending Control $inStr...\n";
	$PortObj->write($packet);
	($count_in, $string_in) = $PortObj->read(275);
	print "Got $count_in bytes back.\n";
	#$string_in = "";
	print "\n";
	$string_in =~ s/(.)/$1 /g;
	$string_in =~ s/$STX/STX/g;
	$string_in =~ s/$ETX/ETX/g;
	$retMsg = "OK - Received $count_in byte response.";
	$retMsg = $retMsg."\n  - $string_in";
	return $retMsg;
	return "OK - Received $count_in byte response.";
}

sub writeMacroFile
{
	local($inFile) = @_;

	if (open(MYFILE, ">macro/$inFile.rxm")) {
		for $key ( keys %MacroLibrary )
		{
			print MYFILE "macro $key\n$MacroLibrary{$key}end\n\n";
		}
	}
	close(MYFILE);
}

sub readMacroFile
{
	local($inFile) = @_;

	if (open(MYFILE, "macro/$inFile.rxm")) {
		while (<MYFILE>)
		{
	    	next unless /\S/;       # blank line check
	
			s/\n//;
			s/\r//;
			s/^\s*//;

			if ( /^macro\s+(\S+)/i ) {
				$macroName = $1;
				print "reading macro '$macroName'\n";
				$MacroLibrary{$macroName} = "";
		
			    while (<MYFILE>) 
			    {
			    	next unless /\S/;       # blank line check
					last if /^end/;
			
					s/\n//;
					s/\r//;
					s/^\s*//;
					$MacroLibrary{$macroName} .= $_."\n";
				}
			}
		}
	}
	close(MYFILE);
}

sub decode
{
	local($inStr) = @_;
	$_ = $inStr;

	if ( /^Control/ )
	{
		s/^Control\s*//;
		$command = $_;
		#sendInit();
		sendReady();
		$status = sendControl($command);
		print $status."\n";
		print $client $status."\n";
	} elsif ( /^play/i ) {
		s/play\s*//;
		# Fork since this will never close on it's own.
		# This will interrupt current audio.
		system("fork.pl \"c:\\Program Files\\Windows Media Player\\wmplayer.exe\" \"$_\"");
	} elsif ( /^sleep/i ) {
		s/sleep\s*//;
		$time = 0;
		if ( s/^(\d+)$// )
		{
			$time = $1;
		}
		if ( s/(\d+)d//i )
		{
			$time += 24 * 60 * 60 * $1;
		}
		if ( s/(\d+)h//i )
		{
			$time += 60 * 60 * $1;
		}
		if ( s/(\d+)m//i )
		{
			$time += 60 * $1;
		}
		if ( s/(\d+)s//i )
		{
			$time += $1;
		}
		sleep $time;
	} elsif ( /^test/i ) {
		$rcvd = 0;
            $string_in = "";
		while ( 20 > $rcvd )
		{
			($count_in, $string_i) = $PortObj->read(512);
                $string_in .= $string_i;
			if ( 0 != $count_in )
			{
				$rcvd++;
				print "Got $count_in bytes back.\n";
				#$string_in = "";
				print "\n";
                    $pat = $STX."(.)(.)(..)(..)".$ETX;
                    while ( $string_in =~ s/$pat// )
                    {
                      print $client "recvd $1$2$3$4\n";
                      print $client "From: $Spec{$yamaha{'ModelID'}}{'Report'}{'ControlType'}[$1]\n";
                      print $client "Guard: $Spec{$yamaha{'ModelID'}}{'Report'}{'GuardStatus'}[$2]\n";
                      $rcmd = $3;
                      $rdat = $4;
                      print "rcmd $3 rdat $4\n";
                      if ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}) )
                      {
                        print "eval $Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}\n";
                        eval($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd});
                        if ( "" ne $error )
                        {
                          print "===================================\n";
                          print "===  vv  !!!  ERRORS  !!!  vv   ===\n";
                          print "===================================\n";
                          print $error;
                          print "===================================\n";
                          print "===  ^^  !!!  ERRORS  !!!  ^^   ===\n";
                          print "===================================\n";
                          $error = "";
                        }
                        if ( "" ne $warning )
                        {
                          print "\nWarnings:\n";
                          print $warning;
                          print "\n";
                          $warning = "";
                        }
                        if ( "" ne $info )
                        {
                          print $info."\n";
                          $info = "";
                        }
                      }
                      $rdat = "";
                    }
#					$string_in =~ s/(.)/$1 /g;
#					$string_in =~ s/$STX/STX/g;
#					$string_in =~ s/$ETX/ETX/g;
#					$retMsg = "OK - Received $count_in byte response.";
#					$retMsg = $retMsg."\n  - $string_in";
#					#print $client $retMsg."\n";
#					$_ = "c:\\Documents and Settings\\Dave\\My Documents\\My Music\\Gershwin\\American Draft - Someone to Watch Over Me.mp3";
#					system("fork.pl \"c:\\Program Files\\Windows Media Player\\wmplayer.exe\" \"$_\"");
			}
		}
	} elsif ( /^macro\s+(\S+)/i ) {
		$macroName = $1;
		$MacroLibrary{$macroName} = "";

		print $client "Recording macro '$macroName'...\n";
		print $client "(use 'end' when finished)\n";

	    while (<$client>) 
	    {
	    	next unless /\S/;       # blank line check
			last if /^end/;
	
			s/\n//;
			s/\r//;
			s/^\s*//;
			$MacroLibrary{$macroName} .= $_."\n";
		}

		print $client "Recorded macro '$macroName' as follows:\n";
		print $client $MacroLibrary{$macroName}."\n[end of listing]\n";
		writeMacroFile("default");
	} elsif ( /^run\s+(\S+)/i ) {
		my $macroName = $1;
		if ( !defined($MacroLibrary{$macroName}) ) {
			print $client "error: Unknown macro '$macroName'\n";
			return;
		}
		my $macro = $MacroLibrary{$macroName};
		print "running macro '$macro'\n";
		while ( $macro =~ s/(.+?)\n// )
		{
			print "running cmd '$1'\n";
			decode($1);
		}
		print $client "Macro '$macroName' completed.\n";
	} elsif ( /^write\s+(\S+)/i ) {
		writeMacroFile($1);
	} elsif ( /^read\s+(\S+)/i ) {
		readMacroFile($1);
	} elsif ( /^clear\s+(\S+)/i ) {
		%MacroLibrary = ();
	} elsif ( /^bye/i ) {
		close $client;
 		return;
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
			print $client "  play      - play specified media\n";
			print $client "  sleep     - sleep for specified time (e.g. 7h 5m 23s)\n";
			print $client "  bye       - disconnect from server\n";
			print $client "  reload    - restart server (for updates)\n";
			print $client "  shutdown  - shutdown server\n";
			print $client "  help      - this message\n";
			print $client "\n";
			print $client " Additional documentation on capitalized basic commands is available by typing\n";
			print $client "help and that command name.  e.g. \"help Control\"\n";
			print $client " Command options with an asterisk (*) following their name are sub-commands\n";
			print $client "which have their own options which you can get help on too.\ne.g. \"help Control Operation\"\n";
			print $client " Command syntax is based on the Yamaha I/O specifications.  Sorry\n";
			print $client " Most commands are case-sensitive.\n";
		} else {
			print $client "\nCommands that being with \"$_\" have the following options:\n";
		}
		while ( "" ne $cdr )
		{
			if ( $count > 100 ) { print $client "error: Internal search fault.\n"; $cdr = ""; return; }
			$count++;
			$cdr =~ s/(\S+)\s*//;
			$car = $1;
			if ( !defined($source->{$car}) )
			{
				print $client "error: Couldn't understand '$car' in '$help'\n";
				$cdr = "";
				return;
			}
			if ( "" ne $cdr )
			{
				$source = $source->{$car};
			} else {
				$options = 0;
				for $key ( keys %{$source->{$car}} )
				{
					if ( "Prefix" ne $key && "Suffix" ne $key && "Eval" ne $key )
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
	} else {
		print $client "error: Couldn't understand command '$_'\n";
	}
	print $client "\n";
}

setupSerialPort();
sendInit();
sendReady();

my %MacroLibrary = ();
readMacroFile("default");

$PORT = 9000;

$server = IO::Socket::INET->new( Proto     => 'tcp',
                                 LocalPort => $PORT,
                                 Listen    => SOMAXCONN,
                                 Reuse     => 1);

die "sorry, couldn't setup server" unless $server;
print "[LINX-Server waiting for commands on port $PORT]\n";

#$PortObj->write($STX."07AED".$ETX.$STX."07EBA".$ETX.$STX."07A1B".$ETX.$STX."07A1B".$ETX.$STX."07A1B".$ETX.$STX."07A1B".$ETX);

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
		decode($_);
    }
    #close $client;
} 

#close the port - when the server is shut down
undef $PortObj;


sub setZ1Power
{
	local($inVal) = @_;
    $val = $Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[$inVal];
    if ( $yamaha{'Zone1Power'} eq $val ) { return ""; }
    $yamaha{'Zone1Power'} = $val;
    $msg = "Zone1Power turned $val.\n";
    if ( "ON" eq $val )
    {
        $msg .= "Input: $yamaha{'Zone1Input'}  Volume: $yamaha{'Zone1Volume'}  Mute: $yamaha{'Zone1Mute'}\n";
    }
    return $msg;
}

sub setZ2Power
{
	local($inVal) = @_;
    $val = $Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[$inVal];
    if ( $yamaha{'Zone2Power'} eq $val ) { return ""; }
    $yamaha{'Zone2Power'} = $val;
    $msg = "Zone2Power turned $val.\n";
    if ( "ON" eq $val )
    {
        $msg .= "Input: $yamaha{'Zone2Input'}  Volume: $yamaha{'Zone2Volume'}  Mute: $yamaha{'Zone2Mute'}\n";
    }
    return $msg;
}

sub setZ3Power
{
	local($inVal) = @_;
    $val = $Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[$inVal];
    if ( $yamaha{'Zone3Power'} eq $val ) { return ""; }
    $yamaha{'Zone3Power'} = $val;
    $msg = "Zone3Power turned $val.\n";
    if ( "ON" eq $val )
    {
        $msg .= "Input: $yamaha{'Zone3Input'}  Volume: $yamaha{'Zone3Volume'}  Mute: $yamaha{'Zone3Mute'}\n";
    }
    return $msg;
}

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

sub itoa
{
	local($inNum) = @_;
	$retVal = "";
	while ( $inNum > 0 )
	{
		$char = $inNum % 16;
		$inNum >>= 4;
		if ( $char < 10 ) { $char += 0x30; }
		else { $char += (0x41-10); }
		$retVal = chr($char).$retVal;
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
