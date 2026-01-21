#!/usr/bin/env perl

# YouTube Transcriptor with AI-powered filename generation
# Downloads YouTube auto-subs, cleans them up, and names the file intelligently

# ================================================================ PRAGMAS

use v5.14;
use warnings;

use Cwd qw(getcwd);
use FindBin qw($RealBin);
use Term::ANSIColor qw(:constants);

# Load local Ollama module from pm/ directory
use lib $RealBin.'/pm/';
use Ollama;

# ================================================================ VARIABLES

$|++;

# Epoch timestamp for collision avoidance
my $epoch = time();

# Temp file for yt-dlp output (will be deleted after processing)
my $temp_srt = $epoch.q(.en.srt);

# Output directory is wherever the user is running from
my $out_dir = getcwd();

# yt-dlp command to grab auto-generated English subtitles
my $ytsrt = qq(yt-dlp --write-auto-subs --skip-download -o "${epoch}" --sub-langs en --sub-format srt);

# AI filename prompt - tells the model exactly what we want
my $ai_prompt = <<'EOF';
You are a filename generator. Read the transcript below and output a single filename.

FORMAT: lowercase-words-with-dashes.txt
OUTPUT: filename only - no quotes, no explanation, must end with .txt
RULES: Be descriptive but concise (3-6 words ideal), capture the main topic

EXAMPLE INPUTS/OUTPUTS:
- Video about Bitcoin price analysis → bitcoin-price-analysis.txt
- Discussion of Federal Reserve policy → fed-monetary-policy-analysis.txt
- Tutorial on Linux commands → linux-command-tutorial.txt

TRANSCRIPT:
EOF

# ================================================================ INIT

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Check for YouTube URL argument
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

unless ($ARGV[0])
{
    say q(> ), RED 'Need a YouTube video link!', RESET '';
    exit 1;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Initialize Ollama client
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

my $ai = Ollama->new(
    model       => 'ministral-3:14b-instruct-2512-q8_0',
    temperature => 0.7,
    max_tokens  => 100,
    timeout     => 120,
);

# ================================================================ DOWNLOAD

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Grab subtitles via yt-dlp
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

my $url = $ARGV[0];
my $cmd = qq(${ytsrt} '${url}');
say q(> ), YELLOW $cmd, RESET '';
system $cmd;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Open and read the SRT file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

open my $fh, '<', $temp_srt or do
{
    say q(> ), RED 'File open fail bail!', RESET '';
    exit 1;
};

say q(> ), YELLOW qq(Opening: ${temp_srt}), RESET '';
my $text = join '', <$fh>;
close $fh;

# ================================================================ CLEANUP

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Strip SRT formatting cruft
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Remove sequence numbers, timestamps, and collapse whitespace
$text =~ s~(?xm)
    (?:
        ^\d+$                                    # Sequence numbers
        |
        ^(\d+:\d+:\d+),\d+\s+-->\s(?1),\d+      # Timestamp lines
    )$
        |
        ^$                                       # Blank lines
        |
        \n+                                      # Multiple newlines
~ ~g;

# Collapse multiple spaces into single space
$text =~ s~\s{2,}~ ~g;

# Clean up leading/trailing whitespace
$text =~ s~^\s+|\s+$~~g;

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Remove temp SRT file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

unlink($temp_srt);
say q(> ), YELLOW qq(Removing: ${temp_srt}), RESET '';

# ================================================================ AI NAMING

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Extract first ~1000 chars for AI
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Grab enough text to understand the content, cut at a word boundary
my $sample = $text =~ s~^(.{1,1000}[[:alnum:]\ ,-:]+\.).*$~$1~sgr;

# Build the query for Ollama
my $query = $ai_prompt . $sample;

say q(> ), CYAN 'Asking AI for filename...', RESET '';

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Get filename from Ollama
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

my $result = $ai->prompt($query);

unless ($result->{success})
{
    say q(> ), RED 'AI request failed, using fallback name', RESET '';
    $result->{text} = 'transcript.txt';
}

# Clean up AI response - strip whitespace and newlines
my $pretty_name = $result->{text} =~ s~^\s+|\n|\s+$~~gr;

# Make sure it ends with .txt
$pretty_name .= '.txt' unless $pretty_name =~ m~\.txt$~;

# Sanitize - only allow lowercase, dashes, dots
$pretty_name = lc($pretty_name) =~ s~[^a-z0-9\-\.]~-~gr;

# Remove duplicate dashes
$pretty_name =~ s~-{2,}~-~g;

say q(> ), GREEN qq(AI suggested: ${pretty_name}), RESET '';

# ================================================================ SAVE

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Build final filename with epoch prefix
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

my $final_name = "${epoch}-${pretty_name}";
my $final_path = "${out_dir}/${final_name}";

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Write transcript to file
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

open $fh, '>', $final_path or do
{
    say q(> ), RED "Cannot write to ${final_path}", RESET '';
    exit 1;
};

print $fh $text;
close $fh;

say q(> ), GREEN qq(Saved: ${final_name}), RESET '';
say q(> ), GREEN 'All done!', RESET '';

# ================================================================ END

__END__
