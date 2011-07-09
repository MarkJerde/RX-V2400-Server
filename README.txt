=== Contents ===
1. Introduction
2. Documentation
3. Enhancement
================

=== Introduction ===

RX-V2400 Server
Control software for certain Yamaha A/V receivers.
This is independently developed software with no relation to Yamaha.

Copyright 2006-2011 Mark Jerde

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=== Documentation ===

No documentation yet.  Sorry.
Runs on Windows, Linux, and Mac OS.  No recent testing has been done on Windows or Linux.
Roughly put.. you need to be able to run Perl programs, and you need a serial connection between your computer and the receiver.
* rxv2400server.pl is the main program.
* webControl contains the web elements, but you'll need a webserver with php support for this.

=== Enhancement ===
Yamaha has some pdf files floating around on the internet that document the serial control commands.  You'd need these to make it work with a different model.  First, because it might be good to make sure the command numbers are all the same; but more that the model ID is hard-coded in the code so it doesn't make a mess by sending incorrect instructions to a different model receiver.  There are two files per receiver, "standard" and "extended".  Neither is a subset of the other.  Here's one that I managed to track down to give you a start tracking down the others.
http://www.yamahapab.com/assets/downloads/codes/RX-V2400_RS232C_Standard.pdf

