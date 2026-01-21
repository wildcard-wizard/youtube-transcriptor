#!/usr/bin/env perl

# Setup script for YouTube Transcriptor
# Creates symlink in /usr/local/bin for system-wide access

use v5.14;
use warnings;

use FindBin qw($RealBin);
use Term::ANSIColor qw(:constants);

# ================================================================ VARIABLES

$|++;

my $script_path = "${RealBin}/youtube-transcriptor.pl";
my $link_path   = '/usr/local/bin/youtube-transcriptor';

# ================================================================ INIT

say q(> ), CYAN 'YouTube Transcriptor Setup', RESET '';

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Check if script exists
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

unless (-e $script_path)
{
    say q(> ), RED "Cannot find ${script_path}", RESET '';
    exit 1;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Make script executable
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

my $chmod_result = chmod 0755, $script_path;

if ($chmod_result == 1)
{
    say q(> ), GREEN "Made executable: ${script_path}", RESET '';
}
else
{
    say q(> ), RED "Failed to chmod: ${script_path}", RESET '';
    exit 1;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Remove existing symlink if present
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if (-l $link_path)
{
    unlink $link_path;
    say q(> ), YELLOW "Removed old symlink: ${link_path}", RESET '';
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create symlink (needs sudo)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

my $cmd = "sudo ln -s '${script_path}' '${link_path}'";
say q(> ), YELLOW $cmd, RESET '';

system($cmd) == 0 or do
{
    say q(> ), RED 'Symlink creation failed!', RESET '';
    exit 1;
};

say q(> ), GREEN "Created symlink: ${link_path}", RESET '';
say q(> ), GREEN 'All done! Run with: youtube-transcriptor <url>', RESET '';

# ================================================================ END

__END__
