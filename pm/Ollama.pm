package Ollama;

use strict;
use warnings;
use utf8;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

# ============================================================================
# OLLAMA CLIENT - Generic prompt/response with streaming support
# ============================================================================

sub new
{
    my ($class, %args) = @_;
    
    my $self = {
        # Connection settings
        base_url => $args{base_url} // 'http://localhost:11434',
        timeout  => $args{timeout}  // 120,
        
        # Default model (override per-request if needed)
        model => $args{model} // 'llama3.2:3b',
        
        # Generation defaults
        temperature    => $args{temperature}    // 0.7,
        top_p          => $args{top_p}          // 0.9,
        repeat_penalty => $args{repeat_penalty} // 1.1,
        max_tokens     => $args{max_tokens}     // 1024,
        
        # Mojo user agent for HTTP
        ua => Mojo::UserAgent->new,
    };
    
    # Set timeouts on the user agent
    # request_timeout = total time for entire request
    # inactivity_timeout = max idle time between data chunks
    $self->{ua}->request_timeout($self->{timeout});
    $self->{ua}->inactivity_timeout($self->{timeout});
    
    return bless $self, $class;
}

# ============================================================================
# BLOCKING REQUEST - Send prompt, wait for complete response
# ============================================================================

sub prompt
{
    my ($self, $prompt_text, %opts) = @_;
    
    # Build the request payload
    my $payload = {
        model   => $opts{model} // $self->{model},
        prompt  => $prompt_text,
        stream  => \0,  # Disable streaming - wait for full response
        options => {
            temperature    => $opts{temperature}    // $self->{temperature},
            top_p          => $opts{top_p}          // $self->{top_p},
            repeat_penalty => $opts{repeat_penalty} // $self->{repeat_penalty},
            num_predict    => $opts{max_tokens}     // $self->{max_tokens},
        },
    };
    
    # Add stop sequences if provided
    if ($opts{stop})
    {
        $payload->{options}{stop} = $opts{stop};
    }
    
    # Add system prompt if provided
    if ($opts{system})
    {
        $payload->{system} = $opts{system};
    }
    
    # POST to Ollama generate endpoint
    my $url = "$self->{base_url}/api/generate";
    my $tx  = $self->{ua}->post(
        $url => {'Content-Type' => 'application/json'} => encode_json($payload)
    );
    
    return $self->_handle_response($tx);
}

# ============================================================================
# STREAMING REQUEST - Send prompt, call handler for each chunk
# ============================================================================

sub prompt_stream
{
    my ($self, $prompt_text, $on_chunk, %opts) = @_;
    
    # Validate callback
    die "on_chunk callback required for streaming" unless ref $on_chunk eq 'CODE';
    
    # Build the request payload
    my $payload = {
        model   => $opts{model} // $self->{model},
        prompt  => $prompt_text,
        stream  => \1,  # Enable streaming
        options => {
            temperature    => $opts{temperature}    // $self->{temperature},
            top_p          => $opts{top_p}          // $self->{top_p},
            repeat_penalty => $opts{repeat_penalty} // $self->{repeat_penalty},
            num_predict    => $opts{max_tokens}     // $self->{max_tokens},
        },
    };
    
    # Add stop sequences if provided
    if ($opts{stop})
    {
        $payload->{options}{stop} = $opts{stop};
    }
    
    # Add system prompt if provided
    if ($opts{system})
    {
        $payload->{system} = $opts{system};
    }
    
    # Accumulate full response text
    my $full_text = '';
    my $final_data;
    
    # POST with streaming - process chunks as they arrive
    my $url = "$self->{base_url}/api/generate";
    my $tx  = $self->{ua}->post(
        $url => {'Content-Type' => 'application/json'} => encode_json($payload)
    );
    
    # Read the response body and parse NDJSON chunks
    my $body = $tx->result->body;
    
    # Each line is a JSON object
    for my $line (split m~\n~, $body)
    {
        next unless $line =~ m~\S~;  # Skip empty lines
        
        my $chunk = eval { decode_json($line) };
        next unless $chunk;
        
        # Extract the token from this chunk
        my $token = $chunk->{response} // '';
        $full_text .= $token;
        
        # Call the user's handler with the token
        $on_chunk->($token, $chunk);
        
        # Save final chunk for metadata
        $final_data = $chunk if $chunk->{done};
    }
    
    # Return complete response
    return {
        success => 1,
        text    => $full_text,
        model   => $final_data->{model} // $self->{model},
        done    => 1,
        raw     => $final_data,
    };
}

# ============================================================================
# CHAT REQUEST - Multi-turn conversation with message history
# ============================================================================

sub chat
{
    my ($self, $messages, %opts) = @_;
    
    # Messages should be arrayref of {role => 'user|assistant|system', content => '...'}
    die "messages must be an arrayref" unless ref $messages eq 'ARRAY';
    
    my $payload = {
        model    => $opts{model} // $self->{model},
        messages => $messages,
        stream   => \0,
        options  => {
            temperature    => $opts{temperature}    // $self->{temperature},
            top_p          => $opts{top_p}          // $self->{top_p},
            repeat_penalty => $opts{repeat_penalty} // $self->{repeat_penalty},
            num_predict    => $opts{max_tokens}     // $self->{max_tokens},
        },
    };
    
    my $url = "$self->{base_url}/api/chat";
    my $tx  = $self->{ua}->post(
        $url => {'Content-Type' => 'application/json'} => encode_json($payload)
    );
    
    return $self->_handle_response($tx);
}

# ============================================================================
# INTERNAL - Parse Ollama API response
# ============================================================================

sub _handle_response
{
    my ($self, $tx) = @_;
    
    my $res = $tx->result;
    
    # Success - parse JSON and extract text
    if ($res->is_success)
    {
        my $data = decode_json($res->body);
        
        # Response text lives in different places for generate vs chat
        my $text = $data->{response} // $data->{message}{content} // '';
        
        return {
            success => 1,
            text    => $text,
            model   => $data->{model},
            done    => $data->{done},
            raw     => $data,
        };
    }
    
    # Failure - return error info
    return {
        success => 0,
        error   => $res->message,
        status  => $res->code,
    };
}

# ============================================================================
# UTILITY - List models available on Ollama server
# ============================================================================

sub list_models
{
    my ($self) = @_;
    
    my $url = "$self->{base_url}/api/tags";
    my $tx  = $self->{ua}->get($url);
    
    if ($tx->result->is_success)
    {
        my $data = decode_json($tx->result->body);
        return {
            success => 1,
            models  => $data->{models} // [],
        };
    }
    
    return {
        success => 0,
        error   => $tx->result->message,
    };
}

# ============================================================================
# UTILITY - Quick health check
# ============================================================================

sub ping
{
    my ($self, $model) = @_;
    
    $model //= $self->{model};
    
    my $result = $self->prompt("Say ok", model => $model, max_tokens => 5);
    return $result->{success};
}

1;

__END__
