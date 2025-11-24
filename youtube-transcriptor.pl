#!/usr/bin/env perl

# ================================================================ PRAGMAS

use feature qw(say);
use Term::ANSIColor qw(:constants);

# ================================================================ VARIABLES

my $time = time();
my $file = $time.q(.en.srt);
my $ytsrt=qq(yt-dlp --write-auto-subs --skip-download -o "${time}" --sub-langs en --sub-format srt);

# ================================================================ INIT

unless ( $ARGV[0] )
{
	say q(> ), RED 'Need a YouTube video link!', RESET '';
	exit 1;
}

my $cmd = "${ytsrt} " . $ARGV[0];
say q(> ), YELLOW $cmd, RESET '';
system $cmd;

open my $fh, "<", $file or do {
	say q(> ), RED "File open fail bail!", RESET '';
	exit 1;
};

say q(> ), YELLOW qq(Opening: ${file}), RESET '';

my $text = join '', <$fh>;

$text =~ s~(?xm)
	(?:
		^\d+$
		|
		^(\d+:\d+:\d+),\d+\s+-->\s(?1),\d+
	)$
		|
		^$
		|
		\n+
~ ~g;

$text =~ s~\s{2,}~ ~g;

close $fh;
unlink( $file );
say q(> ), YELLOW qq(Removing: ${file}), RESET '';

open $fh, '>', "${time}.txt" or do {
	say q(> ), RED "File open fail bail!", RESET '';
	exit 1;
};

say $fh $text;
say q(> ), YELLOW qq(Saving: ${time}.txt), RESET '';
close $fh;

# ================================================================ END

__END__
