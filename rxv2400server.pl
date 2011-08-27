#!/usr/bin/perl -w

#   RX-V2400 Server
#   Control software for certain Yamaha A/V receivers.
#   This is independently developed software with no relation to Yamaha.
#
#   Copyright 2006-2011 Mark Jerde
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

my $version = "2.3";
# version 2.3 of rxv2400server.pl ##################################
####################################################################
############## hacked by Mark Jerde, fall 05 (mjerde3@charter.net) #
################# further hacked over the years through feb 2011 ###
####################################################################
# based on the original version linxServer.pl 1.1 ##################
# hacked by jörg dießl, fall 99 (joreg@testphase.at) ###############
####################################################################
# based on the original version talkrcx.txt,v 1.3 ##################
# written by Paul Haas (http://www.hamjudo.com/rcx/talkrcx.txt) ####
####################################################################
# besides a perl version (>5) this script requires two modules #####
# installed on your system if using Windows: #######################
# Win32::API available under http://www.divinf.it/dada/perl/Win32API-0.011.zip
# Win32::SerialPort available under http://members.aol.com/Bbirthisel/Win32-SerialPort-0.18.tar.gz
# pmm Win32-SerialPort
####################################################################
####################################################################
# This server listens to port 8675 for various commands detailed   #
# in the "help" command", corresponding to the command a string is #
# sent to the serial-port (to which a Yamaha RX-V 2400 should be   #
# connected) that performs the operations allowed by the Yamaha    #
# receiver.                                                        #
####################################################################
# before the server starts listening...                            #
# ...the serial-port is opened                                     #
####################################################################

use 5.008;             # 5.8 required for stable threading
use strict;            # Amen
use warnings;          # Hallelujah
use threads;           # pull in threading routines
use threads::shared;   # and variable sharing routines
use POSIX qw(strftime);

my $timeformat = '[%b %d, %Y %H:%M:%S]';

use English;
use IO::Socket;
use Net::hostent;
use Sys::Hostname;

$| = 1; # Set STDOUT to line buffering even when attached to a file.

my $cmd = $0;

my $endedcr = 1;
sub logprint
{
	my $string = shift;
	my ($package, $filename, $line) = caller;
	my $header = strftime($timeformat,localtime)." $$.".threads->tid()." [$line] ";
	if ( $endedcr ) { $string = $header.$string; }
	$endedcr = ($string =~ s/\n$//)?1:0;
	$string =~ s/\n/\n$header/g;
	if ( $endedcr ) { $string .= "\n"; }
	print $string;
}

sub assert
{
	return 1 if shift;
	my ($package, $filename, $line) = caller;
	logprint "assert failed at line $line.\nTerminating.\n";
	exit;
}

my $starnix = 1; # default to being a *NIX
my $osname = $^O;
if ( $osname eq "MSWin32" ) { $starnix = 0; }

sub onscreenInfo
{
	my ($title, $message) = @_;
	if ( $osname eq 'darwin' )
	{
		system "growlnotify -d 1 '$title' -m '$message'";
	}
}

onscreenInfo("RX-V2400","Starting server");

## Put timestamps on every line of STDOUT
#-- Doesn't play well with threads.
#my $cmddir = $cmd;
#$cmddir =~ s/\/[^\/]*$//;
#eval "use lib '$cmddir'";
#eval "use Logger";
#unless ($@)
#{
#	open my $stdout, ">&STDOUT";
#	close STDOUT;
#	open (STDOUT, ">&:via(Logger)", $stdout)
#	  or print "Unable to logify standard output: $!\n";
#} else {
#	print "couldn't load optional module : $!\n$@";
#}

my $PORT = 8675;
my $numServersToRun = 1;
my $forward = "";
my $forwardReceiver = "";
my $forwardReceiverPort = 9000;
my $forwardOther = "";
my $forwardOtherPort = 9000;

eval "use Getopt::Long";
if ($@)
{
	if ( defined(shift) )
	{
		logprint "Command-line parameters are not supported unless Getopt::Long is installed.\nTerminating.\n";
		exit;
	}
} else {
	GetOptions("port=i"=>\$PORT,
	           "forward|f=s"=>\$forward,
	           "forward_receiver|fr=s"=>\$forwardReceiver,
	           "forward_other|fo=s"=>\$forwardOther);
	my $temp = shift;
	if ( defined($temp) )
	{
		logprint "Unrecognized option: '$temp'.\nTerminating.\n";
		exit;
	}
}

if ( $forward ne "" )
{
	$forwardReceiver = $forward;
	$forwardOther = $forward;
}

if ( ($forwardReceiver ne "") || ($forwardOther ne "") )
{
	eval "use Net::Telnet";
	if ($@)
	{
		logprint "Forwarding is not supported unless Net::Telnet is installed.\nTerminating.\n";
		exit;
	}
}

if ( $forwardReceiver ne "" )
{
	my $fw = $forwardReceiver;
	if ( $forwardReceiver =~ s/:(\d+)$// )
	{
		$forwardReceiverPort = $1;
	}
	my $telnet = new Net::Telnet('Host'=>$forwardReceiver,
	                             'Port'=>$forwardReceiverPort);
	$telnet->put("bye\n");
	my $output = $telnet->get();

	$telnet->close();

	unless ( $output =~ m/RX-V\d+ Server [\S ]+ connection open/ )
	{
		logprint "Could not connect to $fw for forwarding.\nTerminating.\n";
		exit;
	}
} else {
	if ($osname eq "MSWin32")
	{
		eval "use Win32::SerialPort 0.15";
		die "couldn't load module : $!\n$@" if ($@);
	} else { # default 'linux'
		eval "use Device::SerialPort 0.15";
		die "couldn't load module : $!\n$@" if ($@);
	}
}

if ( $forwardOther ne "" )
{
	my $fw = $forwardOther;
	if ( $forwardOther =~ s/:(\d+)$// )
	{
		$forwardOtherPort = $1;
	}
	my $telnet = new Net::Telnet('Host'=>$forwardOther,
	                             'Port'=>$forwardOtherPort);
	$telnet->put("bye\n");
	my $output = $telnet->get();

	$telnet->close();

	unless ( $output =~ m/RX-V\d+ Server [\S ]+ connection open/ )
	{
		logprint "Could not connect to $fw for forwarding.\nTerminating.\n";
		exit;
	}
}

# Shared resources:
our %input  : shared; # Each command will have a new UID.
our %output : shared; # Results will be placed here keyed by input pid.
our $nextioUID : shared;
$nextioUID = 1;
our $needSendReady : shared;
$needSendReady = 0;
our $lastSend : shared;
$lastSend = 0;
our $lastRecv : shared;
$lastRecv = 0;
our %expect : shared;
our %expectStimulus : shared;
our $nextExpectUID : shared;
$nextExpectUID = 1;
our $inhibitReadReport : shared;
our $requireConfiguration : shared;
$requireConfiguration = 0;
our %yamaha : shared;
%yamaha = ( "System" => "1", "Power" => "0" ); # Busy and Off
our %MacroLibrary : shared;
our $stopNetworkServers : shared;
$stopNetworkServers = 0;
our $runningNetworkServers : shared;
$runningNetworkServers = 0;

our $debug : shared;
$debug = 0;

sub dbglogprint
{
	logprint (shift) if $debug;
}

if ( !defined($ENV{'HOME'}) )
{
	logprint "warning: \$HOME is undefined.  Setting to current directory.\n";
	$ENV{'HOME'} = ".";
}

if ($osname eq "MSWin32")
{
	chdir("F:\\Documents and Settings\\All\ Users\\Documents\\My Music\\Upload");
}

my $STX = hex2str("02");
my $ETX = hex2str("03");
my $DC1 = hex2str("11");
my $DC2 = hex2str("12");
my $DC3 = hex2str("13");
my $DC4 = hex2str("14");

my %settings;
$settings{"DVD"}{'AudioDelay'} = 130;

my %Spec = (
	"R0161" => {
		"Configuration" => {
			"System" => { "OK" => "0" , "Busy" => "1" , "OFF" => "2" },
			"Power" => { "OFF" => "0" , "ON" => "1" },
			# The zone power status is incorrect in the documentation.
			# And it's slightly different between Configuration messages
			# and Report messages.
			# It's silly.
			# Really.
			"PowerDecode" => {
				"0" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'OFF';
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"1" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'ON';
				        \$yamaha{'Zone3Power'} = 'ON';",
				"2" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'OFF';
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"3" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'ON';
				        \$yamaha{'Zone3Power'} = 'ON';",
				"4" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'ON';
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"5" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'OFF';
				        \$yamaha{'Zone3Power'} = 'ON';",
				"6" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'ON';
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"7" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'OFF';
				        \$yamaha{'Zone3Power'} = 'ON';",
			},
			"ReportPowerDecode" => {
				"0" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'OFF';
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"1" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'ON';
				        \$yamaha{'Zone3Power'} = 'ON';",
				"2" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'ON';  # Different
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"3" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'ON';
				        \$yamaha{'Zone3Power'} = 'ON';",
				"4" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'OFF'; # Different
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"5" => "\$yamaha{'Zone1Power'} = 'ON';  \$yamaha{'Zone2Power'} = 'OFF';
				        \$yamaha{'Zone3Power'} = 'ON';",
				"6" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'ON';
				        \$yamaha{'Zone3Power'} = 'OFF';",
				"7" => "\$yamaha{'Zone1Power'} = 'OFF'; \$yamaha{'Zone2Power'} = 'OFF';
				        \$yamaha{'Zone3Power'} = 'ON';",
			},
			"ReportPowerEncode" =>
				"((\$z1&\$z2)?(\$z3?1:4):((\$z1^\$z2)?(\$z1?(\$z3?5:2):(\$z3?3:6)):(\$z3?7:0)))",
			"Input" => [ "PHONO" , "CD" , "TUNER" , "CD-R" , "MD/TAPE" , "DVD" , "D-TV/LD" ,
			             "CABLE/SAT" , "SAT" , "VCR1" , "VCR2/DVR" , "VCR3" , "V-AUX" ],
			"InputEncode" => { "PHONO" =>   "0" , "CD" =>        "1" , "TUNER" => "2" ,
			                   "CD-R" =>    "3" , "MD/TAPE" =>   "4" , "DVD" =>   "5" ,
			                   "D-TV/LD" => "6" , "CABLE/SAT" => "7" , "SAT" =>   "8" ,
			                   "VCR1" =>    "9" , "VCR2/DVR" =>  "A" , "VCR3" =>  "B" ,
			                   "V-AUX" => "C" },
			"OffOn" => [ "OFF" , "ON" ],
			"ABCDE" => [ "A" , "B" , "C" , "D" , "E" ],
			"InputMode" => [ "AUTO" , "DD/RF" , "DTS" , "DIGITAL" , "ANALOG" , "AAC" ],
		},
		"macro" => { },
		"Control" => {
			"Prefix" => $STX,
			"Suffix" => $ETX,
			"Operation" => {
				"Prefix" => "07",
				"Zone1Volume" => { "Prefix" => "A1" , "Up" => "A" , "Down" => "B" },
				"Zone1Mute" =>   { "Prefix" => "EA" , "ON" => "2" , "OFF" => "3" },
				"Zone1Input" => { "Prefix" => "A" ,
				                  "PHONO" =>   "14" , "CD" =>        "15" , "TUNER" => "16" ,
				                  "CD-R" =>    "19" , "MD/TAPE" =>   "C9" , "DVD" =>   "C1" ,
				                  "D-TV/LD" => "54" , "CABLE/SAT" => "C0" , "SAT" =>   "CA" ,
				                  "VCR1" =>    "0F" , "VCR2/DVR" =>  "13" , "VCR3" =>  "C8" ,
				                  "V-AUX" =>   "55" },
				"6chInput" =>  { "Prefix" => "EA" , "ON" => "4" , "OFF" => "5" },
				"InputMode" => { "Prefix" => "EA" ,
				                 "AUTO" =>    "6" , "DD/RF" =>  "7" , "DTS" => "8" ,
				                 "DIGITAL" => "9" , "ANALOG" => "A" , "AAC" => "B" },
				"Zone2Volume" => { "Prefix" => "AD" , "Up" => "A" , "Down" => "B" },
				"Zone2Mute" =>   { "Prefix" => "EA" , "ON" => "0" , "OFF" => "1" },
				"Zone2Input" => { "Prefix" => "A" ,
				                  "PHONO" =>   "D0" , "CD" =>        "D1" , "TUNER" => "D2" ,
				                  "CD-R" =>    "D4" , "MD/TAPE" =>   "CF" , "DVD" =>   "CD" ,
				                  "D-TV/LD" => "D9" , "CABLE/SAT" => "CC" , "SAT" =>   "CB" ,
				                  "VCR1" =>    "D6" , "VCR2/DVR" =>  "D7" , "VCR3" =>  "CE" ,
				                  "V-AUX" =>   "D8" },
				"Power" => { "Prefix" => "A1" ,
				             "ON" => "D" , "OFF" => "E" ,
				             "Expect" => 1 }, # Wait for Power because it blocks other ops.
				"Zone1Power" => { "Prefix" => "E7" ,
				                  "ON" => "E" , "OFF" => "F" ,
				                  "Expect" => 1 }, # Same as above.
				"Zone2Power" => { "Prefix" => "EB" ,
				                  "ON" => "A" , "OFF" => "B" ,
				                  "Expect" => 1 }, # Same as above.
				"Zone3Power" => { "Prefix" => "AE" ,
				                  "ON" => "D" , "OFF" => "E" ,
				                  "Expect" => 1 }, # Same as above.
				"Zone3Mute" => { "Prefix" => "E" , "ON" => "2" , "OFF" => "6" , "Suffix" => "6" },
				"Zone3Volume" => { "Prefix" => "AF" , "Up" => "D" , "Down" => "E" },
				"Zone3Input" => { "Prefix" => "AF" ,
				                  "PHONO" =>   "1" , "CD" =>        "2" , "TUNER" => "3" ,
				                  "CD-R" =>    "5" , "MD/TAPE" =>   "4" , "DVD" =>   "C" ,
				                  "D-TV/LD" => "6" , "CABLE/SAT" => "7" , "SAT" =>   "8" ,
				                  "VCR1" =>    "9" , "VCR2/DVR" =>  "A" , "VCR3" =>  "B" ,
				                  "V-AUX" =>   "0" },
				#...,
				"TunerPreset" => { "Prefix" => "AE" ,
				                   "Page" => { "A" => "0" , "B" => "1" , "C" => "2" ,
				                               "D" => "3" , "E" => "4" } ,
				                   "Num" => { "1" => "5" , "2" => "6" , "3" => "7" , "4" => "8" ,
				                              "5" => "9" , "6" => "A" , "7" => "B" , "8" => "C" } },
				#...,
				"SpeakerRelay" => { "Prefix" => "EA" ,
				                    "A" => { "ON" => "B" , "OFF" => "C" } ,
				                    "B" => { "ON" => "D" , "OFF" => "E" } }
			},
			"System" => {
				"Prefix" => "2",
				"Zone1Volume" => { "Prefix" => "30" ,
				                   "Eval" => "val" ,
				                   "Up" => "\$yamaha{'Zone1Volume'}++;
				                            itoa(\$yamaha{'Zone1Volume'});" ,
				                   "Down" => "\$yamaha{'Zone1Volume'}--;
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
				                   "Down" => "\$yamaha{'Zone2Volume'}--;
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
				                   "Down" => "\$yamaha{'Zone3Volume'}--;
				                              itoa(\$yamaha{'Zone3Volume'});",
				                   "Adjust" => { "Eval" => "\$yamaha{'Zone3Volume'}+=(\$car*2);
				                                            itoa(\$yamaha{'Zone3Volume'});"},
				                   "Set" => { "Eval" => "\$yamaha{'Zone3Volume'}=(\$car*2+199);
				                                         itoa(\$yamaha{'Zone3Volume'});"}
				},
				#...,
				# Spec says AudioDelay is 52, but RX-V2400 actually accepts this command and sends report on 53.
				"AudioDelay" => { "Prefix" => "53" ,
				                  "Eval" => "val" ,
				                  "Up" => "\$yamaha{'AudioDelay'}++;
				                           \$yamaha{'AudioDelay'}
				                           = boundval(\$yamaha{'AudioDelay'},0,240);
				                           itoa(\$yamaha{'AudioDelay'},2);" ,
				                  "Down" => "\$yamaha{'AudioDelay'}--;
				                             \$yamaha{'AudioDelay'}
				                              = boundval(\$yamaha{'AudioDelay'},
				                                         0,
				                                         240);
				                             itoa(\$yamaha{'AudioDelay'},2);",
				                  "Adjust" => { "Eval" => "\$yamaha{'AudioDelay'}+=\$car;
				                                           \$yamaha{'AudioDelay'}
				                                            = boundval(\$yamaha{'AudioDelay'},
				                                                       0,
				                                                       240);
				                                           itoa(\$yamaha{'AudioDelay'},2);"},
				                  "Set" => { "Eval" => "\$yamaha{'AudioDelay'}=\$car;
				                                        itoa(\$yamaha{'AudioDelay'},2);"}
				}
			}
		},
		"Expect" => {
			"Operation" => {
				"Zone1Volume" => { "Eval" => "val" , "Up" => "" , "Down" => "" },
				"Zone1Mute" => { "ON" => "2301" , "OFF" => "2300" },
				"Zone1Input" => { "Eval" => "val" ,
				                  "PHONO" =>     "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"0\"" ,
				                  "CD" =>        "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"1\"" ,
				                  "TUNER" =>     "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"2\"" ,
				                  "CD-R" =>      "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"3\"" ,
				                  "MD/TAPE" =>   "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"4\"" ,
				                  "DVD" =>       "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"5\"" ,
				                  "D-TV/LD" =>   "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"6\"" ,
				                  "CABLE/SAT" => "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"7\"" ,
				                  "SAT" =>       "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"8\"" ,
				                  "VCR1" =>      "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"9\"" ,
				                  "VCR2/DVR" =>  "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"A\"" ,
				                  "VCR3" =>      "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"B\"" ,
				                  "V-AUX" =>     "\"21\".((\$yamaha{'6chInput'}eq'ON')?1:0).\"C\"" },
				"6chInput" => { "Eval" => "val" ,
				                "ON" =>  "211\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'InputEncode'}{\$yamaha{'Zone1Input'}}" ,
				                "OFF" => "210\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'InputEncode'}{\$yamaha{'Zone1Input'}}" },
				"InputMode" => { "Eval" => "val" ,
				                 "AUTO" => "" ,
				                 "DD/RF" => "" ,
				                 "DTS" => "" ,
				                 "DIGITAL" => "" ,
				                 "ANALOG" => "" ,
				                 "AAC" => "" },
#        "Zone2Volume" => { "Up" => "A" , "Down" => "B" },
#        "Zone2Mute" => { "ON" => "0" , "OFF" => "1" },
#        "Zone2Input" => {
#                          "PHONO" => "D0" ,
#                          "CD" => "D1" ,
#                          "TUNER" => "D2" ,
#                          "CD-R" => "D4" ,
#                          "MD/TAPE" => "CF" ,
#                          "DVD" => "CD" ,
#                          "D-TV/LD" => "D9" ,
#                          "CABLE/SAT" => "CC" ,
#                          "SAT" => "CB" ,
#                          "VCR1" => "D6" ,
#                          "VCR2/DVR" => "D7" ,
#                          "VCR3" => "CE" ,
#                          "V-AUX" => "D8" },
				"Power" => { "Eval" => "my \$z1 = ('ON'eq\$car)?1:0;
				                        my \$z2 = \$z1;
				                        my \$z3 = \$z1;
				                        '200'.eval(\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'ReportPowerEncode'})" },
				"Zone1Power" => { "Eval" => "my \$z1 = ('ON'eq\$car)?1:0;
				                             my \$z2 = ('ON'eq\$yamaha{'Zone2Power'})?1:0;
				                             my \$z3 = ('ON'eq\$yamaha{'Zone3Power'})?1:0;
				                             '200'.eval(\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'ReportPowerEncode'})" },
				"Zone2Power" => { "Eval" => "my \$z1 = ('ON'eq\$yamaha{'Zone1Power'})?1:0;
				                             my \$z2 = ('ON'eq\$car)?1:0;
				                             my \$z3 = ('ON'eq\$yamaha{'Zone3Power'})?1:0;
				                             '200'.eval(\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'ReportPowerEncode'})" },
				"Zone3Power" => { "Eval" => "my \$z1 = ('ON'eq\$yamaha{'Zone1Power'})?1:0;
				                             my \$z2 = ('ON'eq\$yamaha{'Zone2Power'})?1:0;
				                             my \$z3 = ('ON'eq\$car)?1:0;
				                             '200'.eval(\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'ReportPowerEncode'})" },
#        "Zone3Mute" => { "ON" => "2" , "OFF" => "6" },
#        "Zone3Volume" => { "Up" => "D" , "Down" => "E" },
#        "Zone3Input" => {
#                          "PHONO" => "1" ,
#                          "CD" => "2" ,
#                          "TUNER" => "3" ,
#                          "CD-R" => "5" ,
#                          "MD/TAPE" => "4" ,
#                          "DVD" => "C" ,
#                          "D-TV/LD" => "6" ,
#                          "CABLE/SAT" => "7" ,
#                          "SAT" => "8" ,
#                          "VCR1" => "9" ,
#                          "VCR2/DVR" => "A" ,
#                          "VCR3" => "B" ,
#                          "V-AUX" => "0" },
#        #...,
#        "TunerPreset" => {
#                           "Page" => { "A" => "0" , "B" => "1" , "C" => "2" , "D" => "3" , "E" => "4" } ,
#                           "Num" => { "1" => "5" , "2" => "6" , "3" => "7" , "4" => "8" , "5" => "9" , "6" => "A" , "7" => "B" , "8" => "C" } },
#        #...,
#        "SpeakerRelay" => {
#                            "A" => { "ON" => "B" , "OFF" => "C" } ,
#                            "B" => { "ON" => "D" , "OFF" => "E" } }
#      },
#      "System" =>
#      {
#        "Zone1Volume" => {
#                           "Eval" => "val" ,
#                           "Up" => "\$yamaha{'Zone1Volume'}++;
#                                    itoa(\$yamaha{'Zone1Volume'});" ,
#                           "Down" => "\$yamaha{'Zone1Volume'}++;
#                                      itoa(\$yamaha{'Zone1Volume'});",
#                           "Adjust" => { "Eval" => "\$yamaha{'Zone1Volume'}+=(\$car*2);
#                                                    itoa(\$yamaha{'Zone1Volume'});"},
#                           "Set" => { "Eval" => "\$yamaha{'Zone1Volume'}=(\$car*2+199);
#                                                 itoa(\$yamaha{'Zone1Volume'});"}
#        },
#        "Zone2Volume" => {
#                           "Eval" => "val" ,
#                           "Up" => "\$yamaha{'Zone2Volume'}++;
#                                    itoa(\$yamaha{'Zone2Volume'});" ,
#                           "Down" => "\$yamaha{'Zone2Volume'}++;
#                                      itoa(\$yamaha{'Zone2Volume'});",
#                           "Adjust" => { "Eval" => "\$yamaha{'Zone2Volume'}+=(\$car*2);
#                                                    itoa(\$yamaha{'Zone2Volume'});"},
#                           "Set" => { "Eval" => "\$yamaha{'Zone2Volume'}=(\$car*2+199);
#                                                 itoa(\$yamaha{'Zone2Volume'});"}
#        },
#        "Zone3Volume" => {
#                           "Eval" => "val" ,
#                           "Up" => "\$yamaha{'Zone3Volume'}++;
#                                    itoa(\$yamaha{'Zone3Volume'});" ,
#                           "Down" => "\$yamaha{'Zone3Volume'}++;
#                                      itoa(\$yamaha{'Zone3Volume'});",
#                           "Adjust" => { "Eval" => "\$yamaha{'Zone3Volume'}+=(\$car*2);
#                                                    itoa(\$yamaha{'Zone3Volume'});"},
#                           "Set" => { "Eval" => "\$yamaha{'Zone3Volume'}=(\$car*2+199);
#                                                 itoa(\$yamaha{'Zone3Volume'});"}
#        },
			}
		},
		"Report" => {
			"ControlType" => [ "serial" , "IR" , "panel" , "system" , "encoder" ],
			"GuardStatus" => ["No" , "System" , "Setting" ],
			"00" => {
				"Name" => "System",
				"00" => {
					"Message" => "OK",
					"Eval" => "\$yamaha{'System'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'};"
				},
				"01" => {
					"Message" => "Busy",
					"Eval" => "\$yamaha{'System'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'System'}{'Busy'};"
				},
				"02" => {
					"Message" => "Power Off",
					"Eval" => "\$yamaha{'System'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'};\$yamaha{'Power'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Power'}{'OFF'};"
				},
				"Eval" => "\$error .= \"ERROR: Invalid system status \$rcmd.\n\";"
			},
			"01" => {
				"Name" => "Warning",
				"00" => {
					"Message" => "Over current.",
					"Eval" => "\$error .= \"ERROR: SYSTEM WARNING: over current.\n\";"
				},
				"01" => {
					"Message" => "DC detect.",
					"Eval" => "\$error .= \"ERROR: SYSTEM WARNING: DC Detect.\n\";"
				},
				"02" => {
					"Message" => "Power trouble.",
					"Eval" => "\$error .= \"ERROR: SYSTEM WARNING: power trouble.\n\";"
				},
				"03" => {
					"Message" => "Over heat.",
					"Eval" => "\$error .= \"ERROR: SYSTEM WARNING: over heat.\n\";"
				},
				"Eval" => "\$error .= \"ERROR: SYSTEM WARNING \$rcmd.\n\";"
			},
#      "10" => "assert(14>atoi(\$rdat));\$yamaha{'Playback'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Playback'}[\$rdat];\$info .= \"Playback = \$yamaha{'Playback'}\n\";",
#      "11" => "assert(12>atoi(\$rdat));\$yamaha{'Fs'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Fs'}[\$rdat];\$info .= \"Fs = \$yamaha{'Fs'}\n\";",
#      "12" => "assert(3>atoi(\$rdat));\$yamaha{'EX/ES'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'EX/ES'}[\$rdat];\$info .= \"EX/ES = \$yamaha{'EX/ES'}\n\";",
#      "13" => "assert(2>atoi(\$rdat));\$yamaha{'Thr/Bypass'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[\$rdat];\$info .= \"Thr/Bypass = \$yamaha{'Thr/Bypass'}\n\";",
#      "14" => "assert(2>atoi(\$rdat));\$yamaha{'REDdts'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'REDdts'}[\$rdat];\$info .= \"REDdts = \$yamaha{'REDdts'}\n\";",
#      "15" => "assert(2>atoi(\$rdat));\$yamaha{'TunerTuned'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[\$rdat];\$info .= \"TunerTuned = \$yamaha{'TunerTuned'}\n\";",
#      "16" => "assert(2>atoi(\$rdat));\$yamaha{'Dts96/24'}=\$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[\$rdat];\$info .= \"Dts96/24 = \$yamaha{'Dts96/24'}\n\";",
			"20" => {
				"Name" => "Power",
				# Spec is wrong for this encoding.
				# Correct is as follows.  + = on
				# 123 #   123 #   123 #   123 #   123 #   123 #   123 #   123 #
				# --- 0   +++ 1   +-- 2   -++ 3   ++- 4   +-+ 5   -+- 6   --+ 7
				"Eval" => "\$rdat=atoi(\$rdat);
				           assert(8>\$rdat);
				           { lock \%yamaha; \$yamaha{'Power'} = \$rdat?1:0; }
				           \$info .= setZ1Power((((\$rdat%7)%3)+1)>>1);
				           \$info .= setZ2Power((6==\$rdat||4==\$rdat||3==\$rdat||1==\$rdat)?1:0);
				           \$info .= setZ3Power(\$rdat&1);"
			},
			"21" => {
				"Name" => "Zone1Input",
				"Eval" => "\$yamaha{'6chInput'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[atoi(substr(\$rdat,0,1))];
				           \$yamaha{'Zone1Input'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Input'}[atoi(substr(\$rdat,1,1))];
				           onscreenInfo('Input',\$yamaha{'Zone1Input'});
				           if ( defined(\$settings{\$yamaha{'Zone1Input'}}{'AudioDelay'}) ) {
				               decode('Control Operation AudioDelay Set '.
				                      \$settings{\$yamaha{'Zone1Input'}}{'AudioDelay'},
				                      (*STDOUT) ); }"
			},
#			"22" => { },
			"23" => {
				"Name" => "Zone1Mute",
				"Eval" => "\$yamaha{'Zone1Mute'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[atoi(\$rdat)]; onscreenInfo('Mute',\$yamaha{'Zone1Mute'});"
			},
			"24" => {
				"Name" => "Zone2Input",
				"Eval" => "\$yamaha{'Zone2Input'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'Input'}[atoi(\$rdat)];"
			},
			"25" => {
				"Name" => "Zone2Mute",
				"Eval" => "\$yamaha{'Zone2Mute'} = \$Spec{\$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[atoi(\$rdat)];"
			},
			"26" => {
				"Name" => "Master Volume",
				"Eval" => "\$yamaha{'Zone1Volume'} = atoi(\$rdat);
				           onscreenInfo('Volume',((\$yamaha{'Zone1Volume'}-199)/2).' dB');"
			},
			# ...,
			"53" => {
				"Name" => "Audio Delay",
				"Eval" => "\$yamaha{'AudioDelay'} = atoi(\$rdat);
				           print('Audio Delay: '.\$yamaha{'AudioDelay'}.' ms\n');"
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

my $PortName = "";
if ( $osname eq "MSWin32" ) { $PortName = "COM1"; }
elsif ( $osname eq "darwin" ) { $PortName = "/dev/cu.KeySerial1"; }
elsif ( $osname eq "linux" ) { $PortName = "/dev/ttyS0"; }
my $PortObj;

# SerialPort probably isn't threaded, so protect it with a single-function
# locking interface.
our @serialInput : shared;
our @serialOutput : shared;
our $serialComSemaphore : shared;
$serialComSemaphore = -2; # Init

sub serialThread
{
	my $cmd = shift;
	if ( ($cmd ne "setup")
	   &&($cmd ne "write")
	   &&($cmd ne "read")
	   &&($cmd ne "destroy") )
	{
		print STDERR "Invalid serialThread command.\n";
		return;
	}
	{
		dbglogprint ' lock $serialComSemaphore;'."\n";
		lock $serialComSemaphore;
		dbglogprint ' locked $serialComSemaphore;'."\n";
		dbglogprint ' unlocked $serialComSemaphore;'."\n";
		dbglogprint ' cond_wait $serialComSemaphore;'."\n";
		cond_wait($serialComSemaphore) until $serialComSemaphore == 0; # Idle
		dbglogprint ' locked $serialComSemaphore;'."\n";
		undef @serialInput;
		exit if ( defined($serialOutput[0]) && ($serialOutput[0] eq "destroyed") );
		dbglogprint ' didn\'t exit'."\n";
		@serialInput = ($cmd,shift);
		$serialComSemaphore = -1; # Thread
		cond_broadcast($serialComSemaphore);
		dbglogprint ' cond_broadcast $serialComSemaphore;'."\n";
		dbglogprint ' unlocked $serialComSemaphore;'."\n";
	}
	{
		dbglogprint ' lock $serialComSemaphore;'."\n";
		lock $serialComSemaphore;
		dbglogprint ' locked $serialComSemaphore;'."\n";
		dbglogprint ' unlocked $serialComSemaphore;'."\n";
		dbglogprint ' cond_wait $serialComSemaphore;'."\n";
		cond_wait($serialComSemaphore) until $serialComSemaphore == 1; # Function
		dbglogprint ' locked $serialComSemaphore;'."\n";
		my @output = @serialOutput;
		$serialComSemaphore = 0; # Idle
		cond_broadcast($serialComSemaphore);
		dbglogprint ' cond_broadcast $serialComSemaphore;'."\n";
		dbglogprint ' unlocked $serialComSemaphore;'."\n";
		return @output;
	}
}

async { # serial thread loop
	threads->detach();

	{
		lock $serialComSemaphore;
		dbglogprint ' locked $serialComSemaphore;'."\n";
		$serialComSemaphore = 0; # Idle
		cond_broadcast($serialComSemaphore);
		dbglogprint ' cond_broadcast $serialComSemaphore;'."\n";
		dbglogprint ' unlocked $serialComSemaphore;'."\n";
	}
	for (;;) # forever
	{
		lock $serialComSemaphore;
		dbglogprint ' locked $serialComSemaphore;'."\n";
		dbglogprint ' unlocked $serialComSemaphore;'."\n";
		dbglogprint ' cond_wait $serialComSemaphore;'."\n";
		cond_wait($serialComSemaphore) until $serialComSemaphore == -1; # Thread
		dbglogprint ' locked $serialComSemaphore;'."\n";
		undef @serialOutput;
		if ( $forwardReceiver ne "" )
		{
			# Eat all of our init actions talking to the receiver.
		}
		elsif ( $serialInput[0] eq "setup" )
		{
			setupSerialPort();
			$lastSend = time;
			$lastRecv = time;
		}
		elsif ( $serialInput[0] eq "write" )
		{
			dbglogprint "\$PortObj->write($serialInput[1]);\n";
			logprint "\$PortObj->write(".str2hex($serialInput[1]).");\n";
			$PortObj->write($serialInput[1]);
			$lastSend = time;
		}
		elsif ( $serialInput[0] eq "read" )
		{
			dbglogprint "\$PortObj->read($serialInput[1]);\n";
			@serialOutput = $PortObj->read($serialInput[1]);
			dbglogprint "$serialOutput[0] , $serialOutput[1]\n";
			logprint "($serialOutput[0] , ".str2hex($serialOutput[1]).") = \$PortObj->read()\n" if $serialOutput[0];
			$lastRecv = time if $serialOutput[0] != 0;
		}
		elsif ( $serialInput[0] eq "destroy" )
		{
			undef $PortObj;
			@serialOutput = ("destroyed");
		}
		$serialComSemaphore = 1; # Function
		cond_broadcast($serialComSemaphore);
		dbglogprint ' cond_broadcast $serialComSemaphore;'."\n";
		dbglogprint ' unlocked $serialComSemaphore;'."\n";
	}
};

my $info = "";
my $warning = "";
my $error = "";

my $lastCtrl = 0;

sub setupSerialPort # Only called from the serial thread loop.
{
	undef $PortObj;

	if ( $osname eq "MSWin32" )
	{
		$PortObj = new Win32::SerialPort ($PortName)
		       || die "Can't open $PortName: $^E\n";
	} else {
		$PortObj = new Device::SerialPort ($PortName)
		       || die "Can't open $PortName: $^E\n";
	}
	# Not sure if this works on Win32::SerialPort, so I'll
	# keep it out here until I find out it needs to move.
	# Make the buffer hot so we send our command when we send
	# it rather than waiting for a bus load of commands.
	select((select($PortObj->{'HANDLE'}), $|=1)[0]);

	$PortObj->user_msg("ON");
	$PortObj->databits(8);
	$PortObj->baudrate(9600);
	$PortObj->parity("none");
	$PortObj->handshake("none");
	$PortObj->parity_enable("F");
	$PortObj->stopbits(1);
	$PortObj->buffers(4096, 4096);
	$PortObj->dtr_active(1);
	$PortObj->rts_active(1);

	if ($PortObj->write_settings != 1)
	{
		logprint "sorry, couldn't setup serial port\n";
	}
}

sub rs232_read
{
	my $length = shift;
	my $count_in = 0;
	my $string_in = "";
	my $timeout = 0;

	#logprint "read $length\n";
	($count_in, $string_in) = serialThread("read",$length);

	if ( ($count_in < $length) && ($timeout < 5) )
	{
		$timeout++;
		sleep(1);

		#logprint "read $length - $count_in t$timeout\n";
		my ($ncount_in, $nstring_in) = serialThread("read",$length-$count_in);
		$count_in += $ncount_in;
		$string_in .= $nstring_in;
	}

	logprint "rs232_read: $count_in, ".str2hex($string_in)."\n" if ( $count_in );
	return ($count_in, $string_in);
}

sub rs232_flush
{
	logprint "Flushing rs232 read buffer.\n";
	my ($count_in, $string_in) = (275,"");
	while ( 275 == $count_in )
	{
		($count_in, $string_in) = serialThread("read",275);
		logprint "Got $count_in bytes back.\n";
	}
}

sub sendInit
{
	dbglogprint ' lock $inhibitReadReport;'."\n";
	lock $inhibitReadReport;
	dbglogprint " locked inhibitReadReport\n";
	logprint "Sending undocumented init...\n";
	serialThread("write","0000020100");
	rs232_flush();
	logprint "\n";
	dbglogprint " unlocked inhibitReadReport\n";
}

sub printStatus
{
	my ($out, $long) = @_;
	if ( !defined $out ) { logprint "Losing STDOUT timestamp control.\n"; $out = (*STDOUT); }
	if ( !defined $long ) { $long = 0; }

	print $out "== === Yamaha ";
	if ( $yamaha{'ModelID'} eq "R0161" ) { print $out "RX-V2400"; }
	else { print $out $yamaha{'ModelID'}; }
	print $out " Settings === ==\n";
	for my $i ( keys %{$Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}} )
	{
		if ( $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}{$i} eq $yamaha{'Power'})
		{
			print $out "Power: $i\n";
		}
	}
	for my $i ( keys %{$Spec{$yamaha{'ModelID'}}{'Configuration'}{'System'}} )
	{
		if ( $Spec{$yamaha{'ModelID'}}{'Configuration'}{'System'}{$i} eq $yamaha{'System'})
		{
			print $out "System: $i\n";
		}
	}
	print $out "          Zone 1    Zone 2    Zone 3\n";
	printf $out "Power     %-9s %-9s %s\n",$yamaha{'Zone1Power'},$yamaha{'Zone2Power'},$yamaha{'Zone3Power'};
	if ( $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}{"OFF"} ne $yamaha{'Power'})
	{
		printf $out "Input     %-9s %-9s %s\n",$yamaha{'Zone1Input'},$yamaha{'Zone2Input'},$yamaha{'Zone3Input'};
		printf $out "Volume    %-9s %-9s %s\n",($yamaha{'Zone1Volume'}-199)/2,($yamaha{'Zone2Volume'}-199)/2,($yamaha{'Zone3Volume'}-199)/2;
		printf $out "Mute      %-9s %-9s %s\n",$yamaha{'Zone1Mute'},$yamaha{'Zone2Mute'},$yamaha{'Zone3Mute'};

		if ( $long )
		{
			print $out "\n";
			printf $out "6chInput  %-9s %-9s %s\n",$yamaha{'6chInput'},"","";
			printf $out "Effect    %-9s %-9s %s\n",$yamaha{'Effect'},"","";
			printf $out "TunerPage %-9s %-9s %s\n",$yamaha{'TunerPage'},"","";
			printf $out "TunerNum  %-9s %-9s %s\n",$yamaha{'TunerNum'},"","";
			printf $out "NightMode %-9s %-9s %s\n",$yamaha{'NightMode'},"","";
			printf $out "Speaker A %-9s %-9s %s\n",$yamaha{'SpeakerA'},"","";
			printf $out "Speaker B %-9s %-9s %s\n",$yamaha{'SpeakerB'},"","";
		}
	}
	logprint "Restoring STDOUT timestamp control (if lost).\n";
}

my $dcnfail = 0;
sub sendReady # getConfiguration
{
	{
		dbglogprint ' lock $inhibitReadReport;'."\n";
		lock $inhibitReadReport;
		dbglogprint " locked inhibitReadReport\n";
		rs232_flush();
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		dbglogprint ' cond_wait $requireConfiguration;'."\n";
		cond_wait($requireConfiguration) until $requireConfiguration == 0;
		dbglogprint ' locked $requireConfiguration;'."\n";
		$requireConfiguration = 1;
		dbglogprint ' unlocked $requireConfiguration;'."\n";
		dbglogprint " unlocked inhibitReadReport\n";
	}

	logprint "Sending Ready command...\n";
	serialThread("write","000");

	# Wait for configuration read.
	my $failed = 0;
	{
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		dbglogprint ' cond_wait $requireConfiguration;'."\n";
		cond_wait($requireConfiguration) until $requireConfiguration != 1;
		dbglogprint ' locked $requireConfiguration;'."\n";
		if ( $requireConfiguration == -1 )
		{
			$failed = 1;
			$requireConfiguration = 0;
		}
		dbglogprint ' unlocked $requireConfiguration;'."\n";
	}
	if ( !$failed )
	{
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		dbglogprint ' cond_wait $requireConfiguration;'."\n";
		cond_wait($requireConfiguration) until $requireConfiguration != 2;
		dbglogprint ' locked $requireConfiguration;'."\n";
		if ( $requireConfiguration == -2 )
		{
			$failed = 1;
			$requireConfiguration = 0;
		}
		dbglogprint ' unlocked $requireConfiguration;'."\n";
	}
	if ( $failed )
	{
		if ( 4 < $dcnfail )
		{
			logprint "failing.\n" and exit;
		} elsif ( 0 != $dcnfail ) {
			logprint "sleeping... ";
			sleep 30;
		}
		$dcnfail++;
		#logprint "reloading serial interface.\n";
		#serialThread("setup");
		logprint "Trying ready command...\n";
		dbglogprint " unlocked inhibitReadReport\n";
		return sendReady();
	}
	$dcnfail = 0;
}

sub processReport
{
	my $report = shift;

	my $info = "";
	my $warning = "";
	my $error = "";

	logprint ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";

	my $pat = $STX."(.)(.)(..)(..)".$ETX;
	while ( $report =~ s/$pat// )
	{
		logprint "recvd $1 $2 $3 $4\n";
		if ( defined $yamaha{'ModelID'} )
		{
			logprint "From: $Spec{$yamaha{'ModelID'}}{'Report'}{'ControlType'}[$1]\n";
			logprint "Guard: $Spec{$yamaha{'ModelID'}}{'Report'}{'GuardStatus'}[$2]\n";
		}
		my $rcmd = $3;
		my $rdat = $4;
		logprint "rcmd $3 rdat $4\n";
		my $expected = 0;
		foreach my $i ( sort { $a <=> $b } keys %expect )
		{
			if ( $expect{$i} eq "$rcmd$rdat" )
			{
				$expected = 1;
				dbglogprint ' lock %expect;'."\n";
				lock %expect;
				dbglogprint " locked expect\n";
				# Clear unhandled prior expects.
				foreach my $j ( sort { $a <=> $b } keys %expect )
				{
					last if ( $i == $j );
					logprint "Expected report, $expect{$j}, was not found.\n";
					delete($expect{$j});
				}
				# Clear retry-stimulus, including ours.
				foreach my $j ( sort { $a <=> $b } keys %expectStimulus )
				{
					last if ( $i < $j );
					delete($expectStimulus{$j});
				}
				logprint "Found expected report, $expect{$i}.\n";
				delete($expect{$i});
				dbglogprint ' cond_broadcast %expect;'."\n";
				cond_broadcast(%expect);
				dbglogprint " unlocked expect\n";
				last;
			}
		}
		if ( !$expected )
		{
			logprint "Found unexpected report, $rcmd$rdat.\n";
		}
		if ( defined $yamaha{'ModelID'} )
		{
			if ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}) )
			{
				if ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{'Name'}) )
				{
					logprint "Name: ".$Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{'Name'}."\n";
				}
				if ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{$rdat}) )
				{
					if ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{$rdat}{'Message'}) )
					{
						logprint ": ".$Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{$rdat}{'Message'}."\n";
					}
					if ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{$rdat}{'Eval'}) )
					{
						my $cmd = $Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{$rdat}{'Eval'};
						logprint "eval $cmd\n";
						eval($cmd);
						writeStatusXML();
					}
				} elsif ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{'Eval'}) ) {
					logprint " (value: $rdat)\n";
					my $cmd = $Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}{'Eval'};
					logprint "eval $cmd\n";
					eval($cmd);
					writeStatusXML();
				} else {
					logprint "\n";
					logprint "eval $Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}\n";
					eval($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd});
					writeStatusXML();
				}
				if ( "" ne $error )
				{
					logprint "===================================\n";
					logprint "===  vv  !!!  ERRORS  !!!  vv   ===\n";
					logprint "===================================\n";
					logprint $error;
					logprint "===================================\n";
					logprint "===  ^^  !!!  ERRORS  !!!  ^^   ===\n";
					logprint "===================================\n";
				}
				if ( "" ne $warning )
				{
					logprint "\nWarnings:\n";
					logprint $warning;
					logprint "\n";
				}
				if ( "" ne $info )
				{
					logprint $info."\n";
				}
			}
		}
	}
	logprint "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n";
	return $report;
}

sub dataToPrint
{
	my $string = shift;
	$string =~ s/(.)/$1 /g;
	$string =~ s/$DC1/DC1/g;
	$string =~ s/$DC2/DC2/g;
	$string =~ s/$DC3/DC3/g;
	$string =~ s/$DC4/DC4/g;
	$string =~ s/$STX/STX/g;
	$string =~ s/$ETX/ETX/g;
	return $string;
}

sub readData
{
	dbglogprint ' lock $inhibitReadReport; # Not that we really inhibit ourselves, but it lets us finish.'."\n";
	lock $inhibitReadReport; # Not that we really inhibit ourselves, but it lets us finish.
	dbglogprint " locked inhibitReadReport\n";

	my ($count_read, $string_read) = rs232_read(1);
	if ( ($requireConfiguration==1) && !$count_read )
	{
		sleep 1;
		($count_read, $string_read) = rs232_read(1);
	}
	logprint "readData: $count_read, ".str2hex($string_read)."\n" if ($count_read);

	if ( ($requireConfiguration==1) )
	{
		if ( !($count_read && ($string_read =~ m/$DC2/)) )
		{
			if ( $count_read )
			{
				logprint "Received ".dataToPrint($string_read)."\n";
			}
			logprint "error: No DC2... ";
			logprint "DC2 is ".str2hex($DC2)."\n";
			dbglogprint ' lock $requireConfiguration;'."\n";
			lock $requireConfiguration;
			dbglogprint ' locked $requireConfiguration;'."\n";
			$requireConfiguration = -1;
			dbglogprint ' cond_signal $requireConfiguration;'."\n";
			cond_signal($requireConfiguration);
			dbglogprint ' unlocked $requireConfiguration;'."\n";
			return 1;
		} else {
			dbglogprint ' lock $requireConfiguration;'."\n";
			lock $requireConfiguration;
			dbglogprint ' locked $requireConfiguration;'."\n";
			$requireConfiguration = 2;
			dbglogprint ' cond_signal $requireConfiguration;'."\n";
			cond_signal($requireConfiguration);
			dbglogprint ' unlocked $requireConfiguration;'."\n";
		}
	}

	if ( $count_read )
	{
		if ( $string_read =~ m/$DC2/ )
		{
			return 1 + readConfiguration();
		}
		elsif ( $string_read =~ m/$STX/ )
		{
			return 1 + readReport();
		}
	} else {
		return 0;
	}
}

sub readReport
{
	#logprint "Reading report.\n";
	my ($count_read, $string_read) = rs232_read(7);

	$count_read++;
	$string_read = $STX.$string_read;

	my $data = $string_read;

	logprint "OK - Received $count_read byte response.\n";
	$string_read = dataToPrint $string_read;
	logprint "   - $string_read\n";

	if ( $count_read < 8 )
	{
		logprint "malformed report.  Only $count_read bytes.\n";
		exit;
	}
	if ( !($data =~ m/$ETX$/) )
	{
		logprint "malformed report.  Not ETX terminated.\n";
		exit;
	}

	$data = processReport($data);

	return $count_read - 1;
}

sub readConfiguration
{
	my $bytes_read = 0;

	my ($count_in, $response) = rs232_read(8);
	$bytes_read += $count_in;
	logprint "Got $count_in bytes, reading Configuration...\n";
	if ( $count_in < 8 )
	{
		logprint "error: Configuration too short. ($count_in of 8 bytes)\n" and exit;
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		$requireConfiguration = -2;
		dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
		cond_broadcast($requireConfiguration);
		dbglogprint ' unlocked $requireConfiguration;'."\n";
		return $bytes_read;
	}
	logprint " Received Configuration...\n";
	# 5B Model ID
	{
		dbglogprint ' lock %yamaha;'."\n";
		lock %yamaha;
		dbglogprint " locked yamaha\n";
		$response =~ s/(.....)//;
		$yamaha{'ModelID'} = $1;
		dbglogprint " unlocked yamaha\n";
	}
	logprint "  model ID: ".$yamaha{'ModelID'};
	if ( $yamaha{'ModelID'} eq "R0161" ) { logprint " (RX-V2400)"; }
	logprint "\n";
	# 1B Software Version
	$response =~ s/(.)//;
	logprint "  software version: $1\n";
	# 2B data length
	$response =~ s/(..)//;
	my $dataLength = $1;
	logprint "  data length: 0x".$dataLength;
	$dataLength = atoi($dataLength);
	logprint " ($dataLength)\n";
	# up to 256B data
	if ( $dataLength < 9 )
	{
		logprint "error: Data length less than minimum.\n";
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		$requireConfiguration = -2;
		dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
		cond_broadcast($requireConfiguration);
		dbglogprint ' unlocked $requireConfiguration;'."\n";
		return $bytes_read;
	}

	($count_in, $response) = rs232_read($dataLength);
	$bytes_read += $count_in;
	while ( $dataLength > $count_in )
	{
		logprint "warning: Ready response missing ".($dataLength - ($count_in - 12))." bytes.\n";
		my ($ncount_in, $nresponse) = rs232_read($dataLength-$count_in);
		$bytes_read += $ncount_in;
		$count_in += $ncount_in;
		$response .= $nresponse;
		if ( $ncount_in == 0 )
		{
			logprint "error: Couldn't read ready data.\n";
			dbglogprint ' lock $requireConfiguration;'."\n";
			lock $requireConfiguration;
			dbglogprint ' locked $requireConfiguration;'."\n";
			$requireConfiguration = -2;
			dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
			cond_broadcast($requireConfiguration);
			dbglogprint ' unlocked $requireConfiguration;'."\n";
			return $bytes_read;
		}
	}

	logprint "Got $count_in bytes, reading Configuration Data...\n";
	# Data 0 through 6 are "Don't care" per spec
	{
		dbglogprint ' lock %yamaha;'."\n";
		lock %yamaha;
		dbglogprint " locked yamaha\n";
		$yamaha{'System'} = substr($response,7,1);
		$yamaha{'Power'} = substr($response,8,1);
		dbglogprint " unlocked yamaha\n";
	}
	if ( defined($Spec{$yamaha{'ModelID'}}{'Configuration'}{'PowerDecode'}{$yamaha{'Power'}}) )
	{
		dbglogprint ' lock %yamaha;'."\n";
		lock %yamaha;
		dbglogprint " locked yamaha\n";
		eval($Spec{$yamaha{'ModelID'}}{'Configuration'}{'PowerDecode'}{$yamaha{'Power'}});
					logprint "-$yamaha{'Zone1Power'}-$yamaha{'Zone2Power'}-$yamaha{'Zone3Power'}-\n";
		dbglogprint " unlocked yamaha\n";
	} else {
		logprint "error: Power data is invalid.\n";
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		$requireConfiguration = -2;
		dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
		cond_broadcast($requireConfiguration);
		dbglogprint ' unlocked $requireConfiguration;'."\n";
		return $bytes_read;
	}

	# The zone power encoding is a defect in the RX-V2400 receiver, so just
	# save as ON or OFF.
	if ( $yamaha{'Power'} ne "0" ) { logprint ' lock %yamaha;'."\n" if $debug;lock %yamaha;logprint " locked yamaha\n" if $debug; $yamaha{'Power'} = 1;logprint " locked yamaha\n" if $debug; }

	if ( $yamaha{'System'} eq "0" )
	{
		if ( !$yamaha{'Power'} )
		{
			if ( $dataLength != 9 )
			{
				logprint "error: Data length greater than expected.\n";
				dbglogprint ' lock $requireConfiguration;'."\n";
				lock $requireConfiguration;
				dbglogprint ' locked $requireConfiguration;'."\n";
				$requireConfiguration = -2;
				dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
				cond_broadcast($requireConfiguration);
				dbglogprint ' unlocked $requireConfiguration;'."\n";
				return $bytes_read;
			}
		} else {
			if ( $dataLength != 138 )
			{
				logprint "error: Data length not as expected.\n";
				dbglogprint ' lock $requireConfiguration;'."\n";
				lock $requireConfiguration;
				dbglogprint ' locked $requireConfiguration;'."\n";
				$requireConfiguration = -2;
				dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
				cond_broadcast($requireConfiguration);
				dbglogprint ' unlocked $requireConfiguration;'."\n";
				return $bytes_read;
			}

			dbglogprint ' lock %yamaha;'."\n";
			lock %yamaha;
			dbglogprint " locked yamaha\n";
			$yamaha{'Zone1Input'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Input'}[hex(substr($response,9,1))];
			$yamaha{'6chInput'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,10,1)];
			$yamaha{'InputMode'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'InputMode'}[substr($response,11,1)];
			$yamaha{'Zone1Mute'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,12,1)];
			$yamaha{'Zone2Input'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Input'}[hex(substr($response,13,1))];
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
			# ...
			$yamaha{'AudioDelay'} = atoi(substr($response,78,2));
			# ...
			$yamaha{'Zone3Input'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Input'}[hex(substr($response,127,1))];
			$yamaha{'Zone3Mute'} = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[substr($response,128,1)];
			$yamaha{'Zone3Volume'} = atoi(substr($response,129,2));

			printStatus();
			writeStatusXML();
			dbglogprint " unlocked yamaha\n";
		}
	}
	logprint "  data: ";
	while ( $dataLength > 0 )
	{
		logprint substr($response,0,1);
		$response =~ s/.//;
		$dataLength--;
	}
	logprint "\n";
	($count_in, $response) = rs232_read(3);
	$bytes_read += $count_in;
	logprint "Got $count_in bytes, reading Checksum + ETX...\n";
	# 2B checksum
	my $checksum = substr($response,0,2);
	logprint "  checksum: 0x".$checksum;
	$checksum = atoi($checksum);
	logprint " ($checksum)\n";
	$response =~ s/..//;
	# ETX
	$response =~ s/(.)//;
	$_ = str2hex($1);
	if ( m/03/ ) { logprint " ETX\n"; }
	else
	{
		logprint "error: No ETX\n";
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		$requireConfiguration = -2;
		dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
		cond_broadcast($requireConfiguration);
		dbglogprint ' unlocked $requireConfiguration;'."\n";
		return $bytes_read;
	}
	logprint "\n";
	{
		dbglogprint ' lock $requireConfiguration;'."\n";
		lock $requireConfiguration;
		dbglogprint ' locked $requireConfiguration;'."\n";
		$requireConfiguration = 0;
		dbglogprint ' cond_broadcast $requireConfiguration;'."\n";
		cond_broadcast($requireConfiguration);
		dbglogprint ' unlocked $requireConfiguration;'."\n";
	}
	return $bytes_read;
}

sub stopNetworkServers
{
	{
		dbglogprint ' lock $stopNetworkServers;'."\n";
		lock $stopNetworkServers;
		dbglogprint " locked stopNetworkServers\n";
		$stopNetworkServers = 1;
		dbglogprint " unlocked stopNetworkServers\n";
	}

	while ( 1 )
	{
		{
			dbglogprint ' lock $runningNetworkServers;'."\n";
			lock $runningNetworkServers;
			dbglogprint " locked runningNetworkServers\n";
			if ( !$runningNetworkServers )
			{
				dbglogprint " unlocked runningNetworkServers\n";
				return;
			}
			dbglogprint " unlocked runningNetworkServers\n";
		}

		IO::Socket::INET->new("localhost:$PORT");
	}
}

sub sendControl # getReport
{
	my $inStr = shift;
	logprint "Sending Control $inStr\n";

	$_ = $inStr;
	if ( /^reload/i ) {
		stopNetworkServers();
		serialThread("destroy");
		exec( "\"$cmd\"" );
		exit;
	} elsif ( /^shutdown/i ) {
		stopNetworkServers();
		serialThread("destroy");
		exit;
	} elsif ( /^ready/i ) {
		logprint "Sending Ready...\n";
		sendReady();
		return "ok";
	}

	my $curCtrl = time;
	if ( $curCtrl > ($lastCtrl + 10) )
	{
#		logprint "Sending Ready...\n";
#		sendReady();
	}
	$lastCtrl = time;

	# Rules
	if ( ($yamaha{'Power'} ne $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}{'ON'})
	  &&!(($inStr =~ m/Power/))
	  &&!(($inStr =~ m/System/)) )
	{
		return "error: Only Power and System Control commands are valid when the power is off.\n($yamaha{'Power'} ne $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}{'ON'})\n";
	}
	my $timeout = 120;
	while ( ($timeout > 0) && $yamaha{'System'} ne $Spec{$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'} )
	{
		select(undef,undef,undef,0.5); # 500 millisecond sleep
		$timeout--;
	}
	if ( $yamaha{'System'} ne $Spec{$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'} )
	{
		return "error: No Control commands are allowed when the system status is not OK.  Status is currently $yamaha{'System'}.\n";
	}

	my $source = $Spec{$yamaha{'ModelID'}}{'Control'};
	my $cdr = $inStr;
	my $packet = "";
	my $packetTail = "";
	my $count = 0;
	my $waitForExpect = 0;
	while ( "" ne $cdr )
	{
		if ( $count > 100 ) { return "error: Internal search fault."; }
		$count++;
		if ( defined($source->{'Prefix'}) ) { $packet .= $source->{'Prefix'}; }
		if ( defined($source->{'Suffix'}) ) { $packetTail = $source->{'Suffix'}.$packetTail; }
		if ( defined($source->{'Expect'}) ) { $waitForExpect = $source->{'Expect'}; }
		logprint "cdr $cdr\n";
		$cdr =~ s/(\S+)\s*//;
		my $car = $1;
#		logprint "car $car cdr $cdr source source\n$packet $packetTail\n";
		if ( !defined($source->{$car}) &&
			( "" ne $cdr
			|| !defined($source->{'Eval'})
			|| "val" eq $source->{'Eval'} ) )
		{
			if ( "" ne $cdr ) { logprint "necdr\n"; }
			else { logprint "cdr |$cdr|\n"; }
			if ( !defined($source->{'Eval'}) ) { logprint "nedef\n"; }
			elsif ( "val" ne $source->{'Eval'} ) { logprint "seval $source->{'Eval'}\n"; }
			return "error: Couldn't understand '$car' in '$inStr'";
		}
		if ( "" ne $cdr )
		{
#			logprint "source $source\n";
#			logprint "source keys";
#			for $key ( keys %{$source} ) { logprint " ".$key; }
#			logprint "\n";
#			logprint "source->{$car} ".$source->{$car}."\n";
			$source = $source->{$car};
		} else {
#			logprint "source->{$car} $source->{$car}\n";
			if ( defined($source->{'Eval'}) )
			{
				if ( "val" eq $source->{'Eval'} )
				{
					dbglogprint ' lock %yamaha;'."\n";
					lock %yamaha;
					dbglogprint " locked yamaha\n";
					$packet = $packet.eval($source->{$car}).$packetTail;
					dbglogprint " unlocked yamaha\n";
				} else {
					dbglogprint ' lock %yamaha;'."\n";
					lock %yamaha;
					dbglogprint " locked yamaha\n";
					$packet = $packet.eval($source->{'Eval'}).$packetTail;
					dbglogprint " unlocked yamaha\n";
				}
			} else {
				$packet = $packet.$source->{$car}.$packetTail;
			}
		}
	}
	logprint "send $packet";

	my $expectReport;
	$source = $Spec{$yamaha{'ModelID'}}{'Expect'};
	$cdr = $inStr;
	$count = 0;
	while ( "" ne $cdr )
	{
		if ( $count > 100 ) { return "error: Internal search fault."; }
		$count++;
		logprint "cdr $cdr\n";
		$cdr =~ s/(\S+)\s*//;
		my $car = $1;
		if ( !defined($source->{$car}) &&
			( "" ne $cdr
			|| !defined($source->{'Eval'})
			|| "val" eq $source->{'Eval'} ) )
		{
			last;
		}
		if ( "" ne $cdr )
		{
			$source = $source->{$car};
		} else {
			if ( defined($source->{'Eval'}) )
			{
				if ( "val" eq $source->{'Eval'} )
				{
					$expectReport = eval($source->{$car});
				} else {
					logprint "-$yamaha{'Zone1Power'}-$yamaha{'Zone2Power'}-$yamaha{'Zone3Power'}-\n";
					logprint "expectReport = eval($source->{'Eval'});\n";
					$expectReport = eval($source->{'Eval'});
					logprint "expectReport = -$expectReport-\n";
				}
			} else {
				$expectReport = $source->{$car};
			}
		}
	}

	$curCtrl = time;
	if ( $curCtrl > ($lastCtrl + 10) )
	{
#		# also done at the top of this function, but included here in case our decode took a long time.
#		logprint "Sending Ready...\n";
#		sendReady();
	}

	my $myExpect;
	if ( defined($expectReport) )
	{
		logprint "expect $expectReport";
		dbglogprint ' lock %expect;'."\n";
		lock %expect;
		dbglogprint " locked expect\n";
		$expect{$nextExpectUID} = $expectReport;
		$expectStimulus{$nextExpectUID} = $packet;
		$myExpect = $nextExpectUID;
		$nextExpectUID++;
		dbglogprint " unlocked expect\n";
	}

	logprint "Sending Control $inStr...\n";
	serialThread("write",$packet);
	$lastCtrl = time;
	logprint "Sent.\n";

	if ( $waitForExpect && defined($expectReport))
	{
		logprint "Waiting for expect...\n";
		{
			logprint "expect $expectReport\n";
			dbglogprint ' lock %expect;'."\n";
			lock %expect;
			dbglogprint " locked expect\n";
			dbglogprint " cond_wait expect\n";
			while (defined($expect{$myExpect}))
			{
				cond_timedwait(%expect,time+1);
				if ($needSendReady && defined($expect{$myExpect}))
				{
					dbglogprint ' lock $needSendReady;'."\n";
					lock $needSendReady;
					dbglogprint ' locked $needSendReady;'."\n";
					sendReady();
					$needSendReady = 0;
					dbglogprint ' cond_broadcast $needSendReady;'."\n";
					cond_broadcast($needSendReady);
					dbglogprint ' unlocked $needSendReady;'."\n";
				}
			}
			dbglogprint " locked expect\n";
		}
		logprint "Done waiting.\n";
	}

	logprint "Return from sendControl.\n";
	return ""; #readReport();
}

sub sendControlToServer
{
	#TODO: unsorted commands may not be fair or desireable.
	my $inStr = shift;
	my $id;

	{
		dbglogprint ' lock $nextioUID;'."\n";
		lock $nextioUID;
		dbglogprint " locked nextioUID\n";
		$id = $nextioUID;
		$nextioUID++;
		dbglogprint " unlocked nextioUID\n";
	}
	{
		dbglogprint ' lock %output;'."\n";
		lock %output;
		dbglogprint " locked output\n";
		undef $output{$id};
		dbglogprint " unlocked output\n";
	}

	{
		dbglogprint ' lock %input;'."\n";
		lock %input;
		dbglogprint " locked input\n";
		$input{$id} = $inStr;
		cond_signal(%input);
		dbglogprint " cond_signal input\n";
		dbglogprint " unlocked input\n";
	}

	{
		dbglogprint ' lock %output;'."\n";
		lock %output;
		dbglogprint " locked output\n";
		dbglogprint " unlocked output\n";
		dbglogprint " cond_wait output\n";
		cond_wait(%output) until defined($output{$id});
		dbglogprint " locked output\n";
		dbglogprint " unlocked output\n";
		return $output{$id};
	}
}

sub writeStatusXML
{
	my $xmlfile = "$ENV{'HOME'}/Sites.private/rxv2400/ajax.xml";
	if (open(XML, ">$xmlfile"))
	{
		my $sp;
		for my $i ( keys %{$Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}} )
		{
			if ( $Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}{$i} eq $yamaha{'Power'})
			{
				$sp = $i;
			}
		}
		my $z1p = $yamaha{'Zone1Power'};
		my $z2p = $yamaha{'Zone2Power'};
		my $z3p = $yamaha{'Zone3Power'};
		my $z1v = ($yamaha{'Zone1Volume'}-199)/2;
		my $z2v = ($yamaha{'Zone2Volume'}-199)/2;
		my $z3v = ($yamaha{'Zone3Volume'}-199)/2;

		$sp = lc $sp; $sp =~ s/o/O/;
		$z1p = lc $z1p; $z1p =~ s/o/O/;
		$z2p = lc $z2p; $z2p =~ s/o/O/;
		$z3p = lc $z3p; $z3p =~ s/o/O/;
		$z1v .= ".0" unless $z1v =~ m/\.0/;
		$z2v .= ".0" unless $z2v =~ m/\.0/;
		$z3v .= ".0" unless $z3v =~ m/\.0/;

		print XML qq|<?xml version="1.0" encoding="ISO-8859-1"?>
<data>
	<SystemPower><Value>$sp</Value></SystemPower>
	<Zone1Power><Value>$z1p</Value></Zone1Power>
	<Zone1Volume><Value>$z1v</Value></Zone1Volume>
	<Zone1Input><Value>DVD</Value></Zone1Input>
	<Zone2Power><Value>$z2p</Value></Zone2Power>
	<Zone2Volume><Value>$z2v</Value></Zone2Volume>
	<Zone2Input><Value>DVD</Value></Zone2Input>
	<Zone3Power><Value>$z3p</Value></Zone3Power>
	<Zone3Volume><Value>$z3v</Value></Zone3Volume>
	<Zone3Input><Value>DVD</Value></Zone3Input>
</data>|;
		close(XML);
	}
}

my %directories = ();
$directories{'macros'} = "";
$directories{'settings'} = "";

sub initDirectory
{
	my $dirname = shift;
	if ( -e "$ENV{'HOME'}/.rxv2400_rxm" || ($starnix && -e "/etc/rxv2400_rxm") )
	{
		if ( ! -e "$ENV{'HOME'}/.rxv2400/$dirname" )
		{
			mkdir("$ENV{'HOME'}/.rxv2400");
			mkdir("$ENV{'HOME'}/.rxv2400/$dirname");
		} elsif ( ! -d "$ENV{'HOME'}/.rxv2400/$dirname" ) {
			logprint "error: ~/.rxv2400/$dirname not a $dirname directory.\n" and die;
		}
		$directories{$dirname} = "$ENV{'HOME'}/.rxv2400/$dirname";
	} else {
		$directories{$dirname} = "rxv2400data/$dirname";
		if ( ! -e $directories{$dirname} )
		{
			mkdir("rxv2400data");
			mkdir($directories{$dirname});
			if ( ! -d $directories{$dirname} )
			{
				logprint "warning: '$directories{$dirname}' $dirname directory could not be created.  Attempts to add or save $dirname may fail.\n";
			}
		} elsif ( ! -d $directories{$dirname} ) {
			$directories{$dirname} = ".";
		}
	}
}

initDirectory("macros");
initDirectory("settings");
%MacroLibrary = ();

sub writeMacroFile
{
	my $inFile = shift;

	if ( !($inFile =~ m/rxm$/) )
	{
		$inFile = "$directories{'macro'}/$inFile.rxm";
	}

	if (open(MYFILE, ">$inFile")) {
		dbglogprint ' lock %MacroLibrary;'."\n";
		lock %MacroLibrary;
		dbglogprint " locked MacroLibrary\n";
		for my $key ( keys %MacroLibrary )
		{
			print MYFILE "macro $key\n$MacroLibrary{$key}end\n\n";
		}
		close(MYFILE);
		dbglogprint " unlocked MacroLibrary\n";
	}
}

sub readMacroFile
{
	my $inFile = shift;

	if ( !($inFile =~ m/rxm$/) )
	{
		$inFile = "$directories{'macro'}/$inFile.rxm";
	}

	if (open(MYFILE, "$inFile")) {
		while (<MYFILE>)
		{
			s/#.*//;  # Remove comments
			next unless /\S/;       # blank line check

			s/\n//;
			s/\r//;
			s/^\s*//;

			if ( /^macro\s+(\S+)/i ) {
				my $macroName = $1;
				dbglogprint ' lock %MacroLibrary;'."\n";
				lock %MacroLibrary;
				dbglogprint " locked MacroLibrary\n";
				logprint "reading macro '$macroName'\n";
				$MacroLibrary{$macroName} = "";

				while (<MYFILE>)
				{
					s/#.*//;  # Remove comments
					next unless /\S/;       # blank line check
					last if /^end/;

					s/\n//;
					s/\r//;
					s/^\s*//;
					$MacroLibrary{$macroName} .= $_."\n";
				}
				dbglogprint " unlocked MacroLibrary\n";
			}
		}
		close(MYFILE);
	}
}

our %schedule : shared;

sub receiverIsON
{
	return ($Spec{$yamaha{'ModelID'}}{'Configuration'}{'Power'}{'ON'} eq $yamaha{'Power'});
}

sub receiverIsOK
{
	return ($Spec{$yamaha{'ModelID'}}{'Configuration'}{'System'}{'OK'} eq $yamaha{'System'});
}

sub decode
{
	my $inStr = shift;
	my $client = shift;
	$_ = $inStr;

	if ( /^Control/ || /^cstatus/ || /^status/ )
	{
		if ( $forwardReceiver ne "" )
		{
			my $telnet = new Net::Telnet('Host'=>$forwardReceiver, 'Port'=>$forwardReceiverPort);
			my $output = $telnet->get(); # Clear out the welcome text.
			$telnet->put("$_\nbye\n");
			$output = $telnet->get();
			print $client $output;
			$telnet->close();
		}
	} else {
		if ( $forwardOther ne "" )
		{
			my $telnet = new Net::Telnet('Host'=>$forwardOther, 'Port'=>$forwardOtherPort);
			my $output = $telnet->get(); # Clear out the welcome text.
			$telnet->put("$_\nbye\n");
			$output = $telnet->get();
			print $client $output;
			$telnet->close();
		}
	}
	if ( /^Control/ )
	{
		s/^Control\s*//;
		my $command = $_;
		#sendInit();
		logprint "receiver is not OK\n" unless ( receiverIsON() );
		sendControlToServer("ready") unless ( receiverIsON() );
		my $status = sendControlToServer($command);
		logprint $status."\n";
		if ( defined($client) && (!$client->error()) )
		{
			print $client $status."\n";
		}
	} elsif ( /^cstatus/i && defined($client) ) {
		sendControlToServer("ready");
		printStatus($client,1);
	} elsif ( /^status/i && defined($client) ) {
		printStatus($client,1);
	} elsif ( (/osascript/i) && ($osname eq 'darwin') ) {
		s/osascript\s*//;
		system qq~osascript -e $_~;
	} elsif ( /^play/i ) {
		s/play\s*//;
		if ( $osname eq 'MSWin32' )
		{
			# Fork since this will never close on it's own.
			# This will interrupt current audio.
			system("fork.pl \"f:\\Program Files\\Windows Media Player\\wmplayer.exe\" \"$_\"");
		} elsif ( $osname eq 'linux' ) {
			# Stop any previously run so we don't get mixed audio.
			system("killall shuffle.pl");
			system("killall mpg123");
			# Fork so this operation is untimed.
			system("shuffle.pl $_& > /dev/null") and system("./shuffle.pl $_& > /dev/null");
		} elsif ( $osname eq 'darwin' ) {
			system qq~osascript -e 'tell application "iTunes"' -e 'play $_' -e 'end tell'~;
		}
	} elsif ( /^sleep/i ) {
		logprint "$_\n";
		s/sleep\s*//;
		my $time = 0;
		if ( s/^(\d+)$// )
		{
			$time = $1;
			logprint "$time time\n";
		}
		if ( s/(\d+)d//i )
		{
			$time += 24 * 60 * 60 * $1;
			logprint "$1 days\n";
		}
		if ( s/(\d+)h//i )
		{
			$time += 60 * 60 * $1;
			logprint "$1 hours\n";
		}
		if ( s/(\d+)m//i )
		{
			$time += 60 * $1;
			logprint "$1 mins\n";
		}
		if ( s/(\d+)s//i )
		{
			$time += $1;
			logprint "$1 secs\n";
		}
		logprint "$time total\n";
		sleep $time;
	} elsif ( 0 && defined($client) && /^test/i ) {
#		$rcvd = 0;
#            $string_in = "";
#		while ( 20 > $rcvd )
#		{
#			($count_in, $string_i) = rs232_read(512);
#                $string_in .= $string_i;
#			if ( 0 != $count_in )
#			{
#				$rcvd++;
#				logprint "Got $count_in bytes back.\n";
#				#$string_in = "";
#				logprint "\n";
#                    $pat = $STX."(.)(.)(..)(..)".$ETX;
#                    while ( $string_in =~ s/$pat// )
#                    {
#                      print $client "recvd $1$2$3$4\n";
#                      print $client "From: $Spec{$yamaha{'ModelID'}}{'Report'}{'ControlType'}[$1]\n";
#                      print $client "Guard: $Spec{$yamaha{'ModelID'}}{'Report'}{'GuardStatus'}[$2]\n";
#                      my $rcmd = $3;
#                      my $rdat = $4;
#                      logprint "rcmd $3 rdat $4\n";
#                      if ( defined($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}) )
#                      {
#                        logprint "eval $Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd}\n";
#                        eval($Spec{$yamaha{'ModelID'}}{'Report'}{$rcmd});
#                        if ( "" ne $error )
#                        {
#                          logprint "===================================\n";
#                          logprint "===  vv  !!!  ERRORS  !!!  vv   ===\n";
#                          logprint "===================================\n";
#                          logprint $error;
#                          logprint "===================================\n";
#                          logprint "===  ^^  !!!  ERRORS  !!!  ^^   ===\n";
#                          logprint "===================================\n";
#                          $error = "";
#                        }
#                        if ( "" ne $warning )
#                        {
#                          logprint "\nWarnings:\n";
#                          logprint $warning;
#                          logprint "\n";
#                          $warning = "";
#                        }
#                        if ( "" ne $info )
#                        {
#                          logprint $info."\n";
#                          $info = "";
#                        }
#                      }
#                      $rdat = "";
#                    }
##					$string_in = dataToPrint $string_in;
##					$retMsg = "OK - Received $count_in byte response.";
##					$retMsg = $retMsg."\n  - $string_in";
##					#print $client $retMsg."\n";
##					$_ = "c:\\Documents and Settings\\Dave\\My Documents\\My Music\\Gershwin\\American Draft - Someone to Watch Over Me.mp3";
##					system("fork.pl \"c:\\Program Files\\Windows Media Player\\wmplayer.exe\" \"$_\"");
#			}
#		}
	} elsif ( /^macro\s+(\S+)/i && defined($client) ) {
		my $macroName = $1;
		{
			dbglogprint ' lock %MacroLibrary;'."\n";
			lock %MacroLibrary;
			dbglogprint " locked MacroLibrary\n";
			$MacroLibrary{$macroName} = "";
			dbglogprint " unlocked MacroLibrary\n";
		}

		print $client "Recording macro '$macroName'...\n";
		print $client "(use 'end' when finished)\n";

		while (<$client>)
		{
			next unless /\S/;       # blank line check
			last if /^end/;

			s/\n//;
			s/\r//;
			s/^\s*//;
			{
				dbglogprint ' lock %MacroLibrary;'."\n";
				lock %MacroLibrary;
				dbglogprint " locked MacroLibrary\n";
				$MacroLibrary{$macroName} .= $_."\n";
				dbglogprint " unlocked MacroLibrary\n";
			}
		}

		print $client "Recorded macro '$macroName' as follows:\n";
		print $client $MacroLibrary{$macroName}."\n[end of listing]\n";
		writeMacroFile("default");
	} elsif ( /^run\s+(\S+)/i ) {
		my $macroName = $1;
		my $macro = "";
		{
			dbglogprint ' lock %MacroLibrary;'."\n";
			lock %MacroLibrary;
			dbglogprint " locked MacroLibrary\n";
			if ( !defined($MacroLibrary{$macroName}) ) {
				if ( defined($client) )
				{
					print $client "error: Unknown macro '$macroName'\n";
				}
				return 0;
			}
			$macro = $MacroLibrary{$macroName};
			dbglogprint " unlocked MacroLibrary\n";
		}
		logprint "running macro '$macro'\n";
		while ( $macro =~ s/(.+?)\n// )
		{
			logprint "running cmd '$1'\n";
			decode($1,$client);
		}
		if ( defined($client) && (!$client->error()) )
		{
			print $client "Macro '$macroName' completed.\n";
		}
	} elsif ( /^write\s+(\S+)/i ) {
		dbglogprint ' lock %MacroLibrary;'."\n";
		lock %MacroLibrary;
		dbglogprint " locked MacroLibrary\n";
		writeMacroFile($1);
		dbglogprint " unlocked MacroLibrary\n";
	} elsif ( /^read\s+(\S+)/i ) {
		readMacroFile($1);
	} elsif ( /^clear\s+(\S+)/i ) {
		dbglogprint ' lock %MacroLibrary;'."\n";
		lock %MacroLibrary;
		dbglogprint " locked MacroLibrary\n";
		%MacroLibrary = ();
		dbglogprint " unlocked MacroLibrary\n";
	} elsif ( s/^(at\s+.*?)\sdo\s+//i ) {
		my $dotime = $1;
		addScheduled($dotime,$_,$client);
	} elsif ( /^schedule/i && defined($client) ) {
		printSchedule($client);
	} elsif ( s/^settings\s+//i ) {
		if ( s/^store\s+//i )
		{
			if ( s/^default audio delay for input$//i )
			{
				$settings{$yamaha{'Zone1Input'}}{'AudioDelay'} = $yamaha{'AudioDelay'};
			}
		}
	} elsif ( /^debug\s+([0-9])/i ) {
		$debug = $1;
		return (!defined($client));
	} elsif ( /^bye/i && defined($client) ) {
		print $client "Goodbye.\n";
		close $client;
		return 1;
	} elsif ( /^mem/i && defined($client) ) {
		print $client "Goodbye.\n";
		print $client 'our %input              '.(scalar keys %input)."\n";
		print $client 'our %output             '.(scalar keys %output)."\n";
		print $client 'our %expect             '.(scalar keys %expect)."\n";
		print $client 'our %expectStimulus     '.(scalar keys %expectStimulus)."\n";
		print $client 'our %serialInput        '.(scalar @serialInput)."\n";
		print $client 'our %serialOutput       '.(scalar @serialOutput)."\n";
		print $client 'our %schedule           '.(scalar keys %schedule)."\n";
	} elsif ( /^reload/i ) {
		if ( defined($client) )
		{ close $client; }
		{
			my $id;
			{
				dbglogprint ' lock $nextioUID;'."\n";
				lock $nextioUID;
				dbglogprint " locked nextioUID\n";
				$id = $nextioUID;
				$nextioUID++;
				dbglogprint " unlocked nextioUID\n";
			}
			dbglogprint ' lock %input;'."\n";
			lock %input;
			dbglogprint " locked input\n";
			$input{$id} = "reload";
			cond_signal(%input);
			dbglogprint " cond_signal input\n";
			dbglogprint " unlocked input\n";
		}
		exit;
	} elsif ( /^shutdown/i ) {
		if ( defined($client) )
		{ close $client; }
		close $client;
		{
			my $id;
			{
				dbglogprint ' lock $nextioUID;'."\n";
				lock $nextioUID;
				dbglogprint " locked nextioUID\n";
				$id = $nextioUID;
				$nextioUID++;
				dbglogprint " unlocked nextioUID\n";
			}
			dbglogprint ' lock %input;'."\n";
			lock %input;
			dbglogprint " locked input\n";
			$input{$id} = "shutdown";
			cond_signal(%input);
			dbglogprint " cond_signal input\n";
			dbglogprint " unlocked input\n";
		}
		exit;
	} elsif ( /^help/i && defined($client) ) {
		s/help\s*//;
		my $request = $_;

		my $modelID = "";
		{
			$modelID = $yamaha{'ModelID'};
		}
		my $source = $Spec{$modelID};
		my $cdr = $_;
		if ( "" eq $cdr )
		{
			print $client "\nWelcome to help.\n";
			print $client "Basic commands are:\n";
			print $client "  Control\n";
			if ( $osname eq "darwin" )
			{
				print $client "  osascript - execute osascript\n";
			}
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
			print $client "\nCommands that begin with \"$_\" have the following options:\n";
		}
		my $count = 0;
		while ( "" ne $cdr )
		{
			if ( $count > 100 ) { print $client "error: Internal search fault.\n"; $cdr = ""; return 0; }
			$count++;
			$cdr =~ s/(\S+)\s*//;
			my $car = $1;
			if ( !defined($source->{$car}) )
			{
				print $client "error: Couldn't understand '$car' in '$request'\n";
				$cdr = "";
				return 0;
			}
			if ( "" ne $cdr )
			{
				$source = $source->{$car};
			} else {
				my $options = 0;
				for my $key ( keys %{$source->{$car}} )
				{
					if ( "Prefix" ne $key && "Suffix" ne $key && "Eval" ne $key && "Expect" ne $key )
					{
						$options++;
						print $client "  ".$key;
						if ( ref($source->{$car}->{$key}) eq "HASH" ) { print $client "*"; }
						print $client "\n";
					}
				}
				if ( 0 == $options ) { print $client "  <none>\n"; }
			}
		}
	} elsif ( 0 && /^advinpmode/i && defined($client) ) {
		# Advanced Input Mode allows arrow keys & history
		my $advInpMode = 1;
		my $history = ("");
		my $x = -1;
		my $y = 0;
		my $buf;
		my @history = ();
		while ( 1 == $advInpMode && 2 != $client->recv($buf,1))
		{
			if ( $buf eq "z" ) { $advInpMode = 0; }
			$buf = ord($buf);
			print $client "got: $buf\n";
			next;
			next unless $buf eq "z";
			last;
			if ( $x == -1 ) { $history[0] .= $buf; }
			next unless /\S/;       # blank line check

			s/\n//;
			s/\r//;
			s/^\s*//;
			last if /^siminpmode/i;
			next if /^advinpmode/i; # Don't nest the handling.
			decode($_,$client);
		}
	} elsif ( /^siminpmode/i && defined($client) ) {
		# Keep it here so they can ensure without error.
	} else {
		if ( defined($client) && (!$client->error()) )
		{
			print $client "error: Couldn't understand command '$_'\n";
		}
	}
	if ( defined($client) && (!$client->error()) )
	{
		print $client "\n";
	}
	return (!defined($client));
}

serialThread("setup");

if ( $forwardReceiver eq "" )
{
	async { # Read data loop.
		threads->detach();
		my $readless = 0;
		for (;;) # forever
		{
			if ( !readData() )
			{
				if ( ($lastSend > $lastRecv) && (($lastSend+10) < time) && !$needSendReady)
				{
					logprint "Ten seconds of action without reaction.  Sending Ready command.\n";
					# After ten seconds of action without reaction we send a Ready command.
					async { # Don't block the read thread.
						threads->detach();
						my $letItBeMe = 0;
						{
							dbglogprint ' lock $needSendReady;'."\n";
							lock $needSendReady;
							dbglogprint ' locked $needSendReady;'."\n";
							if ( ! $needSendReady )
							{
								$letItBeMe = 1;
								$needSendReady = 1;
								dbglogprint ' unlocked $needSendReady;'."\n";
								dbglogprint ' cond_wait $needSendReady;'."\n";
								cond_wait($needSendReady) until $needSendReady == 0;
								dbglogprint ' locked $needSendReady;'."\n";
							}
							dbglogprint ' unlocked $needSendReady;'."\n";
						}
						# Resend unfulfilled commands.
						if ( $letItBeMe )
						{
							foreach my $i ( sort { $a <=> $b } keys %expectStimulus )
							{
								serialThread("write",$expectStimulus{$i});
							}
						}
					};
				}
				if ( $readless < 50 )
				{
					$readless++;
				}
				# Sleep a tenth of a second for every five $readless.
				select(undef,undef,undef,0.1*int($readless/5));
			} else {
				$readless = 0;
			}
		}
	};
}

sendInit();
#sendReady();
$needSendReady = 1;
#Test line:
#sendControl("Operation Zone1Power ON");

sub serviceClient
{
	my $id = shift;
	my $client = shift;

	# Welcome message
	print $client "RX-V2400 Server $version connection open.\n";
	{
		print $client "Accepting commands for $yamaha{'ModelID'}";
		if ( $yamaha{'ModelID'} eq "R0161" ) { print $client " (RX-V2400)"; }
	}
	print $client " device.\n";
	print $client "(type 'help' for documentation)\n";

	my $closed = 0; # connected() gives a warning if it isn't connected (weird)
	                # so we'll keep track of that ourselves as well.
	while ((!$closed) && (!$client->error()))
	{
		if ( defined($_ = <$client>) )
		{
			next unless /\S/;       # blank line check
			s/\n//;
			s/\r//;
			s/^\s*//;
			$closed = decode($_,$client);
		}
	}
}

our $nextScheduleIndex : shared;
$nextScheduleIndex = 1;
our $nextRun : shared;
$nextRun = -1;
our $activeScheduleSleeper : shared;
$activeScheduleSleeper = 0;

sub newScheduleSleeper
{
	my $seconds = shift;
	my $client = shift;
	async {
		threads->detach();

		my $num;
		if ( defined($client) && (!$client->error()) )
		{
			# We have passed our client all the way through to this strange
			# location not because we have even the slightest desire to make
			# use of it, but because this thread which was never made to know
			# of the client still must close it to avoid a non-terminating
			# connection.
			close $client;
		}
		dbglogprint ' { lock $activeScheduleSleeper; $activeScheduleSleeper++; $num = $activeScheduleSleeper; }'."\n";
		{ lock $activeScheduleSleeper; $activeScheduleSleeper++; $num = $activeScheduleSleeper; }
		dbglogprint " unlocked\n";
		if ( $seconds > 0 ) { sleep ($seconds); }
		{
			dbglogprint ' lock $activeScheduleSleeper;'."\n";
			lock $activeScheduleSleeper;
			dbglogprint " locked activeScheduleSleeper\n";
			if ( $num == $activeScheduleSleeper )
			{
				$num = 1;
				dbglogprint ' lock $nextRun;'."\n";
				lock $nextRun;
				dbglogprint " locked nextRun\n";
				$nextRun = -1;
				dbglogprint " unlocked nextRun\n";
			} else {
				$num = 0;
			}
			dbglogprint " unlocked activeScheduleSleeper\n";
		}
		if ( $num )
		{
			runSchedule();
		}
	};
}

sub runSchedule
{
	dbglogprint ' lock %schedule;'."\n";
	lock %schedule;
	dbglogprint " locked schedule\n";
	my $nextTime = -1;
	foreach my $id ( keys %schedule )
	{
		if ( $schedule{$id}{'nextRun'} <= time )
		{
			my $delete = 0;
			if ( $schedule{$id}{'repeat'} )
			{
				my $client;
				my ($timeToRun,$repeat) = decodeTime($schedule{$id}{'desc'},$client);
				$schedule{$id}{'nextRun'} = $timeToRun;
				if ( ($nextTime > $schedule{$id}{'nextRun'})
				   ||(-1 == $nextTime) )
				{
					$nextTime = $schedule{$id}{'nextRun'};
				}
			} else {
				$schedule{$id}{'nextRun'} += time; # Make sure we don't hit it before it is deleted..
				$delete = 1;
			}
			my $child = threads->new(\&serviceScheduled,$id,$delete);
			$child->detach();
		} else {
			if ( ($nextTime > $schedule{$id}{'nextRun'})
			   ||(-1 == $nextTime) )
			{
				$nextTime = $schedule{$id}{'nextRun'};
			}
		}
	}
	{
		dbglogprint ' lock $nextRun;'."\n";
		lock $nextRun;
		dbglogprint " locked nextRun\n";
		if ( (-1 != $nextTime) && ((-1 == $nextRun) || ($nextRun > $nextTime)) )
		{
				$nextRun = $nextTime;
				newScheduleSleeper($nextRun-time);
		}
		dbglogprint " unlocked nextRun\n";
	}
	dbglogprint " unlocked schedule\n";
}

sub printSchedule
{
	my $client = shift;
	foreach my $id ( sort { $a <=> $b } keys %schedule )
	{
		print $client "$id.\t$schedule{$id}{'command'}\n"
		              . "\tNext run: ".localtime($schedule{$id}{'nextRun'})."\n";
		if ( defined($schedule{$id}{'desc'}) )
		{
			print $client "\t$schedule{$id}{'desc'}\n";
		}
	}
}

sub decodeTime
{
	my $dotime = shift;
	my $client = shift;
	my $dosleep = -1;
	my $repeat = 0;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;

	if ( $dotime =~ s/^(..) every\s/$1 /i )
	{
		$repeat = 1;
	}

	if ( $dotime =~ s/^at\s//i )
	{
		if ( $dotime =~ m/^(\d{1,2}):(\d{1,2})\s*$/ )
		{
			$sec += 1; # Prevent time being right now.
			# Assume 24 hour time.
			my ($dohour,$domin) = ($1,$2);
			$dohour = ($dohour-$hour);
			$domin = ($domin-$min);
			$dosleep = (((($dohour*60)+$domin)*60)-$sec)%(60*60*24);
			$dosleep += 1; # For $sec tweak above.
			my @timeinfo = localtime(time+$dosleep);
			if ( ($isdst != $timeinfo[8]) && ($dohour >= 2) )
			{
				if ( $isdst )
				{
					$dosleep += (60*60);
				} else {
					$dosleep -= (60*60);
				}
			}
		} else {
			if ( defined($client) && (!$client->error()) )
			{
				print $client "error: Couldn't understand time format '$dotime'\n";
			}
		}
	}
	elsif ( $dotime =~ s/^in\s//i )
	{
		if ( 0 )
		{
		} else {
			if ( defined($client) && (!$client->error()) )
			{
				print $client "error: Couldn't understand time format '$dotime'\n";
			}
		}
	}
	return(time+$dosleep,$repeat);
}

sub addScheduled
{
	my $desc = shift;
	my $command = shift;
	my $client = shift;

	$desc =~ s/\s+/ /g;
	$command =~ s/\s+/ /g;
	$command =~ s/\s+$//;

	my ($timeToRun,$repeat) = decodeTime($desc,$client);
	print $client "Will run in ";
	print $client ($timeToRun-time)." seconds";
	print $client " repeating ";
	print $client "$repeat\n";

	{
		dbglogprint ' lock %schedule;'."\n";
		lock %schedule;
		dbglogprint " locked schedule\n";
		dbglogprint ' lock $nextScheduleIndex;'."\n";
		lock $nextScheduleIndex;
		dbglogprint " locked nextScheduleIndex\n";
		my $myindex = $nextScheduleIndex;
		share($schedule{$myindex});
		$schedule{$myindex} = &share( {} );
		$schedule{$myindex}{'nextRun'} = $timeToRun;
		$schedule{$myindex}{'repeat'} = $repeat;
		share($schedule{$myindex}{'command'});
		$schedule{$myindex}{'command'} = $command;
		$schedule{$myindex}{'desc'} = $desc;
		$nextScheduleIndex++;
		dbglogprint " unlocked schedule\n";
		dbglogprint " unlocked nextScheduleIndex\n";
	}
	{
		dbglogprint ' lock $nextRun;'."\n";
		lock $nextRun;
		dbglogprint " locked nextRun\n";
		if ( (-1 == $nextRun) || ($nextRun > $timeToRun) )
		{
			$nextRun = $timeToRun;
			newScheduleSleeper($nextRun-time,$client);
		}
		dbglogprint " unlocked nextRun\n";
	}
}

sub serviceScheduled
{
	my $id = shift;
	my $delete = shift;
	my $client;
	my $command = $schedule{$id}{'command'};
	if ((!decode($command,$client)) || $delete)
	{
		dbglogprint ' lock %schedule;'."\n";
		lock %schedule;
		dbglogprint " locked schedule\n";
		# Just in case there's a race on delete...
		if ( defined($schedule{$id}) )
		{
			delete($schedule{$id});
		}
		dbglogprint " unlocked schedule\n";
	}
}

#sub listenOnServer
#{
#	my $server = shift;
#
#	$client = $server->accept();
#
#	{
#		lock($server);
#		cond_signal($server);
#	}
#
#	serviceClient(1, $client);
#}

sub startNetworkServer
{
	my $server = IO::Socket::INET->new( Proto     => 'tcp',
	                                    LocalPort => $PORT,
	                                    Listen    => SOMAXCONN,
	                                    Reuse     => 1);

	die "sorry, couldn't setup server" unless $server;
	{
		dbglogprint ' lock $runningNetworkServers;'."\n";
		lock $runningNetworkServers;
		dbglogprint " locked runningNetworkServers\n";
		$runningNetworkServers++;
		print "[RXV-Server $version ($runningNetworkServers) waiting for commands on port $PORT]\n";
		dbglogprint " unlocked runningNetworkServers\n";
	}

	while ( !$server->error() ) # Returns -1 when socket is closed.
	{
		if ( my $client = $server->accept() )
		{
			$client->autoflush(1);
			dbglogprint ' lock $stopNetworkServers;'."\n";
			lock $stopNetworkServers;
			dbglogprint " locked stopNetworkServers\n";
			if ( $stopNetworkServers )
			{
				close $client;
				close $server;
				dbglogprint ' lock $runningNetworkServers;'."\n";
				lock $runningNetworkServers;
				dbglogprint " locked runningNetworkServers\n";
				$runningNetworkServers--;
				dbglogprint " unlocked runningNetworkServers\n";
			} else {
				my $child = threads->new(\&serviceClient,1, $client);
				close $client;
				$child->detach();
			}
			dbglogprint " unlocked stopNetworkServers\n";
		}
	}
}


if ( -e "$ENV{'HOME'}/.rxv2400_rxm" ) {
	readMacroFile("$ENV{'HOME'}/.rxv2400_rxm");
} elsif ( $starnix && -e "/etc/rxv2400_rxm" ) {
	readMacroFile("/etc/rxv2400_rxm");
} elsif ( -d "macro" && -e "macro/default.rxm" ) {
	readMacroFile("macro/default.rxm");
} elsif ( -e "default.rxm" ) {
	readMacroFile("default.rxm");
}

while ( $numServersToRun )
{
	my $child = threads->new(\&startNetworkServer);
	$numServersToRun--;
	$child->detach();
}

for (;;) # forever
{
	dbglogprint 'check $needSendReady;'."\n";
	if ( $needSendReady )
	{
		dbglogprint ' lock $needSendReady;'."\n";
		lock $needSendReady;
		dbglogprint ' locked $needSendReady;'."\n";
		sendReady();
		$needSendReady = 0;
		dbglogprint ' cond_broadcast $needSendReady;'."\n";
		cond_broadcast($needSendReady);
		dbglogprint ' unlocked $needSendReady;'."\n";
	}

	{
		dbglogprint ' lock %input;'."\n";
		lock %input;
		dbglogprint " locked input\n";

		dbglogprint " unlocked input\n";
		dbglogprint " cond_wait input\n";
		cond_wait(%input) until int(keys %input);
		dbglogprint " locked input\n";
		dbglogprint " unlocked input\n";
	}

	for my $id ( keys %input )
	{
		if ( defined($input{$id}) )
		{
			my $result = sendControl($input{$id});
			{
				dbglogprint ' lock %input;'."\n";
				lock %input;
				dbglogprint " locked input\n";
				undef($input{$id});
				delete($input{$id});
				dbglogprint " unlocked input\n";
			}
			{
				dbglogprint ' lock %output;'."\n";
				lock %output;
				dbglogprint " locked output\n";
				$output{$id} = $result;
				cond_broadcast(%output);
				dbglogprint " unlocked output\n";
			}
		}
	}
}
#close the port - when the server is shut down
serialThread("destroy");


sub setZ1Power
{
	my $inVal = shift()?1:0;
	my $val = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[$inVal];
	if ( $yamaha{'Zone1Power'} eq $val ) { return ""; }
	{
		dbglogprint ' lock %yamaha;'."\n";
		lock %yamaha;
		dbglogprint " locked yamaha\n";
		$yamaha{'Zone1Power'} = $val;
		dbglogprint " unlocked yamaha\n";
	}
	my $msg = "Zone1Power turned $val.\n";
	if ( "ON" eq $val )
	{
	    $msg .= "Input: $yamaha{'Zone1Input'}  Volume: $yamaha{'Zone1Volume'}  Mute: $yamaha{'Zone1Mute'}\n";
	}
	writeStatusXML();
	return $msg;
}

sub setZ2Power
{
	my $inVal = shift()?1:0;
	my $val = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[$inVal];
	if ( $yamaha{'Zone2Power'} eq $val ) { return ""; }
	{
		dbglogprint ' lock %yamaha;'."\n";
		lock %yamaha;
		dbglogprint " locked yamaha\n";
		$yamaha{'Zone2Power'} = $val;
		dbglogprint " unlocked yamaha\n";
	}
	my $msg = "Zone2Power turned $val.\n";
	if ( "ON" eq $val )
	{
	    $msg .= "Input: $yamaha{'Zone2Input'}  Volume: $yamaha{'Zone2Volume'}  Mute: $yamaha{'Zone2Mute'}\n";
	}
	writeStatusXML();
	return $msg;
}

sub setZ3Power
{
	my $inVal = shift()?1:0;
	my $val = $Spec{$yamaha{'ModelID'}}{'Configuration'}{'OffOn'}[$inVal];
	if ( $yamaha{'Zone3Power'} eq $val ) { return ""; }
	{
		dbglogprint ' lock %yamaha;'."\n";
		lock %yamaha;
		dbglogprint " locked yamaha\n";
		$yamaha{'Zone3Power'} = $val;
		dbglogprint " unlocked yamaha\n";
	}
	my $msg = "Zone3Power turned $val.\n";
	if ( "ON" eq $val )
	{
	    $msg .= "Input: $yamaha{'Zone3Input'}  Volume: $yamaha{'Zone3Volume'}  Mute: $yamaha{'Zone3Mute'}\n";
	}
	writeStatusXML();
	return $msg;
}

sub atoi
{
	my $inStr = shift;
	my $retVal = 0;
	while ( $inStr =~ s/(.)// )
	{
		my $char = $1;
		$retVal <<= 4;
		my $num = ord($char);
		if ( $num >= 0x30 && $num <= 0x39 ) { $retVal += ($num - 0x30); }
		elsif ( $num >= 0x41 && $num <= 0x46 ) { $retVal += (10 + $num - 0x41); }
		else { logprint "atoi error at $char ($num) $retVal $inStr\n" and exit; }
	}
	return $retVal;
}

sub boundval
{
	my ($val,$low,$high) = @_;
	$val = $low if ( $val < $low );
	$val = $high if ( $val > $high );
	return $val;
}

sub itoa
{
	my ($inNum, $charCountOut) = @_;
	my $retVal = "";
	while ( $inNum > 0 )
	{
		my $char = $inNum % 16;
		$inNum >>= 4;
		if ( $char < 10 ) { $char += 0x30; }
		else { $char += (0x41-10); }
		$retVal = chr($char).$retVal;
	}
	if ( defined $charCountOut )
	{
		until ( $retVal =~ m/.{$charCountOut}/ )
		{
			$retVal = "0$retVal";
		}
	}
	return $retVal;
}

# Convert a string into hex for easier viewing by people.
sub str2hex
{
	my $line = shift;
	$line =~ s/(.)/sprintf("%02x ",ord($1))/eg;
	return $line;
}

# $string = hex2str ( $hexstring );
# Where string is of the form "xx xx xx xx" where x is 0-9a-f
# hex numbers are limited to 8 bits.
sub hex2str
{
	my $l = shift;
	$l =~ s/([0-9a-f]{1,2})\s*/sprintf("%c",hex($1))/egi;
	return $l;
}

