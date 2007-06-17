#!/usr/bin/perl -w

my @files;

while ( defined($_ = shift) )
{
	if ( m/\.mp3$/ )
	{
		push(@files,$_);
	} elsif ( -d $_ ) {
		@files = (@files,split(/\n/,`find $_ -name *.mp3`));
	}
}

while ( @files > 0 )
{
	$current = int(rand(@files));
	system("mpg123 \"$files[$current]\"");
	splice(@files,$current,1);
}

